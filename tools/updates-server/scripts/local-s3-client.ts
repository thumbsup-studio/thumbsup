import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, readdir, rename, stat, unlink, writeFile } from 'node:fs/promises';
import { dirname, relative, resolve, sep } from 'node:path';
import {
  CopyObjectCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { resolveObjectPath } from '../src/store.js';
import type { S3ClientLike } from './publish-update.js';

function etag(value: Uint8Array): string {
  return `"${createHash('md5').update(value).digest('hex')}"`;
}

function notFound(key: string): Error {
  return Object.assign(new Error(`Local object does not exist: ${key}`), {
    name: 'NoSuchKey',
    $metadata: { httpStatusCode: 404 },
  });
}

function preconditionFailed(key: string): Error {
  return Object.assign(new Error(`Local object precondition failed: ${key}`), {
    name: 'PreconditionFailed',
    $metadata: { httpStatusCode: 412 },
  });
}

async function optionalBytes(path: string): Promise<Uint8Array | undefined> {
  try {
    return await readFile(path);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
    throw error;
  }
}

async function filesBelow(root: string): Promise<string[]> {
  let entries;
  try {
    entries = await readdir(root, { withFileTypes: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }
  const files: string[] = [];
  for (const entry of entries) {
    const path = resolve(root, entry.name);
    if (entry.isDirectory()) files.push(...await filesBelow(path));
    else if (entry.isFile()) files.push(path);
  }
  return files;
}

function bodyBytes(body: unknown): Uint8Array {
  if (typeof body === 'string') return Buffer.from(body);
  if (body instanceof Uint8Array) return body;
  throw new Error('Local object store only accepts string or Uint8Array bodies');
}

export class LocalS3Client implements S3ClientLike {
  private readonly root: string;

  constructor(root: string) {
    this.root = resolve(root);
  }

  async send(command: unknown): Promise<any> {
    if (command instanceof CopyObjectCommand) {
      const key = String(command.input.Key ?? '');
      const copySource = decodeURIComponent(String(command.input.CopySource ?? ''));
      const separator = copySource.indexOf('/');
      if (separator < 0) throw new Error(`Invalid local copy source: ${copySource}`);
      const sourceKey = copySource.slice(separator + 1);
      const bytes = await optionalBytes(resolveObjectPath(this.root, sourceKey));
      if (!bytes) throw notFound(sourceKey);
      const path = resolveObjectPath(this.root, key);
      await mkdir(dirname(path), { recursive: true });
      const temporary = `${path}.${process.pid}.${randomUUID()}.tmp`;
      await writeFile(temporary, bytes);
      await rename(temporary, path);
      return { CopyObjectResult: { ETag: etag(bytes) } };
    }

    if (command instanceof GetObjectCommand) {
      const key = String(command.input.Key ?? '');
      const bytes = await optionalBytes(resolveObjectPath(this.root, key));
      if (!bytes) throw notFound(key);
      return {
        ETag: etag(bytes),
        Body: { transformToByteArray: async () => bytes },
      };
    }

    if (command instanceof PutObjectCommand) {
      const key = String(command.input.Key ?? '');
      const path = resolveObjectPath(this.root, key);
      const current = await optionalBytes(path);
      if (command.input.IfNoneMatch === '*' && current) throw preconditionFailed(key);
      if (command.input.IfMatch && (!current || etag(current) !== command.input.IfMatch)) {
        throw preconditionFailed(key);
      }
      await mkdir(dirname(path), { recursive: true });
      const temporary = `${path}.${process.pid}.${randomUUID()}.tmp`;
      await writeFile(temporary, bodyBytes(command.input.Body));
      await rename(temporary, path);
      return { ETag: etag(await readFile(path)) };
    }

    if (command instanceof ListObjectsV2Command) {
      const prefix = String(command.input.Prefix ?? '');
      const files = await filesBelow(this.root);
      const keys = files
        .map((path) => relative(this.root, path).split(sep).join('/'))
        .filter((key) => key.startsWith(prefix))
        .sort();
      return { Contents: keys.map((Key) => ({ Key })), IsTruncated: false };
    }

    if (command instanceof DeleteObjectsCommand) {
      for (const object of command.input.Delete?.Objects ?? []) {
        if (!object.Key) continue;
        const path = resolveObjectPath(this.root, object.Key);
        try {
          if ((await stat(path)).isFile()) await unlink(path);
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
        }
      }
      return {};
    }

    throw new Error(`Unsupported local S3 command: ${command?.constructor?.name ?? typeof command}`);
  }
}

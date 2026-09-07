import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { readFile } from 'node:fs/promises';
import { isAbsolute, relative, resolve, sep } from 'node:path';
import type { ObjectStore } from './types.js';

export function resolveObjectPath(root: string, key: string): string {
  if (!key || isAbsolute(key) || key.split('/').includes('..')) {
    throw new Error(`Unsafe object key: ${key}`);
  }
  const resolvedRoot = resolve(root);
  const path = resolve(resolvedRoot, ...key.split('/'));
  const value = relative(resolvedRoot, path).split(sep).join('/');
  if (!value || value === '..' || value.startsWith('../')) {
    throw new Error(`Unsafe object key: ${key}`);
  }
  return path;
}

export class LocalObjectStore implements ObjectStore {
  constructor(private readonly root: string) {}

  async get(key: string): Promise<Uint8Array> {
    return readFile(resolveObjectPath(this.root, key));
  }
}

export class S3ObjectStore implements ObjectStore {
  constructor(
    private readonly bucket: string,
    private readonly client = new S3Client({}),
  ) {}

  async get(key: string): Promise<Uint8Array> {
    const response = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    if (!response.Body) {
      throw new Error(`S3 object has no body: ${key}`);
    }
    return response.Body.transformToByteArray();
  }
}

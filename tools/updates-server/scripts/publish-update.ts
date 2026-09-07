import { readdir, readFile, stat } from 'node:fs/promises';
import { extname, join, relative, resolve, sep } from 'node:path';
import {
  DeleteObjectsCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import type { ChannelIndex, ChannelUpdate, Platform, UpdateMetadata } from '../src/types.js';

const INDEX_KEY = 'channels/index.json';
const MAX_INDEX_ATTEMPTS = 6;
const decoder = new TextDecoder();

export interface PrArtifactMetadata {
  schemaVersion: 1;
  runtimeVersion: string;
  commit: string;
  prNumber: number;
  branch: string;
  title: string;
  createdAt: string;
}

export interface S3ClientLike {
  send(command: unknown): Promise<any>;
}

export interface PublishOptions {
  artifactDir: string;
  bucket: string;
  prNumber: number;
  commit: string;
  channel?: string;
  client?: S3ClientLike;
  sleep?: (milliseconds: number) => Promise<void>;
}

export interface CleanupOptions {
  bucket: string;
  prNumber: number;
  client?: S3ClientLike;
  sleep?: (milliseconds: number) => Promise<void>;
}

interface IndexSnapshot {
  index: ChannelIndex;
  etag?: string;
}

function assertPrNumber(value: number): void {
  if (!Number.isSafeInteger(value) || value <= 0) throw new Error(`Invalid PR number: ${value}`);
}

function assertCommit(value: string): void {
  if (!/^[0-9a-f]{40}$/i.test(value)) throw new Error(`Invalid commit SHA: ${value}`);
}

function assertChannel(value: string): void {
  if (!/^[A-Za-z0-9._-]+$/.test(value)) throw new Error(`Invalid channel: ${value}`);
}

function isNotFound(error: unknown): boolean {
  const candidate = error as { name?: string; $metadata?: { httpStatusCode?: number } };
  return candidate?.name === 'NoSuchKey' || candidate?.name === 'NotFound' || candidate?.$metadata?.httpStatusCode === 404;
}

function isPreconditionFailure(error: unknown): boolean {
  const candidate = error as { name?: string; $metadata?: { httpStatusCode?: number } };
  return candidate?.name === 'PreconditionFailed' || candidate?.$metadata?.httpStatusCode === 412;
}

function contentType(path: string): string {
  const types: Record<string, string> = {
    '.bundle': 'application/javascript',
    '.hbc': 'application/octet-stream',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
  };
  return types[extname(path).toLowerCase()] ?? 'application/octet-stream';
}

function parseJson<T>(bytes: Uint8Array): T {
  return JSON.parse(decoder.decode(bytes)) as T;
}

async function bodyBytes(body: { transformToByteArray(): Promise<Uint8Array> } | undefined): Promise<Uint8Array> {
  if (!body) throw new Error('S3 object has no body');
  return body.transformToByteArray();
}

async function loadIndex(client: S3ClientLike, bucket: string): Promise<IndexSnapshot> {
  try {
    const response = await client.send(new GetObjectCommand({ Bucket: bucket, Key: INDEX_KEY }));
    return {
      index: parseJson<ChannelIndex>(await bodyBytes(response.Body)),
      etag: response.ETag,
    };
  } catch (error) {
    if (isNotFound(error)) return { index: { channels: {} } };
    throw error;
  }
}

async function updateIndex(
  client: S3ClientLike,
  bucket: string,
  mutate: (index: ChannelIndex) => ChannelIndex,
  sleep: (milliseconds: number) => Promise<void>,
): Promise<void> {
  for (let attempt = 0; attempt < MAX_INDEX_ATTEMPTS; attempt += 1) {
    const snapshot = await loadIndex(client, bucket);
    const next = mutate(structuredClone(snapshot.index));
    try {
      await client.send(new PutObjectCommand({
        Bucket: bucket,
        Key: INDEX_KEY,
        Body: `${JSON.stringify(next, null, 2)}\n`,
        ContentType: 'application/json',
        CacheControl: 'no-cache',
        ...(snapshot.etag ? { IfMatch: snapshot.etag } : { IfNoneMatch: '*' }),
      }));
      return;
    } catch (error) {
      if (!isPreconditionFailure(error) || attempt === MAX_INDEX_ATTEMPTS - 1) throw error;
      await sleep(50 * (2 ** attempt));
    }
  }
}

async function filesBelow(root: string): Promise<string[]> {
  const entries = await readdir(root, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const path = join(root, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`Symbolic links are not allowed in update artifacts: ${path}`);
    if (entry.isDirectory()) files.push(...await filesBelow(path));
    else if (entry.isFile()) files.push(path);
  }
  return files.sort();
}

function safeRelativePath(root: string, path: string): string {
  const value = relative(resolve(root), resolve(path)).split(sep).join('/');
  if (!value || value === '..' || value.startsWith('../')) throw new Error(`Unsafe artifact path: ${path}`);
  return value;
}

function validateExportMetadata(metadata: UpdateMetadata, runtimeVersion: string): void {
  for (const platform of ['ios', 'android'] satisfies Platform[]) {
    const files = metadata.fileMetadata?.[platform];
    if (!files?.bundle) throw new Error(`Expo export metadata is missing ${platform} bundle`);
    for (const path of [files.bundle, ...files.assets.map((asset) => asset.path)]) {
      if (!path || path.startsWith('/') || path.split('/').includes('..')) {
        throw new Error(`Unsafe path in Expo export metadata: ${path}`);
      }
    }
  }
  metadata.extra = { ...metadata.extra, runtimeVersion };
}

function nativeAssetPaths(metadata: UpdateMetadata): Set<string> {
  const paths = new Set<string>();
  for (const platform of ['ios', 'android'] satisfies Platform[]) {
    const files = metadata.fileMetadata[platform];
    paths.add(files.bundle);
    for (const asset of files.assets) paths.add(asset.path);
  }
  return paths;
}

export async function publishUpdate(options: PublishOptions): Promise<{ channel: string; updateId: string }> {
  assertPrNumber(options.prNumber);
  assertCommit(options.commit);
  const client = options.client ?? new S3Client({});
  const sleep = options.sleep ?? ((milliseconds) => new Promise((accept) => setTimeout(accept, milliseconds)));
  const artifactDir = resolve(options.artifactDir);
  const exportDir = join(artifactDir, 'dist');
  const artifact = JSON.parse(await readFile(join(artifactDir, 'metadata.json'), 'utf8')) as PrArtifactMetadata;
  if (artifact.schemaVersion !== 1 || artifact.prNumber !== options.prNumber || artifact.commit !== options.commit) {
    throw new Error('Artifact provenance does not match the trusted workflow_run payload');
  }
  if (!artifact.runtimeVersion || !artifact.branch || !artifact.title || !Number.isFinite(Date.parse(artifact.createdAt))) {
    throw new Error('Artifact metadata is incomplete');
  }

  const exportMetadataPath = join(exportDir, 'metadata.json');
  const exportMetadata = JSON.parse(await readFile(exportMetadataPath, 'utf8')) as UpdateMetadata;
  validateExportMetadata(exportMetadata, artifact.runtimeVersion);
  const channel = options.channel ?? `pr-${options.prNumber}`;
  assertChannel(channel);
  exportMetadata.extra = {
    ...exportMetadata.extra,
    updateChannel: channel,
    pullRequest: {
      number: artifact.prNumber,
      branch: artifact.branch,
      title: artifact.title,
      commit: artifact.commit,
    },
  };

  const updateId = options.commit;
  const prefix = `updates/${channel}/${updateId}`;
  const allFiles = await filesBelow(exportDir);
  const filesByPath = new Map(allFiles.map((path) => [safeRelativePath(exportDir, path), path]));
  const assetFiles = [...nativeAssetPaths(exportMetadata)].sort().map((path) => {
    const file = filesByPath.get(path);
    if (!file) throw new Error(`Expo export metadata references a missing file: ${path}`);
    return file;
  });
  for (const path of assetFiles) {
    const objectPath = safeRelativePath(exportDir, path);
    const file = await stat(path);
    if (!file.isFile()) throw new Error(`Update asset is not a regular file: ${path}`);
    await client.send(new PutObjectCommand({
      Bucket: options.bucket,
      Key: `${prefix}/${objectPath}`,
      Body: await readFile(path),
      ContentType: contentType(path),
      CacheControl: 'public, max-age=31536000, immutable',
    }));
  }

  await client.send(new PutObjectCommand({
    Bucket: options.bucket,
    Key: `${prefix}/metadata.json`,
    Body: `${JSON.stringify(exportMetadata, null, 2)}\n`,
    ContentType: 'application/json',
    CacheControl: 'no-cache',
  }));

  const entry: ChannelUpdate = {
    updateId,
    runtimeVersion: artifact.runtimeVersion,
    createdAt: artifact.createdAt,
    prNumber: artifact.prNumber,
    branch: artifact.branch,
    title: artifact.title,
    commit: artifact.commit,
  };
  await updateIndex(client, options.bucket, (index) => {
    const existing = index.channels[channel] ?? [];
    index.channels[channel] = [
      entry,
      ...existing.filter((item) => item.type === 'rollback' || item.updateId !== updateId),
    ];
    return index;
  }, sleep);
  return { channel, updateId };
}

export async function cleanupUpdate(options: CleanupOptions): Promise<void> {
  assertPrNumber(options.prNumber);
  const client = options.client ?? new S3Client({});
  const sleep = options.sleep ?? ((milliseconds) => new Promise((accept) => setTimeout(accept, milliseconds)));
  const channel = `pr-${options.prNumber}`;
  await updateIndex(client, options.bucket, (index) => {
    delete index.channels[channel];
    return index;
  }, sleep);

  const prefix = `updates/${channel}/`;
  let continuationToken: string | undefined;
  do {
    const page = await client.send(new ListObjectsV2Command({
      Bucket: options.bucket,
      Prefix: prefix,
      ContinuationToken: continuationToken,
    }));
    const objects = (page.Contents ?? []).flatMap((item: { Key?: string }) => item.Key ? [{ Key: item.Key }] : []);
    if (objects.length > 0) {
      await client.send(new DeleteObjectsCommand({
        Bucket: options.bucket,
        Delete: { Objects: objects, Quiet: true },
      }));
    }
    continuationToken = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (continuationToken);
}

function argumentsFrom(argv: string[]): Record<string, string> {
  const values: Record<string, string> = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) throw new Error(`Invalid argument near ${key ?? '<end>'}`);
    values[key.slice(2)] = value;
  }
  return values;
}

async function main(): Promise<void> {
  const [command, ...rest] = process.argv.slice(2);
  const args = argumentsFrom(rest);
  const localStore = args['local-store'];
  const bucket = args.bucket ?? process.env.ARTIFACTS_BUCKET ?? (localStore ? 'local' : undefined);
  const prNumber = Number(args.pr);
  if (!bucket) throw new Error('--bucket or ARTIFACTS_BUCKET is required');
  if (command === 'publish') {
    if (!args['artifact-dir'] || !args.commit) throw new Error('publish requires --artifact-dir and --commit');
    const client = localStore
      ? new (await import('./local-s3-client.js')).LocalS3Client(localStore)
      : undefined;
    const result = await publishUpdate({
      artifactDir: args['artifact-dir'], bucket, prNumber, commit: args.commit,
      channel: args.channel,
      client,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }
  if (command === 'cleanup') {
    const client = localStore
      ? new (await import('./local-s3-client.js')).LocalS3Client(localStore)
      : undefined;
    await cleanupUpdate({ bucket, prNumber, client });
    return;
  }
  throw new Error('First argument must be publish or cleanup');
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname)) {
  await main();
}

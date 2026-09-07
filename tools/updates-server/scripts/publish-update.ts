import { readdir, readFile, stat } from 'node:fs/promises';
import { extname, join, relative, resolve, sep } from 'node:path';
import {
  CopyObjectCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import type {
  ChannelIndex,
  ChannelRollback,
  ChannelUpdate,
  Platform,
  UpdateMetadata,
} from '../src/types.js';

const INDEX_KEY = 'channels/index.json';
const MAX_INDEX_ATTEMPTS = 6;
const decoder = new TextDecoder();

export interface PrArtifactMetadata {
  schemaVersion: 1;
  runtimeVersion: string;
  commit: string;
  prNumber?: number;
  branch: string;
  title: string;
  createdAt: string;
  releaseTag?: string;
}

export interface S3ClientLike {
  send(command: unknown): Promise<any>;
}

export interface PublishOptions {
  artifactDir: string;
  bucket: string;
  prNumber?: number;
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

export interface PromoteOptions {
  bucket: string;
  from: string;
  to: string;
  updateId: string;
  runtimeVersion?: string;
  rolloutPercentage?: number;
  dryRun?: boolean;
  client?: S3ClientLike;
  sleep?: (milliseconds: number) => Promise<void>;
  now?: () => string;
}

export interface RollbackOptions {
  bucket: string;
  channel: string;
  to: string;
  runtimeVersion?: string;
  commitTime?: string;
  dryRun?: boolean;
  client?: S3ClientLike;
  sleep?: (milliseconds: number) => Promise<void>;
  now?: () => string;
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

function assertUpdateId(value: string): void {
  if (!/^(?:[0-9a-f]{32,64}|[0-9a-f]{8}-[0-9a-f-]{27})$/i.test(value)) {
    throw new Error(`Invalid update ID: ${value}`);
  }
}

function assertRolloutPercentage(value: number): void {
  if (!Number.isInteger(value) || value < 0 || value > 100) {
    throw new Error(`Invalid rollout percentage: ${value}`);
  }
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
  if (options.prNumber !== undefined) assertPrNumber(options.prNumber);
  assertCommit(options.commit);
  const client = options.client ?? new S3Client({});
  const sleep = options.sleep ?? ((milliseconds) => new Promise((accept) => setTimeout(accept, milliseconds)));
  const artifactDir = resolve(options.artifactDir);
  const exportDir = join(artifactDir, 'dist');
  const artifact = JSON.parse(await readFile(join(artifactDir, 'metadata.json'), 'utf8')) as PrArtifactMetadata;
  if (
    artifact.schemaVersion !== 1 ||
    artifact.commit !== options.commit ||
    (options.prNumber !== undefined && artifact.prNumber !== options.prNumber) ||
    (options.prNumber === undefined && artifact.prNumber !== undefined)
  ) {
    throw new Error('Artifact provenance does not match the trusted workflow_run payload');
  }
  if (!artifact.runtimeVersion || !artifact.branch || !artifact.title || !Number.isFinite(Date.parse(artifact.createdAt))) {
    throw new Error('Artifact metadata is incomplete');
  }
  if (options.prNumber === undefined && !artifact.releaseTag) {
    throw new Error('Release artifact metadata is missing releaseTag');
  }

  const exportMetadataPath = join(exportDir, 'metadata.json');
  const exportMetadata = JSON.parse(await readFile(exportMetadataPath, 'utf8')) as UpdateMetadata;
  validateExportMetadata(exportMetadata, artifact.runtimeVersion);
  if (!options.channel && options.prNumber === undefined) {
    throw new Error('A channel is required when publishing a non-PR artifact');
  }
  const channel = options.channel ?? `pr-${options.prNumber}`;
  assertChannel(channel);
  exportMetadata.extra = {
    ...exportMetadata.extra,
    ...(artifact.prNumber !== undefined
      ? { updateChannel: channel }
      : { sourceChannel: channel }),
    ...(artifact.prNumber !== undefined
      ? {
          pullRequest: {
            number: artifact.prNumber,
            branch: artifact.branch,
            title: artifact.title,
            commit: artifact.commit,
          },
        }
      : {
          release: {
            tag: artifact.releaseTag,
            branch: artifact.branch,
            title: artifact.title,
            commit: artifact.commit,
          },
        }),
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

export async function promoteUpdate(
  options: PromoteOptions,
): Promise<{ from: string; to: string; updateId: string; copiedObjects: number; dryRun: boolean }> {
  assertChannel(options.from);
  assertChannel(options.to);
  assertUpdateId(options.updateId);
  if (options.from === options.to) throw new Error('Promotion source and target channels must differ');
  const rolloutPercentage = options.rolloutPercentage ?? 100;
  assertRolloutPercentage(rolloutPercentage);
  const client = options.client ?? new S3Client({});
  const sleep = options.sleep ?? ((milliseconds) => new Promise((accept) => setTimeout(accept, milliseconds)));
  const sourceSnapshot = await loadIndex(client, options.bucket);
  const source = sourceSnapshot.index.channels[options.from]?.find(
    (entry): entry is ChannelUpdate => entry.type !== 'rollback' && entry.updateId === options.updateId,
  );
  if (!source) throw new Error(`Update ${options.updateId} does not exist in ${options.from}`);
  if (options.runtimeVersion && source.runtimeVersion !== options.runtimeVersion) {
    throw new Error(
      `runtimeVersion mismatch: update=${source.runtimeVersion}, expected=${options.runtimeVersion}`,
    );
  }

  const sourcePrefix = `updates/${options.from}/${options.updateId}`;
  const targetPrefix = `updates/${options.to}/${options.updateId}`;
  const metadataResponse = await client.send(new GetObjectCommand({
    Bucket: options.bucket,
    Key: `${sourcePrefix}/metadata.json`,
  }));
  const metadata = parseJson<UpdateMetadata>(await bodyBytes(metadataResponse.Body));
  const metadataRuntimeVersion = metadata.extra?.runtimeVersion;
  if (metadataRuntimeVersion !== source.runtimeVersion) {
    throw new Error(
      `runtimeVersion mismatch: index=${source.runtimeVersion}, metadata=${String(metadataRuntimeVersion)}`,
    );
  }

  let continuationToken: string | undefined;
  const objectKeys: string[] = [];
  do {
    const page = await client.send(new ListObjectsV2Command({
      Bucket: options.bucket,
      Prefix: `${sourcePrefix}/`,
      ContinuationToken: continuationToken,
    }));
    objectKeys.push(...(page.Contents ?? []).flatMap(
      (item: { Key?: string }) => item.Key ? [item.Key] : [],
    ));
    continuationToken = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (continuationToken);
  if (!objectKeys.includes(`${sourcePrefix}/metadata.json`)) {
    throw new Error(`Update ${options.updateId} has no metadata object in ${options.from}`);
  }

  if (!options.dryRun) {
    for (const sourceKey of objectKeys.sort()) {
      const targetKey = `${targetPrefix}/${sourceKey.slice(sourcePrefix.length + 1)}`;
      await client.send(new CopyObjectCommand({
        Bucket: options.bucket,
        Key: targetKey,
        CopySource: encodeURIComponent(`${options.bucket}/${sourceKey}`).replace(/%2F/g, '/'),
        MetadataDirective: 'COPY',
      }));
    }
    const promotedAt = options.now?.() ?? new Date().toISOString();
    await updateIndex(client, options.bucket, (index) => {
      const existing = index.channels[options.to] ?? [];
      const entry: ChannelUpdate = {
        ...source,
        createdAt: promotedAt,
        rolloutPercentage,
      };
      index.channels[options.to] = [
        entry,
        ...existing.filter((item) => item.type === 'rollback' || item.updateId !== options.updateId),
      ];
      return index;
    }, sleep);
  }
  return {
    from: options.from,
    to: options.to,
    updateId: options.updateId,
    copiedObjects: objectKeys.length,
    dryRun: options.dryRun ?? false,
  };
}

export async function rollbackUpdate(
  options: RollbackOptions,
): Promise<{ channel: string; to: string; dryRun: boolean }> {
  assertChannel(options.channel);
  const client = options.client ?? new S3Client({});
  const sleep = options.sleep ?? ((milliseconds) => new Promise((accept) => setTimeout(accept, milliseconds)));
  const snapshot = await loadIndex(client, options.bucket);
  const entries = snapshot.index.channels[options.channel] ?? [];
  const createdAt = options.now?.() ?? new Date().toISOString();
  let next: ChannelUpdate | ChannelRollback;
  if (options.to === 'embedded') {
    if (!options.runtimeVersion) throw new Error('Embedded rollback requires --runtime-version');
    const commitTime = options.commitTime ?? createdAt;
    if (!Number.isFinite(Date.parse(commitTime))) throw new Error(`Invalid commit time: ${commitTime}`);
    next = {
      type: 'rollback',
      runtimeVersion: options.runtimeVersion,
      createdAt,
      commitTime,
    };
  } else {
    assertUpdateId(options.to);
    const selected = entries.find(
      (entry): entry is ChannelUpdate => entry.type !== 'rollback' && entry.updateId === options.to,
    );
    if (!selected) throw new Error(`Update ${options.to} does not exist in ${options.channel}`);
    next = { ...selected, createdAt, rolloutPercentage: 100 };
  }

  if (!options.dryRun) {
    await updateIndex(client, options.bucket, (index) => {
      const current = index.channels[options.channel] ?? [];
      index.channels[options.channel] = [next, ...current];
      return index;
    }, sleep);
  }
  return { channel: options.channel, to: options.to, dryRun: options.dryRun ?? false };
}

function argumentsFrom(argv: string[]): Record<string, string | boolean> {
  const values: Record<string, string | boolean> = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key?.startsWith('--')) throw new Error(`Invalid argument near ${key ?? '<end>'}`);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      values[key.slice(2)] = true;
    } else {
      values[key.slice(2)] = value;
      index += 1;
    }
  }
  return values;
}

async function main(): Promise<void> {
  const [command, ...rest] = process.argv.slice(2);
  const args = argumentsFrom(rest);
  const stringArg = (name: string): string | undefined =>
    typeof args[name] === 'string' ? args[name] : undefined;
  const localStore = stringArg('local-store');
  const bucket = stringArg('bucket') ?? process.env.ARTIFACTS_BUCKET ?? (localStore ? 'local' : undefined);
  const prNumber = stringArg('pr') === undefined ? undefined : Number(stringArg('pr'));
  if (!bucket) throw new Error('--bucket or ARTIFACTS_BUCKET is required');
  if (command === 'publish') {
    if (!stringArg('artifact-dir') || !stringArg('commit')) throw new Error('publish requires --artifact-dir and --commit');
    const client = localStore
      ? new (await import('./local-s3-client.js')).LocalS3Client(localStore)
      : undefined;
    const result = await publishUpdate({
      artifactDir: stringArg('artifact-dir')!, bucket, prNumber, commit: stringArg('commit')!,
      channel: stringArg('channel'),
      client,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }
  if (command === 'cleanup') {
    if (prNumber === undefined) throw new Error('cleanup requires --pr');
    const client = localStore
      ? new (await import('./local-s3-client.js')).LocalS3Client(localStore)
      : undefined;
    await cleanupUpdate({ bucket, prNumber, client });
    return;
  }
  const client = localStore
    ? new (await import('./local-s3-client.js')).LocalS3Client(localStore)
    : undefined;
  if (command === 'promote') {
    const from = stringArg('from');
    const to = stringArg('to');
    const updateId = stringArg('update-id');
    if (!from || !to || !updateId) throw new Error('promote requires --from, --update-id, and --to');
    const rollout = stringArg('rollout-percentage');
    const result = await promoteUpdate({
      bucket,
      from,
      to,
      updateId,
      runtimeVersion: stringArg('runtime-version'),
      rolloutPercentage: rollout === undefined ? undefined : Number(rollout),
      dryRun: args['dry-run'] === true,
      client,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }
  if (command === 'rollback') {
    const channel = stringArg('channel');
    const to = stringArg('to');
    if (!channel || !to) throw new Error('rollback requires --channel and --to');
    const result = await rollbackUpdate({
      bucket,
      channel,
      to,
      runtimeVersion: stringArg('runtime-version'),
      commitTime: stringArg('commit-time'),
      dryRun: args['dry-run'] === true,
      client,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }
  throw new Error('First argument must be publish, cleanup, promote, or rollback');
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname)) {
  await main();
}

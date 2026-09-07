import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { mkdtemp } from 'node:fs/promises';
import {
  CopyObjectCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { describe, expect, it } from 'vitest';
import {
  cleanupUpdate,
  promoteUpdate,
  publishUpdate,
  rollbackUpdate,
  type S3ClientLike,
} from '../scripts/publish-update.js';
import { LocalS3Client } from '../scripts/local-s3-client.js';

const sha = '0123456789abcdef0123456789abcdef01234567';
const execFileAsync = promisify(execFile);

async function artifact(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), 'thumbsup-pr-bundle-'));
  await mkdir(join(root, 'dist', '_expo', 'static', 'js', 'ios'), { recursive: true });
  await mkdir(join(root, 'dist', '_expo', 'static', 'js', 'android'), { recursive: true });
  await writeFile(join(root, 'metadata.json'), JSON.stringify({
    schemaVersion: 1,
    runtimeVersion: '0.1.0',
    commit: sha,
    prNumber: 348,
    branch: 'feat/348-pr-bundle-publish',
    title: 'safe publish',
    createdAt: '2026-09-08T00:00:00.000Z',
  }));
  await writeFile(join(root, 'dist', 'metadata.json'), JSON.stringify({
    version: 0,
    bundler: 'metro',
    fileMetadata: {
      ios: { bundle: '_expo/static/js/ios/app.hbc', assets: [] },
      android: { bundle: '_expo/static/js/android/app.hbc', assets: [] },
    },
  }));
  await writeFile(join(root, 'dist', '_expo', 'static', 'js', 'ios', 'app.hbc'), 'ios');
  await writeFile(join(root, 'dist', '_expo', 'static', 'js', 'android', 'app.hbc'), 'android');
  return root;
}

function stream(value: object): { transformToByteArray(): Promise<Uint8Array> } {
  return { transformToByteArray: async () => new TextEncoder().encode(JSON.stringify(value)) };
}

describe('publishUpdate', () => {
  it('publishes an artifact to a local directory with a selected channel', async () => {
    const root = await mkdtemp(join(tmpdir(), 'thumbsup-local-store-'));
    const result = await publishUpdate({
      artifactDir: await artifact(),
      bucket: 'local',
      prNumber: 348,
      commit: sha,
      channel: 'staging',
      client: new LocalS3Client(root),
    });

    expect(result).toEqual({ channel: 'staging', updateId: sha });
    const index = JSON.parse(await readFile(join(root, 'channels', 'index.json'), 'utf8'));
    expect(index.channels.staging[0]).toMatchObject({ updateId: sha, runtimeVersion: '0.1.0' });
    const metadata = JSON.parse(await readFile(
      join(root, 'updates', 'staging', sha, 'metadata.json'),
      'utf8',
    ));
    expect(metadata.extra.updateChannel).toBe('staging');
    expect(await readFile(
      join(root, 'updates', 'staging', sha, '_expo', 'static', 'js', 'android', 'app.hbc'),
      'utf8',
    )).toBe('android');
  });

  it('uploads assets before metadata and exposes the update with an ETag conditional write', async () => {
    const commands: unknown[] = [];
    const client: S3ClientLike = {
      async send(command) {
        commands.push(command);
        if (command instanceof GetObjectCommand) {
          return { ETag: '"index-v1"', Body: stream({ channels: {} }) };
        }
        return {};
      },
    };
    await publishUpdate({
      artifactDir: await artifact(), bucket: 'bucket', prNumber: 348, commit: sha, client,
    });
    const puts = commands.filter((command): command is PutObjectCommand => command instanceof PutObjectCommand);
    expect(puts.map((command) => command.input.Key)).toEqual([
      `updates/pr-348/${sha}/_expo/static/js/android/app.hbc`,
      `updates/pr-348/${sha}/_expo/static/js/ios/app.hbc`,
      `updates/pr-348/${sha}/metadata.json`,
      'channels/index.json',
    ]);
    expect(puts.at(-1)?.input.IfMatch).toBe('"index-v1"');
    expect(puts.at(-1)?.input.IfNoneMatch).toBeUndefined();
    const indexBody = JSON.parse(String(puts.at(-1)?.input.Body));
    expect(indexBody.channels['pr-348'][0]).toMatchObject({
      prNumber: 348,
      branch: 'feat/348-pr-bundle-publish',
      title: 'safe publish',
      commit: sha,
      runtimeVersion: '0.1.0',
    });
  });

  it('reloads and retries the index after a competing conditional write', async () => {
    let reads = 0;
    let indexWrites = 0;
    const client: S3ClientLike = {
      async send(command) {
        if (command instanceof GetObjectCommand) {
          reads += 1;
          return { ETag: `"v${reads}"`, Body: stream({ channels: reads === 1 ? {} : { 'pr-999': [] } }) };
        }
        if (command instanceof PutObjectCommand && command.input.Key === 'channels/index.json') {
          indexWrites += 1;
          if (indexWrites === 1) throw Object.assign(new Error('race'), { name: 'PreconditionFailed' });
        }
        return {};
      },
    };
    await publishUpdate({
      artifactDir: await artifact(), bucket: 'bucket', prNumber: 348, commit: sha, client,
      sleep: async () => undefined,
    });
    expect(reads).toBe(2);
    expect(indexWrites).toBe(2);
  });

  it('rejects artifact provenance that differs from workflow_run', async () => {
    await expect(publishUpdate({
      artifactDir: await artifact(), bucket: 'bucket', prNumber: 349, commit: sha,
      client: { send: async () => ({}) },
    })).rejects.toThrow('provenance');
  });
});

describe('cleanupUpdate', () => {
  it('removes the channel before deleting all objects in its PR prefix', async () => {
    const commands: unknown[] = [];
    const client: S3ClientLike = {
      async send(command) {
        commands.push(command);
        if (command instanceof GetObjectCommand) {
          return { ETag: '"v1"', Body: stream({ channels: { 'pr-348': [], production: [] } }) };
        }
        if (command instanceof ListObjectsV2Command) {
          return { Contents: [{ Key: 'updates/pr-348/id/asset' }] };
        }
        return {};
      },
    };
    await cleanupUpdate({ bucket: 'bucket', prNumber: 348, client });
    expect(commands.findIndex((command) => command instanceof PutObjectCommand))
      .toBeLessThan(commands.findIndex((command) => command instanceof DeleteObjectsCommand));
    const list = commands.find((command): command is ListObjectsV2Command => command instanceof ListObjectsV2Command);
    expect(list).toBeDefined();
    if (!list) throw new Error('ListObjectsV2Command was not sent');
    expect(list.input.Prefix).toBe('updates/pr-348/');
  });
});

describe('promoteUpdate', () => {
  it('copies the exact staging objects and advances the production pointer', async () => {
    const root = await mkdtemp(join(tmpdir(), 'thumbsup-promote-store-'));
    await publishUpdate({
      artifactDir: await artifact(),
      bucket: 'local',
      prNumber: 348,
      commit: sha,
      channel: 'staging',
      client: new LocalS3Client(root),
    });
    const result = await promoteUpdate({
      bucket: 'local',
      from: 'staging',
      to: 'production',
      updateId: sha,
      runtimeVersion: '0.1.0',
      rolloutPercentage: 25,
      client: new LocalS3Client(root),
      now: () => '2026-09-09T00:00:00.000Z',
    });

    expect(result).toMatchObject({ updateId: sha, copiedObjects: 3, dryRun: false });
    expect(await readFile(
      join(root, 'updates', 'production', sha, '_expo', 'static', 'js', 'ios', 'app.hbc'),
      'utf8',
    )).toBe('ios');
    const index = JSON.parse(await readFile(join(root, 'channels', 'index.json'), 'utf8'));
    expect(index.channels.production[0]).toMatchObject({
      updateId: sha,
      runtimeVersion: '0.1.0',
      rolloutPercentage: 25,
      createdAt: '2026-09-09T00:00:00.000Z',
    });
  });

  it('validates runtimeVersion and makes no copy during dry-run', async () => {
    const commands: unknown[] = [];
    const client: S3ClientLike = {
      async send(command) {
        commands.push(command);
        if (command instanceof GetObjectCommand) {
          if (command.input.Key === 'channels/index.json') {
            return { ETag: '"v1"', Body: stream({ channels: { staging: [{
              updateId: sha, runtimeVersion: '0.1.0', createdAt: '2026-09-08T00:00:00.000Z',
            }] } }) };
          }
          return { Body: stream({ extra: { runtimeVersion: '0.1.0' } }) };
        }
        if (command instanceof ListObjectsV2Command) {
          return { Contents: [{ Key: `updates/staging/${sha}/metadata.json` }] };
        }
        return {};
      },
    };
    await expect(promoteUpdate({
      bucket: 'bucket', from: 'staging', to: 'production', updateId: sha,
      runtimeVersion: '9.9.9', client,
    })).rejects.toThrow('runtimeVersion mismatch');
    const result = await promoteUpdate({
      bucket: 'bucket', from: 'staging', to: 'production', updateId: sha,
      runtimeVersion: '0.1.0', dryRun: true, client,
    });
    expect(result.dryRun).toBe(true);
    expect(commands.some((command) => command instanceof CopyObjectCommand)).toBe(false);
    expect(commands.some((command) => command instanceof PutObjectCommand)).toBe(false);
  });
});

describe('rollbackUpdate', () => {
  it('moves a previous production update to the channel head', async () => {
    const root = await mkdtemp(join(tmpdir(), 'thumbsup-rollback-store-'));
    await mkdir(join(root, 'channels'), { recursive: true });
    await writeFile(join(root, 'channels', 'index.json'), JSON.stringify({ channels: {
      production: [{ updateId: sha, runtimeVersion: '0.1.0', createdAt: '2026-09-08T00:00:00.000Z' }],
    } }));
    await rollbackUpdate({
      bucket: 'local', channel: 'production', to: sha, client: new LocalS3Client(root),
      now: () => '2026-09-09T00:00:00.000Z',
    });
    const index = JSON.parse(await readFile(join(root, 'channels', 'index.json'), 'utf8'));
    expect(index.channels.production[0]).toMatchObject({
      updateId: sha, rolloutPercentage: 100, createdAt: '2026-09-09T00:00:00.000Z',
    });
  });

  it('writes an embedded rollback directive for the kill switch', async () => {
    const root = await mkdtemp(join(tmpdir(), 'thumbsup-kill-switch-store-'));
    await mkdir(join(root, 'channels'), { recursive: true });
    await writeFile(join(root, 'channels', 'index.json'), JSON.stringify({ channels: {} }));
    await rollbackUpdate({
      bucket: 'local', channel: 'production', to: 'embedded', runtimeVersion: '0.1.0',
      commitTime: '2026-09-07T00:00:00.000Z', client: new LocalS3Client(root),
      now: () => '2026-09-09T00:00:00.000Z',
    });
    const index = JSON.parse(await readFile(join(root, 'channels', 'index.json'), 'utf8'));
    expect(index.channels.production[0]).toEqual({
      type: 'rollback',
      runtimeVersion: '0.1.0',
      createdAt: '2026-09-09T00:00:00.000Z',
      commitTime: '2026-09-07T00:00:00.000Z',
    });
  });
});

it('parses the promote --dry-run CLI without mutating the local store', async () => {
  const root = await mkdtemp(join(tmpdir(), 'thumbsup-cli-dry-run-'));
  await publishUpdate({
    artifactDir: await artifact(), bucket: 'local', prNumber: 348, commit: sha,
    channel: 'staging', client: new LocalS3Client(root),
  });
  const { stdout } = await execFileAsync('pnpm', [
    'exec', 'tsx', 'scripts/publish-update.ts', 'promote',
    '--local-store', root, '--from', 'staging', '--update-id', sha,
    '--to', 'production', '--runtime-version', '0.1.0', '--dry-run',
  ], { cwd: new URL('..', import.meta.url) });

  expect(JSON.parse(stdout)).toMatchObject({ updateId: sha, dryRun: true, copiedObjects: 3 });
  const index = JSON.parse(await readFile(join(root, 'channels', 'index.json'), 'utf8'));
  expect(index.channels.production).toBeUndefined();
});

import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { mkdtemp } from 'node:fs/promises';
import {
  DeleteObjectsCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { describe, expect, it } from 'vitest';
import { cleanupUpdate, publishUpdate, type S3ClientLike } from '../scripts/publish-update.js';

const sha = '0123456789abcdef0123456789abcdef01234567';

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

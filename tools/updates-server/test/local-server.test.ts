import { once } from 'node:events';
import { mkdir, writeFile } from 'node:fs/promises';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { mkdtemp } from 'node:fs/promises';
import { afterEach, describe, expect, it } from 'vitest';
import { createLocalServer } from '../scripts/local-server.js';

const updateId = 'b15ed6d8f39b04ada248fa3b95fd7e0e01234567';
const servers: ReturnType<typeof createLocalServer>[] = [];

async function fixture(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), 'thumbsup-local-updates-'));
  const prefix = join(root, 'updates', 'pr-101', updateId);
  await mkdir(join(prefix, 'bundles'), { recursive: true });
  await mkdir(join(root, 'channels'), { recursive: true });
  await writeFile(join(root, 'channels', 'index.json'), JSON.stringify({
    channels: {
      'pr-101': [{ updateId, runtimeVersion: '0.1.0', createdAt: '2026-09-08T00:00:00.000Z' }],
    },
  }));
  await writeFile(join(prefix, 'metadata.json'), JSON.stringify({
    version: 0,
    bundler: 'metro',
    fileMetadata: {
      ios: { bundle: 'bundles/ios.js', assets: [] },
      android: { bundle: 'bundles/android.js', assets: [] },
    },
  }));
  await writeFile(join(prefix, 'bundles', 'ios.js'), 'console.log("ios")');
  await writeFile(join(prefix, 'bundles', 'android.js'), 'console.log("android")');
  return root;
}

async function listen(storeDir: string, manifestStatus?: number): Promise<string> {
  const server = createLocalServer({
    storeDir,
    publicUrl: 'http://10.0.2.2:8081',
    manifestStatus,
  });
  servers.push(server);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address() as AddressInfo;
  return `http://127.0.0.1:${address.port}`;
}

afterEach(async () => {
  await Promise.all(servers.splice(0).map(async (server) => {
    server.close();
    await once(server, 'close');
  }));
});

describe('local updates server', () => {
  it('serves the channel index, manifest, and launch asset from a directory', async () => {
    const baseUrl = await listen(await fixture());
    const index = await fetch(`${baseUrl}/channels/index.json`);
    expect(index.status).toBe(200);
    expect(await index.json()).toMatchObject({ channels: { 'pr-101': expect.any(Array) } });

    const manifestResponse = await fetch(baseUrl, {
      headers: {
        accept: 'application/expo+json',
        'expo-protocol-version': '1',
        'expo-platform': 'android',
        'expo-runtime-version': '0.1.0',
        'expo-channel-name': 'pr-101',
      },
    });
    expect(manifestResponse.status).toBe(200);
    const manifest = await manifestResponse.json();
    expect(manifest.launchAsset.url).toBe(
      `http://10.0.2.2:8081/updates/pr-101/${updateId}/bundles/android.js`,
    );

    const asset = await fetch(
      `${baseUrl}/updates/pr-101/${updateId}/bundles/android.js`,
    );
    expect(await asset.text()).toBe('console.log("android")');
  });

  it('can force a manifest 404 for recovery testing', async () => {
    const baseUrl = await listen(await fixture(), 404);
    const response = await fetch(baseUrl);
    expect(response.status).toBe(404);
  });

  it('returns 404 instead of serving paths outside the store', async () => {
    const baseUrl = await listen(await fixture());
    const response = await fetch(`${baseUrl}/package.json`);
    expect(response.status).toBe(404);
  });
});

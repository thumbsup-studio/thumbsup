import { generateKeyPairSync, verify } from 'node:crypto';
import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createHandler, rolloutBucket, sha256Base64Url } from '../src/manifest.js';
import { resetSigningKeyCache } from '../src/signing.js';
import type { ObjectStore } from '../src/types.js';

const updateId = 'b15ed6d8-f39b-04ad-a248-fa3b95fd7e0e';
const launchAssets = {
  ios: new TextEncoder().encode('console.log("ios fixture")'),
  android: new TextEncoder().encode('console.log("android fixture")'),
};
const image = Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10]);
const signingKeys = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

class MemoryStore implements ObjectStore {
  constructor(private readonly objects: Record<string, Uint8Array>) {}

  async get(key: string): Promise<Uint8Array> {
    const value = this.objects[key];
    if (!value) throw new Error(`Missing fixture: ${key}`);
    return value;
  }
}

function bytes(value: unknown): Uint8Array {
  return new TextEncoder().encode(typeof value === 'string' ? value : JSON.stringify(value));
}

function fixtures(entry: Record<string, unknown> = {
  updateId,
  runtimeVersion: '1',
  createdAt: '2026-09-08T00:00:00.000Z',
}): Record<string, Uint8Array> {
  const prefix = `updates/production/${updateId}`;
  return {
    'channels/index.json': bytes({ channels: { production: [entry] } }),
    [`${prefix}/metadata.json`]: bytes({
      version: 0,
      bundler: 'metro',
      fileMetadata: {
        ios: { bundle: 'bundles/ios.js', assets: [{ path: 'assets/image', ext: 'png' }] },
        android: { bundle: 'bundles/android.js', assets: [{ path: 'assets/image', ext: 'png' }] },
      },
      extra: { expoClient: { name: 'expo-updates-client', runtimeVersion: '1' } },
    }),
    [`${prefix}/bundles/ios.js`]: launchAssets.ios,
    [`${prefix}/bundles/android.js`]: launchAssets.android,
    [`${prefix}/assets/image`]: image,
  };
}

function event(headers: Record<string, string>): APIGatewayProxyEventV2 {
  return {
    version: '2.0', routeKey: '$default', rawPath: '/api/manifest', rawQueryString: '',
    headers,
    requestContext: {
      accountId: 'test', apiId: 'test', domainName: 'test', domainPrefix: 'test',
      http: { method: 'GET', path: '/api/manifest', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'vitest' },
      requestId: 'test', routeKey: '$default', stage: '$default', time: '', timeEpoch: 0,
    },
    isBase64Encoded: false,
  };
}

function headers(platform: 'ios' | 'android', accept: string): Record<string, string> {
  return {
    'expo-protocol-version': '1',
    'expo-platform': platform,
    'expo-runtime-version': '1',
    'expo-channel-name': 'production',
    'expo-client-id': 'client-fixture',
    'expo-expect-signature': 'sig, keyid="main", alg="rsa-v1_5-sha256"',
    accept,
  };
}

function multipartPart(body: string): { headers: Record<string, string>; value: string } {
  const sections = body.split('\r\n\r\n');
  const rawHeaders = sections[0].split('\r\n').slice(1);
  return {
    headers: Object.fromEntries(rawHeaders.map((line) => {
      const separator = line.indexOf(':');
      return [line.slice(0, separator).toLowerCase(), line.slice(separator + 1).trim()];
    })),
    value: sections[1].split('\r\n--expo-')[0],
  };
}

beforeEach(() => {
  process.env.ASSET_BASE_URL = 'https://updates.example.com';
  process.env.SIGNING_PRIVATE_KEY = signingKeys.privateKey;
  delete process.env.SIGNING_PRIVATE_KEY_PARAMETER;
  resetSigningKeyCache();
});

afterEach(() => {
  delete process.env.ASSET_BASE_URL;
  delete process.env.SIGNING_PRIVATE_KEY;
  resetSigningKeyCache();
});

describe.each(['ios', 'android'] as const)('%s official-style fixture', (platform) => {
  it('returns a JSON Expo manifest with platform-specific launch asset', async () => {
    const result = await createHandler(new MemoryStore(fixtures()))(
      event(headers(platform, 'application/expo+json')),
    );

    expect(result.statusCode).toBe(200);
    expect(result.headers).toMatchObject({
      'content-type': 'application/expo+json',
      'cache-control': 'no-cache',
      'expo-protocol-version': '1',
    });
    const manifest = JSON.parse(result.body ?? '{}');
    expect(manifest).toMatchObject({
      id: updateId,
      runtimeVersion: '1',
      createdAt: '2026-09-08T00:00:00.000Z',
      metadata: {},
      extra: { expoClient: { name: 'expo-updates-client', runtimeVersion: '1' } },
    });
    expect(manifest.launchAsset.hash).toBe(sha256Base64Url(launchAssets[platform]));
    expect(manifest.launchAsset.key).toMatch(/^[0-9a-f]{32}$/);
    expect(manifest.launchAsset.contentType).toBe('application/javascript');
    expect(manifest.assets[0]).toMatchObject({
      hash: sha256Base64Url(image), contentType: 'image/png', fileExtension: '.png',
    });
  });
});

it('negotiates multipart/mixed', async () => {
  const result = await createHandler(new MemoryStore(fixtures()))(
    event(headers('ios', 'multipart/mixed,application/expo+json')),
  );

  expect(result.headers?.['content-type']).toMatch(/^multipart\/mixed; boundary=expo-/);
  const part = multipartPart(result.body ?? '');
  expect(part.headers['content-disposition']).toContain('name="manifest"');
  expect(JSON.parse(part.value).id).toBe(updateId);
});

it('honors Accept quality values', async () => {
  const result = await createHandler(new MemoryStore(fixtures()))(
    event(headers('ios', 'multipart/mixed;q=0.2, application/expo+json;q=0.9')),
  );
  expect(result.headers?.['content-type']).toBe('application/expo+json');
});

it('returns application/json when it is the requested representation', async () => {
  const result = await createHandler(new MemoryStore(fixtures()))(
    event(headers('ios', 'application/json')),
  );
  expect(result.headers?.['content-type']).toBe('application/json');
});

it('rejects a runtimeVersion that does not match the channel head', async () => {
  const requestHeaders = headers('ios', 'application/json');
  requestHeaders['expo-runtime-version'] = '2';
  const result = await createHandler(new MemoryStore(fixtures()))(event(requestHeaders));
  expect(result.statusCode).toBe(406);
});

it('selects the latest update compatible with the requested runtimeVersion', async () => {
  const objects = fixtures();
  objects['channels/index.json'] = bytes({
    channels: {
      production: [
        { updateId, runtimeVersion: '1', createdAt: '2026-09-08T00:00:00.000Z' },
        {
          updateId: 'a25ed6d8-f39b-04ad-a248-fa3b95fd7e0e',
          runtimeVersion: '2',
          createdAt: '2026-09-09T00:00:00.000Z',
        },
      ],
    },
  });
  const result = await createHandler(new MemoryStore(objects))(
    event(headers('ios', 'application/json')),
  );
  expect(JSON.parse(result.body ?? '{}').id).toBe(updateId);
});

it('returns 204 when the channel has no update', async () => {
  const store = new MemoryStore({ 'channels/index.json': bytes({ channels: {} }) });
  const result = await createHandler(store)(event(headers('ios', 'application/json')));
  expect(result.statusCode).toBe(204);
});

it('requires code signing negotiation on the production channel', async () => {
  const requestHeaders = headers('ios', 'application/json');
  delete requestHeaders['expo-expect-signature'];
  const result = await createHandler(new MemoryStore(fixtures()))(event(requestHeaders));
  expect(result.statusCode).toBe(406);
  expect(result.body).toContain('require code signing');
});

it('persists a generated rollout client ID with server-defined headers', async () => {
  const requestHeaders = headers('ios', 'application/json');
  delete requestHeaders['expo-client-id'];
  const result = await createHandler(new MemoryStore(fixtures()))(event(requestHeaders));
  expect(result.headers?.['expo-server-defined-headers']).toMatch(
    /^expo-client-id="[0-9a-f-]{36}"$/,
  );
});

it('uses a stable client hash to split a gradual rollout', async () => {
  const includedClient = Array.from({ length: 1000 }, (_, index) => `included-${index}`)
    .find((value) => rolloutBucket(value) < 10);
  const excludedClient = Array.from({ length: 1000 }, (_, index) => `excluded-${index}`)
    .find((value) => rolloutBucket(value) >= 10);
  expect(includedClient).toBeTruthy();
  expect(excludedClient).toBeTruthy();
  const previousId = 'a25ed6d8-f39b-04ad-a248-fa3b95fd7e0e';
  const objects = fixtures();
  objects['channels/index.json'] = bytes({
    channels: {
      production: [
        {
          updateId,
          runtimeVersion: '1',
          createdAt: '2026-09-08T00:00:00.000Z',
          rolloutPercentage: 10,
        },
        {
          updateId: previousId,
          runtimeVersion: '1',
          createdAt: '2026-09-07T00:00:00.000Z',
          rolloutPercentage: 100,
        },
      ],
    },
  });
  for (const [key, value] of Object.entries(fixtures())) {
    if (key.includes(updateId)) objects[key.replace(updateId, previousId)] = value;
  }
  const includedHeaders = headers('ios', 'application/json');
  includedHeaders['expo-client-id'] = includedClient!;
  const excludedHeaders = headers('ios', 'application/json');
  excludedHeaders['expo-client-id'] = excludedClient!;

  const handler = createHandler(new MemoryStore(objects));
  expect(JSON.parse((await handler(event(includedHeaders))).body ?? '{}').id).toBe(updateId);
  expect(JSON.parse((await handler(event(excludedHeaders))).body ?? '{}').id).toBe(previousId);
});

it('returns 204 when a protocol v1 client already has the latest update', async () => {
  const requestHeaders = headers('ios', 'application/json');
  requestHeaders['expo-current-update-id'] = updateId;
  const result = await createHandler(new MemoryStore(fixtures()))(event(requestHeaders));
  expect(result.statusCode).toBe(204);
});

it('returns a protocol v1 rollback directive', async () => {
  const rollback = {
    type: 'rollback', runtimeVersion: '1', createdAt: '2026-09-08T00:00:00.000Z',
    commitTime: '2026-09-07T00:00:00.000Z',
  };
  const result = await createHandler(new MemoryStore(fixtures(rollback)))(
    event(headers('android', 'multipart/mixed')),
  );
  expect(JSON.parse(multipartPart(result.body ?? '').value)).toEqual({
    type: 'rollBackToEmbedded', parameters: { commitTime: rollback.commitTime },
  });
});

it('rejects a rollback directive when multipart is not accepted', async () => {
  const rollback = {
    type: 'rollback', runtimeVersion: '1', createdAt: '2026-09-08T00:00:00.000Z',
    commitTime: '2026-09-07T00:00:00.000Z',
  };
  const result = await createHandler(new MemoryStore(fixtures(rollback)))(
    event(headers('android', 'application/json')),
  );
  expect(result.statusCode).toBe(406);
});

it('signs the exact manifest body when expo-expect-signature is present', async () => {
  const requestHeaders = headers('ios', 'application/json');

  const result = await createHandler(new MemoryStore(fixtures()))(event(requestHeaders));
  const signature = String(result.headers?.['expo-signature']).match(/sig="([^"]+)"/)?.[1];

  expect(signature).toBeTruthy();
  expect(verify(
    'RSA-SHA256',
    Buffer.from(result.body ?? ''),
    signingKeys.publicKey,
    Buffer.from(signature!, 'base64'),
  )).toBe(true);
});

it('rejects an unsupported requested signing key', async () => {
  const requestHeaders = headers('ios', 'application/json');
  requestHeaders['expo-expect-signature'] = 'sig, keyid="other", alg="rsa-v1_5-sha256"';
  const result = await createHandler(new MemoryStore(fixtures()))(event(requestHeaders));
  expect(result.statusCode).toBe(406);
});

it('computes unpadded base64url SHA-256 asset hashes', () => {
  expect(sha256Base64Url(bytes('hello'))).toBe('LPJNul-wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ');
});

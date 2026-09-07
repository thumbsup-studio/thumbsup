import { createHash, randomUUID } from 'node:crypto';
import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from 'aws-lambda';
import { getSigningPrivateKey, signatureHeader, signBody } from './signing.js';
import { S3ObjectStore } from './store.js';
import type {
  ChannelIndex,
  ChannelRollback,
  ChannelUpdate,
  ObjectStore,
  Platform,
  UpdateMetadata,
} from './types.js';

const decoder = new TextDecoder();
const JSON_CONTENT_TYPES = ['application/json', 'application/expo+json'];

interface RequestHeaders {
  protocolVersion: 0 | 1;
  platform: Platform;
  runtimeVersion: string;
  channel: string;
  expectsSignature: boolean;
  signingKeyId: string;
  responseContentType: 'application/json' | 'application/expo+json' | 'multipart/mixed';
  supportsMultipart: boolean;
  assetBaseUrl: string;
  currentUpdateId?: string;
  embeddedUpdateId?: string;
  clientId: string;
}

interface ManifestAsset {
  hash: string;
  key: string;
  fileExtension: string;
  contentType: string;
  url: string;
}

interface Manifest {
  id: string;
  createdAt: string;
  runtimeVersion: string;
  launchAsset: ManifestAsset;
  assets: ManifestAsset[];
  metadata: Record<string, never>;
  extra: Record<string, unknown>;
}

export function sha256Base64Url(value: Uint8Array): string {
  return createHash('sha256').update(value).digest('base64url');
}

function parseHeaders(event: APIGatewayProxyEventV2): RequestHeaders | APIGatewayProxyStructuredResultV2 {
  const headers = Object.fromEntries(
    Object.entries(event.headers ?? {}).map(([key, value]) => [key.toLowerCase(), value]),
  );
  const protocol = headers['expo-protocol-version'] ?? '0';
  if (protocol !== '0' && protocol !== '1') {
    return error(400, 'Unsupported protocol version. Expected either 0 or 1.');
  }
  const platform = headers['expo-platform'] ?? event.queryStringParameters?.platform;
  if (platform !== 'ios' && platform !== 'android') {
    return error(400, 'Unsupported platform. Expected either ios or android.');
  }
  const runtimeVersion =
    headers['expo-runtime-version'] ?? event.queryStringParameters?.['runtime-version'];
  if (!runtimeVersion) {
    return error(400, 'No runtimeVersion provided.');
  }
  const channel = headers['expo-channel-name'] ?? 'production';
  if (!/^[A-Za-z0-9._-]+$/.test(channel)) {
    return error(400, 'Invalid channel name.');
  }
  const responseType = negotiateResponseType(headers.accept);
  if (!responseType) {
    return error(406, 'Accept must allow application/json, application/expo+json, or multipart/mixed.');
  }
  const expectSignature = headers['expo-expect-signature'];
  if (channel === 'production' && expectSignature === undefined) {
    return error(406, 'Production updates require code signing.');
  }
  const configuredKeyId = process.env.SIGNING_KEY_ID ?? 'main';
  const requestedKeyId = expectSignature?.match(/(?:^|,)\s*keyid\s*=\s*"([^"]+)"/)?.[1];
  const requestedAlgorithm = expectSignature?.match(/(?:^|,)\s*alg\s*=\s*"([^"]+)"/)?.[1];
  if (requestedKeyId && requestedKeyId !== configuredKeyId) {
    return error(406, `Unsupported signing key: ${requestedKeyId}.`);
  }
  if (requestedAlgorithm && requestedAlgorithm !== 'rsa-v1_5-sha256') {
    return error(406, `Unsupported signing algorithm: ${requestedAlgorithm}.`);
  }
  const clientId = headers['expo-client-id'] ?? randomUUID();
  if (!/^[A-Za-z0-9._:-]{1,128}$/.test(clientId)) {
    return error(400, 'Invalid Expo client ID.');
  }
  return {
    protocolVersion: Number(protocol) as 0 | 1,
    platform,
    runtimeVersion,
    channel,
    expectsSignature: expectSignature !== undefined,
    signingKeyId: configuredKeyId,
    responseContentType: responseType.preferred,
    supportsMultipart: responseType.supportsMultipart,
    assetBaseUrl: process.env.ASSET_BASE_URL ?? `https://${headers['x-forwarded-host'] ?? ''}`,
    currentUpdateId: headers['expo-current-update-id'],
    embeddedUpdateId: headers['expo-embedded-update-id'],
    clientId,
  };
}

function negotiateResponseType(acceptHeader?: string): {
  preferred: RequestHeaders['responseContentType'];
  supportsMultipart: boolean;
} | null {
  if (!acceptHeader) {
    return { preferred: 'application/expo+json', supportsMultipart: true };
  }
  const accepted = acceptHeader.toLowerCase().split(',').map((part, order) => {
    const [mediaType, ...parameters] = part.trim().split(';');
    const quality = Number(
      parameters.find((value) => value.trim().startsWith('q='))?.split('=')[1] ?? '1',
    );
    return { mediaType, quality: Number.isFinite(quality) ? quality : 0, order };
  }).filter((item) => item.quality > 0).sort(
    (a, b) => b.quality - a.quality || a.order - b.order,
  );
  const supportsMultipart = accepted.some(
    (item) => item.mediaType === 'multipart/mixed' || item.mediaType === '*/*',
  );
  for (const item of accepted) {
    if (item.mediaType === 'multipart/mixed') return { preferred: item.mediaType, supportsMultipart };
    if (JSON_CONTENT_TYPES.includes(item.mediaType)) {
      return { preferred: item.mediaType as 'application/json' | 'application/expo+json', supportsMultipart };
    }
    if (item.mediaType === '*/*') {
      return { preferred: 'application/expo+json', supportsMultipart };
    }
  }
  return null;
}

function error(statusCode: number, message: string): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-cache' },
    body: JSON.stringify({ error: message }),
  };
}

function noContent(request: RequestHeaders): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode: 204,
    headers: {
      'cache-control': 'no-cache',
      'expo-protocol-version': String(request.protocolVersion),
      'expo-sfv-version': '0',
      'expo-server-defined-headers': `expo-client-id="${request.clientId}"`,
    },
  };
}

function json<T>(bytes: Uint8Array): T {
  return JSON.parse(decoder.decode(bytes)) as T;
}

function contentType(extension: string, launchAsset: boolean): string {
  if (launchAsset) return 'application/javascript';
  const types: Record<string, string> = {
    png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp',
    gif: 'image/gif', svg: 'image/svg+xml', json: 'application/json', ttf: 'font/ttf',
    otf: 'font/otf', woff: 'font/woff', woff2: 'font/woff2', mp4: 'video/mp4',
  };
  return types[extension.toLowerCase()] ?? 'application/octet-stream';
}

function objectUrl(baseUrl: string, key: string): string {
  return `${baseUrl.replace(/\/$/, '')}/${key.split('/').map(encodeURIComponent).join('/')}`;
}

function safeObjectPath(path: string): boolean {
  return path.length > 0 && !path.startsWith('/') && !path.split('/').includes('..');
}

async function asset(
  store: ObjectStore,
  baseUrl: string,
  objectKey: string,
  extension: string,
  launchAsset: boolean,
): Promise<ManifestAsset> {
  const bytes = await store.get(objectKey);
  const hash = sha256Base64Url(bytes);
  return {
    hash,
    key: createHash('md5').update(bytes).digest('hex'),
    fileExtension: launchAsset ? '.bundle' : `.${extension}`,
    contentType: contentType(extension, launchAsset),
    url: objectUrl(baseUrl, objectKey),
  };
}

export function rolloutBucket(clientId: string): number {
  return createHash('sha256').update(clientId).digest().readUInt32BE(0) % 100;
}

function latestForRuntime(
  entries: Array<ChannelUpdate | ChannelRollback>,
  runtimeVersion: string,
  clientId: string,
): ChannelUpdate | ChannelRollback | undefined {
  const compatible = entries.filter((entry) => entry.runtimeVersion === runtimeVersion).sort(
    (a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt),
  );
  const latest = compatible[0];
  if (!latest || latest.type === 'rollback') return latest;
  const percentage = latest.rolloutPercentage ?? 100;
  if (percentage >= 100 || rolloutBucket(clientId) < percentage) return latest;
  return compatible.slice(1).find((entry) =>
    entry.type === 'rollback' || (entry.rolloutPercentage ?? 100) === 100,
  );
}

function uuid(value: string): string | null {
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    return value;
  }
  if (/^[0-9a-f]{32,}$/i.test(value)) {
    return `${value.slice(0, 8)}-${value.slice(8, 12)}-${value.slice(12, 16)}-${value.slice(16, 20)}-${value.slice(20, 32)}`;
  }
  return null;
}

async function buildManifest(
  store: ObjectStore,
  channel: string,
  update: ChannelUpdate,
  platform: Platform,
  baseUrl: string,
): Promise<Manifest> {
  const id = uuid(update.updateId);
  if (!id) throw new Error(`Invalid updateId: ${update.updateId}`);
  const prefix = `updates/${channel}/${update.updateId}`;
  const metadata = json<UpdateMetadata>(await store.get(`${prefix}/metadata.json`));
  const files = metadata.fileMetadata[platform];
  if (!files) throw new Error(`No ${platform} metadata for update ${update.updateId}`);
  if (!safeObjectPath(files.bundle) || files.assets.some((item) => !safeObjectPath(item.path))) {
    throw new Error(`Unsafe asset path for update ${update.updateId}`);
  }
  const launchAsset = await asset(store, baseUrl, `${prefix}/${files.bundle}`, '', true);
  const assets = await Promise.all(
    files.assets.map((item) => asset(store, baseUrl, `${prefix}/${item.path}`, item.ext, false)),
  );
  return {
    id,
    createdAt: update.createdAt,
    runtimeVersion: update.runtimeVersion,
    launchAsset,
    assets,
    metadata: {},
    extra: metadata.extra ?? {},
  };
}

function multipart(partName: 'manifest' | 'directive', body: string, signature?: string): { body: string; contentType: string } {
  const boundary = `expo-${randomUUID()}`;
  const lines = [
    `--${boundary}`,
    `content-disposition: form-data; name="${partName}"`,
    'content-type: application/json; charset=utf-8',
    ...(signature ? [`expo-signature: ${signature}`] : []),
    '',
    body,
    `--${boundary}--`,
    '',
  ];
  const value = lines.join('\r\n');
  return { body: value, contentType: `multipart/mixed; boundary=${boundary}` };
}

async function response(
  request: RequestHeaders,
  partName: 'manifest' | 'directive',
  payload: Manifest | Record<string, unknown>,
  forceMultipart = false,
): Promise<APIGatewayProxyStructuredResultV2> {
  const body = JSON.stringify(payload);
  let signature: string | undefined;
  if (request.expectsSignature) {
    const privateKey = await getSigningPrivateKey();
    if (!privateKey) return error(400, 'Code signing requested but no private key is configured.');
    signature = signatureHeader(signBody(body, privateKey), request.signingKeyId);
  }
  const headers: Record<string, string> = {
    'expo-protocol-version': String(request.protocolVersion),
    'expo-sfv-version': '0',
    'cache-control': 'no-cache',
    'expo-server-defined-headers': `expo-client-id="${request.clientId}"`,
  };
  if (forceMultipart || request.responseContentType === 'multipart/mixed') {
    const encoded = multipart(partName, body, signature);
    headers['content-type'] = encoded.contentType;
    return { statusCode: 200, headers, body: encoded.body };
  }
  headers['content-type'] = request.responseContentType;
  if (signature) headers['expo-signature'] = signature;
  return { statusCode: 200, headers, body };
}

export function createHandler(store: ObjectStore, options: { assetBaseUrl?: string } = {}) {
  return async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyStructuredResultV2> => {
    if (event.requestContext?.http?.method && event.requestContext.http.method !== 'GET') {
      return error(405, 'Expected GET.');
    }
    const request = parseHeaders(event);
    if (!('protocolVersion' in request)) return request;
    if (options.assetBaseUrl) request.assetBaseUrl = options.assetBaseUrl;
    let index: ChannelIndex;
    try {
      index = json<ChannelIndex>(await store.get('channels/index.json'));
    } catch {
      return error(500, 'Unable to read channel index.');
    }
    const channel = index.channels[request.channel];
    if (!channel?.length) return noContent(request);
    if (!channel.some((entry) => entry.runtimeVersion === request.runtimeVersion)) {
      return error(406, `No update for runtimeVersion ${request.runtimeVersion}.`);
    }
    const latest = latestForRuntime(channel, request.runtimeVersion, request.clientId);
    if (!latest) {
      return noContent(request);
    }
    if (latest.type === 'rollback') {
      if (request.protocolVersion !== 1) return error(406, 'Rollback directives require protocol version 1.');
      if (!request.supportsMultipart) return error(406, 'Rollback directives require multipart/mixed.');
      if (request.currentUpdateId && request.currentUpdateId === request.embeddedUpdateId) {
        return noContent(request);
      }
      return response(request, 'directive', {
        type: 'rollBackToEmbedded',
        parameters: { commitTime: latest.commitTime },
      }, true);
    }
    if (request.protocolVersion === 1 && request.currentUpdateId === uuid(latest.updateId)) {
      return noContent(request);
    }
    try {
      return response(
        request,
        'manifest',
        await buildManifest(store, request.channel, latest, request.platform, request.assetBaseUrl),
      );
    } catch {
      return error(500, 'Unable to build update manifest.');
    }
  };
}

export const handler = createHandler(new S3ObjectStore(process.env.ARTIFACTS_BUCKET ?? ''));

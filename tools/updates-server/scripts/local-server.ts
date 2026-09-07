import { createServer, type IncomingHttpHeaders, type ServerResponse } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { createHandler } from '../src/manifest.js';
import { LocalObjectStore } from '../src/store.js';

const MIME_TYPES: Record<string, string> = {
  bundle: 'application/javascript',
  gif: 'image/gif',
  hbc: 'application/octet-stream',
  jpeg: 'image/jpeg',
  jpg: 'image/jpeg',
  js: 'application/javascript',
  json: 'application/json',
  otf: 'font/otf',
  png: 'image/png',
  svg: 'image/svg+xml',
  ttf: 'font/ttf',
  webp: 'image/webp',
  woff: 'font/woff',
  woff2: 'font/woff2',
};

export interface LocalServerOptions {
  storeDir: string;
  publicUrl: string;
  manifestStatus?: number;
}

function requestHeaders(headers: IncomingHttpHeaders): Record<string, string> {
  return Object.fromEntries(Object.entries(headers).flatMap(([key, value]) => {
    if (value === undefined) return [];
    return [[key, Array.isArray(value) ? value.join(',') : value]];
  }));
}

function event(url: URL, method: string, headers: IncomingHttpHeaders): APIGatewayProxyEventV2 {
  return {
    version: '2.0',
    routeKey: '$default',
    rawPath: url.pathname,
    rawQueryString: url.search.slice(1),
    headers: requestHeaders(headers),
    queryStringParameters: Object.fromEntries(url.searchParams),
    requestContext: {
      accountId: 'local', apiId: 'local', domainName: url.host, domainPrefix: 'local',
      http: {
        method, path: url.pathname, protocol: 'HTTP/1.1', sourceIp: '127.0.0.1',
        userAgent: headers['user-agent'] ?? 'local',
      },
      requestId: 'local', routeKey: '$default', stage: '$default', time: '', timeEpoch: Date.now(),
    },
    isBase64Encoded: false,
  };
}

function contentType(pathname: string): string {
  const extension = pathname.split('.').at(-1)?.toLowerCase() ?? '';
  return MIME_TYPES[extension] ?? 'application/octet-stream';
}

function send(response: ServerResponse, status: number, body: string | Uint8Array, headers = {}): void {
  response.writeHead(status, headers);
  response.end(body);
}

export function createLocalServer(options: LocalServerOptions) {
  const store = new LocalObjectStore(options.storeDir);
  const manifest = createHandler(store, { assetBaseUrl: options.publicUrl });
  return createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', options.publicUrl);
      if (url.pathname === '/' || url.pathname === '/api/manifest') {
        if (options.manifestStatus) {
          send(response, options.manifestStatus, JSON.stringify({ error: 'Forced local failure' }), {
            'content-type': 'application/json', 'cache-control': 'no-cache',
          });
          return;
        }
        const result = await manifest(event(url, request.method ?? 'GET', request.headers));
        send(response, result.statusCode ?? 200, result.body ?? '', result.headers ?? {});
        return;
      }
      if (request.method !== 'GET' && request.method !== 'HEAD') {
        send(response, 405, 'Method Not Allowed');
        return;
      }
      const key = decodeURIComponent(url.pathname.replace(/^\//, ''));
      if (key !== 'channels/index.json' && !key.startsWith('updates/')) {
        send(response, 404, 'Not Found');
        return;
      }
      try {
        const bytes = await store.get(key);
        response.writeHead(200, {
          'content-type': contentType(url.pathname),
          'cache-control': key === 'channels/index.json' ? 'no-cache' : 'public, max-age=31536000, immutable',
        });
        response.end(request.method === 'HEAD' ? undefined : bytes);
      } catch {
        send(response, 404, 'Not Found');
      }
    } catch (error) {
      send(response, 500, JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), {
        'content-type': 'application/json',
      });
    }
  });
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
  const args = argumentsFrom(process.argv.slice(2));
  const port = Number(args.port ?? '8081');
  if (!Number.isSafeInteger(port) || port < 1 || port > 65535) throw new Error(`Invalid port: ${port}`);
  const host = args.host ?? '0.0.0.0';
  const publicUrl = (args['public-url'] ?? `http://10.0.2.2:${port}`).replace(/\/$/, '');
  const manifestStatus = args['manifest-status'] ? Number(args['manifest-status']) : undefined;
  if (manifestStatus !== undefined && (
    !Number.isSafeInteger(manifestStatus) || manifestStatus < 400 || manifestStatus > 599
  )) {
    throw new Error(`Invalid manifest status: ${manifestStatus}`);
  }
  const storeDir = resolve(args['store-dir'] ?? new URL('../.local-store', import.meta.url).pathname);
  if (args['signing-private-key']) {
    process.env.SIGNING_PRIVATE_KEY = await readFile(resolve(args['signing-private-key']), 'utf8');
  }
  const server = createLocalServer({ storeDir, publicUrl, manifestStatus });
  server.listen(port, host, () => {
    process.stdout.write(`Local updates server: ${publicUrl} (${storeDir})\n`);
  });
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname)) {
  await main();
}

import { randomUUID } from 'node:crypto';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from 'aws-lambda';

const MAX_BODY_BYTES = 16_384;
const MAX_REQUESTS_PER_MINUTE = 60;
const TYPES = ['launch', 'crash', 'emergency'] as const;
type TelemetryType = typeof TYPES[number];

export interface TelemetryWriter {
  put(key: string, value: unknown): Promise<void>;
}

export class S3TelemetryWriter implements TelemetryWriter {
  constructor(
    private readonly bucket: string,
    private readonly client = new S3Client({}),
  ) {}

  async put(key: string, value: unknown): Promise<void> {
    await this.client.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: JSON.stringify(value),
      ContentType: 'application/json',
    }));
  }
}

function response(statusCode: number, message?: string): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
    ...(message ? { body: JSON.stringify({ error: message }) } : {}),
  };
}

function exactKeys(value: Record<string, unknown>, expected: string[]): boolean {
  return Object.keys(value).every((key) => expected.includes(key));
}

function string(value: unknown, max: number, nullable = false): boolean {
  return (nullable && value === null) || (typeof value === 'string' && value.length > 0 && value.length <= max);
}

function validBase(value: Record<string, unknown>): boolean {
  return string(value.occurredAt, 40)
    && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value.occurredAt as string)
    && !Number.isNaN(Date.parse(value.occurredAt as string))
    && string(value.updateId, 200, true)
    && string(value.runtimeVersion, 100, true)
    && string(value.channel, 100)
    && /^[A-Za-z0-9._-]+$/.test(value.channel as string)
    && string(value.appVersion, 100)
    && (value.platform === 'ios' || value.platform === 'android' || value.platform === 'web')
    && string(value.deviceModel, 200, true);
}

function validPayload(value: unknown, routeType: TelemetryType): value is Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const payload = value as Record<string, unknown>;
  if (payload.type !== routeType || !validBase(payload)) return false;
  const base = ['type', 'occurredAt', 'updateId', 'runtimeVersion', 'channel', 'appVersion', 'platform', 'deviceModel'];
  if (routeType === 'launch') {
    return exactKeys(payload, [...base, 'success', 'isEmergencyLaunch', 'launchDuration'])
      && typeof payload.success === 'boolean'
      && typeof payload.isEmergencyLaunch === 'boolean'
      && typeof payload.launchDuration === 'number'
      && Number.isFinite(payload.launchDuration)
      && payload.launchDuration >= 0
      && payload.launchDuration <= 300_000;
  }
  if (routeType === 'emergency') {
    return exactKeys(payload, [...base, 'isEmergencyLaunch']) && payload.isEmergencyLaunch === true;
  }
  return exactKeys(payload, [...base, 'fatal', 'errorName', 'message', 'stack'])
    && typeof payload.fatal === 'boolean'
    && string(payload.errorName, 100)
    && string(payload.message, 1_000)
    && Array.isArray(payload.stack)
    && payload.stack.length <= 20
    && payload.stack.every((line) => typeof line === 'string' && line.length <= 500);
}

export function createTelemetryHandler(
  writer: TelemetryWriter,
  id: () => string = randomUUID,
  now: () => number = Date.now,
) {
  const windows = new Map<string, { startedAt: number; count: number }>();
  return async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyStructuredResultV2> => {
    if (event.requestContext?.http?.method !== 'POST') return response(405, 'Expected POST.');
    const contentType = event.headers?.['content-type'] ?? event.headers?.['Content-Type'];
    if (!contentType?.toLowerCase().startsWith('application/json')) {
      return response(415, 'Expected application/json.');
    }
    const raw = event.body ?? '';
    const byteLength = Buffer.byteLength(raw, event.isBase64Encoded ? 'base64' : 'utf8');
    if (byteLength > MAX_BODY_BYTES) return response(413, 'Payload exceeds 16 KiB.');
    const source = (event.headers?.['x-forwarded-for'] ?? event.requestContext.http.sourceIp)
      .split(',')[0]?.trim() ?? 'unknown';
    const timestamp = now();
    const current = windows.get(source);
    if (!current || timestamp - current.startedAt >= 60_000) {
      windows.set(source, { startedAt: timestamp, count: 1 });
    } else {
      current.count += 1;
      if (current.count > MAX_REQUESTS_PER_MINUTE) {
        return response(429, 'Telemetry rate limit exceeded.');
      }
    }
    const type = event.rawPath.split('/').at(-1);
    if (!TYPES.includes(type as TelemetryType)) return response(404, 'Unknown telemetry route.');
    let payload: unknown;
    try {
      payload = JSON.parse(event.isBase64Encoded ? Buffer.from(raw, 'base64').toString('utf8') : raw);
    } catch {
      return response(400, 'Invalid JSON.');
    }
    if (!validPayload(payload, type as TelemetryType)) return response(400, 'Invalid telemetry payload.');
    const date = (payload.occurredAt as string).slice(0, 10);
    const key = `telemetry/${date}/${payload.channel as string}/${id()}.json`;
    await writer.put(key, payload);
    return response(202);
  };
}

export const handler = createTelemetryHandler(
  new S3TelemetryWriter(process.env.ARTIFACTS_BUCKET ?? ''),
);

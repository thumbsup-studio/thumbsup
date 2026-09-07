import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { describe, expect, it } from 'vitest';
import { createTelemetryHandler, type TelemetryWriter } from '../src/telemetry.js';

function event(path: string, body: unknown, method = 'POST'): APIGatewayProxyEventV2 {
  return {
    version: '2.0', routeKey: '$default', rawPath: path, rawQueryString: '',
    headers: { 'content-type': 'application/json' },
    requestContext: {
      accountId: 'test', apiId: 'test', domainName: 'test', domainPrefix: 'test',
      http: { method, path, protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
      requestId: 'test', routeKey: '$default', stage: '$default', time: '', timeEpoch: 0,
    },
    body: JSON.stringify(body), isBase64Encoded: false,
  };
}

function launch() {
  return {
    type: 'launch', occurredAt: '2026-09-08T00:00:00.000Z', updateId: 'update-1',
    runtimeVersion: '0.1.0', channel: 'production', appVersion: '0.1.0',
    platform: 'android', deviceModel: 'Pixel 9', success: true,
    isEmergencyLaunch: false, launchDuration: 125,
  };
}

describe('telemetry handler', () => {
  it('validates and stores a launch event under its date and channel', async () => {
    const writes: Array<{ key: string; value: unknown }> = [];
    const writer: TelemetryWriter = { put: async (key, value) => { writes.push({ key, value }); } };
    const handler = createTelemetryHandler(writer, () => 'fixed-id');

    const response = await handler(event('/api/telemetry/launch', launch()));

    expect(response.statusCode).toBe(202);
    expect(writes).toEqual([{
      key: 'telemetry/2026-09-08/production/fixed-id.json',
      value: launch(),
    }]);
  });

  it('rejects malformed, mismatched, and oversized payloads', async () => {
    const writer: TelemetryWriter = { put: async () => undefined };
    const handler = createTelemetryHandler(writer);

    expect((await handler(event('/api/telemetry/crash', launch()))).statusCode).toBe(400);
    expect((await handler(event('/api/telemetry/launch', { ...launch(), channel: '../bad' }))).statusCode).toBe(400);
    expect((await handler(event('/api/telemetry/launch', { ...launch(), occurredAt: '2026/09/08' }))).statusCode).toBe(400);
    expect((await handler({ ...event('/api/telemetry/launch', launch()), body: 'x'.repeat(16_385) })).statusCode).toBe(413);
  });

  it('accepts crash stacks with at most 20 lines', async () => {
    const writes: unknown[] = [];
    const handler = createTelemetryHandler({ put: async (_key, value) => { writes.push(value); } });
    const crash = {
      ...launch(), type: 'crash', fatal: true, errorName: 'Error', message: 'boom',
      stack: Array.from({ length: 20 }, (_, index) => `line ${index}`),
    };
    delete (crash as Partial<ReturnType<typeof launch>>).success;
    delete (crash as Partial<ReturnType<typeof launch>>).isEmergencyLaunch;
    delete (crash as Partial<ReturnType<typeof launch>>).launchDuration;

    expect((await handler(event('/api/telemetry/crash', crash))).statusCode).toBe(202);
    expect(writes).toHaveLength(1);
    expect((await handler(event('/api/telemetry/crash', { ...crash, stack: [...crash.stack, 'extra'] }))).statusCode).toBe(400);
  });

  it('limits each source to 60 requests per minute', async () => {
    const handler = createTelemetryHandler({ put: async () => undefined }, () => 'id', () => 0);
    for (let count = 0; count < 60; count += 1) {
      expect((await handler(event('/api/telemetry/launch', launch()))).statusCode).toBe(202);
    }
    expect((await handler(event('/api/telemetry/launch', launch()))).statusCode).toBe(429);
  });
});

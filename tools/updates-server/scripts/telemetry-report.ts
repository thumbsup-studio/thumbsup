import { GetObjectCommand, ListObjectsV2Command, S3Client } from '@aws-sdk/client-s3';
import { readdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

export interface ReportEvent {
  type: 'launch' | 'crash' | 'emergency';
  channel: string;
  updateId: string | null;
  success?: boolean;
}

export interface TelemetryReportStore {
  readDay(date: string): Promise<ReportEvent[]>;
}

export interface TelemetryReportRow {
  channel: string;
  updateId: string;
  launchSuccess: number;
  launchFailure: number;
  emergency: number;
  crashes: number;
  adoptionRate: number;
}

export async function buildTelemetryReport(
  store: TelemetryReportStore,
  date: string,
): Promise<TelemetryReportRow[]> {
  const events = await store.readDay(date);
  const launchesByChannel = new Map<string, number>();
  const rows = new Map<string, TelemetryReportRow>();
  for (const event of events) {
    const updateId = event.updateId ?? '(embedded)';
    const key = `${event.channel}\0${updateId}`;
    const row = rows.get(key) ?? {
      channel: event.channel, updateId, launchSuccess: 0, launchFailure: 0,
      emergency: 0, crashes: 0, adoptionRate: 0,
    };
    if (event.type === 'launch') {
      if (event.success) row.launchSuccess += 1;
      else row.launchFailure += 1;
      launchesByChannel.set(event.channel, (launchesByChannel.get(event.channel) ?? 0) + 1);
    } else if (event.type === 'crash') row.crashes += 1;
    else row.emergency += 1;
    rows.set(key, row);
  }
  for (const row of rows.values()) {
    const total = launchesByChannel.get(row.channel) ?? 0;
    row.adoptionRate = total === 0 ? 0 : (row.launchSuccess + row.launchFailure) / total;
  }
  return [...rows.values()].sort((a, b) =>
    a.channel.localeCompare(b.channel) || a.updateId.localeCompare(b.updateId));
}

export class LocalTelemetryReportStore implements TelemetryReportStore {
  constructor(private readonly root: string) {}

  async readDay(date: string): Promise<ReportEvent[]> {
    const dayRoot = resolve(this.root, 'telemetry', date);
    let channels: string[];
    try { channels = await readdir(dayRoot); } catch { return []; }
    const events: ReportEvent[] = [];
    for (const channel of channels) {
      const channelRoot = resolve(dayRoot, channel);
      for (const file of await readdir(channelRoot)) {
        if (file.endsWith('.json')) {
          events.push(JSON.parse(await readFile(resolve(channelRoot, file), 'utf8')) as ReportEvent);
        }
      }
    }
    return events;
  }
}

export class S3TelemetryReportStore implements TelemetryReportStore {
  constructor(private readonly bucket: string, private readonly client = new S3Client({})) {}

  async readDay(date: string): Promise<ReportEvent[]> {
    const prefix = `telemetry/${date}/`;
    const events: ReportEvent[] = [];
    let token: string | undefined;
    do {
      const listed = await this.client.send(new ListObjectsV2Command({
        Bucket: this.bucket, Prefix: prefix, ContinuationToken: token,
      }));
      for (const object of listed.Contents ?? []) {
        if (!object.Key) continue;
        const result = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: object.Key }));
        if (result.Body) events.push(JSON.parse(await result.Body.transformToString()) as ReportEvent);
      }
      token = listed.NextContinuationToken;
    } while (token);
    return events;
  }
}

function parseArgs(argv: string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index]; const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) throw new Error(`Invalid argument near ${key ?? '<end>'}`);
    args[key.slice(2)] = value;
  }
  return args;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const date = args.date ?? new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error('date must be YYYY-MM-DD');
  const bucket = args.bucket ?? process.env.ARTIFACTS_BUCKET;
  const store = args['store-dir']
    ? new LocalTelemetryReportStore(resolve(args['store-dir']))
    : new S3TelemetryReportStore(bucket ?? (() => { throw new Error('--bucket or ARTIFACTS_BUCKET is required'); })());
  const rows = await buildTelemetryReport(store, date);
  console.table(rows.map((row) => ({
    channel: row.channel, updateId: row.updateId,
    'launch 성공': row.launchSuccess, 'launch 실패': row.launchFailure,
    emergency: row.emergency, crash: row.crashes,
    '채택률': `${(row.adoptionRate * 100).toFixed(1)}%`,
  })));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname)) {
  await main();
}

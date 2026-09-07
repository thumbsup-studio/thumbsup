import { describe, expect, it } from 'vitest';
import { buildTelemetryReport, type ReportEvent, type TelemetryReportStore } from '../scripts/telemetry-report.js';

describe('telemetry report', () => {
  it('groups daily adoption and failures by channel and updateId', async () => {
    const values: ReportEvent[] = [
      { type: 'launch', channel: 'production', updateId: 'new', success: true },
      { type: 'launch', channel: 'production', updateId: 'new', success: false },
      { type: 'launch', channel: 'production', updateId: 'old', success: true },
      { type: 'crash', channel: 'production', updateId: 'new' },
      { type: 'emergency', channel: 'staging', updateId: 'bad' },
    ];
    const store: TelemetryReportStore = { readDay: async () => values };

    const report = await buildTelemetryReport(store, '2026-09-08');

    expect(report).toEqual([
      { channel: 'production', updateId: 'new', launchSuccess: 1, launchFailure: 1, emergency: 0, crashes: 1, adoptionRate: 2 / 3 },
      { channel: 'production', updateId: 'old', launchSuccess: 1, launchFailure: 0, emergency: 0, crashes: 0, adoptionRate: 1 / 3 },
      { channel: 'staging', updateId: 'bad', launchSuccess: 0, launchFailure: 0, emergency: 1, crashes: 0, adoptionRate: 0 },
    ]);
  });
});

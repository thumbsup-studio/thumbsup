export interface TelemetryBase {
  occurredAt: string;
  updateId: string | null;
  runtimeVersion: string | null;
  channel: string;
  appVersion: string;
  platform: "android" | "ios" | "web";
  deviceModel: string | null;
}

export interface LaunchTelemetry extends TelemetryBase {
  type: "launch";
  success: boolean;
  isEmergencyLaunch: boolean;
  launchDuration: number;
}

export interface CrashTelemetry extends TelemetryBase {
  type: "crash";
  fatal: boolean;
  errorName: string;
  message: string;
  stack: string[];
}

export interface EmergencyTelemetry extends TelemetryBase {
  type: "emergency";
  isEmergencyLaunch: true;
}

export type TelemetryPayload = LaunchTelemetry | CrashTelemetry | EmergencyTelemetry;

export interface TelemetryQueueStore {
  read(): Promise<TelemetryPayload[]>;
  write(values: TelemetryPayload[]): Promise<void>;
}

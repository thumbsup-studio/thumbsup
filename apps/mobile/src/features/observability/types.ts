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

export interface InteractionTelemetry extends TelemetryBase {
  type: "interaction";
  /** tap: 접근성 라벨이 있는 컨트롤을 눌렀다. dialog: 다이얼로그·시트가 열렸다. */
  action: "tap" | "dialog";
  /** accessibilityRole 값. 라벨만으로는 무엇을 눌렀는지 구분되지 않는다. */
  role: string;
  /** accessibilityLabel을 정규화한 값. 개인정보는 마스킹한다. */
  label: string;
  /** expo-router 경로. 어느 화면에서 눌렀는지. */
  screen: string;
}

export type TelemetryPayload =
  | LaunchTelemetry
  | CrashTelemetry
  | EmergencyTelemetry
  | InteractionTelemetry;

export interface TelemetryQueueStore {
  read(): Promise<TelemetryPayload[]>;
  write(values: TelemetryPayload[]): Promise<void>;
}

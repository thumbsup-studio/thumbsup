import AsyncStorage from "@react-native-async-storage/async-storage";
import NetInfo from "@react-native-community/netinfo";
import Constants from "expo-constants";
import * as Device from "expo-device";
import Updates from "expo-updates/build/ExpoUpdates";
import { Component, type ErrorInfo, type ReactNode, useEffect } from "react";
import { Platform, Text, View } from "react-native";
import { setInteractionReporter } from "./interaction";
import { TelemetryClient } from "./telemetry-client";
import type {
  CrashTelemetry,
  InteractionTelemetry,
  LaunchTelemetry,
  TelemetryBase,
  TelemetryPayload,
} from "./types";

const QUEUE_KEY = "thumbsup.telemetry.queue.v1";
const startedAt = globalThis.performance?.now?.() ?? Date.now();
let launchSettled = false;
let emergencyReported = false;

const queue = {
  async read(): Promise<TelemetryPayload[]> {
    const value = await AsyncStorage.getItem(QUEUE_KEY);
    if (!value) return [];
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed) ? (parsed as TelemetryPayload[]) : [];
  },
  async write(values: TelemetryPayload[]): Promise<void> {
    if (values.length === 0) await AsyncStorage.removeItem(QUEUE_KEY);
    else await AsyncStorage.setItem(QUEUE_KEY, JSON.stringify(values));
  },
};

function extra(): Record<string, unknown> {
  return Constants.expoConfig?.extra ?? {};
}

function metadata(): TelemetryBase {
  const configExtra = extra();
  return {
    occurredAt: new Date().toISOString(),
    updateId: Updates.updateId ?? null,
    runtimeVersion: Updates.runtimeVersion ?? null,
    channel:
      typeof configExtra.updateChannel === "string"
        ? configExtra.updateChannel
        : (Updates.channel ?? "development"),
    appVersion: Constants.expoConfig?.version ?? "unknown",
    platform: Platform.OS === "android" || Platform.OS === "ios" ? Platform.OS : "web",
    deviceModel: Device.modelName ?? null,
  };
}

const updatesUrl = typeof extra().updatesUrl === "string" ? String(extra().updatesUrl) : "";
const client = new TelemetryClient(updatesUrl, queue);

function duration(): number {
  return Math.max(0, Math.round((globalThis.performance?.now?.() ?? Date.now()) - startedAt));
}

export async function reportLaunch(success: boolean): Promise<void> {
  if (launchSettled) return;
  launchSettled = true;
  const payload: LaunchTelemetry = {
    ...metadata(),
    type: "launch",
    success,
    isEmergencyLaunch: Updates.isEmergencyLaunch,
    launchDuration: Updates.launchDuration ?? duration(),
  };
  await Promise.all([client.send(payload), reportEmergencyLaunch()]);
}

async function reportEmergencyLaunch(): Promise<void> {
  if (!Updates.isEmergencyLaunch || emergencyReported) return;
  emergencyReported = true;
  await client.send({ ...metadata(), type: "emergency", isEmergencyLaunch: true });
}

async function reportInteraction(
  action: InteractionTelemetry["action"],
  role: string,
  label: string,
  screen: string,
): Promise<void> {
  await client.send({ ...metadata(), type: "interaction", action, role, label, screen });
}

// 이 모듈이 로드되는 앱에서만 상호작용 수집이 켜진다. 화면 컴포넌트는 interaction.tsx만
// 알면 되고, 무거운 네이티브 의존은 여기에 머문다.
setInteractionReporter((action, role, label, screen) => {
  void reportInteraction(action, role, label, screen).catch(() => undefined);
});

export async function reportCrash(error: Error, fatal: boolean): Promise<void> {
  const payload: CrashTelemetry = {
    ...metadata(),
    type: "crash",
    fatal,
    errorName: error.name.slice(0, 100),
    message: error.message.slice(0, 1_000),
    stack: (error.stack ?? "")
      .split("\n")
      .slice(0, 20)
      .map((line) => line.slice(0, 500)),
  };
  await Promise.all([reportLaunch(false), client.send(payload)]);
}

function installGlobalErrorHandler(): () => void {
  const errorUtils = (
    globalThis as unknown as {
      ErrorUtils?: {
        getGlobalHandler(): (error: Error, fatal?: boolean) => void;
        setGlobalHandler(handler: (error: Error, fatal?: boolean) => void): void;
      };
    }
  ).ErrorUtils;
  if (!errorUtils) return () => undefined;
  const previous = errorUtils.getGlobalHandler();
  const handler = (error: Error, fatal?: boolean) => {
    void reportCrash(error, fatal ?? true);
    previous(error, fatal);
  };
  errorUtils.setGlobalHandler(handler);
  return () => errorUtils.setGlobalHandler(previous);
}

export function ObservabilityProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    const uninstall = installGlobalErrorHandler();
    const unsubscribe = NetInfo.addEventListener((state) => {
      if (state.isConnected) void client.retryQueued();
    });
    // 첫 commit 이후 effect가 실행되는 시점을 JS 첫 화면 렌더 성공으로 본다.
    void reportLaunch(true);
    return () => {
      uninstall();
      unsubscribe();
    };
  }, []);

  return children;
}

interface BoundaryState {
  failed: boolean;
}

export class ObservabilityErrorBoundary extends Component<{ children: ReactNode }, BoundaryState> {
  state: BoundaryState = { failed: false };

  static getDerivedStateFromError(): BoundaryState {
    return { failed: true };
  }

  componentDidCatch(error: Error, _info: ErrorInfo): void {
    void reportCrash(error, false);
  }

  render() {
    if (this.state.failed) {
      return (
        <View className="flex-1 items-center justify-center bg-bg px-6">
          <Text className="text-center text-base text-ink">앱을 여는 중 문제가 발생했어요.</Text>
        </View>
      );
    }
    return this.props.children;
  }
}

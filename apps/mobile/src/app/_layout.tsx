import "../global.css";

import { Stack } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { type ComponentType, type ReactNode, useEffect, useState } from "react";
import { ActivityIndicator, View } from "react-native";
import { SafeAreaProvider } from "react-native-safe-area-context";
import {
  ObservabilityErrorBoundary,
  ObservabilityProvider,
} from "../features/observability/observability";
import { ApiProvider, useApi } from "../lib/api/api-provider";
import { isStagingBuild } from "../lib/app-environment";
import { ConnectivityProvider } from "../lib/connectivity/connectivity-provider";

const StagingBoundary: ComponentType<{ children: ReactNode }> = isStagingBuild
  ? require("../features/dev-channels/staging-update-provider").StagingUpdateProvider
  : ({ children }) => children;

void SplashScreen.preventAutoHideAsync();

function RootNavigator() {
  const { sessionStatus } = useApi();

  if (sessionStatus === "restoring") {
    return (
      <View
        accessibilityLabel="로그인 상태 확인 중"
        accessibilityRole="progressbar"
        className="flex-1 items-center justify-center bg-bg"
      >
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="index" />
      <Stack.Protected guard={sessionStatus === "unauthenticated"}>
        <Stack.Screen name="(auth)" />
      </Stack.Protected>
      <Stack.Protected guard={sessionStatus === "authenticated"}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen
          name="briefing"
          options={{ animation: "slide_from_right", gestureEnabled: true }}
        />
        <Stack.Screen name="play" />
        <Stack.Screen name="insight" />
        <Stack.Screen name="follow-up" />
      </Stack.Protected>
    </Stack>
  );
}

export default function RootLayout() {
  const [fontsReady, setFontsReady] = useState(false);

  useEffect(() => {
    // 웹의 Pretendard 자산은 WOFF2라 네이티브에서 쓸 수 없다. 호환 자산이 추가될 때까지 시스템 폰트를 쓴다.
    setFontsReady(true);
  }, []);

  useEffect(() => {
    if (fontsReady) {
      void SplashScreen.hideAsync();
    }
  }, [fontsReady]);

  if (!fontsReady) {
    return null;
  }

  return (
    <ObservabilityErrorBoundary>
      <ObservabilityProvider>
        <SafeAreaProvider>
          <ConnectivityProvider>
            <ApiProvider>
              <StagingBoundary>
                <RootNavigator />
              </StagingBoundary>
            </ApiProvider>
          </ConnectivityProvider>
        </SafeAreaProvider>
      </ObservabilityProvider>
    </ObservabilityErrorBoundary>
  );
}

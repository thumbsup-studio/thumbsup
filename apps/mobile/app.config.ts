import type { ConfigContext, ExpoConfig } from "expo/config";

export const UPDATES_URL_PLACEHOLDER = "https://updates.thumbsup.invalid";

export type AppEnvironment = "development" | "staging" | "production";

type Environment = Record<string, string | undefined>;

const profiles: Record<
  AppEnvironment,
  { appName: string; applicationId: string; channel: string | undefined }
> = {
  development: {
    appName: "Thumbs Up Dev",
    applicationId: "studio.thumbsup.dev",
    channel: undefined,
  },
  staging: {
    appName: "Thumbs Up Staging",
    applicationId: "studio.thumbsup.staging",
    channel: "staging",
  },
  production: {
    appName: "Thumbs Up",
    applicationId: "studio.thumbsup",
    channel: "production",
  },
};

function required(environment: Environment, key: string): string {
  const value = environment[key]?.trim();
  if (!value) {
    throw new Error(`[mobile config] ${key} is required`);
  }
  return value;
}

function parseAppEnvironment(value: string | undefined): AppEnvironment {
  if (value !== "development" && value !== "staging" && value !== "production") {
    throw new Error("[mobile config] APP_ENV must be development, staging, or production");
  }
  return value;
}

function validateUrl(value: string, key: string): string {
  try {
    return new URL(value).toString().replace(/\/$/, "");
  } catch {
    throw new Error(`[mobile config] ${key} must be an absolute URL`);
  }
}

export function buildExpoConfig(environment: Environment): ExpoConfig {
  const appEnvironment = parseAppEnvironment(environment.APP_ENV);
  const profile = profiles[appEnvironment];
  const buildProfile = environment.EAS_BUILD_PROFILE?.trim();
  if (buildProfile && buildProfile !== appEnvironment) {
    throw new Error(
      `[mobile config] EAS_BUILD_PROFILE (${buildProfile}) does not match APP_ENV (${appEnvironment})`,
    );
  }

  const apiUrl = validateUrl(required(environment, "EXPO_PUBLIC_API_URL"), "EXPO_PUBLIC_API_URL");
  const updatesUrl = validateUrl(
    environment.EXPO_PUBLIC_UPDATES_URL?.trim() || UPDATES_URL_PLACEHOLDER,
    "EXPO_PUBLIC_UPDATES_URL",
  );
  const configuredChannel = environment.EXPO_PUBLIC_UPDATES_CHANNEL?.trim();
  if (configuredChannel && configuredChannel !== profile.channel) {
    throw new Error(
      `[mobile config] EXPO_PUBLIC_UPDATES_CHANNEL (${configuredChannel}) does not match APP_ENV (${appEnvironment})`,
    );
  }

  const requestHeaders = profile.channel ? { "expo-channel-name": profile.channel } : undefined;

  return {
    name: profile.appName,
    slug: "thumbsup-mobile",
    version: "0.1.0",
    orientation: "portrait",
    scheme: "thumbsup",
    userInterfaceStyle: "automatic",
    runtimeVersion: { policy: "appVersion" },
    updates: {
      url: updatesUrl,
      requestHeaders,
      enabled: appEnvironment !== "development",
      checkAutomatically: "ON_LOAD",
      fallbackToCacheTimeout: 0,
    },
    ios: {
      supportsTablet: true,
      bundleIdentifier: profile.applicationId,
    },
    android: {
      package: profile.applicationId,
    },
    web: {
      bundler: "metro",
    },
    plugins: [
      "expo-router",
      [
        "expo-splash-screen",
        {
          backgroundColor: "#f4f7fb",
          image: "../web/public/icons/tabs/home-full.png",
          imageWidth: 120,
        },
      ],
      "expo-updates",
      "expo-secure-store",
    ],
    experiments: { typedRoutes: true },
    extra: {
      appEnvironment,
      apiUrl,
      updateChannel: profile.channel ?? null,
    },
  };
}

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  ...buildExpoConfig(process.env),
});

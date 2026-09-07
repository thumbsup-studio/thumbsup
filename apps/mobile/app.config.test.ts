import { describe, expect, it } from "vitest";

import { buildExpoConfig, UPDATES_URL_PLACEHOLDER } from "./app.config";

const baseEnvironment = {
  APP_ENV: "staging",
  EAS_BUILD_PROFILE: "staging",
  EXPO_PUBLIC_API_URL: "https://staging-api.thumbsup.example",
  EXPO_PUBLIC_UPDATES_URL: "https://updates.thumbsup.example",
  EXPO_PUBLIC_UPDATES_CHANNEL: "staging",
};

describe("buildExpoConfig", () => {
  it.each([
    ["development", "Thumbs Up Dev", "studio.thumbsup.dev", undefined],
    ["staging", "Thumbs Up Staging", "studio.thumbsup.staging", "staging"],
    ["production", "Thumbs Up", "studio.thumbsup", "production"],
  ] as const)("builds the %s identity", (appEnvironment, name, applicationId, channel) => {
    const config = buildExpoConfig({
      ...baseEnvironment,
      APP_ENV: appEnvironment,
      EAS_BUILD_PROFILE: appEnvironment,
      EXPO_PUBLIC_UPDATES_CHANNEL: channel,
    });

    expect(config.name).toBe(name);
    expect(config.ios?.bundleIdentifier).toBe(applicationId);
    expect(config.android?.package).toBe(applicationId);
    expect(config.updates?.requestHeaders).toEqual(
      channel ? { "expo-channel-name": channel } : undefined,
    );
    expect(config.extra).toMatchObject({ appEnvironment, updateChannel: channel ?? null });
  });

  it("uses the updates placeholder until the CloudFront URL is assigned", () => {
    const config = buildExpoConfig({
      ...baseEnvironment,
      EXPO_PUBLIC_UPDATES_URL: undefined,
    });

    expect(config.updates?.url).toBe(UPDATES_URL_PLACEHOLDER);
  });

  it.each(["APP_ENV", "EXPO_PUBLIC_API_URL"])("rejects a missing %s", (key) => {
    expect(() => buildExpoConfig({ ...baseEnvironment, [key]: undefined })).toThrow(key);
  });

  it("rejects a mismatched build profile", () => {
    expect(() => buildExpoConfig({ ...baseEnvironment, EAS_BUILD_PROFILE: "production" })).toThrow(
      "does not match APP_ENV",
    );
  });

  it("rejects a mismatched update channel", () => {
    expect(() =>
      buildExpoConfig({ ...baseEnvironment, EXPO_PUBLIC_UPDATES_CHANNEL: "production" }),
    ).toThrow("EXPO_PUBLIC_UPDATES_CHANNEL");
  });

  it("rejects a non-URL API endpoint", () => {
    expect(() => buildExpoConfig({ ...baseEnvironment, EXPO_PUBLIC_API_URL: "localhost" })).toThrow(
      "absolute URL",
    );
  });
});

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
    ["development", "Thumbs Up Dev", "studio.thumbsup.dev", undefined, "thumbsup-dev"],
    ["staging", "Thumbs Up Staging", "studio.thumbsup.staging", "staging", "thumbsup-staging"],
    ["production", "Thumbs Up", "studio.thumbsup", "production", "thumbsup"],
  ] as const)("builds the %s identity", (appEnvironment, name, applicationId, channel, scheme) => {
    const config = buildExpoConfig({
      ...baseEnvironment,
      APP_ENV: appEnvironment,
      EAS_BUILD_PROFILE: appEnvironment,
      EXPO_PUBLIC_UPDATES_CHANNEL: channel,
    });

    expect(config.name).toBe(name);
    expect(config.ios?.bundleIdentifier).toBe(applicationId);
    expect(config.android?.package).toBe(applicationId);
    expect(config.scheme).toBe(scheme);
    expect(config.updates?.requestHeaders).toEqual(
      channel ? { "expo-channel-name": channel } : undefined,
    );
    expect(config.extra).toMatchObject({
      appEnvironment,
      updateChannel: channel ?? null,
      updatesUrl: baseEnvironment.EXPO_PUBLIC_UPDATES_URL,
      updatesBaseUrl: "https://updates.thumbsup.example",
    });
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

  it("enables cleartext traffic only for a staging HTTP updates server", () => {
    const config = buildExpoConfig({
      ...baseEnvironment,
      EXPO_PUBLIC_UPDATES_URL: "http://10.0.2.2:8081",
    });

    expect(config.plugins).toContain("./plugins/with-staging-cleartext");
    expect(config.extra?.updatesBaseUrl).toBe("http://10.0.2.2:8081");
  });

  it("rejects a production HTTP updates server", () => {
    expect(() =>
      buildExpoConfig({
        ...baseEnvironment,
        APP_ENV: "production",
        EAS_BUILD_PROFILE: "production",
        EXPO_PUBLIC_UPDATES_CHANNEL: "production",
        EXPO_PUBLIC_UPDATES_URL: "http://updates.example.com",
      }),
    ).toThrow("must use HTTPS");
  });

  it("rejects a non-local staging HTTP updates server", () => {
    expect(() =>
      buildExpoConfig({
        ...baseEnvironment,
        EXPO_PUBLIC_UPDATES_URL: "http://updates.example.com",
      }),
    ).toThrow("must use a local emulator host");
  });

  it("configures a local signing certificate only for staging", () => {
    const config = buildExpoConfig({
      ...baseEnvironment,
      EXPO_UPDATES_CODE_SIGNING_CERTIFICATE: "../../.omc/331/certificate.pem",
    });

    expect(config.updates).toMatchObject({
      codeSigningCertificate: "../../.omc/331/certificate.pem",
      codeSigningMetadata: { keyid: "main", alg: "rsa-v1_5-sha256" },
    });
  });
});

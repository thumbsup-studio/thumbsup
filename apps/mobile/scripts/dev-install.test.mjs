import { describe, expect, it } from "vitest";
import { artifactUrl, localFallback, parsePlatform } from "./dev-install.mjs";

describe("dev-install helpers", () => {
  it("accepts only supported platforms", () => {
    expect(parsePlatform("android")).toBe("android");
    expect(() => parsePlatform("web")).toThrow("ios|android");
  });

  it("builds stable artifact URLs", () => {
    expect(artifactUrl("https://artifacts.example/dev/", "android")).toBe(
      "https://artifacts.example/dev/android/latest.apk",
    );
    expect(artifactUrl("https://artifacts.example/dev", "ios")).toBe(
      "https://artifacts.example/dev/ios/latest.zip",
    );
  });

  it("falls back to a local build on both platforms", () => {
    expect(localFallback("android")).toEqual({
      command: "pnpm",
      args: ["exec", "expo", "run:android", "--no-bundler"],
    });
    expect(localFallback("ios")).toEqual({
      command: "pnpm",
      args: ["exec", "expo", "run:ios", "--no-bundler"],
    });
  });
});

import { describe, expect, it } from "vitest";
import { androidSdkPath, androidTool, apiReachable, parseEnvironment } from "./doctor.mjs";

describe("doctor helpers", () => {
  it("parses dotenv values without comments", () => {
    expect(
      parseEnvironment(
        "# comment\nAPP_ENV=development\nEXPO_PUBLIC_API_URL=http://localhost:8080\n",
      ),
    ).toEqual({
      APP_ENV: "development",
      EXPO_PUBLIC_API_URL: "http://localhost:8080",
    });
  });

  it("chooses an explicit Android SDK before the macOS default", () => {
    expect(androidSdkPath({ ANDROID_HOME: "/sdk" }, "/Users/me")).toBe("/sdk");
    expect(androidSdkPath({}, "/Users/me")).toBe("/Users/me/Library/Android/sdk");
  });

  it("falls back when an SDK tool path does not exist", () => {
    expect(androidTool("/missing", "platform-tools/adb", "adb")).toBe("adb");
  });

  it("treats any real HTTP response as reachable", () => {
    expect(apiReachable(0, "404")).toBe(true);
    expect(apiReachable(7, "000")).toBe(false);
  });
});

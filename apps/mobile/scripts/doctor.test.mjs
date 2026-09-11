import { describe, expect, it } from "vitest";
import {
  androidSdkPath,
  androidTool,
  apiReachable,
  javaMajor,
  meetsVersion,
  parseEnvironment,
  parsePlatform,
  xcodeVersion,
} from "./doctor.mjs";

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

describe("platform argument", () => {
  it("reads a supported platform from argv", () => {
    expect(parsePlatform(["android"])).toBe("android");
    expect(parsePlatform(["--", "ios"])).toBe("ios");
  });

  it("returns null when no platform is given", () => {
    expect(parsePlatform([])).toBeNull();
    expect(parsePlatform(["web"])).toBeNull();
  });
});

describe("javaMajor", () => {
  it("reads modern version strings", () => {
    expect(javaMajor('openjdk version "17.0.15" 2025-04-15 LTS')).toBe(17);
    expect(javaMajor('openjdk version "21.0.4" 2024-07-16 LTS')).toBe(21);
  });

  it("reads the legacy 1.x scheme", () => {
    expect(javaMajor('java version "1.8.0_401"')).toBe(8);
  });

  it("returns null when there is no version", () => {
    expect(javaMajor(null)).toBeNull();
    expect(javaMajor("command not found")).toBeNull();
  });
});

describe("xcodeVersion", () => {
  it("reads the version from xcodebuild output", () => {
    expect(xcodeVersion("Xcode 26.6\nBuild version 17F113")).toBe("26.6");
    expect(xcodeVersion("Xcode 16.2\nBuild version 16C5032a")).toBe("16.2");
  });

  it("returns null when xcodebuild produced nothing", () => {
    expect(xcodeVersion(null)).toBeNull();
  });
});

describe("meetsVersion", () => {
  it("compares dotted versions numerically, not as strings", () => {
    expect(meetsVersion("26.10", "26.4")).toBe(true);
    expect(meetsVersion("26.4", "26.4")).toBe(true);
    expect(meetsVersion("26.3", "26.4")).toBe(false);
    expect(meetsVersion("16.2", "26.4")).toBe(false);
  });

  it("treats missing trailing parts as zero", () => {
    expect(meetsVersion("27", "26.4")).toBe(true);
    expect(meetsVersion("26", "26.4")).toBe(false);
  });

  it("fails when the version is unknown", () => {
    expect(meetsVersion(null, "26.4")).toBe(false);
  });
});

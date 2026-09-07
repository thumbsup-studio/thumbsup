import { existsSync } from "node:fs";
import { createServer } from "node:net";
import { fileURLToPath } from "node:url";
import { commandExists, commandOutput, printResult, run } from "./process.mjs";

const environmentFile = fileURLToPath(new URL("../.env.local", import.meta.url));

export function parseEnvironment(text) {
  return Object.fromEntries(
    text
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#") && line.includes("="))
      .map((line) => {
        const separator = line.indexOf("=");
        return [line.slice(0, separator).trim(), line.slice(separator + 1).trim()];
      }),
  );
}

export function androidSdkPath(environment, home) {
  return (
    environment.ANDROID_HOME ||
    environment.ANDROID_SDK_ROOT ||
    joinHome(home, "Library/Android/sdk")
  );
}

export function androidTool(sdk, relativePath, fallback) {
  const candidate = sdk ? `${sdk}/${relativePath}` : "";
  return candidate && existsSync(candidate) ? candidate : fallback;
}

function joinHome(home, suffix) {
  return home ? `${home.replace(/\/$/, "")}/${suffix}` : "";
}

export function apiReachable(status, httpCode) {
  return status === 0 && /^\d{3}$/.test(httpCode) && httpCode !== "000";
}

export async function portAvailable(port) {
  return new Promise((resolve) => {
    const server = createServer();
    server.once("error", () => resolve(false));
    server.listen(port, "127.0.0.1", () => server.close(() => resolve(true)));
  });
}

export async function main(environment = process.env) {
  const { readFileSync } = await import("node:fs");
  const fileEnvironment = existsSync(environmentFile)
    ? parseEnvironment(readFileSync(environmentFile, "utf8"))
    : {};
  const env = { ...fileEnvironment, ...environment };
  let failures = 0;
  let warnings = 0;
  const required = (label, ok, detail) => {
    printResult(label, ok, detail);
    if (!ok) failures += 1;
  };
  const optional = (label, ok, detail) => {
    printResult(label, ok, detail);
    if (!ok) warnings += 1;
  };

  const javaResult = run("java", ["-version"]);
  const java =
    javaResult.status === 0 ? (javaResult.stderr || javaResult.stdout).trim().split("\n")[0] : null;
  required("JDK", Boolean(java), java || "설치되지 않음");

  const sdk = androidSdkPath(env, env.HOME);
  required("Android SDK", Boolean(sdk && existsSync(sdk)), sdk || "ANDROID_HOME 미설정");
  const emulator = androidTool(sdk, "emulator/emulator", "emulator");
  const avds = commandOutput(emulator, ["-list-avds"]);
  optional("Android AVD", Boolean(avds), avds?.replace(/\n/g, ", ") || "없음");
  const adbCommand = androidTool(sdk, "platform-tools/adb", "adb");
  const adb = commandOutput(adbCommand, ["devices"]);
  optional(
    "Android 에뮬레이터/기기",
    Boolean(
      adb
        ?.split("\n")
        .slice(1)
        .some((line) => /\tdevice$/.test(line)),
    ),
    adb ? "연결 상태 확인" : "adb 없음",
  );

  const xcode = commandOutput("xcodebuild", ["-version"]);
  optional("Xcode", Boolean(xcode), xcode?.replace(/\n/g, " / ") || "설치되지 않음");
  const simulators = commandOutput("xcrun", ["simctl", "list", "devices", "available"]);
  optional(
    "iOS 시뮬레이터",
    Boolean(simulators && /iPhone|iPad/.test(simulators)),
    simulators ? "사용 가능" : "없음",
  );

  const metroFree = await portAvailable(8081);
  required("Metro 포트 8081", metroFree, metroFree ? "사용 가능" : "다른 프로세스가 사용 중");

  const apiUrl = env.EXPO_PUBLIC_API_URL?.trim();
  if (!apiUrl) {
    required("EXPO_PUBLIC_API_URL", false, ".env.local에 설정 필요");
  } else {
    const curl = run("curl", [
      "--silent",
      "--show-error",
      "--output",
      "/dev/null",
      "--write-out",
      "%{http_code}",
      "--connect-timeout",
      "3",
      "--max-time",
      "5",
      apiUrl,
    ]);
    required(
      "EXPO_PUBLIC_API_URL 도달성",
      apiReachable(curl.status, curl.stdout.trim()),
      `${apiUrl} (HTTP ${curl.stdout.trim() || "응답 없음"})`,
    );
  }

  optional(
    "Watchman",
    commandExists("watchman"),
    commandExists("watchman") ? commandOutput("watchman", ["--version"]) : "설치되지 않음",
  );
  console.log(`\n진단 완료: 실패 ${failures}개, 경고 ${warnings}개`);
  process.exitCode = failures === 0 ? 0 : 1;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();

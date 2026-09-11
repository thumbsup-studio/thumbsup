import { existsSync } from "node:fs";
import { createServer } from "node:net";
import { fileURLToPath } from "node:url";
import { commandExists, commandOutput, printResult, run } from "./process.mjs";

const environmentFile = fileURLToPath(new URL("../.env.local", import.meta.url));

export const MINIMUM_JDK_MAJOR = 17;
export const MINIMUM_XCODE_VERSION = "26.4";

const DOCUMENT = "apps/mobile/docs/local-dev.md";

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

export function parsePlatform(argv) {
  const value = argv.find((entry) => entry === "android" || entry === "ios");
  return value ?? null;
}

export function javaMajor(text) {
  if (!text) return null;
  const match = text.match(/version "(\d+)(?:\.(\d+))?/);
  if (!match) return null;
  const first = Number.parseInt(match[1], 10);
  if (first === 1) return match[2] ? Number.parseInt(match[2], 10) : null;
  return first;
}

export function xcodeVersion(text) {
  const match = text?.match(/Xcode (\d+(?:\.\d+)*)/);
  return match ? match[1] : null;
}

export function meetsVersion(actual, minimum) {
  if (!actual) return false;
  const left = actual.split(".").map((part) => Number.parseInt(part, 10) || 0);
  const right = minimum.split(".").map((part) => Number.parseInt(part, 10) || 0);
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const a = left[index] ?? 0;
    const b = right[index] ?? 0;
    if (a !== b) return a > b;
  }
  return true;
}

export function isMetroStatus(body) {
  return typeof body === "string" && body.trim().startsWith("packager-status:running");
}

// Metro는 /status에 packager-status:running으로 응답한다. React Native 도구들이 쓰는 것과 같은 신호다.
function metroListening() {
  const probe = run("curl", ["--silent", "--max-time", "2", "http://127.0.0.1:8081/status"]);
  return probe.status === 0 && isMetroStatus(probe.stdout);
}

export async function portAvailable(port) {
  return new Promise((resolve) => {
    const server = createServer();
    server.once("error", () => resolve(false));
    server.listen(port, "127.0.0.1", () => server.close(() => resolve(true)));
  });
}

export async function main(environment = process.env, argv = process.argv.slice(2)) {
  const { readFileSync } = await import("node:fs");
  const fileEnvironment = existsSync(environmentFile)
    ? parseEnvironment(readFileSync(environmentFile, "utf8"))
    : {};
  const env = { ...fileEnvironment, ...environment };
  const platform = parsePlatform(argv);

  let failures = 0;
  const fix = (hint) => {
    if (hint) console.log(`  → ${hint}`);
  };
  const check = (label, ok, detail, hint, level) => {
    printResult(label, ok, detail);
    if (ok) return ok;
    fix(hint);
    if (level === "required") failures += 1;
    return ok;
  };
  // 플랫폼을 지정하면 그 플랫폼 도구가 필수가 되고, 지정하지 않으면 안내만 한다.
  const forPlatform = (target) => (platform === target ? "required" : "info");

  console.log(
    platform
      ? `대상 플랫폼: ${platform}\n`
      : "대상 플랫폼: 지정 없음 (android 또는 ios를 인자로 주면 해당 도구를 필수로 검사한다)\n",
  );

  // --- Android ---
  const javaResult = run("java", ["-version"]);
  const javaText =
    javaResult.status === 0 ? (javaResult.stderr || javaResult.stdout).trim().split("\n")[0] : null;
  const major = javaMajor(javaText);
  const javaOk = Boolean(major) && major >= MINIMUM_JDK_MAJOR;
  check(
    `JDK ${MINIMUM_JDK_MAJOR} 이상`,
    javaOk,
    javaText ?? "설치되지 않음",
    javaText
      ? `Android 빌드의 Gradle에는 JDK ${MINIMUM_JDK_MAJOR} 이상이 필요하다. brew install --cask temurin@${MINIMUM_JDK_MAJOR} 로 설치하고 JAVA_HOME을 그 경로로 지정한다.`
      : `brew install --cask temurin@${MINIMUM_JDK_MAJOR} 로 설치한다.`,
    forPlatform("android"),
  );

  const sdk = androidSdkPath(env, env.HOME);
  const sdkConfigured = Boolean(env.ANDROID_HOME || env.ANDROID_SDK_ROOT);
  const sdkOk = Boolean(sdk && existsSync(sdk));
  const sdkMiss = sdkConfigured
    ? "ANDROID_HOME 경로가 없음"
    : "ANDROID_HOME 미설정, 기본 경로에도 없음";
  check(
    "Android SDK",
    sdkOk,
    sdkOk ? sdk : `${sdk || "경로 없음"} (${sdkMiss})`,
    `Android Studio를 설치하고 SDK Manager에서 Android SDK를 받은 뒤 ANDROID_HOME을 설정한다. 절차는 ${DOCUMENT}의 "준비물" 참고.`,
    forPlatform("android"),
  );

  const emulator = androidTool(sdk, "emulator/emulator", "emulator");
  const avds = commandOutput(emulator, ["-list-avds"]);
  check(
    "Android AVD",
    Boolean(avds),
    avds?.replace(/\n/g, ", ") || "없음",
    `Android Studio의 Device Manager에서 가상 기기를 하나 만든다. 시스템 이미지는 API 35(Android 15)를 고른다. 절차는 ${DOCUMENT}의 "준비물" 참고.`,
    forPlatform("android"),
  );

  const adbCommand = androidTool(sdk, "platform-tools/adb", "adb");
  const adb = commandOutput(adbCommand, ["devices"]);
  const adbConnected = Boolean(
    adb
      ?.split("\n")
      .slice(1)
      .some((line) => /\tdevice$/.test(line)),
  );
  check(
    "Android 에뮬레이터/기기",
    adbConnected,
    adb ? (adbConnected ? "연결됨" : "연결된 기기 없음") : "adb 없음",
    adb
      ? "Android Studio의 Device Manager에서 가상 기기를 실행하거나, USB로 실기기를 연결하고 개발자 모드의 USB 디버깅을 켠다."
      : "Android SDK의 platform-tools가 설치돼 있는지 확인한다.",
    forPlatform("android"),
  );

  // --- iOS ---
  const xcodeText = commandOutput("xcodebuild", ["-version"]);
  const xcode = xcodeVersion(xcodeText);
  const xcodeOk = meetsVersion(xcode, MINIMUM_XCODE_VERSION);
  check(
    `Xcode ${MINIMUM_XCODE_VERSION} 이상`,
    xcodeOk,
    xcodeText?.replace(/\n/g, " / ") || "설치되지 않음",
    xcode
      ? `Expo SDK 57의 iOS 네이티브 빌드에는 Xcode ${MINIMUM_XCODE_VERSION} 이상이 필요하다. 올리기 전에는 cd apps/mobile && pnpm exec expo start 로 Expo Go에서 JavaScript 화면만 확인한다.`
      : "App Store에서 Xcode를 설치하고 xcode-select --install 로 Command Line Tools까지 받는다.",
    forPlatform("ios"),
  );

  const simulators = commandOutput("xcrun", ["simctl", "list", "devices", "available"]);
  const simulatorOk = Boolean(simulators && /iPhone|iPad/.test(simulators));
  check(
    "iOS 시뮬레이터",
    simulatorOk,
    simulators ? "사용 가능" : "없음",
    "Xcode를 한 번 실행해 첫 구동 설정을 마치고, Settings의 Components에서 iOS 시뮬레이터 런타임을 내려받는다.",
    forPlatform("ios"),
  );

  // --- 공통 ---
  // 포트가 비어 있거나, 점유자가 Metro 자신이면 통과한다. 개발 중에는 Metro가 떠 있는 게 정상이다.
  const metroFree = await portAvailable(8081);
  const metroRunning = metroFree ? false : metroListening();
  check(
    "Metro 포트 8081",
    metroFree || metroRunning,
    metroFree ? "사용 가능" : metroRunning ? "Metro 실행 중" : "다른 프로세스가 사용 중",
    "lsof -nP -iTCP:8081 -sTCP:LISTEN 으로 점유 프로세스를 확인하고 종료한 뒤 다시 실행한다.",
    "required",
  );

  const apiUrl = env.EXPO_PUBLIC_API_URL?.trim();
  if (!apiUrl) {
    check(
      "EXPO_PUBLIC_API_URL",
      false,
      ".env.local에 없음",
      "pnpm bootstrap 을 실행해 apps/mobile/.env.local을 만든다. 앱은 이 값이 없으면 시작 시점에 예외를 던진다.",
      "required",
    );
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
    check(
      "EXPO_PUBLIC_API_URL 도달성",
      apiReachable(curl.status, curl.stdout.trim()),
      `${apiUrl} (HTTP ${curl.stdout.trim() || "응답 없음"})`,
      "로컬 서버 주소라면 서버가 떠 있는지 확인한다. Android 에뮬레이터에서는 localhost가 아니라 10.0.2.2를 쓴다.",
      "required",
    );
  }

  const watchmanOk = commandExists("watchman");
  check(
    "Watchman",
    watchmanOk,
    watchmanOk ? commandOutput("watchman", ["--version"]) : "설치되지 않음",
    "brew install watchman — 선택 사항이지만 파일 변경 감지가 안정된다.",
    "info",
  );

  // 플랫폼을 지정하지 않았다면 적어도 한쪽은 앱을 띄울 수 있어야 한다.
  const androidReady = javaOk && sdkOk && adbConnected;
  const iosReady = xcodeOk && simulatorOk;
  if (!platform) {
    check(
      "실행 가능한 플랫폼",
      androidReady || iosReady,
      androidReady || iosReady
        ? [androidReady && "android", iosReady && "ios"].filter(Boolean).join(", ")
        : "없음",
      `Android는 JDK ${MINIMUM_JDK_MAJOR} 이상·Android SDK·실행 중인 기기가, iOS는 Xcode ${MINIMUM_XCODE_VERSION} 이상·시뮬레이터가 모두 있어야 한다. 위의 ✗ 항목을 채운다.`,
      "required",
    );
  }

  console.log(`\n진단 완료: 필수 항목 실패 ${failures}개`);
  if (!platform) {
    console.log(
      "한쪽 플랫폼만 쓸 계획이면 pnpm diagnose android 또는 pnpm diagnose ios 로 그 플랫폼만 필수 검사한다.",
    );
  }
  process.exitCode = failures === 0 ? 0 : 1;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();

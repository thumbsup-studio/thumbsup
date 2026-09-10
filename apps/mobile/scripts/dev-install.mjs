import { spawn } from "node:child_process";
import { mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { printResult, run } from "./process.mjs";

const mobileDirectory = fileURLToPath(new URL("..", import.meta.url));

export function parsePlatform(value) {
  if (value === "ios" || value === "android") return value;
  throw new Error("사용법: pnpm dev:install [ios|android]");
}

export function artifactUrl(baseUrl, platform) {
  const extension = platform === "android" ? "apk" : "zip";
  return `${baseUrl.replace(/\/+$/, "")}/${platform}/latest.${extension}`;
}

export function localFallback(platform) {
  const target = platform === "android" ? "run:android" : "run:ios";
  return { command: "pnpm", args: ["exec", "expo", target, "--no-bundler"] };
}

function installDownloaded(platform, directory) {
  if (platform === "android") {
    return run("adb", ["install", "-r", join(directory, "latest.apk")], { stdio: "inherit" });
  }

  const archive = join(directory, "latest.zip");
  const unzip = run("unzip", ["-q", archive, "-d", directory], { stdio: "inherit" });
  if (unzip.status !== 0) return unzip;
  const app = readdirSync(directory).find((entry) => entry.endsWith(".app"));
  if (!app) return { status: 1 };
  return run("xcrun", ["simctl", "install", "booted", join(directory, app)], { stdio: "inherit" });
}

export function runExpoLocalBuild(fallback) {
  return new Promise((resolve) => {
    const child = spawn(fallback.command, fallback.args, {
      cwd: mobileDirectory,
      env: { ...process.env, CI: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let installed = false;
    const forward = (target) => (chunk) => {
      target.write(chunk);
      if (!installed && chunk.toString().includes("› Opening ")) {
        installed = true;
        child.kill("SIGINT");
      }
    };
    child.stdout.on("data", forward(process.stdout));
    child.stderr.on("data", forward(process.stderr));
    child.once("error", () => resolve(1));
    child.once("exit", (code, signal) =>
      resolve(installed && signal === "SIGINT" ? 0 : (code ?? 1)),
    );
  });
}

export async function main(argv = process.argv.slice(2), environment = process.env) {
  let platform;
  try {
    platform = parsePlatform(argv[0]);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
    return;
  }

  const baseUrl = environment.MOBILE_DEV_CLIENT_BASE_URL?.trim();
  if (!baseUrl) {
    const fallback = localFallback(platform);
    console.log(`MOBILE_DEV_CLIENT_BASE_URL 미설정: 로컬 ${platform} dev 빌드로 대체합니다.`);
    process.exitCode = await runExpoLocalBuild(fallback);
    return;
  }

  const directory = mkdtempSync(join(tmpdir(), "thumbsup-dev-client-"));
  const url = artifactUrl(baseUrl, platform);
  const target = join(directory, basename(url));
  try {
    const download = run("curl", ["--fail", "--location", "--output", target, url], {
      stdio: "inherit",
    });
    if (download.status !== 0) {
      process.exitCode = download.status ?? 1;
      return;
    }
    const install = installDownloaded(platform, directory);
    const ok = install.status === 0;
    printResult(`${platform} dev-client 설치`, ok, url);
    process.exitCode = install.status ?? 1;
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();

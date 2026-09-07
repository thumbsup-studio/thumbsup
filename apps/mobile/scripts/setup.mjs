import { constants, copyFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { commandExists, commandOutput, printResult, run } from "./process.mjs";

export const mobileDirectory = fileURLToPath(new URL("..", import.meta.url));
export const repositoryDirectory = fileURLToPath(new URL("../../..", import.meta.url));

export function nodeMajor(version) {
  return Number.parseInt(version.replace(/^v/, "").split(".")[0], 10);
}

export function pnpmMajor(version) {
  return Number.parseInt(version.split(".")[0], 10);
}

export function shouldCreateEnvironment(targetExists) {
  return !targetExists;
}

export function main() {
  const nodeOk = nodeMajor(process.version) >= 22;
  printResult("Node.js 22 이상", nodeOk, process.version);

  const pnpmVersion = commandOutput("pnpm", ["--version"]);
  const pnpmOk = pnpmVersion !== null && pnpmMajor(pnpmVersion) === 10;
  printResult("pnpm 10", pnpmOk, pnpmVersion ?? "설치되지 않음");

  const watchmanOk = commandExists("watchman");
  printResult(
    "Watchman",
    watchmanOk,
    watchmanOk ? commandOutput("watchman", ["--version"]) : "설치되지 않음(선택 사항)",
  );

  if (!nodeOk || !pnpmOk) process.exitCode = 1;
  if (!nodeOk || !pnpmOk) return;

  const install = run("pnpm", ["install", "--frozen-lockfile"], {
    cwd: repositoryDirectory,
    stdio: "inherit",
  });
  if (install.status !== 0) {
    process.exitCode = install.status ?? 1;
    return;
  }

  const source = fileURLToPath(new URL("../.env.example", import.meta.url));
  const target = fileURLToPath(new URL("../.env.local", import.meta.url));
  if (shouldCreateEnvironment(existsSync(target))) {
    copyFileSync(source, target, constants.COPYFILE_EXCL);
    console.log("✓ apps/mobile/.env.local 생성");
  } else {
    console.log("✓ apps/mobile/.env.local 유지(기존 파일을 덮어쓰지 않음)");
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();

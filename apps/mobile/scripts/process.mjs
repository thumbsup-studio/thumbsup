import { spawnSync } from "node:child_process";

export function run(command, args = [], options = {}) {
  return spawnSync(command, args, {
    encoding: "utf8",
    ...options,
  });
}

export function commandOutput(command, args = []) {
  const result = run(command, args);
  return result.status === 0 ? result.stdout.trim() : null;
}

export function commandExists(command) {
  return run("sh", ["-c", `command -v "$1"`, "sh", command]).status === 0;
}

export function printResult(label, ok, detail) {
  const suffix = detail ? ` — ${detail}` : "";
  console.log(`${ok ? "✓" : "✗"} ${label}${suffix}`);
}

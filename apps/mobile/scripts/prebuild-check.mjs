import { spawnSync } from "node:child_process";
import { rmSync } from "node:fs";
import { fileURLToPath } from "node:url";

const projectDirectory = fileURLToPath(new URL("..", import.meta.url));
const generatedDirectories = ["ios", "android"].map((name) =>
  fileURLToPath(new URL(`../${name}`, import.meta.url)),
);

let exitCode = 1;
try {
  const result = spawnSync(
    "pnpm",
    ["exec", "expo", "prebuild", "--no-install", "--platform", "all"],
    {
      cwd: projectDirectory,
      env: process.env,
      stdio: "inherit",
    },
  );
  exitCode = result.status ?? 1;
} finally {
  for (const directory of generatedDirectories) {
    rmSync(directory, { recursive: true, force: true });
  }
}

process.exit(exitCode);

import { spawnSync } from "node:child_process";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const projectDirectory = fileURLToPath(new URL("..", import.meta.url));
const temporaryDirectory = mkdtempSync(join(tmpdir(), "thumbsup-production-export-"));
const certificatePath = join(temporaryDirectory, "certificate.pem");
const privateKeyPath = join(temporaryDirectory, "private-key.pem");
const outputDirectory = join(temporaryDirectory, "dist");
const forbidden = "setUpdateRequestHeadersOverride";

function filesBelow(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? filesBelow(path) : [path];
  });
}

try {
  const certificate = spawnSync(
    "openssl",
    [
      "req",
      "-x509",
      "-newkey",
      "rsa:2048",
      "-nodes",
      "-keyout",
      privateKeyPath,
      "-out",
      certificatePath,
      "-days",
      "1",
      "-subj",
      "/CN=thumbsup-production-export-check",
    ],
    { cwd: projectDirectory, stdio: "ignore" },
  );
  if (certificate.status !== 0) throw new Error("테스트용 코드 서명 인증서를 만들지 못했습니다.");

  const exported = spawnSync(
    "pnpm",
    ["exec", "expo", "export", "--platform", "all", "--output-dir", outputDirectory],
    {
      cwd: projectDirectory,
      env: {
        ...process.env,
        APP_ENV: "production",
        EAS_BUILD_PROFILE: "production",
        NODE_ENV: "production",
        EXPO_PUBLIC_API_URL: "https://thumbsup-api.duckdns.org",
        EXPO_PUBLIC_UPDATES_CHANNEL: "production",
        EXPO_PUBLIC_UPDATES_URL: "https://updates.thumbsup.invalid",
        EXPO_UPDATES_CODE_SIGNING_CERTIFICATE: certificatePath,
      },
      stdio: "inherit",
    },
  );
  if (exported.status !== 0) process.exitCode = exported.status ?? 1;
  else {
    const leakingFiles = filesBelow(outputDirectory).filter((path) =>
      readFileSync(path).includes(forbidden),
    );
    if (leakingFiles.length > 0) {
      throw new Error(
        `production 번들에 staging 채널 전환 API가 포함됐습니다: ${leakingFiles.join(", ")}`,
      );
    }
    process.stdout.write(`production export 검사 통과: ${forbidden} 없음\n`);
  }
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
}

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

export type BridgeCli = "CLAUDE" | "CODEX" | "GEMINI";
export type BridgeConfig = { serverUrl: string; cli: BridgeCli; accessToken: string; refreshToken: string };

const BRIDGE_CLIS: readonly BridgeCli[] = ["CLAUDE", "CODEX", "GEMINI"];

export const CONFIG_PATH = join(homedir(), ".thumbsup", "bridge.json");

export function loadConfig(path: string = CONFIG_PATH): BridgeConfig {
  let raw: string;
  try {
    raw = readFileSync(path, "utf-8");
  } catch {
    throw new Error(`설정 파일을 찾을 수 없습니다: ${path}\n먼저 login 명령으로 로그인해주세요.`);
  }

  const data = JSON.parse(raw) as Partial<BridgeConfig>;

  if (typeof data.serverUrl !== "string" || data.serverUrl.length === 0) {
    throw new Error("설정이 올바르지 않습니다: serverUrl이 비어있습니다.");
  }
  if (typeof data.cli !== "string" || !BRIDGE_CLIS.includes(data.cli as BridgeCli)) {
    throw new Error(`설정이 올바르지 않습니다: cli는 ${BRIDGE_CLIS.join(", ")} 중 하나여야 합니다.`);
  }
  if (typeof data.accessToken !== "string" || data.accessToken.length === 0) {
    throw new Error("설정이 올바르지 않습니다: accessToken이 비어있습니다.");
  }
  if (typeof data.refreshToken !== "string" || data.refreshToken.length === 0) {
    throw new Error("설정이 올바르지 않습니다: refreshToken이 비어있습니다.");
  }

  return {
    serverUrl: data.serverUrl.replace(/\/+$/, ""),
    cli: data.cli,
    accessToken: data.accessToken,
    refreshToken: data.refreshToken,
  };
}

export function saveConfig(config: BridgeConfig, path: string = CONFIG_PATH): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(config, null, 2), { mode: 0o600 });
}

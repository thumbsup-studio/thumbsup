import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { loadConfig, saveConfig, type BridgeCli, type BridgeConfig } from "../src/config.js";

describe("config", () => {
  const valid: BridgeConfig = { serverUrl: "http://localhost:8080", cli: "CLAUDE", accessToken: "a", refreshToken: "r" };

  it("저장한 config를 그대로 다시 읽는다", () => {
    const path = join(mkdtempSync(join(tmpdir(), "bridge-")), "bridge.json");
    saveConfig(valid, path);
    expect(loadConfig(path)).toEqual(valid);
  });
  it("cli 값이 잘못되면 명확한 에러를 던진다", () => {
    const path = join(mkdtempSync(join(tmpdir(), "bridge-")), "bridge.json");
    saveConfig({ ...valid, cli: "COPILOT" as BridgeCli }, path);
    expect(() => loadConfig(path)).toThrow(/cli/);
  });
  it("파일이 없으면 로그인 안내 메시지를 던진다", () => {
    expect(() => loadConfig("/nonexistent/bridge.json")).toThrow(/login/);
  });
});

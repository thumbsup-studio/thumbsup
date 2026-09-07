import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  DEFAULT_AUTHORING_URL,
  getAuthoringUrl,
  loadConfig,
  saveConfig,
  type BridgeCli,
  type BridgeConfig,
} from "../src/config.js";

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
  it("파일 내용이 손상된 JSON이면 친절한 한국어 메시지를 던진다", () => {
    const path = join(mkdtempSync(join(tmpdir(), "bridge-")), "bridge.json");
    writeFileSync(path, "{corrupted");
    expect(() => loadConfig(path)).toThrow(/login/);
  });
  it("파일 내용이 객체가 아니면(null) 친절한 한국어 메시지를 던진다", () => {
    const path = join(mkdtempSync(join(tmpdir(), "bridge-")), "bridge.json");
    writeFileSync(path, "null");
    expect(() => loadConfig(path)).toThrow(/login/);
  });

  it("저작 앱 URL은 운영 주소를 기본값으로 쓰고 환경변수로 바꿀 수 있다", () => {
    expect(getAuthoringUrl({})).toBe(DEFAULT_AUTHORING_URL);
    expect(getAuthoringUrl({ THUMBSUP_AUTHORING_URL: "https://authoring.example.com/" })).toBe(
      "https://authoring.example.com",
    );
  });
});

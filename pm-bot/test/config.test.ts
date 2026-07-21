import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config.js";

describe("loadConfig", () => {
  it("유효한 설정을 그대로 반환한다", () => {
    const cfg = loadConfig({ channels: ["C1"], dbPath: "./x.sqlite", specDir: "./docs" });
    expect(cfg.channels).toEqual(["C1"]);
    expect(cfg.claudeBin).toBeUndefined();
  });

  it("channels가 비어 있으면 키 이름을 담아 던진다", () => {
    expect(() => loadConfig({ channels: [], dbPath: "./x", specDir: "./d" })).toThrow(/channels/);
  });

  it("dbPath·specDir 누락 시 던진다", () => {
    expect(() => loadConfig({ channels: ["C1"] })).toThrow(/dbPath|specDir/);
  });

  it("객체가 아니면 던진다", () => {
    expect(() => loadConfig(null)).toThrow();
  });

  it("github 블록이 있으면 필수 키를 검증한다", () => {
    const base = { channels: ["C1"], dbPath: "./db", specDir: "./specs" };
    expect(() => loadConfig({ ...base, github: { repo: "o/r" } })).toThrow(/github/);
    const ok = loadConfig({ ...base, github: { repo: "o/r", projectOwner: "o", projectNumber: 2, specDirInRepo: "docs/x", account: "kmjnnhyk" } });
    expect(ok.github?.projectNumber).toBe(2);
  });

  it("github 블록이 없으면 undefined로 통과한다 (Phase 1 설정 호환)", () => {
    expect(loadConfig({ channels: ["C1"], dbPath: "./db", specDir: "./specs" }).github).toBeUndefined();
  });
});

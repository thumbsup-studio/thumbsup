import { describe, expect, it } from "vitest";
import { commandExists, commandOutput } from "./process.mjs";

describe("process helpers", () => {
  it("captures successful command output", () => {
    expect(commandOutput(process.execPath, ["--version"])).toMatch(/^v\d+/);
  });

  it("detects commands without invoking a shell interpolation", () => {
    expect(commandExists("node")).toBe(true);
    expect(commandExists("thumbsup-command-that-does-not-exist")).toBe(false);
  });
});

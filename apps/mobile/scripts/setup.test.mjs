import { describe, expect, it } from "vitest";
import { nodeMajor, pnpmMajor, shouldCreateEnvironment } from "./setup.mjs";

describe("setup helpers", () => {
  it("parses tool major versions", () => {
    expect(nodeMajor("v22.19.0")).toBe(22);
    expect(pnpmMajor("10.11.0")).toBe(10);
  });

  it("creates .env.local only when it does not exist", () => {
    expect(shouldCreateEnvironment(false)).toBe(true);
    expect(shouldCreateEnvironment(true)).toBe(false);
  });
});

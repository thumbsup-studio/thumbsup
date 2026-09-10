import { describe, expect, it } from "vitest";
import { isStagingBuild, isStagingEnvironment } from "./app-environment";

describe("staging 환경 가드", () => {
  it("production 프로파일에서 staging 기능을 비활성화한다", () => {
    expect(isStagingBuild).toBe(false);
    expect(isStagingEnvironment("production")).toBe(false);
  });

  it("staging 프로파일만 허용한다", () => {
    expect(isStagingEnvironment("staging")).toBe(true);
  });
});

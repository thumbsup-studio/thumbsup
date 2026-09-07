import { hasInvalidIdParam, parsePositiveIdParam } from "./route-params";

describe("route params", () => {
  it("양의 정수만 ID로 허용한다", () => {
    expect(parsePositiveIdParam("3")).toBe(3);
    expect(parsePositiveIdParam("0")).toBeUndefined();
    expect(hasInvalidIdParam(["1", "2"])).toBe(true);
    expect(hasInvalidIdParam(undefined)).toBe(false);
  });
});

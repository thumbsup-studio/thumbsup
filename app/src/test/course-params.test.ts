import { describe, expect, it } from "vitest";
import { parseCourseId } from "@/features/play/course-params";

describe("parseCourseId", () => {
  it("accepts a positive integer string", () => {
    expect(parseCourseId("2")).toBe(2);
  });

  it("rejects a decimal value instead of truncating it", () => {
    expect(parseCourseId("2.9")).toBeUndefined();
  });

  it("rejects zero, negative, and non-numeric values", () => {
    expect(parseCourseId("0")).toBeUndefined();
    expect(parseCourseId("-1")).toBeUndefined();
    expect(parseCourseId("abc")).toBeUndefined();
    expect(parseCourseId(undefined)).toBeUndefined();
  });
});

import { describe, expect, it } from "vitest";
import {
  buildBriefingHref,
  buildPlayHref,
  parseCourseId,
  parseStepId,
} from "@/features/play/course-params";

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

describe("briefing and step params", () => {
  it("parses a positive stepId", () => {
    expect(parseStepId("42")).toBe(42);
    expect(parseStepId("0")).toBeUndefined();
  });

  it("builds briefing and step-scoped play hrefs", () => {
    expect(buildBriefingHref(2)).toBe("/briefing?courseId=2");
    expect(buildPlayHref(2, 42)).toBe("/play?courseId=2&stepId=42");
    expect(buildPlayHref(2)).toBe("/play?courseId=2");
  });
});

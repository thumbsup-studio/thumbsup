import { describe, expect, it } from "vitest";

import {
  formatStreakDays,
  getCharacterMood,
  getWelcomeVariant,
  shouldShowStreak,
} from "@/features/home/home-logic";

describe("home logic", () => {
  it("returns commute before 13:00", () => {
    expect(getWelcomeVariant(new Date("2026-07-08T12:59:00+09:00"))).toBe("commute");
  });

  it("returns afterWork from 13:00 to 18:59 in Asia/Seoul", () => {
    expect(getWelcomeVariant(new Date("2026-07-08T04:00:00Z"))).toBe("afterWork");
    expect(getWelcomeVariant(new Date("2026-07-08T09:59:00Z"))).toBe("afterWork");
  });

  it("returns night from 19:00 in Asia/Seoul", () => {
    expect(getWelcomeVariant(new Date("2026-07-08T10:00:00Z"))).toBe("night");
  });

  it("hides streak when days are zero", () => {
    expect(shouldShowStreak(0)).toBe(false);
  });

  it("formats streak days without zero padding", () => {
    expect(formatStreakDays(1)).toBe("1일");
    expect(formatStreakDays(12)).toBe("12일");
  });

  it("returns happy at 70 and above", () => {
    expect(getCharacterMood(70)).toBe("happy");
    expect(getCharacterMood(100)).toBe("happy");
  });

  it("returns neutral from 30 to 69", () => {
    expect(getCharacterMood(69)).toBe("neutral");
    expect(getCharacterMood(50)).toBe("neutral");
    expect(getCharacterMood(30)).toBe("neutral");
  });

  it("returns hungry below 30", () => {
    expect(getCharacterMood(29)).toBe("hungry");
    expect(getCharacterMood(0)).toBe("hungry");
  });
});

import { describe, expect, it } from "vitest";
import {
  validateEmail,
  validatePassword,
  validatePasswordConfirm,
} from "@/features/auth/validation";

describe("validateEmail", () => {
  it("빈 값이면 안내 문구", () => {
    expect(validateEmail("")).toBe("이메일을 입력해 주세요.");
    expect(validateEmail("   ")).toBe("이메일을 입력해 주세요.");
  });

  it("형식이 아니면 안내 문구", () => {
    expect(validateEmail("not-an-email")).toBe("이메일 형식이 올바르지 않아요.");
    expect(validateEmail("a@b")).toBe("이메일 형식이 올바르지 않아요.");
  });

  it("올바른 이메일이면 null", () => {
    expect(validateEmail("user@example.com")).toBeNull();
  });
});

describe("validatePassword", () => {
  it("빈 값이면 안내 문구", () => {
    expect(validatePassword("")).toBe("비밀번호를 입력해 주세요.");
  });

  it("8자 미만이면 형식 오류", () => {
    expect(validatePassword("1234567")).toBe("8자 이상 72자 이하로 입력해 주세요.");
  });

  it("72자 초과면 형식 오류", () => {
    expect(validatePassword("a".repeat(73))).toBe("8자 이상 72자 이하로 입력해 주세요.");
  });

  it("경계값(8자·72자)은 통과", () => {
    expect(validatePassword("a".repeat(8))).toBeNull();
    expect(validatePassword("a".repeat(72))).toBeNull();
  });
});

describe("validatePasswordConfirm", () => {
  it("빈 값이면 안내 문구", () => {
    expect(validatePasswordConfirm("password123", "")).toBe("비밀번호를 다시 입력해 주세요.");
  });

  it("불일치면 안내 문구", () => {
    expect(validatePasswordConfirm("password123", "different1")).toBe(
      "비밀번호가 일치하지 않아요.",
    );
  });

  it("일치하면 null", () => {
    expect(validatePasswordConfirm("password123", "password123")).toBeNull();
  });
});

import { describe, expect, it } from "vitest";
import { validateEmail, validatePassword, validatePasswordConfirm } from "../src/auth-validation";

describe("auth validation", () => {
  it("이메일 필수값과 형식을 검증한다", () => {
    expect(validateEmail(" ")).toBe("이메일을 입력해 주세요.");
    expect(validateEmail("invalid")).toBe("이메일 형식이 올바르지 않아요.");
    expect(validateEmail("learner@example.com")).toBeNull();
  });

  it("비밀번호 길이와 확인값을 검증한다", () => {
    expect(validatePassword("short")).toBe("8자 이상 72자 이하로 입력해 주세요.");
    expect(validatePassword("password123")).toBeNull();
    expect(validatePasswordConfirm("password123", "different")).toBe("비밀번호가 일치하지 않아요.");
  });
});

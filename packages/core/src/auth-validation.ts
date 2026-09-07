const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const PASSWORD_MIN = 8;
export const PASSWORD_MAX = 72;

export function validateEmail(email: string): string | null {
  if (!email.trim()) return "이메일을 입력해 주세요.";
  if (!EMAIL_RE.test(email)) return "이메일 형식이 올바르지 않아요.";
  return null;
}

export function validatePassword(password: string): string | null {
  if (!password) return "비밀번호를 입력해 주세요.";
  if (password.length < PASSWORD_MIN || password.length > PASSWORD_MAX) {
    return "8자 이상 72자 이하로 입력해 주세요.";
  }
  return null;
}

export function validatePasswordConfirm(password: string, confirm: string): string | null {
  if (!confirm) return "비밀번호를 다시 입력해 주세요.";
  if (password !== confirm) return "비밀번호가 일치하지 않아요.";
  return null;
}

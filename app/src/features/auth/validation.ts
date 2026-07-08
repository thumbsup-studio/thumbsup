/**
 * 클라이언트 폼 검증. 서버 검증(400 INVALID_INPUT)과 별개의 1차 방어.
 * 통과 여부만이 아니라 사용자 노출용 한국어 문구를 반환한다(에러 없으면 null).
 */

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** 서버 정책과 동일(bcrypt 한계 72바이트) */
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

/**
 * 인증 API. 성공 시 발급 토큰을 저장한다(가입/로그인 = 자동 로그인).
 * 엔드포인트: POST /api/v1/auth/{signup,login,refresh,logout}
 */

import { apiRequest } from "./client";
import { ApiError } from "./errors";
import { type Tokens, tokenStore } from "./token-store";

/** 회원가입(공개). 201 + 발급 토큰 → 즉시 자동 로그인 상태로 저장. */
export async function signup(email: string, password: string): Promise<Tokens> {
  const tokens = await apiRequest<Tokens>("/auth/signup", {
    method: "POST",
    body: { email, password },
    auth: false,
  });
  tokenStore.set(tokens);
  return tokens;
}

/** 로그인(공개). 실패는 401 INVALID_CREDENTIALS(원인 미구분). */
export async function login(email: string, password: string): Promise<Tokens> {
  const tokens = await apiRequest<Tokens>("/auth/login", {
    method: "POST",
    body: { email, password },
    auth: false,
  });
  tokenStore.set(tokens);
  return tokens;
}

/** 명시적 재발급(회전). 인터셉터가 자동 처리하지만 필요 시 직접 호출용. */
export async function refresh(): Promise<Tokens> {
  const refreshToken = tokenStore.getRefresh();
  if (!refreshToken) {
    throw new ApiError({ code: "UNAUTHORIZED", status: 401, message: "세션이 만료됐어요." });
  }
  const tokens = await apiRequest<Tokens>("/auth/refresh", {
    method: "POST",
    body: { refreshToken },
    auth: false,
  });
  tokenStore.set(tokens);
  return tokens;
}

/** 로그아웃. 서버 refresh 폐기 요청 + 로컬 토큰 삭제. 서버 실패는 무시하고 로컬은 항상 비운다. */
export async function logout(): Promise<void> {
  try {
    await apiRequest<null>("/auth/logout", { method: "POST" });
  } catch {
    // 서버 폐기 실패해도 로그아웃은 사용자 관점에서 성공해야 한다 — 로컬 토큰만 확실히 삭제.
  } finally {
    tokenStore.clear();
  }
}

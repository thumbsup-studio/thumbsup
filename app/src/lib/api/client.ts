/**
 * 서버 API 소비의 단일 진입점.
 *
 * frontend-api 스킬 계약을 코드로 옮긴 것:
 * - 모든 응답은 `{code,message,data,meta}` envelope → data만 언랩해서 반환
 * - `Authorization: Bearer {accessToken}` 자동 부착
 * - 401 + TOKEN_EXPIRED → refresh 1회 회전식 재발급 후 원 요청 재시도
 * - 그 외 실패는 code/status를 담은 ApiError로 throw
 */

import { ApiError, ErrorCode, type FieldError, NetworkError } from "./errors";
import { type Tokens, tokenStore } from "./token-store";

type CursorMeta = { hasNext: boolean; nextCursor: string | null };

export type ApiResponse<T> = {
  code: string;
  message: string;
  data: T | null;
  meta: CursorMeta | null;
};

const SUCCESS_CODE = "SUCCESS";

/** prod는 NEXT_PUBLIC_API_URL(Vercel env), 미설정 시 로컬 서버(:8080). 로컬 FE→prod는 CORS 차단. */
const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080";
const PREFIX = "/api/v1";

export type RequestOptions = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  /** Authorization: Bearer 부착 여부. login/signup/refresh 같은 공개 요청은 false. 기본 true */
  auth?: boolean;
  /** 내부용: refresh 후 재시도임을 표시해 무한 재발급 루프를 막는다 */
  _retried?: boolean;
};

function extractFieldErrors(envelope: ApiResponse<unknown> | null): FieldError[] | undefined {
  const data = envelope?.data as { fieldErrors?: FieldError[] } | null | undefined;
  return Array.isArray(data?.fieldErrors) ? data.fieldErrors : undefined;
}

/**
 * access token 만료 시 refresh로 새 토큰(회전)을 받아 저장.
 * @returns 재발급 성공 여부. 실패하면 토큰을 비워 로그인 화면으로 유도.
 */
async function tryRefresh(): Promise<boolean> {
  const refreshToken = tokenStore.getRefresh();
  if (!refreshToken) return false;
  try {
    const tokens = await apiRequest<Tokens>("/auth/refresh", {
      method: "POST",
      body: { refreshToken },
      auth: false,
      _retried: true, // refresh 요청 자신은 다시 재발급하지 않는다
    });
    tokenStore.set(tokens); // 회전: access + refresh 모두 새 값으로 교체
    return true;
  } catch {
    tokenStore.clear();
    return false;
  }
}

export async function apiRequest<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, auth = true, _retried = false } = opts;

  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (auth) {
    const access = tokenStore.getAccess();
    if (access) headers.Authorization = `Bearer ${access}`;
  }

  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${PREFIX}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new NetworkError();
  }

  const envelope = (await res.json().catch(() => null)) as ApiResponse<T> | null;

  if (res.status === 401 && envelope?.code === ErrorCode.TOKEN_EXPIRED && auth && !_retried) {
    const refreshed = await tryRefresh();
    if (refreshed) return apiRequest<T>(path, { ...opts, _retried: true });
  }

  if (!res.ok || !envelope || envelope.code !== SUCCESS_CODE) {
    throw new ApiError({
      code: envelope?.code ?? "UNKNOWN",
      status: res.status,
      message: envelope?.message ?? "요청을 처리하지 못했어요.",
      fieldErrors: extractFieldErrors(envelope),
    });
  }

  return envelope.data as T;
}

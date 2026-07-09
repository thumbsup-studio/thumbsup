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

/**
 * API 베이스 URL.
 * - 로컬 개발(`next dev`): env 미설정 시 로컬 서버(:8080)가 기본(비밀 아님).
 * - 배포(Vercel preview·prod): `NEXT_PUBLIC_API_URL` 필수 — 운영 API 주소를 소스에 하드코딩하지 않는다.
 *   미설정 시 첫 API 요청에서 throw 한다(빌드/CI 게이트를 깨지 않도록 모듈 로드가 아닌 요청 시점 검사).
 *   (주의: NEXT_PUBLIC_ 값은 빌드 시 클라이언트 번들에 인라인되므로 배포 산출물엔 노출된다 —
 *    이 처리는 '공개 소스 레포에 주소를 남기지 않는' 목적이지 브라우저에서 숨기는 게 아니다.)
 */
const BASE_URL = (
  process.env.NEXT_PUBLIC_API_URL ||
  (process.env.NODE_ENV === "development" ? "http://localhost:8080" : "")
).replace(/\/+$/, ""); // 끝 슬래시 제거 — env 값에 trailing slash가 있어도 `//api/v1` 더블 슬래시 방지

const PREFIX = "/api/v1";

/** 응답이 오지 않을 때 무한 대기하지 않도록 요청 타임아웃(초과 시 abort → NetworkError). */
const REQUEST_TIMEOUT_MS = 15_000;

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
 * 진행 중인 refresh 요청을 공유하기 위한 단일 인플라이트 프로미스.
 * 여러 요청이 동시에 401 TOKEN_EXPIRED를 받아도 refresh는 한 번만 돈다
 * (회전 토큰이 경합해 서로를 무효화하는 것을 방지).
 */
let refreshInFlight: Promise<boolean> | null = null;

/**
 * access token 만료 시 refresh로 새 토큰(회전)을 받아 저장.
 * 동시 호출은 하나의 refresh에 합류한다.
 * @returns 재발급 성공 여부. 실패하면 토큰을 비워 로그인 화면으로 유도.
 */
function tryRefresh(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = doRefresh().finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

async function doRefresh(): Promise<boolean> {
  const refreshToken = tokenStore.getRefresh();
  if (!refreshToken) {
    tokenStore.clear(); // 실패 catch 분기와 대칭 — 세션 무효 상태를 일치시켜 로그인 화면으로 유도
    return false;
  }
  try {
    const tokens = await apiRequest<Tokens>("/auth/refresh", {
      method: "POST",
      body: { refreshToken },
      auth: false,
      _retried: true, // refresh 요청 자신은 다시 재발급하지 않는다
    });
    tokenStore.set(tokens); // 회전: access + refresh 모두 새 값으로 교체
    return true;
  } catch (error) {
    // 인증 실패(ApiError)만 세션 무효로 보고 토큰을 비운다. 네트워크 오류는 일시적이라 유지.
    if (error instanceof ApiError) tokenStore.clear();
    return false;
  }
}

export async function apiRequest<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  if (!BASE_URL) {
    throw new Error(
      "NEXT_PUBLIC_API_URL이 설정되지 않았습니다 — 배포 환경 변수에 API 베이스 URL을 등록하세요.",
    );
  }
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
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS), // 타임아웃/네트워크 오류 모두 abort → NetworkError
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

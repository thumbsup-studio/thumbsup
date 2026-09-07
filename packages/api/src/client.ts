/**
 * 서버 API 소비의 인스턴스별 진입점.
 *
 * - 모든 응답은 `{code,message,data,meta}` envelope → data만 언랩해서 반환
 * - `Authorization: Bearer {accessToken}` 자동 부착
 * - 401 + TOKEN_EXPIRED → refresh 1회 회전식 재발급 후 원 요청 재시도
 * - 동시 refresh는 같은 클라이언트 인스턴스 안에서만 단일-flight로 합침
 */

import { ApiError, ErrorCode, type FieldError, NetworkError } from "./errors";
import type { TokenStorage, Tokens } from "./token-storage";

export type CursorMeta = { hasNext: boolean; nextCursor: string | null };

export type ApiResponse<T> = {
  code: string;
  message: string;
  data: T | null;
  meta: CursorMeta | null;
};

export type RequestOptions = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  /** Authorization: Bearer 부착 여부. login/signup/refresh 같은 공개 요청은 false. 기본 true */
  auth?: boolean;
};

type InternalRequestOptions = RequestOptions & {
  /** refresh 후 재시도임을 표시해 무한 재발급 루프를 막는다. */
  retried?: boolean;
};

export type EnvelopeResult<T> = { data: T; meta: CursorMeta | null };
export type ApiRequest = <T>(path: string, options?: RequestOptions) => Promise<T>;
export type ApiRequestWithMeta = <T>(
  path: string,
  options?: RequestOptions,
) => Promise<EnvelopeResult<T>>;

export type ApiTransport = {
  apiRequest: ApiRequest;
  apiRequestWithMeta: ApiRequestWithMeta;
  apiUrl(path: string): string;
};

const SUCCESS_CODE = "SUCCESS";
const PREFIX = "/api/v1";
const REQUEST_TIMEOUT_MS = 15_000;

function extractFieldErrors(envelope: ApiResponse<unknown> | null): FieldError[] | undefined {
  const data = envelope?.data as { fieldErrors?: FieldError[] } | null | undefined;
  return Array.isArray(data?.fieldErrors) ? data.fieldErrors : undefined;
}

/** baseUrl과 tokenStorage를 클로저로 캡슐화한 API transport를 만든다. */
export function createApiTransport(baseUrl: string, tokenStorage: TokenStorage): ApiTransport {
  const normalizedBaseUrl = baseUrl.replace(/\/+$/, "");
  if (!normalizedBaseUrl) throw new Error("API 베이스 URL이 비어 있습니다.");

  let refreshInFlight: Promise<boolean> | null = null;

  function apiUrl(path: string): string {
    return `${normalizedBaseUrl}${PREFIX}${path}`;
  }

  function tryRefresh(): Promise<boolean> {
    if (refreshInFlight) return refreshInFlight;
    refreshInFlight = doRefresh().finally(() => {
      refreshInFlight = null;
    });
    return refreshInFlight;
  }

  async function doRefresh(): Promise<boolean> {
    const refreshToken = await tokenStorage.getRefresh();
    if (!refreshToken) {
      await tokenStorage.clear();
      return false;
    }
    try {
      const tokens = await apiRequestEnvelope<Tokens>("/auth/refresh", {
        method: "POST",
        body: { refreshToken },
        auth: false,
        retried: true,
      });
      await tokenStorage.set(tokens.data);
      return true;
    } catch (error) {
      if (error instanceof ApiError) await tokenStorage.clear();
      return false;
    }
  }

  async function apiRequestEnvelope<T>(
    path: string,
    options: InternalRequestOptions = {},
  ): Promise<EnvelopeResult<T>> {
    const { method = "GET", body, auth = true, retried = false } = options;
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (auth) {
      const access = await tokenStorage.getAccess();
      if (access) headers.Authorization = `Bearer ${access}`;
    }

    let response: Response;
    try {
      response = await fetch(apiUrl(path), {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch (error) {
      if (error instanceof Error && error.name === "TimeoutError") {
        throw new NetworkError("요청 시간이 초과됐어요.", "timeout");
      }
      throw new NetworkError();
    }

    const envelope = (await response.json().catch(() => null)) as ApiResponse<T> | null;

    if (response.status === 401 && envelope?.code === ErrorCode.TOKEN_EXPIRED && auth && !retried) {
      const refreshed = await tryRefresh();
      if (refreshed) return apiRequestEnvelope<T>(path, { ...options, retried: true });
    }

    if (!response.ok || !envelope || envelope.code !== SUCCESS_CODE) {
      throw new ApiError({
        code: envelope?.code ?? "UNKNOWN",
        status: response.status,
        message: envelope?.message ?? "요청을 처리하지 못했어요.",
        fieldErrors: extractFieldErrors(envelope),
      });
    }

    return { data: envelope.data as T, meta: envelope.meta };
  }

  async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const { data } = await apiRequestEnvelope<T>(path, options);
    return data;
  }

  function apiRequestWithMeta<T>(
    path: string,
    options: RequestOptions = {},
  ): Promise<EnvelopeResult<T>> {
    return apiRequestEnvelope<T>(path, options);
  }

  return { apiRequest, apiRequestWithMeta, apiUrl };
}

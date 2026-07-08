import { beforeEach, describe, expect, it, vi } from "vitest";
import { apiRequest } from "@/lib/api/client";
import { ApiError, NetworkError } from "@/lib/api/errors";
import { tokenStore } from "@/lib/api/token-store";

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function envelope(code: string, data: unknown = null, message = "OK") {
  return { code, message, data, meta: null };
}

/** fetch 호출의 init 인자에서 헤더/바디를 꺼낸다 */
function callInit(mock: ReturnType<typeof vi.fn>, index: number) {
  return mock.mock.calls[index][1] as { headers: Record<string, string>; body?: string };
}

/** promise가 ApiError로 reject되는지 확인하고 그 에러를 반환한다 */
async function expectApiError(promise: Promise<unknown>): Promise<ApiError> {
  try {
    await promise;
    throw new Error("ApiError가 발생할 것으로 기대했으나 성공했습니다.");
  } catch (error) {
    expect(error).toBeInstanceOf(ApiError);
    return error as ApiError;
  }
}

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
});

describe("apiRequest", () => {
  it("SUCCESS면 envelope의 data만 언랩해 반환한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { quizId: 42 })));
    vi.stubGlobal("fetch", fetchMock);

    const data = await apiRequest<{ quizId: number }>("/quizzes/42");

    expect(data).toEqual({ quizId: 42 });
    expect(callInit(fetchMock, 0).headers.Authorization).toBeUndefined();
  });

  it("access token이 있으면 Authorization: Bearer를 부착한다", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS", {})));
    vi.stubGlobal("fetch", fetchMock);

    await apiRequest("/notices");

    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });

  it("에러 응답을 code·status·fieldErrors를 담은 ApiError로 throw한다", async () => {
    const body = envelope(
      "INVALID_INPUT",
      { fieldErrors: [{ field: "email", reason: "이메일 형식이 아닙니다." }] },
      "입력값이 올바르지 않습니다.",
    );
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(jsonResponse(400, body)));

    const error = await expectApiError(
      apiRequest("/auth/signup", { method: "POST", auth: false, body: {} }),
    );

    expect(error.code).toBe("INVALID_INPUT");
    expect(error.status).toBe(400);
    expect(error.fieldErrors).toEqual([{ field: "email", reason: "이메일 형식이 아닙니다." }]);
  });

  it("401 TOKEN_EXPIRED면 refresh로 회전 재발급 후 원 요청을 1회 재시도한다", async () => {
    tokenStore.set({ accessToken: "old-acc", refreshToken: "old-ref" });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(401, envelope("TOKEN_EXPIRED", null, "만료")))
      .mockResolvedValueOnce(
        jsonResponse(200, envelope("SUCCESS", { accessToken: "new-acc", refreshToken: "new-ref" })),
      )
      .mockResolvedValueOnce(jsonResponse(200, envelope("SUCCESS", { ok: true })));
    vi.stubGlobal("fetch", fetchMock);

    const data = await apiRequest<{ ok: boolean }>("/notices");

    expect(data).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    // 회전: 새 refresh token까지 저장
    expect(tokenStore.get()).toEqual({ accessToken: "new-acc", refreshToken: "new-ref" });
    // refresh 요청은 Bearer 없이 이전 refresh token을 바디로 보낸다
    const refreshCall = fetchMock.mock.calls[1];
    expect(String(refreshCall[0])).toContain("/auth/refresh");
    expect(JSON.parse(callInit(fetchMock, 1).body as string)).toEqual({ refreshToken: "old-ref" });
    // 재시도 요청은 새 access token을 부착한다
    expect(callInit(fetchMock, 2).headers.Authorization).toBe("Bearer new-acc");
  });

  it("refresh가 실패하면 토큰을 비우고, 재시도는 1회로 제한한다", async () => {
    tokenStore.set({ accessToken: "old", refreshToken: "bad-ref" });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(401, envelope("TOKEN_EXPIRED")))
      .mockResolvedValueOnce(jsonResponse(401, envelope("UNAUTHORIZED", null, "재발급 실패")));
    vi.stubGlobal("fetch", fetchMock);

    await expect(apiRequest("/notices")).rejects.toBeInstanceOf(ApiError);
    expect(tokenStore.get()).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(2); // 원요청 + refresh(실패). 재시도 없음
  });

  it("동시 401 TOKEN_EXPIRED는 refresh를 한 번만 호출한다(단일 인플라이트)", async () => {
    tokenStore.set({ accessToken: "old-acc", refreshToken: "old-ref" });
    let refreshCalls = 0;
    const fetchMock = vi
      .fn()
      .mockImplementation((url: unknown, init: { headers: Record<string, string> }) => {
        if (String(url).includes("/auth/refresh")) {
          refreshCalls += 1;
          return Promise.resolve(
            jsonResponse(
              200,
              envelope("SUCCESS", { accessToken: "new-acc", refreshToken: "new-ref" }),
            ),
          );
        }
        // 새 토큰으로 재시도한 요청만 성공, 옛 토큰 요청은 만료 응답
        if (init.headers.Authorization === "Bearer new-acc") {
          return Promise.resolve(jsonResponse(200, envelope("SUCCESS", { ok: true })));
        }
        return Promise.resolve(jsonResponse(401, envelope("TOKEN_EXPIRED", null, "만료")));
      });
    vi.stubGlobal("fetch", fetchMock);

    const [a, b] = await Promise.all([
      apiRequest<{ ok: boolean }>("/notices"),
      apiRequest<{ ok: boolean }>("/notices"),
    ]);

    expect(a).toEqual({ ok: true });
    expect(b).toEqual({ ok: true });
    expect(refreshCalls).toBe(1); // 두 요청이 하나의 refresh를 공유
    expect(tokenStore.get()).toEqual({ accessToken: "new-acc", refreshToken: "new-ref" });
  });

  it("공개 요청(auth:false)은 401이어도 refresh를 시도하지 않는다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(401, envelope("INVALID_CREDENTIALS", null, "실패")));
    vi.stubGlobal("fetch", fetchMock);

    const error = await expectApiError(
      apiRequest("/auth/login", { method: "POST", auth: false, body: {} }),
    );

    expect(error.code).toBe("INVALID_CREDENTIALS");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("fetch 자체가 실패하면 NetworkError를 throw한다", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("failed to fetch")));

    await expect(apiRequest("/x", { auth: false })).rejects.toBeInstanceOf(NetworkError);
  });
});

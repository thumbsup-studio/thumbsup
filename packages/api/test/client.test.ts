import { beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, createApiClient, NetworkError } from "../src";
import { callInit, createMemoryTokenStorage, envelope, jsonResponse } from "./fixtures";

const BASE_URL = "https://api.example.com";

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
  vi.restoreAllMocks();
});

describe("createApiClient", () => {
  it("주입한 baseUrl로 요청하고 SUCCESS envelope의 data만 반환한다", async () => {
    const client = createApiClient({
      baseUrl: `${BASE_URL}/`,
      tokenStorage: createMemoryTokenStorage(),
    });
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { id: 42 })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.apiRequest<{ id: number }>("/items/42")).resolves.toEqual({ id: 42 });
    expect(fetchMock.mock.calls[0]?.[0]).toBe(`${BASE_URL}/api/v1/items/42`);
  });

  it("access token이 있으면 Authorization Bearer 헤더를 붙인다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "acc", refreshToken: "ref" });
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: storage });
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS", {})));
    vi.stubGlobal("fetch", fetchMock);

    await client.apiRequest("/notices");

    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });

  it("에러 응답을 code·status·fieldErrors를 담은 ApiError로 변환한다", async () => {
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: createMemoryTokenStorage() });
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          jsonResponse(
            400,
            envelope(
              "INVALID_INPUT",
              { fieldErrors: [{ field: "email", reason: "이메일 형식이 아닙니다." }] },
              "입력값이 올바르지 않습니다.",
            ),
          ),
        ),
    );

    const error = await expectApiError(
      client.apiRequest("/auth/signup", { method: "POST", auth: false, body: {} }),
    );

    expect(error).toMatchObject({
      code: "INVALID_INPUT",
      status: 400,
      fieldErrors: [{ field: "email", reason: "이메일 형식이 아닙니다." }],
    });
  });

  it("401 TOKEN_EXPIRED면 회전 재발급 후 원 요청을 한 번 재시도한다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "old-acc", refreshToken: "old-ref" });
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: storage });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(401, envelope("TOKEN_EXPIRED", null, "만료")))
      .mockResolvedValueOnce(
        jsonResponse(200, envelope("SUCCESS", { accessToken: "new-acc", refreshToken: "new-ref" })),
      )
      .mockResolvedValueOnce(jsonResponse(200, envelope("SUCCESS", { ok: true })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.apiRequest<{ ok: boolean }>("/notices")).resolves.toEqual({ ok: true });
    expect(storage.get()).toEqual({ accessToken: "new-acc", refreshToken: "new-ref" });
    expect(JSON.parse(callInit(fetchMock, 1).body as string)).toEqual({ refreshToken: "old-ref" });
    expect(callInit(fetchMock, 2).headers.Authorization).toBe("Bearer new-acc");
  });

  it("같은 인스턴스의 동시 만료 요청은 refresh 한 번을 공유한다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "old", refreshToken: "ref" });
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: storage });
    let refreshCalls = 0;
    const fetchMock = vi.fn().mockImplementation((url: unknown, init: RequestInit) => {
      if (String(url).includes("/auth/refresh")) {
        refreshCalls += 1;
        return Promise.resolve(
          jsonResponse(200, envelope("SUCCESS", { accessToken: "new", refreshToken: "new-ref" })),
        );
      }
      const headers = init.headers as Record<string, string>;
      return Promise.resolve(
        headers.Authorization === "Bearer new"
          ? jsonResponse(200, envelope("SUCCESS", { ok: true }))
          : jsonResponse(401, envelope("TOKEN_EXPIRED")),
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(Promise.all([client.apiRequest("/a"), client.apiRequest("/b")])).resolves.toEqual([
      { ok: true },
      { ok: true },
    ]);
    expect(refreshCalls).toBe(1);
  });

  it("서로 다른 인스턴스는 refresh 단일-flight를 공유하지 않는다", async () => {
    const storageA = createMemoryTokenStorage({ accessToken: "old-a", refreshToken: "ref-a" });
    const storageB = createMemoryTokenStorage({ accessToken: "old-b", refreshToken: "ref-b" });
    const clientA = createApiClient({ baseUrl: "https://a.example.com", tokenStorage: storageA });
    const clientB = createApiClient({ baseUrl: "https://b.example.com", tokenStorage: storageB });
    const refreshCalls = { a: 0, b: 0 };
    const fetchMock = vi.fn().mockImplementation((url: unknown, init: RequestInit) => {
      const target = String(url);
      const instance = target.startsWith("https://a.example.com") ? "a" : "b";
      const headers = init.headers as Record<string, string>;
      if (target.includes("/auth/refresh")) {
        refreshCalls[instance] += 1;
        return Promise.resolve(
          jsonResponse(
            200,
            envelope("SUCCESS", {
              accessToken: `new-${instance}`,
              refreshToken: `new-ref-${instance}`,
            }),
          ),
        );
      }
      return Promise.resolve(
        headers.Authorization === `Bearer new-${instance}`
          ? jsonResponse(200, envelope("SUCCESS", { instance }))
          : jsonResponse(401, envelope("TOKEN_EXPIRED")),
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      Promise.all([clientA.apiRequest("/resource"), clientB.apiRequest("/resource")]),
    ).resolves.toEqual([{ instance: "a" }, { instance: "b" }]);
    expect(refreshCalls).toEqual({ a: 1, b: 1 });
    expect(storageA.get()?.accessToken).toBe("new-a");
    expect(storageB.get()?.accessToken).toBe("new-b");
  });

  it("refresh 실패 시 토큰을 비우고 공개 요청은 refresh하지 않는다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "old", refreshToken: "bad" });
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: storage });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(401, envelope("TOKEN_EXPIRED")))
      .mockResolvedValueOnce(jsonResponse(401, envelope("UNAUTHORIZED")));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.apiRequest("/notices")).rejects.toBeInstanceOf(ApiError);
    expect(storage.get()).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(2);

    fetchMock.mockClear().mockResolvedValue(jsonResponse(401, envelope("INVALID_CREDENTIALS")));
    await expect(client.login("user@example.com", "wrong")).rejects.toBeInstanceOf(ApiError);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("refreshToken 없이 받은 TOKEN_EXPIRED는 저장소를 비우고 refresh를 요청하지 않는다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "old", refreshToken: "" });
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: storage });
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(401, envelope("TOKEN_EXPIRED")));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.apiRequest("/notices")).rejects.toBeInstanceOf(ApiError);
    expect(storage.get()).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("fetch가 응답 전에 실패하면 NetworkError를 던진다", async () => {
    const client = createApiClient({ baseUrl: BASE_URL, tokenStorage: createMemoryTokenStorage() });
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("failed to fetch")));

    await expect(client.apiRequest("/x", { auth: false })).rejects.toBeInstanceOf(NetworkError);
  });
});

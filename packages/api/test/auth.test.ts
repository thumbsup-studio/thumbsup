import { beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, createApiClient } from "../src";
import { createMemoryTokenStorage, envelope, jsonResponse } from "./fixtures";

beforeEach(() => {
  vi.restoreAllMocks();
});

describe("auth", () => {
  it("signup과 login 성공 시 발급 토큰을 저장한다", async () => {
    const storage = createMemoryTokenStorage();
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce(
          jsonResponse(201, envelope("SUCCESS", { accessToken: "a", refreshToken: "r" })),
        )
        .mockResolvedValueOnce(
          jsonResponse(200, envelope("SUCCESS", { accessToken: "a2", refreshToken: "r2" })),
        ),
    );

    await expect(client.signup("user@example.com", "password123")).resolves.toEqual({
      accessToken: "a",
      refreshToken: "r",
    });
    await client.login("user@example.com", "password123");
    expect(storage.get()).toEqual({ accessToken: "a2", refreshToken: "r2" });
  });

  it("명시적 refresh는 토큰을 회전하고 인증 실패 시 저장소를 비운다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "a", refreshToken: "r" });
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        jsonResponse(200, envelope("SUCCESS", { accessToken: "a2", refreshToken: "r2" })),
      )
      .mockResolvedValueOnce(jsonResponse(401, envelope("UNAUTHORIZED")));
    vi.stubGlobal("fetch", fetchMock);

    await client.refresh();
    expect(storage.get()).toEqual({ accessToken: "a2", refreshToken: "r2" });
    await expect(client.refresh()).rejects.toBeInstanceOf(ApiError);
    expect(storage.get()).toBeNull();
  });

  it("logout은 서버 실패와 무관하게 저장소를 비운다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "a", refreshToken: "r" });
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(jsonResponse(500, envelope("INTERNAL_ERROR"))),
    );

    await expect(client.logout()).resolves.toBeUndefined();
    expect(storage.get()).toBeNull();
  });

  it("login 실패 시 토큰을 저장하지 않는다", async () => {
    const storage = createMemoryTokenStorage();
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(jsonResponse(401, envelope("INVALID_CREDENTIALS"))),
    );

    await expect(client.login("user@example.com", "wrong")).rejects.toBeInstanceOf(ApiError);
    expect(storage.get()).toBeNull();
  });

  it("logout 성공 요청에 access token을 붙인 뒤 저장소를 비운다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "a", refreshToken: "r" });
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS")));
    vi.stubGlobal("fetch", fetchMock);

    await client.logout();

    const init = fetchMock.mock.calls[0]?.[1] as RequestInit;
    expect(init.headers).toMatchObject({ Authorization: "Bearer a" });
    expect(storage.get()).toBeNull();
  });

  it("refreshToken이 없으면 요청하지 않고 저장소를 비운다", async () => {
    const storage = createMemoryTokenStorage();
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.refresh()).rejects.toBeInstanceOf(ApiError);
    expect(fetchMock).not.toHaveBeenCalled();
    expect(storage.get()).toBeNull();
  });

  it("refresh의 네트워크 실패에는 기존 토큰을 유지한다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "a", refreshToken: "r" });
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("network")));

    await expect(client.refresh()).rejects.toThrow();
    expect(storage.get()).toEqual({ accessToken: "a", refreshToken: "r" });
  });
});

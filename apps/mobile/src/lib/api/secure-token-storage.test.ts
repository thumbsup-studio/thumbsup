import { createApiClient } from "@thumbsup/api";
import * as SecureStore from "expo-secure-store";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY, secureTokenStorage } from "./secure-token-storage";

vi.mock("expo-secure-store", () => ({
  getItemAsync: vi.fn(),
  setItemAsync: vi.fn(() => Promise.resolve()),
  deleteItemAsync: vi.fn(() => Promise.resolve()),
}));

const mockedSecureStore = vi.mocked(SecureStore);
let stored: Record<string, string | undefined>;

function response(status: number, code: string, data: unknown = null) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: vi.fn().mockResolvedValue({ code, message: code, data, meta: null }),
  } as unknown as Response;
}

beforeEach(() => {
  vi.clearAllMocks();
  stored = {};
  mockedSecureStore.getItemAsync.mockImplementation((key) => Promise.resolve(stored[key] ?? null));
  mockedSecureStore.setItemAsync.mockImplementation((key, value) => {
    stored[key] = value;
    return Promise.resolve();
  });
  mockedSecureStore.deleteItemAsync.mockImplementation((key) => {
    delete stored[key];
    return Promise.resolve();
  });
});

describe("secureTokenStorage", () => {
  it("access token과 refresh token을 서로 다른 키로 저장하고 읽는다", async () => {
    stored[ACCESS_TOKEN_KEY] = "access";
    stored[REFRESH_TOKEN_KEY] = "refresh";

    await expect(secureTokenStorage.getAccess()).resolves.toBe("access");
    await expect(secureTokenStorage.getRefresh()).resolves.toBe("refresh");
    await secureTokenStorage.set({ accessToken: "new-access", refreshToken: "new-refresh" });

    expect(mockedSecureStore.setItemAsync).toHaveBeenCalledWith(ACCESS_TOKEN_KEY, "new-access");
    expect(mockedSecureStore.setItemAsync).toHaveBeenCalledWith(REFRESH_TOKEN_KEY, "new-refresh");
  });

  it("로그아웃 시 두 토큰을 모두 삭제한다", async () => {
    await secureTokenStorage.clear();
    expect(mockedSecureStore.deleteItemAsync).toHaveBeenCalledWith(ACCESS_TOKEN_KEY);
    expect(mockedSecureStore.deleteItemAsync).toHaveBeenCalledWith(REFRESH_TOKEN_KEY);
  });

  it("TOKEN_EXPIRED 응답을 받으면 SecureStore 토큰을 회전하고 원 요청을 재시도한다", async () => {
    stored[ACCESS_TOKEN_KEY] = "old-access";
    stored[REFRESH_TOKEN_KEY] = "old-refresh";
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(response(401, "TOKEN_EXPIRED"))
      .mockResolvedValueOnce(
        response(200, "SUCCESS", { accessToken: "new-access", refreshToken: "new-refresh" }),
      )
      .mockResolvedValueOnce(response(200, "SUCCESS", { ok: true }));
    global.fetch = fetchMock;
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: secureTokenStorage,
    });

    await expect(client.apiRequest("/protected")).resolves.toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(mockedSecureStore.setItemAsync).toHaveBeenCalledWith(ACCESS_TOKEN_KEY, "new-access");
    expect(mockedSecureStore.setItemAsync).toHaveBeenCalledWith(REFRESH_TOKEN_KEY, "new-refresh");
    const retryInit = fetchMock.mock.calls[2]?.[1] as RequestInit;
    expect(retryInit.headers).toMatchObject({ Authorization: "Bearer new-access" });
  });
});

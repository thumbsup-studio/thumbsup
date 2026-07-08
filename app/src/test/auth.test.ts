import { beforeEach, describe, expect, it, vi } from "vitest";
import { login, logout, signup } from "@/lib/api/auth";
import { ApiError } from "@/lib/api/errors";
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

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
});

describe("auth", () => {
  it("signup 성공 시 발급 토큰을 저장한다(자동 로그인)", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          jsonResponse(201, envelope("SUCCESS", { accessToken: "a", refreshToken: "r" })),
        ),
    );

    const tokens = await signup("user@example.com", "password123");

    expect(tokens).toEqual({ accessToken: "a", refreshToken: "r" });
    expect(tokenStore.get()).toEqual({ accessToken: "a", refreshToken: "r" });
  });

  it("login 실패(401 INVALID_CREDENTIALS)면 토큰을 저장하지 않는다", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(jsonResponse(401, envelope("INVALID_CREDENTIALS", null, "실패"))),
    );

    await expect(login("user@example.com", "wrong")).rejects.toBeInstanceOf(ApiError);
    expect(tokenStore.get()).toBeNull();
  });

  it("logout은 Bearer로 서버 폐기를 호출하고 로컬 토큰을 삭제한다", async () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS", null)));
    vi.stubGlobal("fetch", fetchMock);

    await logout();

    const init = fetchMock.mock.calls[0][1] as { headers: Record<string, string> };
    expect(init.headers.Authorization).toBe("Bearer a");
    expect(tokenStore.get()).toBeNull();
  });

  it("logout은 서버가 실패해도 로컬 토큰을 삭제한다", async () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(jsonResponse(500, envelope("INTERNAL_ERROR", null, "서버 오류"))),
    );

    await expect(logout()).resolves.toBeUndefined();
    expect(tokenStore.get()).toBeNull();
  });
});

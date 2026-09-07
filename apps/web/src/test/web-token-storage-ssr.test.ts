import { afterEach, describe, expect, it, vi } from "vitest";
import { createWebTokenStorage } from "@/lib/api/web-token-storage";

describe("createWebTokenStorage SSR", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("window가 없는 환경에서 읽기와 쓰기를 안전하게 무시한다", () => {
    vi.stubGlobal("window", undefined);
    const storage = createWebTokenStorage();

    expect(storage.get()).toBeNull();
    expect(storage.getAccess()).toBeNull();
    expect(storage.getRefresh()).toBeNull();
    expect(() => storage.set({ accessToken: "a", refreshToken: "r" })).not.toThrow();
    expect(() => storage.clear()).not.toThrow();
    expect(storage.isAuthenticated()).toBe(false);
  });
});

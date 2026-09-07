import type { ApiRequest } from "./client";
import { ApiError } from "./errors";
import type { TokenStorage, Tokens } from "./token-storage";

export function createAuthApi(apiRequest: ApiRequest, tokenStorage: TokenStorage) {
  return {
    async signup(email: string, password: string): Promise<Tokens> {
      const tokens = await apiRequest<Tokens>("/auth/signup", {
        method: "POST",
        body: { email, password },
        auth: false,
      });
      await tokenStorage.set(tokens);
      return tokens;
    },

    async login(email: string, password: string): Promise<Tokens> {
      const tokens = await apiRequest<Tokens>("/auth/login", {
        method: "POST",
        body: { email, password },
        auth: false,
      });
      await tokenStorage.set(tokens);
      return tokens;
    },

    async refresh(): Promise<Tokens> {
      const refreshToken = await tokenStorage.getRefresh();
      if (!refreshToken) {
        await tokenStorage.clear();
        throw new ApiError({ code: "UNAUTHORIZED", status: 401, message: "세션이 만료됐어요." });
      }
      try {
        const tokens = await apiRequest<Tokens>("/auth/refresh", {
          method: "POST",
          body: { refreshToken },
          auth: false,
        });
        await tokenStorage.set(tokens);
        return tokens;
      } catch (error) {
        if (error instanceof ApiError) await tokenStorage.clear();
        throw error;
      }
    },

    async logout(): Promise<void> {
      try {
        await apiRequest<null>("/auth/logout", { method: "POST" });
      } catch {
        // 사용자 관점의 로그아웃은 로컬 세션 삭제만으로도 완료한다.
      } finally {
        await tokenStorage.clear();
      }
    },
  };
}

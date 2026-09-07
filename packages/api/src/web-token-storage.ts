import type { TokenStorage, Tokens } from "./token-storage";

const ACCESS_KEY = "thumbsup.accessToken";
const REFRESH_KEY = "thumbsup.refreshToken";

export type WebTokenStorage = TokenStorage & {
  get(): Tokens | null;
  isAuthenticated(): boolean;
};

/** 브라우저 접근 시점까지 localStorage 조회를 늦춰 SSR에서도 안전한 저장소를 만든다. */
export function createWebTokenStorage(): WebTokenStorage {
  function storage(): Storage | null {
    if (typeof window === "undefined") return null;
    try {
      return window.localStorage;
    } catch {
      return null;
    }
  }

  return {
    get(): Tokens | null {
      const target = storage();
      const accessToken = target?.getItem(ACCESS_KEY);
      const refreshToken = target?.getItem(REFRESH_KEY);
      if (!accessToken || !refreshToken) return null;
      return { accessToken, refreshToken };
    },
    getAccess(): string | null {
      return storage()?.getItem(ACCESS_KEY) ?? null;
    },
    getRefresh(): string | null {
      return storage()?.getItem(REFRESH_KEY) ?? null;
    },
    set(tokens: Tokens): void {
      try {
        const target = storage();
        target?.setItem(ACCESS_KEY, tokens.accessToken);
        target?.setItem(REFRESH_KEY, tokens.refreshToken);
      } catch {
        // 쿼터 초과·프라이빗 모드에서는 미영속 상태로 인증 흐름을 계속한다.
      }
    },
    clear(): void {
      try {
        const target = storage();
        target?.removeItem(ACCESS_KEY);
        target?.removeItem(REFRESH_KEY);
      } catch {
        // 저장소 접근 실패여도 로그아웃 흐름은 계속한다.
      }
    },
    isAuthenticated(): boolean {
      return this.getAccess() !== null;
    },
  };
}

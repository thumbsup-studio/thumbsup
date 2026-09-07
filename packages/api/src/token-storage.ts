export type Tokens = { accessToken: string; refreshToken: string };

type MaybePromise<T> = T | Promise<T>;

/**
 * 플랫폼이 제공해야 하는 토큰 저장소 계약.
 *
 * 웹의 동기 localStorage와 모바일의 비동기 SecureStore를 모두 수용할 수 있도록
 * 반환 타입은 동기 값과 Promise를 함께 허용한다. API 클라이언트는 항상 await해 사용한다.
 */
export interface TokenStorage {
  getAccess(): MaybePromise<string | null>;
  getRefresh(): MaybePromise<string | null>;
  set(tokens: Tokens): MaybePromise<void>;
  clear(): MaybePromise<void>;
}

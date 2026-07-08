/**
 * 인증 토큰 보관소.
 *
 * [결정] 저장 위치 = localStorage (httpOnly cookie 아님).
 *
 * 근거:
 * - 서버(#44)는 토큰을 JSON 응답 body(`data.{accessToken,refreshToken}`)로 반환한다.
 *   Set-Cookie를 쓰지 않으므로 클라이언트가 직접 보관하고 매 요청에 `Authorization: Bearer`로
 *   부착한다(frontend-api 스킬 계약). httpOnly cookie로 가려면 모든 API 호출을 Next 서버가
 *   대리 호출하는 BFF 프록시가 필요한데, 이는 로그인(#1) 범위를 벗어난다.
 * - localStorage는 탭을 닫았다 다시 열어도 값이 유지된다 → 이슈 #1의 "브라우저 재접속 시
 *   자동 로그인 유지" 완료 기준을 충족한다(sessionStorage는 탭 종료 시 소멸하므로 부적합).
 *
 * 보안 트레이드오프: XSS가 성공하면 토큰이 탈취될 수 있다. 완화책 — React 기본 이스케이프와
 * dangerouslySetInnerHTML 미사용, access token 30분 단명(탈취 노출창 축소). 하드닝 단계에서
 * BFF + httpOnly cookie로 이전하려면 이 모듈의 인터페이스만 교체하면 되도록 소비처는 아래
 * `tokenStore` 함수만 쓴다(localStorage 직접 접근 금지).
 */

export type Tokens = { accessToken: string; refreshToken: string };

const ACCESS_KEY = "thumbsup.accessToken";
const REFRESH_KEY = "thumbsup.refreshToken";

/** SSR/비브라우저 환경 방어 */
function storage(): Storage | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage;
  } catch {
    // 프라이빗 모드 등에서 접근이 막힌 경우
    return null;
  }
}

export const tokenStore = {
  get(): Tokens | null {
    const s = storage();
    const accessToken = s?.getItem(ACCESS_KEY);
    const refreshToken = s?.getItem(REFRESH_KEY);
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
    const s = storage();
    if (!s) return;
    s.setItem(ACCESS_KEY, tokens.accessToken);
    s.setItem(REFRESH_KEY, tokens.refreshToken);
  },

  clear(): void {
    const s = storage();
    if (!s) return;
    s.removeItem(ACCESS_KEY);
    s.removeItem(REFRESH_KEY);
  },

  /** 로그인 여부 (access token 보유) */
  isAuthenticated(): boolean {
    return this.getAccess() !== null;
  },
};

const FALLBACK_AUTHORING_URL = "/authoring";

/** 분리 배포된 저작 앱 주소를 쓰되, 미설정 환경에서는 기존 통합 라우트를 유지한다. */
export function getAuthoringUrl(): string {
  return process.env.NEXT_PUBLIC_AUTHORING_URL || FALLBACK_AUTHORING_URL;
}

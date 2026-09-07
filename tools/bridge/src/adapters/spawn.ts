/**
 * CLI 자식 프로세스 env 새니타이즈 + 출력 후처리.
 * 구독 유지 규칙(전제 보호): 자식 env에 API 키가 남아있으면 개인 구독 세션 대신
 * API 과금으로 새어나간다 — 반드시 이 키들을 제거한 복사본만 넘긴다.
 */
export const BLOCKED_ENV_KEYS = [
  "ANTHROPIC_API_KEY",
  "OPENAI_API_KEY",
  "GOOGLE_API_KEY",
  "GEMINI_API_KEY",
  "GOOGLE_APPLICATION_CREDENTIALS",
] as const;

export function sanitizedEnv(base: NodeJS.ProcessEnv = process.env): NodeJS.ProcessEnv {
  const env = { ...base };
  for (const key of BLOCKED_ENV_KEYS) delete env[key];
  return env;
}

/** ```json ... ``` 코드펜스를 벗기고 trim한다. 펜스가 없으면 trim만 적용. */
export function stripFences(text: string): string {
  const trimmed = text.trim();
  const match = trimmed.match(/^```[a-zA-Z]*\n?([\s\S]*?)\n?```$/);
  return (match ? match[1] : trimmed).trim();
}

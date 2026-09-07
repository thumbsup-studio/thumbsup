import type { BridgeCli } from "../config.js";

export type AdapterInput = { prompt: string; outputSchema: unknown };
export type AdapterHooks = { onLog: (line: string) => void };

/**
 * CLI 어댑터 인터페이스. run()의 반환값 = 서버에 보낼 결과 JSON "문자열"
 * (JSON.parse 가능함을 브리지가 확인, 깊은 검증은 서버 책임).
 */
export type CliAdapter = {
  readonly cli: BridgeCli;
  run(input: AdapterInput, hooks: AdapterHooks): Promise<string>;
};

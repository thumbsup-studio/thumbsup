export type AdapterInput = { prompt: string; outputSchema: unknown };
export type AdapterHooks = { onLog: (line: string) => void };

/** CLI 어댑터. run() 반환값 = JSON 문자열 (파싱 가능성만 보장, 깊은 검증은 호출부 책임). */
export type CliAdapter = {
  run(input: AdapterInput, hooks: AdapterHooks): Promise<string>;
};

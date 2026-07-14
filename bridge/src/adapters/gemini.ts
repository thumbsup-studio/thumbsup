import { execa } from "execa";
import { sanitizedEnv, stripFences } from "./spawn.js";
import type { CliAdapter } from "./types.js";

type GeminiEnvelope = { response?: string; stats?: unknown };

/**
 * `gemini -p <prompt> --output-format json`을 실행해 결과 JSON 문자열을 얻는 어댑터.
 * claude/codex와 달리 스트리밍 이벤트가 없다 — 마지막에 단일 JSON 봉투만 stdout에 찍히므로
 * 전체를 버퍼링한 뒤 한 번에 파싱한다.
 */
export function createGeminiAdapter(opts: { bin?: string } = {}): CliAdapter {
  return {
    cli: "GEMINI",
    async run({ prompt }, { onLog }) {
      onLog("gemini 실행 중 — 이 CLI는 중간 로그를 제공하지 않습니다");

      const { exitCode, stdout, stderr } = await execa(
        opts.bin ?? "gemini",
        ["-p", prompt, "--output-format", "json"],
        { env: sanitizedEnv(), extendEnv: false, reject: false, stdin: "ignore" },
      );

      const stderrLines = stderr.split("\n").filter(Boolean);
      for (const line of stderrLines) onLog(line);

      if (exitCode !== 0) {
        throw new Error(`gemini 실행 실패 (exit ${exitCode}): ${stderrLines.slice(-5).join(" / ")}`);
      }

      const envelope = JSON.parse(stdout) as GeminiEnvelope;
      const cleaned = stripFences(String(envelope.response ?? ""));
      JSON.parse(cleaned); // 파싱 가능성만 확인 (깊은 검증은 서버)
      return cleaned;
    },
  };
}

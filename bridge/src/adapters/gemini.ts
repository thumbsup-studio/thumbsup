import { execa } from "execa";
import { sanitizedEnv, stripFences } from "./spawn.js";
import type { CliAdapter } from "./types.js";

type GeminiEnvelope = { response?: string; stats?: unknown };

/**
 * `gemini -p <prompt> --output-format json`을 실행해 결과 JSON 문자열을 얻는 어댑터.
 * claude/codex와 달리 stdout엔 스트리밍 이벤트가 없다 — 마지막에 단일 JSON 봉투만 찍히므로
 * stdout은 전체 버퍼링(execa 기본값)해 한 번에 파싱한다. stderr는 T3/T4와 동일하게
 * `.on("data")`로 실시간 relay한다 — execa는 buffer:true(기본값)여도 스트림을 계속 노출하므로
 * 실시간 relay와 최종 버퍼링(stdout)이 서로 배타적이지 않다.
 */
export function createGeminiAdapter(opts: { bin?: string } = {}): CliAdapter {
  return {
    cli: "GEMINI",
    async run({ prompt }, { onLog }) {
      onLog("gemini 실행 중 — 이 CLI는 중간 로그를 제공하지 않습니다");

      // gemini CLI엔 claude/codex 같은 스키마 플래그가 없어 outputSchema를 CLI에 넘기지 않는다.
      const subprocess = execa(opts.bin ?? "gemini", ["-p", prompt, "--output-format", "json"], {
        env: sanitizedEnv(),
        extendEnv: false,
        reject: false,
        stdin: "ignore",
      });

      const stderrTail: string[] = [];
      subprocess.stderr?.on("data", (chunk: Buffer) => {
        for (const line of chunk.toString().split("\n").filter(Boolean)) {
          onLog(line);
          stderrTail.push(line);
        }
      });

      const { exitCode, stdout } = await subprocess;

      if (exitCode !== 0) {
        throw new Error(`gemini 실행 실패 (exit ${exitCode}): ${stderrTail.slice(-5).join(" / ")}`);
      }

      let envelope: GeminiEnvelope;
      try {
        envelope = JSON.parse(stdout) as GeminiEnvelope;
      } catch {
        throw new Error(`gemini 출력을 파싱하지 못했습니다(예상치 못한 형식): ${stdout.slice(0, 200)}`);
      }
      const cleaned = stripFences(String(envelope.response ?? ""));
      JSON.parse(cleaned); // 파싱 가능성만 확인 (깊은 검증은 서버)
      return cleaned;
    },
  };
}

import { createInterface } from "node:readline";
import { execa } from "execa";
import { sanitizedEnv, stripFences } from "./spawn.js";
import type { CliAdapter } from "./types.js";

type CodexEvent = { type: string; item?: { type?: string; text?: string }; message?: string };

function safeJsonParse(line: string): CodexEvent | null {
  try {
    return JSON.parse(line) as CodexEvent;
  } catch {
    return null;
  }
}

/**
 * `codex exec --json <prompt>`를 실행해 결과 JSON 문자열을 얻는 어댑터.
 *
 * `--output-schema`는 의도적으로 넘기지 않는다: OpenAI strict 스키마 규격(모든 필드
 * additionalProperties:false + 전 필드 required 강제)을 요구하는데, 서버가 내려주는
 * 얕은 가드 스키마(additionalProperties 미지정, required가 properties 부분집합 등)를
 * 그대로 넘기면 모든 turn이 400 invalid_json_schema로 실패한다 — 실기기 검증(2026-07-14,
 * codex 0.139.0)으로 확인. gemini와 동일하게 프롬프트의 JSON-only 지시 + 서버 딥 검증에
 * 의존한다.
 */
export function createCodexAdapter(opts: { bin?: string } = {}): CliAdapter {
  return {
    cli: "CODEX",
    async run({ prompt }, { onLog }) {
      const subprocess = execa(opts.bin ?? "codex", ["exec", "--json", prompt], {
        env: sanitizedEnv(),
        extendEnv: false,
        reject: false,
        buffer: false,
        stdin: "ignore",
      });

      let result: string | null = null;
      const stderrTail: string[] = [];
      subprocess.stderr?.on("data", (chunk: Buffer) => {
        for (const line of chunk.toString().split("\n").filter(Boolean)) {
          onLog(line);
          stderrTail.push(line);
        }
      });

      if (!subprocess.stdout) throw new Error("codex 프로세스의 stdout을 열 수 없습니다.");
      for await (const line of createInterface({ input: subprocess.stdout })) {
        const event = safeJsonParse(line);
        if (!event) {
          onLog(line);
          continue;
        }
        if (event.type === "item.completed" && event.item) {
          if (event.item.type === "agent_message" && typeof event.item.text === "string") {
            result = event.item.text; // 여러 번 오면 마지막 agent_message가 승리
          } else {
            onLog(`[${event.item.type}] ${event.item.text ?? ""}`.trim());
          }
        } else if (event.type === "error") {
          onLog(`[error] ${event.message ?? ""}`.trim());
        } else {
          onLog(`[${event.type}]`);
        }
      }

      const { exitCode } = await subprocess;
      if (exitCode !== 0 || result === null) {
        throw new Error(`codex 실행 실패 (exit ${exitCode}): ${stderrTail.slice(-5).join(" / ")}`);
      }
      const cleaned = stripFences(result);
      JSON.parse(cleaned); // 파싱 가능성만 확인 (깊은 검증은 서버)
      return cleaned;
    },
  };
}

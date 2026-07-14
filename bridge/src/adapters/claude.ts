import { createInterface } from "node:readline";
import { execa } from "execa";
import { sanitizedEnv, stripFences } from "./spawn.js";
import type { CliAdapter } from "./types.js";

type StreamEvent = {
  type: string;
  message?: { content?: Array<{ type: string; text?: string }> };
  result?: string;
  structured_output?: unknown;
  total_cost_usd?: number;
};

function safeJsonParse(line: string): StreamEvent | null {
  try {
    return JSON.parse(line) as StreamEvent;
  } catch {
    return null;
  }
}

function extractAssistantText(event: StreamEvent): string {
  return (event.message?.content ?? [])
    .filter((c) => c.type === "text" && typeof c.text === "string")
    .map((c) => c.text)
    .join("");
}

/** `claude -p --output-format stream-json --verbose`를 실행해 결과 JSON 문자열을 얻는 어댑터. */
export function createClaudeAdapter(opts: { bin?: string } = {}): CliAdapter {
  return {
    cli: "CLAUDE",
    async run({ prompt, outputSchema }, { onLog }) {
      const subprocess = execa(
        opts.bin ?? "claude",
        ["-p", prompt, "--output-format", "stream-json", "--verbose", "--json-schema", JSON.stringify(outputSchema)],
        { env: sanitizedEnv(), extendEnv: false, reject: false, buffer: false, stdin: "ignore" },
      );

      let result: string | null = null;
      const stderrTail: string[] = [];
      subprocess.stderr?.on("data", (chunk: Buffer) => {
        for (const line of chunk.toString().split("\n").filter(Boolean)) {
          onLog(line);
          stderrTail.push(line);
        }
      });

      if (!subprocess.stdout) throw new Error("claude 프로세스의 stdout을 열 수 없습니다.");
      for await (const line of createInterface({ input: subprocess.stdout })) {
        const event = safeJsonParse(line);
        if (!event) {
          onLog(line);
          continue;
        }
        if (event.type === "assistant") {
          onLog(extractAssistantText(event));
        } else if (event.type === "result") {
          result =
            event.structured_output != null
              ? JSON.stringify(event.structured_output)
              : stripFences(String(event.result ?? ""));
          if (event.total_cost_usd != null) onLog(`[cost] $${event.total_cost_usd}`); // 비용 가시성 — job_log에 남아 팀원별 사용량 추적 (스펙 §8)
        } else {
          onLog(`[${event.type}]`);
        }
      }

      const { exitCode } = await subprocess;
      if (exitCode !== 0 || result === null) {
        throw new Error(`claude 실행 실패 (exit ${exitCode}): ${stderrTail.slice(-5).join(" / ")}`);
      }
      JSON.parse(result); // 파싱 가능성만 확인 (깊은 검증은 서버)
      return result;
    },
  };
}

import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { execa } from "execa";
import { sanitizedEnv, stripFences } from "./spawn.js";
import type { CliAdapter } from "./types.js";

type CodexEvent = { type: string; item?: { type?: string; text?: string } };

function safeJsonParse(line: string): CodexEvent | null {
  try {
    return JSON.parse(line) as CodexEvent;
  } catch {
    return null;
  }
}

/**
 * `codex exec --json --output-schema <schemaFile> <prompt>`를 실행해 결과 JSON 문자열을 얻는 어댑터.
 * outputSchema는 mkdtemp 임시 파일에 써서 --output-schema로 전달하고, 실행 후 finally에서 정리한다.
 */
export function createCodexAdapter(opts: { bin?: string } = {}): CliAdapter {
  return {
    cli: "CODEX",
    async run({ prompt, outputSchema }, { onLog }) {
      const tempDir = await mkdtemp(join(tmpdir(), "thumbsup-bridge-codex-"));
      try {
        const schemaFile = join(tempDir, "schema.json");
        await writeFile(schemaFile, JSON.stringify(outputSchema));

        const subprocess = execa(opts.bin ?? "codex", ["exec", "--json", "--output-schema", schemaFile, prompt], {
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
      } finally {
        await rm(tempDir, { recursive: true, force: true });
      }
    },
  };
}

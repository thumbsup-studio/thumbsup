#!/usr/bin/env node
// argv로 받은 --output-schema 파일을 읽어 이벤트로 echo(스키마가 실제로 전달됐는지 검증용).
// item.completed(agent_message)를 두 번 내려 "마지막 승리" 동작을 검증한다.
import { readFileSync } from "node:fs";

const args = process.argv.slice(2);
const schemaIdx = args.indexOf("--output-schema");
const schemaContent = schemaIdx >= 0 ? readFileSync(args[schemaIdx + 1], "utf-8") : "";

const lines = [
  { type: "item.completed", item: { type: "reasoning", text: `스키마 확인: ${schemaContent}` } },
  { type: "item.completed", item: { type: "agent_message", text: '{"draft":true}' } },
  { type: "item.completed", item: { type: "agent_message", text: '```json\n{"quizzes":[{"type":"OX"}]}\n```' } },
  { type: "turn.completed" },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

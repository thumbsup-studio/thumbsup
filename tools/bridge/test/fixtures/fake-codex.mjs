#!/usr/bin/env node
// 받은 argv를 그대로 로그 이벤트로 흘려보낸다(어댑터가 --output-schema를 안 넘기는지 검증용).
// item.completed(agent_message)를 두 번 내려 "마지막 승리" 동작을 검증한다.
const argv = process.argv.slice(2);

const lines = [
  { type: "item.completed", item: { type: "reasoning", text: `argv: ${argv.join(" ")}` } },
  { type: "item.completed", item: { type: "agent_message", text: '{"draft":true}' } },
  { type: "item.completed", item: { type: "agent_message", text: '```json\n{"quizzes":[{"type":"OX"}]}\n```' } },
  { type: "turn.completed" },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

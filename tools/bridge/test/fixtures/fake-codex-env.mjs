#!/usr/bin/env node
// 자식 프로세스가 OPENAI_API_KEY를 실제로 못 보는지 결과로 echo하는 변형.
const hasOpenAiKey = process.env.OPENAI_API_KEY !== undefined;
const lines = [
  { type: "item.completed", item: { type: "agent_message", text: JSON.stringify({ hasOpenAiKey }) } },
  { type: "turn.completed" },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

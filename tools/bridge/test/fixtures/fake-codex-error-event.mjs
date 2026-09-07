#!/usr/bin/env node
// error 이벤트가 메시지를 포함해 onLog로 전달되는지 검증하는 변형.
const lines = [
  { type: "error", message: "Invalid schema for response_format 'codex_output_schema'" },
  { type: "item.completed", item: { type: "agent_message", text: '{"ok":true}' } },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

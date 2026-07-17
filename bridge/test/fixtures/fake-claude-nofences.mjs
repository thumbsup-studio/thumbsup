#!/usr/bin/env node
// structured_output 없이 result 문자열(코드펜스 포함)만 내려주는 변형.
const lines = [
  { type: "system", subtype: "init", session_id: "s1" },
  { type: "assistant", message: { content: [{ type: "text", text: "리뷰 중..." }] } },
  { type: "result", subtype: "success", result: '```json\n{"quizzes":[{"type":"MULTIPLE_CHOICE"}]}\n```' },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

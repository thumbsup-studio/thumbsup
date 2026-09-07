#!/usr/bin/env node
// argv로 받은 플래그는 무시. stream-json 이벤트 시퀀스를 흉내낸다.
const lines = [
  { type: "system", subtype: "init", session_id: "s1" },
  { type: "assistant", message: { content: [{ type: "text", text: "문제 생성 중..." }] } },
  {
    type: "result",
    subtype: "success",
    result: '```json\n{"quizzes":[{"type":"OX"}]}\n```',
    structured_output: { quizzes: [{ type: "OX" }] },
  },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

#!/usr/bin/env node
// gemini -p --output-format json은 스트리밍 없이 마지막에 단일 JSON 봉투만 찍는다.
process.stderr.write("gemini stderr 라인\n");
process.stdout.write(
  JSON.stringify({
    response: '```json\n{"quizzes":[]}\n```',
    stats: { models: {} },
  }),
);

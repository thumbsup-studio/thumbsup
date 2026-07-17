#!/usr/bin/env node
// 결과 없이 stderr만 남기고 비정상 종료하는 변형.
for (let i = 1; i <= 3; i++) {
  process.stderr.write(`stderr line ${i}\n`);
}
process.exitCode = 1;

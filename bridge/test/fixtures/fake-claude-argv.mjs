#!/usr/bin/env node
// 어댑터가 실제로 넘긴 argv/cwd를 결과로 echo하는 변형 — 격리 플래그 회귀 테스트용.
const argv = process.argv.slice(2);
const lines = [{ type: "result", subtype: "success", structured_output: { argv, cwd: process.cwd() } }];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

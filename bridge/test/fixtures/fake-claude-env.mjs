#!/usr/bin/env node
// 자식 프로세스가 API 키 env를 실제로 못 보는지 결과로 echo하는 변형.
const hasAnthropicKey = process.env.ANTHROPIC_API_KEY !== undefined;
const lines = [{ type: "result", subtype: "success", structured_output: { hasAnthropicKey } }];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");

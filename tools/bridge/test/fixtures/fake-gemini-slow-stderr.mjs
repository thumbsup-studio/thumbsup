#!/usr/bin/env node
// stderr 첫 줄 → 지연 → 둘째 줄 → 종료. 배치 릴레이라면 첫 줄도 지연 이후에야 도착한다.
process.stderr.write("slow line 1\n");
await new Promise((resolve) => setTimeout(resolve, 150));
process.stderr.write("slow line 2\n");
process.stdout.write(JSON.stringify({ response: JSON.stringify({ ok: true }) }));

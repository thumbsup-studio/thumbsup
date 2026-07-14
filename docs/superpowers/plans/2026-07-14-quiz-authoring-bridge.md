# 문제 저작 로컬 브리지 (thumbsup-bridge) — 구현 계획 (#175)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 팀원 노트북에서 서버 잡 큐를 폴링해 claude-code/codex/gemini CLI를 **개인 구독 세션으로 헤드리스 실행**하고, 로그를 서버로 중계하며 결과 JSON을 제출하는 Node/TS 실행기.

**Architecture:** `bridge/` 신규 top-level 패키지(모노레포에 루트 pnpm workspace 없음 — app처럼 독립 패키지). 구조 = config + 서버 API 클라이언트 + CLI 어댑터 3종 + 메인 루프. 어댑터는 `execa`로 CLI를 spawn하고 각 CLI의 출력 봉투를 파싱해 **결과 JSON 문자열**을 돌려준다(검증·적용은 서버 책임).

**Tech Stack:** Node 22, TypeScript(strict, NodeNext, ESM), execa ^9, vitest, tsx.

**Spec:** `docs/superpowers/specs/2026-07-14-quiz-authoring-dashboard-design.md` (§8 브리지 상세)

## Global Constraints

- 브랜치: `feat/175-authoring-bridge`, 커밋 형식 `feat(bridge): <한국어 요약> (#175)` — main 직접 커밋 금지. (scope `bridge`는 이 패키지 신설에 따른 컨벤션 확장.)
- **구독 유지 규칙 (전제 보호 — 절대 위반 금지):** 자식 프로세스 env에서 `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_APPLICATION_CREDENTIALS` 제거. claude에 `--bare` 플래그 금지. Claude Agent SDK 사용 금지(API 키 강제) — CLI 직접 exec만.
- 프롬프트는 서버가 렌더링해 잡에 실어 보낸다 — 브리지는 **프롬프트를 만들지 않는다** (멍청한 실행기).
- 게이트: `cd bridge && pnpm typecheck && pnpm test`. 관련 없는 파일 수정 금지. 각 태스크 완료 시 커밋.
- 테스트에서 실제 CLI(claude/codex/gemini)나 실제 서버를 호출하지 않는다 — 가짜 CLI 스크립트·`node:http` 가짜 서버 픽스처만 사용.

## 서버 HTTP 계약 (정본은 서버 플랜 — 여기 복제본과 불일치 시 서버 플랜 우선)

- Base URL: config의 `serverUrl` (예: `https://thumbsup-api.duckdns.org`), prefix `/api/v1`.
- 엔벨로프: 모든 응답 `{code, message, data, meta}` — `code === "SUCCESS"`면 성공, `data` 언랩. 401 + `code === "TOKEN_EXPIRED"`면 refresh 후 1회 재시도.
- 인증: `Authorization: Bearer <accessToken>`. 리프레시: `POST /api/v1/auth/refresh` — 요청/응답 정확한 형태는 **app의 `app/src/lib/api/client.ts`의 `doRefresh()`를 정본으로 미러링**(회전 발급이므로 응답의 새 accessToken+refreshToken 둘 다 저장).
- 로그인: `POST /api/v1/auth/login` `{email, password}` → `data:{accessToken, refreshToken}`.

```
GET  /api/v1/authoring/bridge/jobs/next
  → 200 data:{jobId:number, kind:"GENERATE"|"REVIEW", prompt:string, outputSchema:object} | data:null(잡 없음)
POST /api/v1/authoring/bridge/jobs/{jobId}/logs    {lines: string[]}                    → 200 data:null
POST /api/v1/authoring/bridge/jobs/{jobId}/result  {cli:"CLAUDE"|"CODEX"|"GEMINI", resultJson: string}
  → 200 data:{jobId, status:"SUCCEEDED"|"FAILED", error?: string}   ← FAILED여도 HTTP 200 (서버 검증 실패는 잡에 기록됨, 재시도 금지)
POST /api/v1/authoring/bridge/jobs/{jobId}/fail    {error: string}                     → 200 data:null
```

## 파일 맵

```
bridge/
  package.json, tsconfig.json                          [T1]
  src/config.ts                                        [T1]  ~/.thumbsup/bridge.json 로드·저장
  src/api.ts                                           [T2]  서버 클라이언트 (envelope·refresh)
  src/login.ts                                         [T2]  대화형 로그인 커맨드
  src/adapters/types.ts, src/adapters/spawn.ts         [T3]  어댑터 인터페이스 + env 새니타이즈
  src/adapters/claude.ts                               [T3]
  src/adapters/codex.ts                                [T4]
  src/adapters/gemini.ts                               [T5]
  src/runner.ts, src/index.ts                          [T6]  메인 루프 + CLI 엔트리
  test/*.test.ts, test/fixtures/fake-*.mjs             [각 태스크]
  README.md                                            [T6]
```

---

### Task 1: 패키지 스캐폴드 + config

**Files:**
- Create: `bridge/package.json`, `bridge/tsconfig.json`, `bridge/src/config.ts`
- Test: `bridge/test/config.test.ts`

**Interfaces (Produces):**
```ts
export type BridgeCli = "CLAUDE" | "CODEX" | "GEMINI";
export type BridgeConfig = { serverUrl: string; cli: BridgeCli; accessToken: string; refreshToken: string };
export const CONFIG_PATH: string;                                     // ~/.thumbsup/bridge.json
export function loadConfig(path?: string): BridgeConfig;             // 검증 실패 시 친절한 한국어 메시지로 throw
export function saveConfig(config: BridgeConfig, path?: string): void; // 디렉터리 생성 + mode 0600
```

- [ ] **Step 1: 스캐폴드 작성**

```json
// bridge/package.json
{
  "name": "thumbsup-bridge",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22" },
  "packageManager": "pnpm@10.11.0",
  "scripts": {
    "start": "tsx src/index.ts",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": { "execa": "^9.6.0" },
  "devDependencies": { "@types/node": "^22", "tsx": "^4.23.0", "typescript": "^5", "vitest": "^3.2.4" }
}
```

```json
// bridge/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022", "module": "NodeNext", "moduleResolution": "NodeNext",
    "strict": true, "noEmit": true, "skipLibCheck": true,
    "types": ["node"], "resolveJsonModule": true
  },
  "include": ["src", "test"]
}
```

- [ ] **Step 2: 실패하는 config 테스트 작성**

```ts
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { loadConfig, saveConfig, type BridgeConfig } from "../src/config.js";

describe("config", () => {
  const valid: BridgeConfig = { serverUrl: "http://localhost:8080", cli: "CLAUDE", accessToken: "a", refreshToken: "r" };

  it("저장한 config를 그대로 다시 읽는다", () => {
    const path = join(mkdtempSync(join(tmpdir(), "bridge-")), "bridge.json");
    saveConfig(valid, path);
    expect(loadConfig(path)).toEqual(valid);
  });
  it("cli 값이 잘못되면 명확한 에러를 던진다", () => {
    const path = join(mkdtempSync(join(tmpdir(), "bridge-")), "bridge.json");
    saveConfig({ ...valid, cli: "COPILOT" as BridgeCli }, path);
    expect(() => loadConfig(path)).toThrow(/cli/);
  });
  it("파일이 없으면 로그인 안내 메시지를 던진다", () => {
    expect(() => loadConfig("/nonexistent/bridge.json")).toThrow(/login/);
  });
});
```

- [ ] **Step 3: 실행 — FAIL 확인** — `cd bridge && pnpm install && pnpm test` → 모듈 미존재 FAIL.
- [ ] **Step 4: config.ts 구현** — `readFileSync`+`JSON.parse`, 필드별 검증(serverUrl 존재·trailing slash 제거, cli는 3값 중 하나, 토큰 비어있지 않음), `saveConfig`는 `mkdirSync(dirname, {recursive:true})` + `writeFileSync(..., {mode: 0o600})`.
- [ ] **Step 5: PASS 확인 → Step 6: 커밋** — `feat(bridge): 패키지 스캐폴드·config 로더 (#175)`

---

### Task 2: 서버 API 클라이언트 + 로그인 커맨드

**Files:**
- Create: `bridge/src/api.ts`, `bridge/src/login.ts`
- Test: `bridge/test/api.test.ts`

**Interfaces (Produces — T6 러너가 소비):**
```ts
export type BridgeJob = { jobId: number; kind: "GENERATE" | "REVIEW"; prompt: string; outputSchema: unknown };
export type ResultOutcome = { jobId: number; status: "SUCCEEDED" | "FAILED"; error?: string };
export class ApiError extends Error { constructor(readonly code: string, readonly status: number, message: string); }
export class BridgeApi {
  constructor(config: BridgeConfig, persist: (c: BridgeConfig) => void);
  nextJob(): Promise<BridgeJob | null>;
  postLogs(jobId: number, lines: string[]): Promise<void>;
  postResult(jobId: number, cli: BridgeCli, resultJson: string): Promise<ResultOutcome>;
  postFail(jobId: number, error: string): Promise<void>;
}
export async function runLogin(configPath?: string): Promise<void>;  // 대화형: 서버URL·이메일·비번·CLI 선택 → saveConfig
```

- [ ] **Step 1: 실패하는 테스트 작성** — `node:http.createServer`로 가짜 서버를 임시 포트에 띄우는 헬퍼(`test/fixtures/fake-server.ts` — 엔드포인트별 응답 프로그래밍 가능, 수신 요청 기록) 작성 후:

```ts
it("nextJob은 data를 언랩하고, 잡이 없으면 null을 반환한다", async () => { ... });
it("TOKEN_EXPIRED(401)이면 refresh 후 새 토큰으로 1회 재시도하고 회전된 토큰쌍을 persist한다", async () => {
  // 가짜 서버 시나리오: 1차 next → 401 {code:"TOKEN_EXPIRED"}, refresh → 새 토큰쌍, 2차 next(새 토큰) → 성공
  // 검증: persist 콜백이 새 accessToken/refreshToken으로 호출됨, 2차 요청의 Authorization 헤더가 새 토큰
});
it("refresh도 실패하면 ApiError를 던진다", async () => { ... });
it("postResult는 FAILED 응답도 예외 없이 반환한다", async () => { ... });
```

- [ ] **Step 2: FAIL 확인 → Step 3: 구현** — 요청 헬퍼 하나로 통일:

```ts
async function request<T>(path: string, init: { method?: string; body?: unknown; retried?: boolean } = {}): Promise<T> {
  const res = await fetch(`${this.config.serverUrl}/api/v1${path}`, {
    method: init.method ?? "GET",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${this.config.accessToken}` },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const envelope = (await res.json()) as { code: string; message: string; data: T };
  if (res.ok) return envelope.data;
  if (res.status === 401 && envelope.code === "TOKEN_EXPIRED" && !init.retried) {
    await this.refresh();                     // app client.ts의 doRefresh 요청 형태를 미러링, 실패 시 ApiError
    return this.request<T>(path, { ...init, retried: true });
  }
  throw new ApiError(envelope.code, res.status, envelope.message);
}
```
`login.ts`는 `node:readline/promises`로 서버 URL(기본값 prod)·이메일·비밀번호(비밀번호는 echo 없이 받기 어려우면 평문 입력 허용 — 내부 도구)·CLI(1/2/3 선택)를 받아 `POST /auth/login` 후 `saveConfig`.
- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(bridge): 서버 API 클라이언트·로그인 (#175)`

---

### Task 3: 어댑터 인터페이스 + env 새니타이즈 + Claude 어댑터

**Files:**
- Create: `bridge/src/adapters/types.ts`, `bridge/src/adapters/spawn.ts`, `bridge/src/adapters/claude.ts`
- Test: `bridge/test/claude-adapter.test.ts`, `bridge/test/fixtures/fake-claude.mjs`

**Interfaces (Produces):**
```ts
// types.ts
export type AdapterInput = { prompt: string; outputSchema: unknown };
export type AdapterHooks = { onLog: (line: string) => void };
export type CliAdapter = { readonly cli: BridgeCli; run(input: AdapterInput, hooks: AdapterHooks): Promise<string> };
// run()의 반환값 = 서버에 보낼 결과 JSON "문자열" (JSON.parse 가능함을 브리지가 확인, 깊은 검증은 서버)

// spawn.ts
export const BLOCKED_ENV_KEYS = ["ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GOOGLE_API_KEY", "GEMINI_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS"] as const;
export function sanitizedEnv(base?: NodeJS.ProcessEnv): NodeJS.ProcessEnv;  // 복사본에서 BLOCKED 제거
export function stripFences(text: string): string;                           // ```json ... ``` 벗기기 + trim

// claude.ts
export function createClaudeAdapter(opts?: { bin?: string }): CliAdapter;    // bin 오버라이드는 테스트용
```

- [ ] **Step 1: 가짜 CLI 픽스처 작성** — `test/fixtures/fake-claude.mjs`: 실제 `claude -p --output-format stream-json --verbose`의 출력 형태를 흉내(JSONL을 stdout에 순차 출력):

```js
#!/usr/bin/env node
// argv로 받은 플래그는 무시. stream-json 이벤트 시퀀스를 흉내낸다.
const lines = [
  { type: "system", subtype: "init", session_id: "s1" },
  { type: "assistant", message: { content: [{ type: "text", text: "문제 생성 중..." }] } },
  { type: "result", subtype: "success",
    result: "```json\n{\"quizzes\":[{\"type\":\"OX\"}]}\n```",
    structured_output: { quizzes: [{ type: "OX" }] } },
];
for (const l of lines) process.stdout.write(JSON.stringify(l) + "\n");
```

- [ ] **Step 2: 실패하는 어댑터 테스트 작성**:

```ts
it("structured_output이 있으면 그것을 JSON 문자열로 반환한다", async () => {
  const adapter = createClaudeAdapter({ bin: fixturePath("fake-claude.mjs") });
  const logs: string[] = [];
  const result = await adapter.run({ prompt: "P", outputSchema: { type: "object" } }, { onLog: (l) => logs.push(l) });
  expect(JSON.parse(result)).toEqual({ quizzes: [{ type: "OX" }] });
  expect(logs.some((l) => l.includes("문제 생성 중"))).toBe(true);
});
it("structured_output이 없으면 result 문자열의 코드펜스를 벗겨 반환한다", async () => { ... fake-claude-nofences 변형 픽스처 ... });
it("비정상 종료 시 stderr 꼬리를 담아 throw한다", async () => { ... process.exit(1) 픽스처 ... });
it("자식 env에서 API 키 변수가 제거된다", async () => {
  // fake-claude-env.mjs: process.env.ANTHROPIC_API_KEY 유무를 JSONL result로 출력 → 어댑터 결과로 검증
});
```

- [ ] **Step 3: FAIL 확인 → Step 4: 구현**:

```ts
export function createClaudeAdapter(opts: { bin?: string } = {}): CliAdapter {
  return {
    cli: "CLAUDE",
    async run({ prompt, outputSchema }, { onLog }) {
      const subprocess = execa(
        opts.bin ?? "claude",
        ["-p", prompt, "--output-format", "stream-json", "--verbose", "--json-schema", JSON.stringify(outputSchema)],
        { env: sanitizedEnv(), extendEnv: false, reject: false, buffer: false, stdin: "ignore" },
      );
      let result: string | null = null;
      const stderrTail: string[] = [];
      subprocess.stderr!.on("data", (chunk: Buffer) => {
        for (const line of chunk.toString().split("\n").filter(Boolean)) { onLog(line); stderrTail.push(line); }
      });
      for await (const line of createInterface({ input: subprocess.stdout! })) {
        const event = safeJsonParse(line);
        if (!event) { onLog(line); continue; }
        if (event.type === "assistant") onLog(extractAssistantText(event));       // message.content[].text 연결
        else if (event.type === "result") {
          result = event.structured_output != null
            ? JSON.stringify(event.structured_output)
            : stripFences(String(event.result ?? ""));
          if (event.total_cost_usd != null) onLog(`[cost] $${event.total_cost_usd}`); // 비용 가시성 — job_log에 남아 팀원별 사용량 추적 (스펙 §8)
        } else onLog(`[${event.type}]`);
      }
      const { exitCode } = await subprocess;
      if (exitCode !== 0 || result === null) throw new Error(`claude 실행 실패 (exit ${exitCode}): ${stderrTail.slice(-5).join(" / ")}`);
      JSON.parse(result); // 파싱 가능성만 확인 (깊은 검증은 서버)
      return result;
    },
  };
}
```
주의: **`--bare` 금지** (CLAUDE_CODE_OAUTH_TOKEN을 읽지 않아 구독 과금이 깨진다). 실 사용 전제: 팀원이 `claude setup-token`을 1회 실행해둔 상태.
- [ ] **Step 5: PASS → Step 6: 커밋** — `feat(bridge): 어댑터 기반·Claude 어댑터 (#175)`

---

### Task 4: Codex 어댑터

**Files:**
- Create: `bridge/src/adapters/codex.ts`
- Test: `bridge/test/codex-adapter.test.ts`, `bridge/test/fixtures/fake-codex.mjs`

**Interfaces:** `export function createCodexAdapter(opts?: { bin?: string }): CliAdapter;`

- [ ] **Step 1: 픽스처** — `codex exec --json`의 JSONL 이벤트 흉내: `{"type":"item.completed","item":{"type":"reasoning","text":"..."}}`, `{"type":"item.completed","item":{"type":"agent_message","text":"{\"quizzes\":[...]}"}}`, `{"type":"turn.completed"}`.
- [ ] **Step 2: 실패하는 테스트** — 마지막 `agent_message` 텍스트(펜스 제거)를 반환, 중간 이벤트는 onLog, `--output-schema`로 전달된 임시 파일에 outputSchema JSON이 실제로 쓰였는지(픽스처가 파일 내용을 이벤트로 echo해 검증), env 새니타이즈.
- [ ] **Step 3: FAIL → Step 4: 구현** — `mkdtemp`로 스키마 임시 파일 작성 후:
  `execa(bin ?? "codex", ["exec", "--json", "--output-schema", schemaFile, prompt], { env: sanitizedEnv(), extendEnv: false, ... })`
  JSONL 파싱: `item.completed` && `item.type === "agent_message"` → 결과 후보(마지막 승리), 그 외 이벤트는 요약해 onLog. 종료 후 `stripFences` → `JSON.parse` 확인 → 반환. finally에서 임시 파일 정리.
- [ ] **Step 5: PASS → Step 6: 커밋** — `feat(bridge): Codex 어댑터 (#175)`

---

### Task 5: Gemini 어댑터

**Files:**
- Create: `bridge/src/adapters/gemini.ts`
- Test: `bridge/test/gemini-adapter.test.ts`, `bridge/test/fixtures/fake-gemini.mjs`

**Interfaces:** `export function createGeminiAdapter(opts?: { bin?: string }): CliAdapter;`

- [ ] **Step 1: 픽스처** — `gemini -p --output-format json`은 스트리밍 이벤트 없이 마지막에 단일 JSON 봉투를 출력: `{"response":"```json\n{\"quizzes\":[]}\n```","stats":{...}}`.
- [ ] **Step 2: 실패하는 테스트** — `.response` 펜스 제거 후 반환, stderr는 onLog로 중계, env 새니타이즈(특히 `GEMINI_API_KEY`·`GOOGLE_API_KEY` 제거 — 있으면 OAuth 구독 세션 대신 API 과금으로 샌다).
- [ ] **Step 3: FAIL → Step 4: 구현** — stdout 전체 버퍼링(스트리밍 아님) → `JSON.parse(stdout)` → `stripFences(envelope.response)` → 파싱 확인 → 반환. 시작 시 `onLog("gemini 실행 중 — 이 CLI는 중간 로그를 제공하지 않습니다")`.
- [ ] **Step 5: PASS → Step 6: 커밋** — `feat(bridge): Gemini 어댑터 (#175)`

---

### Task 6: 메인 루프 + CLI 엔트리 + README

**Files:**
- Create: `bridge/src/runner.ts`, `bridge/src/index.ts`, `bridge/README.md`
- Test: `bridge/test/runner.test.ts` (가짜 서버 + 가짜 CLI 통합)

**Interfaces:**
```ts
// runner.ts
export type RunnerDeps = { api: BridgeApi; adapter: CliAdapter; pollIntervalMs?: number; logFlushMs?: number };
export async function runOnce(deps: RunnerDeps): Promise<"idle" | "done" | "failed">;
// idle = 잡 없음. done = result 제출(서버 FAILED 판정 포함). failed = 실행 예외로 fail 제출.
export async function runLoop(deps: RunnerDeps, signal: AbortSignal): Promise<void>;
```

- [ ] **Step 1: 실패하는 통합 테스트** — T2의 fake-server + T3의 fake-claude 재사용:

```ts
it("잡 수령→실행→로그 배치 전송→result 제출의 전체 사이클", async () => {
  // 가짜 서버: next가 잡 1개 반환 → 이후 null. logs/result 요청을 기록.
  const outcome = await runOnce({ api, adapter: fakeClaudeAdapter, logFlushMs: 10 });
  expect(outcome).toBe("done");
  expect(server.received.logs.flat()).toContain("문제 생성 중...");
  expect(JSON.parse(server.received.result!.resultJson)).toHaveProperty("quizzes");
});
it("어댑터가 throw하면 fail을 제출한다", async () => { ... outcome "failed", server.received.fail.error 포함 ... });
it("잡이 없으면 idle을 반환한다", async () => { ... });
```

- [ ] **Step 2: FAIL → Step 3: 구현** — `runOnce`: `nextJob()` → null이면 idle. 잡 있으면 로그 버퍼+`setInterval(flush, logFlushMs)`(flush = `postLogs`, 실패해도 실행은 계속 — 로그는 best-effort), `adapter.run` → `postResult` → done / catch → `postFail` → failed. finally에서 interval 정리+마지막 flush. `runLoop`: `while (!signal.aborted) { const r = await runOnce(deps); if (r === "idle") await sleep(pollIntervalMs ?? 3000, signal); }`.
  `index.ts`: `login` 서브커맨드 → `runLogin()`, 그 외 → config 로드, cli에 맞는 어댑터 선택, `AbortController` + SIGINT 핸들러(진행 중 잡은 완료 후 종료), 시작 배너(서버 URL·CLI·"Ctrl+C로 종료").
- [ ] **Step 4: PASS → Step 5: README 작성** — 설치(`pnpm install`), 1회 셋업(각 CLI 구독 로그인: `claude setup-token` / `codex login` / `gemini` + `pnpm start login`), 실행(`pnpm start`), 구독 유지 규칙(API 키 env 금지·--bare 금지) 요약.
- [ ] **Step 6: 최종 게이트** — `pnpm typecheck && pnpm test` 전체 통과.
- [ ] **Step 7: 커밋** — `feat(bridge): 메인 루프·CLI 엔트리·README (#175)`

---

## Self-review 체크 (플랜 작성자 완료)

- 스펙 §8의 브리지 책임 전부 매핑: config·로그인 T1~T2, 어댑터 3종+구독 보호 T3~T5, 루프·배칭·graceful shutdown T6.
- 스펙과 다른 점(의도적 정제): 결과 추출을 `out.json` 파일 쓰기 대신 **각 CLI의 구조화 출력 봉투 파싱**으로 변경 — 파일 쓰기는 headless 모드에서 도구 권한 플래그가 필요해 오히려 취약. 스키마 플래그(`--json-schema`/`--output-schema`)는 유지.
- 실제 CLI 출력 포맷은 버전에 따라 다를 수 있음 — 어댑터가 픽스처 기반이므로 실기기 스모크는 통합 단계(오케스트레이터)에서 별도 수행.

# 문제 저작 대시보드 UI — 구현 계획 (#176)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/authoring` 보호 라우트에서 문제 생성/검수/개선/승인을 트리거하고 잡 실행 로그를 xterm.js 터미널로 실시간 표시하는 대시보드.

**Architecture:** 기존 Next.js 앱(`app/`)에 `/authoring` 세그먼트 추가. 기존 관례 그대로: `apiRequest` 래퍼 경유 API 호출, `RequireAuth` 클라이언트 가드 + `dynamic = "force-dynamic"`, LoadState 판별 유니언 패턴, BottomSheet/Chip/Button 등 기존 디자인 시스템. SSE는 **fetch 기반 리더**(EventSource는 Authorization 헤더 불가)로 파싱해 xterm에 흘린다.

**Tech Stack:** Next 16.2.10, React 19.2.4, Tailwind v4(토큰), @xterm/xterm + @xterm/addon-fit (react-xtermjs 미사용 — 직접 마운트가 의존성 적음), vitest + RTL, biome.

**Spec:** `docs/superpowers/specs/2026-07-14-quiz-authoring-dashboard-design.md`

## Global Constraints

- 브랜치: `feat/176-authoring-app`, 커밋 형식 `feat(app): <한국어 요약> (#176)` — main 직접 커밋 금지.
- **디자인 게이트**: raw hex·Tailwind arbitrary value 금지(`scripts/check-design.mjs`) — 불가피하면(xterm theme 객체 등) 해당 라인에 `// design-ok`. `src/components/ui/`에 새 파일을 만들면 `.stories.tsx` 필수이므로 **저작 전용 컴포넌트는 전부 `src/features/authoring/components/`에** 둔다.
- 서버 호출은 반드시 `apiRequest`(`@/lib/api`) 경유 — 단 SSE 스트림만 예외(직접 fetch, 사유: 스트리밍 응답).
- biome이 import를 자동 정렬(lineWidth 100) — 파일 생성 후 `pnpm lint:fix` 실행.
- 페이지는 기존 패턴 복제: 서버 컴포넌트 page.tsx는 `RequireAuth`+스크린 래핑과 `export const dynamic = "force-dynamic"`만, 데이터 로딩은 "use client" 스크린 컴포넌트의 LoadState 유니언(`loading|error|success`) + `useCallback`/`useEffect`.
- 테스트는 `src/test/`에 평면 배치(기존 관례), jsdom + RTL, fetch는 `vi.stubGlobal` 패턴(`src/test/api-client.test.ts` 참고).
- 게이트: `cd app && pnpm typecheck && pnpm lint && pnpm test && pnpm check:design && pnpm build`.
- 소비자 화면(홈·플레이 등)과 공용 내비게이션은 **수정하지 않는다** — 저작 도구는 URL 직접 진입(MVP).

## 서버 HTTP 계약 (정본은 서버 플랜 `2026-07-14-quiz-authoring-server.md` — 불일치 시 그쪽 우선)

Base `/api/v1` + Bearer JWT (apiRequest가 자동 처리). 엔벨로프 `{code,message,data,meta}` — apiRequest가 data 언랩.

```
POST /authoring/drafts/generate         {topic}        → data:{jobId}
POST /authoring/quizzes/{quizId}/improve {instruction} → data:{draftId, jobId}
POST /authoring/drafts/{draftId}/reviews {feedback?}   → data:{jobId}
POST /authoring/drafts/{draftId}/approve               → data:{draftId, status:"APPROVED"}
GET  /authoring/drafts?status=DRAFT|APPROVED           → data:{drafts:[DraftSummary]}
GET  /authoring/drafts/{draftId}                       → data:DraftDetail
GET  /authoring/quizzes                                → data:{steps:[AuthoringStep]}
GET  /authoring/jobs/{jobId}                           → data:JobStatus
GET  /authoring/jobs/{jobId}/stream?fromSeq=N          → SSE(text/event-stream, 엔벨로프 없음)
```

```
DraftSummary = { draftId, origin:"NEW"|"IMPROVE", status:"DRAFT"|"APPROVED", topic, sourceQuizId:number|null, revisionCount:number, updatedAt:string }
DraftDetail  = DraftSummary & { payload:{quizzes:GeneratedQuiz[]}, revisions:Revision[], createdBy:number, approvedBy:number|null, approvedAt:string|null }
Revision     = { revisionNo:number, reviewSummary:string|null, reviewedBy:number|null, jobId:number, createdAt:string }
JobStatus    = { jobId, kind:"GENERATE"|"REVIEW", status:"QUEUED"|"RUNNING"|"SUCCEEDED"|"FAILED", draftId:number|null, error:string|null, createdAt:string, startedAt:string|null, finishedAt:string|null }
AuthoringStep = { stepOrder:number, topic:string, quizzes:{ quizId:number, slotOrder:number, type:string, difficulty:string, questionText:string }[] }
GeneratedQuiz = { type, difficulty, questionText, codeSnippet:string|null, explanationSummary, explanationExample:string|null,
                  wrongAnswerExplanation, correctAnswer:string|null, choices:{content:string,isCorrect:boolean}[]|null,
                  answerKeywords:string[][]|null, followUpQuestions:unknown[]|null, derivedConcepts:string[]|null,
                  keywords:{keyword:string,description:string}[]|null }
SSE 이벤트:  event:log  id:<seq>  data:{"seq":n,"line":"..."}   /   event:status  data:{"status":"SUCCEEDED","draftId":42,"error":null}
```

## 파일 맵

```
app/src/features/authoring/
  types.ts, api.ts                        [T1]
  sse.ts                                  [T2]  fetch 기반 SSE 리더 (프레임워크 무관 함수)
  use-job-log-stream.ts                   [T2]  React 훅
  components/terminal-viewer.tsx          [T3]
  components/job-status-chip.tsx          [T3]
  components/generate-sheet.tsx           [T4]
  components/drafts-screen.tsx            [T4]
  components/job-screen.tsx               [T5]
  components/draft-detail-screen.tsx      [T6]
  components/review-sheet.tsx, approve-sheet.tsx  [T6]
  components/quizzes-screen.tsx, improve-sheet.tsx [T7]
app/src/app/authoring/
  layout.tsx                              [T4]  상단 내비(Draft 목록 | 라이브 문제)
  page.tsx                                [T4]  → DraftsScreen
  jobs/[jobId]/page.tsx                   [T5]  → JobScreen
  drafts/[draftId]/page.tsx               [T6]  → DraftDetailScreen
  quizzes/page.tsx                        [T7]  → QuizzesScreen
app/src/lib/api/client.ts                 [T2 수정]  apiUrl() export 추가
app/src/test/authoring-*.test.ts(x)       [각 태스크]
```

---

### Task 1: 타입 + API 레이어

**Files:**
- Create: `app/src/features/authoring/types.ts`, `app/src/features/authoring/api.ts`
- Test: `app/src/test/authoring-api.test.ts`

**Interfaces (Produces):**
```ts
// types.ts — 위 계약 절의 타입 전부 export (DraftSummary, DraftDetail, Revision, JobStatus, AuthoringStep, GeneratedQuiz 등)
// api.ts
export function generateDraft(topic: string): Promise<{ jobId: number }>;
export function improveQuiz(quizId: number, instruction: string): Promise<{ draftId: number; jobId: number }>;
export function reviewDraft(draftId: number, feedback?: string): Promise<{ jobId: number }>;
export function approveDraft(draftId: number): Promise<{ draftId: number; status: string }>;
export function getDrafts(status?: "DRAFT" | "APPROVED"): Promise<DraftSummary[]>;   // data.drafts 언랩
export function getDraft(draftId: number): Promise<DraftDetail>;
export function getAuthoringQuizzes(): Promise<AuthoringStep[]>;                     // data.steps 언랩
export function getJob(jobId: number): Promise<JobStatus>;
```

- [ ] **Step 1: 실패하는 테스트 작성** — `src/test/api-client.test.ts`의 `vi.stubGlobal("fetch", ...)` + 엔벨로프 헬퍼 패턴 복제. 케이스: ① `generateDraft`가 올바른 경로·메서드·body로 호출하고 jobId 반환, ② `getDrafts("DRAFT")`가 쿼리스트링 포함 + drafts 배열 언랩, ③ `reviewDraft` feedback 생략 시 body에서 필드 제외.
- [ ] **Step 2: 실행 — FAIL** — `cd app && pnpm test -- authoring-api`.
- [ ] **Step 3: 구현** — 전부 `apiRequest` 위임 (기존 `src/lib/api/quiz.ts` 스타일):

```ts
import { apiRequest } from "@/lib/api";
export function generateDraft(topic: string): Promise<{ jobId: number }> {
  return apiRequest("/authoring/drafts/generate", { method: "POST", body: { topic } });
}
export async function getDrafts(status?: "DRAFT" | "APPROVED"): Promise<DraftSummary[]> {
  const query = status ? `?status=${status}` : "";
  const data = await apiRequest<{ drafts: DraftSummary[] }>(`/authoring/drafts${query}`);
  return data.drafts;
}
// 나머지 동일 패턴 — apiRequest의 시그니처·옵션은 src/lib/api/client.ts를 확인해 그대로 사용
```

- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(app): 저작 API 레이어·타입 (#176)`

---

### Task 2: fetch 기반 SSE 리더 + 훅

**Files:**
- Modify: `app/src/lib/api/client.ts` — `export function apiUrl(path: string): string` 추가 (`BASE_URL + PREFIX + path` — 기존 상수 재사용, 다른 코드 변경 금지)
- Create: `app/src/features/authoring/sse.ts`, `app/src/features/authoring/use-job-log-stream.ts`
- Test: `app/src/test/authoring-sse.test.ts`

**Interfaces (Produces):**
```ts
// sse.ts — 프레임워크 무관 (테스트 용이). EventSource를 쓰지 않는 이유: Authorization 헤더를 붙일 수 없음.
export type SseHandlers = {
  onLog: (entry: { seq: number; line: string }) => void;
  onStatus: (status: { status: string; draftId: number | null; error: string | null }) => void;
  onError: (error: unknown) => void;
};
export async function streamJobLogs(jobId: number, handlers: SseHandlers, signal: AbortSignal): Promise<void>;

// use-job-log-stream.ts
export type JobStreamState =
  | { phase: "connecting" }
  | { phase: "streaming" }
  | { phase: "done"; status: string; draftId: number | null; error: string | null }
  | { phase: "error" };
export function useJobLogStream(jobId: number, onLine: (line: string) => void): JobStreamState;
```

- [ ] **Step 1: 실패하는 파서 테스트** — fetch를 stub해서 `ReadableStream`으로 SSE 텍스트를 청크 단위로 흘리는 헬퍼 작성(청크 경계가 이벤트 중간을 자르는 케이스 포함):

```ts
function sseResponse(chunks: string[]): Response { /* ReadableStream.pull로 순차 enqueue */ }
it("log 이벤트를 파싱해 onLog를 호출한다", async () => {
  stubFetch(sseResponse(['event: log\nid: 1\ndata: {"seq":1,"line":"시작"}\n\n', 'event: log\nid: 2\ndata: {"seq":2,"li', 'ne":"진행"}\n\n']));
  // onLog가 seq 1, 2로 두 번 호출 — 청크 경계 분할에도 안전
});
it("status 이벤트를 받으면 onStatus 후 정상 종료한다", async () => { ... });
it("Authorization 헤더에 tokenStore의 access 토큰을 붙인다", async () => { ... });
it("HTTP 401이면 onError를 호출한다", async () => { ... });
```

- [ ] **Step 2: FAIL → Step 3: 구현** — 파서 핵심 (`\n\n` 구분 프레임 버퍼링):

```ts
export async function streamJobLogs(jobId: number, handlers: SseHandlers, signal: AbortSignal): Promise<void> {
  try {
    const access = tokenStore.getAccess();
    const res = await fetch(apiUrl(`/authoring/jobs/${jobId}/stream`), {
      headers: { Accept: "text/event-stream", Authorization: `Bearer ${access ?? ""}` },
      signal,
    });
    if (!res.ok || !res.body) { handlers.onError(new Error(`stream ${res.status}`)); return; }
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let sep: number;
      while ((sep = buffer.indexOf("\n\n")) >= 0) {
        const frame = buffer.slice(0, sep);
        buffer = buffer.slice(sep + 2);
        const event = parseFrame(frame); // event:/data: 필드 추출
        if (event.name === "log") handlers.onLog(JSON.parse(event.data));
        else if (event.name === "status") { handlers.onStatus(JSON.parse(event.data)); return; }
      }
    }
  } catch (error) {
    if (!signal.aborted) handlers.onError(error);
  }
}
```
훅: 마운트 시 `getJob(jobId)`를 먼저 1회 호출(토큰 만료면 apiRequest가 리프레시 — 스트림이 신선한 토큰으로 열리게) 후 `streamJobLogs` 시작, 언마운트 시 abort. 이미 터미널 상태면 스트림 없이 바로 `done`.
- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(app): fetch 기반 SSE 로그 스트림 (#176)`

---

### Task 3: TerminalViewer + JobStatusChip

**Files:**
- Create: `app/src/features/authoring/components/terminal-viewer.tsx`, `job-status-chip.tsx`
- Modify: `app/package.json` — `pnpm add @xterm/xterm @xterm/addon-fit`
- Test: `app/src/test/authoring-terminal.test.tsx`

**Interfaces (Produces):**
```tsx
// TerminalViewer — 부모가 write 함수를 받아 로그를 밀어넣는 명령형 인터페이스
export type TerminalHandle = { write: (line: string) => void };
export function TerminalViewer({ onReady }: { onReady: (handle: TerminalHandle) => void }): JSX.Element;
// JobStatusChip — 기존 Chip을 감싸 상태별 tone 매핑 (QUEUED=대기, RUNNING=실행 중, SUCCEEDED=완료, FAILED=실패)
export function JobStatusChip({ status }: { status: JobStatus["status"] }): JSX.Element;
```

- [ ] **Step 1: 실패하는 테스트** — `@xterm/xterm`을 `vi.mock`(가짜 Terminal: `open`/`write`/`dispose` spy): ① 마운트 시 Terminal.open이 컨테이너 엘리먼트로 호출, ② `onReady`로 받은 handle.write("abc")가 내부 term.write에 `"abc\r\n"`으로 전달(개행 변환), ③ 언마운트 시 dispose. JobStatusChip은 상태별 라벨 렌더 확인.
- [ ] **Step 2: FAIL → Step 3: 구현** — `"use client"`. xterm은 **useEffect 안에서 동적 import**(SSR 회피):

```tsx
"use client";
import "@xterm/xterm/css/xterm.css";
import { useEffect, useRef } from "react";
import type { Terminal } from "@xterm/xterm";

export function TerminalViewer({ onReady }: { onReady: (handle: TerminalHandle) => void }) {
  const containerRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let term: Terminal | undefined;
    let disposed = false;
    void (async () => {
      const [{ Terminal }, { FitAddon }] = await Promise.all([import("@xterm/xterm"), import("@xterm/addon-fit")]);
      if (disposed || !containerRef.current) return;
      term = new Terminal({
        convertEol: true, fontSize: 12, disableStdin: true, cursorBlink: false,
        theme: { background: "#1a1b26", foreground: "#c0caf5" }, // design-ok — xterm theme은 JS 객체라 토큰 사용 불가
      });
      const fit = new FitAddon();
      term.loadAddon(fit);
      term.open(containerRef.current);
      fit.fit();
      onReady({ write: (line) => term?.write(`${line}\r\n`) });
    })();
    return () => { disposed = true; term?.dispose(); };
  }, [onReady]);
  return <div ref={containerRef} className="h-80 w-full overflow-hidden rounded-control bg-graph-bg" aria-label="잡 실행 로그 터미널" />;
}
```
(참고: `bg-graph-bg` 등 다크 캔버스 토큰 클래스명은 `globals.css`의 실제 `--color-graph-*` 토큰명을 확인해 맞출 것. CSS import가 SSR에서 문제되면 dynamic import 쪽으로 이동.)
- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(app): 터미널 뷰어·잡 상태 칩 (#176)`

---

### Task 4: /authoring 레이아웃 + Draft 목록 + 생성 플로우

**Files:**
- Create: `app/src/app/authoring/layout.tsx`, `app/src/app/authoring/page.tsx`
- Create: `app/src/features/authoring/components/drafts-screen.tsx`, `generate-sheet.tsx`
- Test: `app/src/test/authoring-drafts-screen.test.tsx`

**Interfaces:**
- Consumes: T1 `getDrafts`/`generateDraft`, 기존 `RequireAuth`·`Button`·`Card`·`Chip`·`BottomSheet`·`Input`·`useAppToast`
- Produces: URL `/authoring` (Draft 목록). 생성 성공 시 `router.push(\`/authoring/jobs/\${jobId}\`)`.

- [ ] **Step 1: 실패하는 스크린 테스트** — `vi.mock("@/features/authoring/api")` + `vi.mock("next/navigation")`(기존 `require-auth.test.tsx`의 hoisted 패턴): ① 로딩 후 draft 카드 목록 렌더(topic·origin·status·revisionCount 표시), ② 빈 목록이면 EmptyState, ③ "문제 생성" 버튼 → 시트 열림 → 주제 입력 → 제출 시 `generateDraft("운영체제")` 호출 + `/authoring/jobs/7` push, ④ API 에러 시 에러 상태 + 재시도 버튼.
- [ ] **Step 2: FAIL → Step 3: 구현** — 페이지·레이아웃은 기존 패턴 그대로:

```tsx
// app/src/app/authoring/layout.tsx — 서버 컴포넌트. 데스크톱 폭 컨테이너 + 상단 내비.
import Link from "next/link";
export default function AuthoringLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto min-h-dvh w-full max-w-4xl px-6 py-8">
      <header className="mb-6 flex items-center gap-6">
        <h1 className="text-lg font-bold text-ink">문제 저작</h1>
        <nav className="flex gap-4 text-sm text-ink-muted">
          <Link href="/authoring">Draft 목록</Link>
          <Link href="/authoring/quizzes">라이브 문제</Link>
        </nav>
      </header>
      {children}
    </div>
  );
}

// app/src/app/authoring/page.tsx
import { RequireAuth } from "@/features/auth/require-auth";
import { DraftsScreen } from "@/features/authoring/components/drafts-screen";
export const dynamic = "force-dynamic";
export default function AuthoringDraftsPage() {
  return (
    <RequireAuth>
      <DraftsScreen />
    </RequireAuth>
  );
}
```
`DraftsScreen`: LoadState 유니언 + `getDrafts()`(status 필터 토글: DRAFT 기본, APPROVED 탭), 카드 클릭 → `/authoring/drafts/{id}`. `GenerateSheet`: `feedback-sheet.tsx`의 BottomSheet 폼 패턴 복제(제출 중 `loading`, 실패 토스트).
- [ ] **Step 4: PASS → Step 5: `pnpm lint:fix` → 커밋** — `feat(app): 저작 레이아웃·draft 목록·생성 플로우 (#176)`

---

### Task 5: 잡 터미널 화면 (/authoring/jobs/[jobId])

**Files:**
- Create: `app/src/app/authoring/jobs/[jobId]/page.tsx`, `app/src/features/authoring/components/job-screen.tsx`
- Test: `app/src/test/authoring-job-screen.test.tsx`

**Interfaces:**
- Consumes: T2 `useJobLogStream`, T3 `TerminalViewer`/`JobStatusChip`, T1 `getJob`
- Produces: URL `/authoring/jobs/{jobId}` — 실행 로그 실시간 표시, 종료 시 결과 액션.

- [ ] **Step 1: 실패하는 테스트** — `useJobLogStream`·`TerminalViewer` 모킹: ① streaming 중 JobStatusChip "실행 중", ② done(SUCCEEDED, draftId=42) 도달 시 "Draft 보러가기" 링크(`/authoring/drafts/42`) 노출, ③ done(FAILED, error="검증 실패") 시 에러 메시지와 "다시 시도 안내" 노출, ④ QUEUED 오래 지속 표시 문구("브리지 대기 중 — 브리지를 켜세요") 렌더(잡 상태 QUEUED + 스트림 log 이벤트 없음 조건).
- [ ] **Step 2: FAIL → Step 3: 구현** — `JobScreen`: `TerminalHandle`을 `useRef`로 잡고 `useJobLogStream(jobId, line => handleRef.current?.write(line))`. 스트림 상태별 UI: connecting=Skeleton, streaming=터미널+칩, done=터미널+결과 배너(성공: draftId 링크 / 실패: error 텍스트 + Feedback 컴포넌트 danger tone). params는 Next 16 규약(`params` Promise)을 기존 동적 라우트 페이지가 있으면 그 방식, 없으면 `use(params)` 패턴으로.
- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(app): 잡 실행 터미널 화면 (#176)`

---

### Task 6: Draft 상세 + 검수/승인 플로우

**Files:**
- Create: `app/src/app/authoring/drafts/[draftId]/page.tsx`, `app/src/features/authoring/components/draft-detail-screen.tsx`, `review-sheet.tsx`, `approve-sheet.tsx`
- Test: `app/src/test/authoring-draft-detail.test.tsx`

**Interfaces:**
- Consumes: T1 `getDraft`/`reviewDraft`/`approveDraft`, T3 칩, 기존 BottomSheet/Button/Card/Feedback/useAppToast
- Produces: URL `/authoring/drafts/{draftId}`.

- [ ] **Step 1: 실패하는 테스트** — ① payload.quizzes 렌더(슬롯 순서대로 type·difficulty 칩 + questionText + MC면 선지에 정답 표시 + explanationSummary), ② revisions 이력(revisionNo 내림차순, reviewSummary 표시), ③ "검수 시작" → 시트(피드백 textarea 선택 입력) → `reviewDraft(id, feedback)` → `/authoring/jobs/{jobId}` push, ④ "승인" → 확인 시트("승인 즉시 라이브 반영" 경고 문구) → `approveDraft` → 성공 토스트, ⑤ status=APPROVED면 액션 버튼 비노출, ⑥ 409(`ApiError.code === "AUTHORING_DRAFT_JOB_ACTIVE"`) 시 "진행 중인 잡이 있습니다" 토스트.
- [ ] **Step 2: FAIL → Step 3: 구현** — 퀴즈 카드 렌더는 순수 프레젠테이션 컴포넌트로 분리(`QuizPayloadCard` — 같은 파일 내 비공개 컴포넌트로 충분, IMPROVE draft는 1개만 렌더). 날짜는 기존 화면의 표기 유틸/방식 재사용.
- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(app): draft 상세·검수·승인 플로우 (#176)`

---

### Task 7: 라이브 문제 목록 + 개선 플로우

**Files:**
- Create: `app/src/app/authoring/quizzes/page.tsx`, `app/src/features/authoring/components/quizzes-screen.tsx`, `improve-sheet.tsx`
- Test: `app/src/test/authoring-quizzes-screen.test.tsx`

**Interfaces:**
- Consumes: T1 `getAuthoringQuizzes`/`improveQuiz`
- Produces: URL `/authoring/quizzes` — 스텝별 그룹 목록, 문제별 "개선" 액션.

- [ ] **Step 1: 실패하는 테스트** — ① 스텝 헤더(stepOrder·topic) 아래 슬롯 순 문제 행 렌더, ② "개선" → 시트(개선 지시 textarea 필수) → `improveQuiz(quizId, instruction)` → `/authoring/jobs/{jobId}` push, ③ 409(`AUTHORING_IMPROVE_DRAFT_EXISTS`) 시 "이미 열린 개선 draft" 토스트.
- [ ] **Step 2: FAIL → Step 3: 구현 → Step 4: PASS → Step 5: 커밋** — `feat(app): 라이브 문제 목록·개선 플로우 (#176)`

---

### Task 8: 최종 게이트 + 마무리

- [ ] **Step 1: 전체 게이트 실행** — `cd app && pnpm typecheck && pnpm lint && pnpm test && pnpm check:design && pnpm build` 전부 통과. build는 `/authoring/*` 라우트가 정적 프리렌더를 시도하다 실패하지 않는지 확인(`force-dynamic` 누락 탐지).
- [ ] **Step 2: 수동 확인 목록 기록** — PR 본문에 남길 스모크 체크리스트: 로그인 → /authoring 진입, 생성 시트 제출 → 잡 화면 이동(서버 없으면 에러 상태 확인까지).
- [ ] **Step 3: 커밋** — `chore(app): 저작 대시보드 게이트 통과 정리 (#176)` (필요한 수정이 있었던 경우만)

---

## Self-review 체크 (플랜 작성자 완료)

- 스펙 §4(대시보드 역할)·§7(엔드포인트 소비)·§8(터미널=뷰어)·§10(에러 UX: 브리지 대기·실패 사유 표시) 모두 태스크에 매핑.
- 스펙과 다른 점(의도적 정제): ① `react-xtermjs` 대신 `@xterm/xterm` 직접 마운트(의존성·API 불확실성 감소), ② EventSource → fetch 리더(Authorization 헤더 제약 — 스펙 §13에 이미 flag된 문제의 해소), ③ 라우트 그룹 `(authoring)` 대신 실제 URL 세그먼트 `/authoring`(그룹은 URL에 안 드러나므로 애초에 세그먼트가 맞음).
- 타입 일관성: DraftSummary/DraftDetail/JobStatus 필드명이 서버 플랜 T7 DTO와 1:1 일치 확인.

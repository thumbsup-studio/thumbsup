# 해설 꼬리 질문 풀기 + 히스토리 탭바 복구 Implementation Plan

> **For agentic workers:** 설계 근거는 `docs/superpowers/specs/2026-07-10-follow-up-question-and-history-tabbar-design.md` 참조. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 해설 화면에서 이어지는 2단계 꼬리 질문 화면을 추가하고, 히스토리 탭에서 사라지던 하단 앱 탭바를 공용화해 복구한다.

**Architecture:** 꼬리질문은 본 문제에서 파생되므로 `features/play` 안에 데이터·화면·라우트를 둔다. 앱 탭바는 홈 전용에서 `components/ui` 공용 컴포넌트로 승격해 라우팅을 내부화하고 홈·히스토리가 공유한다. API 미확정이라 꼬리질문은 목업.

**Tech Stack:** Next.js App Router, TypeScript strict, Tailwind v4(@theme 토큰), Biome, pnpm, Vitest/RTL.

## Global Constraints

- app/CLAUDE.md 필수: `next-best-practices` + `design-system` 스킬 로드 후 작업. Server Component 기본, `'use client'`는 상호작용 최소 단위.
- 스타일은 globals.css @theme 토큰 · `src/components/ui` 컴포넌트만 (arbitrary value·raw hex 금지 — `check:design` 게이트 강제).
- 완료 기준: `verify-app` 게이트(typecheck → lint → build → check:design) 통과. main 직접 커밋 금지, 커밋은 `commit` 스킬 형식.
- 커밋 scope: `app`. 이슈 참조 `#122`.

---

### Task 1: 앱 탭바 공용화 + 히스토리 탭바 복구 (요구2)

가장 독립적이라 먼저. 홈 전용 탭바를 공용으로 올리고 히스토리에 붙인다.

**Files:**
- Create: `src/components/ui/app-tab-bar.tsx` (이동 + 라우팅 내부화)
- Delete: `src/features/home/components/bottom-tab-bar.tsx`
- Modify: `src/features/home/components/home-page.tsx` (콜백 prop 제거, `<AppTabBar activeTab="home" />`)
- Modify: `src/features/atlas/components/atlas-page.tsx` (하단 `mt-auto`에 `<AppTabBar activeTab="history" />`)
- Test: `src/test/bottom-tab-bar.test.tsx` → 새 경로/props로 갱신 (`next/navigation` mock)

**Interfaces:**
- Produces: `AppTabBar({ activeTab: "home" | "history" | "profile" })` — 내부 `useRouter`(home→`/`, history→`/history`) + `useAppToast`(profile→"프로필은 준비 중입니다.").

- [ ] **Step 1** `app-tab-bar.tsx` 작성: 기존 마크업/아이콘 그대로 옮기고 3버튼 모두 라우팅/토스트 연결. `activeTab`으로 `aria-current`·active 스타일. 아이콘 자산 `/icons/tabs/*.png` 유지.
- [ ] **Step 2** `home-page.tsx`: `BottomTabBar` import·콜백 제거 → `AppTabBar activeTab="home"`.
- [ ] **Step 3** `atlas-page.tsx`: 최하단 컨테이너에 `<div className="mt-auto pt-1"><AppTabBar activeTab="history" /></div>` 추가.
- [ ] **Step 4** 옛 `features/home/.../bottom-tab-bar.tsx` 삭제.
- [ ] **Step 5** `bottom-tab-bar.test.tsx` 갱신: import를 `@/components/ui/app-tab-bar`로, `next/navigation` `useRouter().push` mock, 히스토리 탭 클릭 시 `/history` push 검증 + 홈 탭 `aria-current` 검증.
- [ ] **Step 6** 검증: `pnpm test -- bottom-tab-bar` PASS → `pnpm typecheck && pnpm lint`.
- [ ] **Step 7** 커밋: `fix(app): 히스토리 하단 탭바 복구 — 앱 탭바 공용화 (#122)`

---

### Task 2: 꼬리질문 데이터 모델 + 목업 (요구1 데이터)

**Files:**
- Modify: `src/features/play/types.ts` (`FollowUpQuestion` + `BaseQuestion.followUp?`)
- Modify: `src/features/play/mock-play-session.ts` (5문제에 `followUp`)

**Interfaces:**
- Produces: `FollowUpQuestion { category, difficulty, question, oneLineAnswer, explanation, usageExample, keywords[] }`; `PlayQuestion.followUp?: FollowUpQuestion`.

- [ ] **Step 1** `types.ts`에 `FollowUpQuestion` 타입 + `BaseQuestion`에 `followUp?` 추가 (설계 문서 시그니처).
- [ ] **Step 2** `mock-play-session.ts`: 각 문제에 주제 연속성 있는 `followUp` 작성 (프로세스↔스레드, race condition↔원자연산, context switch↔스케줄링, 임계구역↔세마포어 등). `keywords`는 `insight.keywords`처럼 term+description. `oneLineAnswer`·`explanation`·`usageExample`에 핵심어를 `keywords.term`과 일치시켜 하이라이트 되게.
- [ ] **Step 3** 검증: `pnpm typecheck` PASS (타입 확장이 기존 소비처를 깨지 않는지 — optional이라 안전).
- [ ] **Step 4** 커밋: `feat(app): 꼬리질문 데이터 모델·목업 추가 (#122)`

---

### Task 3: 꼬리질문 화면 + 라우트 + 해설 CTA (요구1 UI)

**Files:**
- Create: `src/features/play/components/follow-up-page.tsx`
- Create: `src/app/follow-up/page.tsx`
- Modify: `src/features/play/components/insight-page.tsx` (CTA 추가)
- Test: `src/test/follow-up-page.test.tsx` (신규)

**Interfaces:**
- Consumes: `FollowUpQuestion`(Task 2), `getProgressPercent`·`getDifficultyLabel`·`clampQuestionIndex`(play-logic), `KeywordTooltipText`, `Progress`.
- Produces: `FollowUpPage({ session, questionIndex, correct, correctStreak })` with `revealed` state.

- [ ] **Step 1** `follow-up-page.tsx`: `"use client"`, `revealed` state. 헤더(뒤로·category·"꼬리 질문"·난이도 배지·진행률 `{N}번 문제에서 이어짐`·`{N+1}/{total}`·Progress). 본문(질문 카드 / 한 줄 답 / 상세 정리). `revealed=false`엔 마스킹(스켈레톤 + eye-off + "먼저 스스로 답을 떠올려 보세요"), `true`엔 `KeywordTooltipText`로 공개. CTA 분기: false→"답 확인하기"(setRevealed)/"이 질문 건너뛰기"(nextHref), true→"해설로 돌아가기"(insightHref)/"다음 문제로"(nextHref). `nextHref = isLast ? "/" : /play?question=N+1`, `insightHref = /insight?question=N&correct=..&streak=..`. 스타일은 @theme 토큰·기존 rounded-card/control 패턴.
- [ ] **Step 2** `app/follow-up/page.tsx`: `/insight` 패턴 복제 — `dynamic="force-dynamic"`, searchParams(question,correct,streak) → clamp → `FollowUpPage` 렌더. `followUp` 없으면 `/play`로 redirect(방어).
- [ ] **Step 3** `insight-page.tsx`: 하단 CTA 컨테이너에 "꼬리 질문 풀기" 버튼 추가 (`question.followUp` 있을 때만) → `/follow-up?question=N&correct=..&streak=..`. 기존 "다음 문제 풀기"/"홈으로" 유지.
- [ ] **Step 4** `follow-up-page.test.tsx`: (a) 초기 답 가림("먼저 스스로…" 노출, 한 줄 답 텍스트 미노출), (b) "답 확인하기" 클릭 → 한 줄 답 노출, (c) CTA href 정확성(해설로 돌아가기=insightHref, 다음 문제로=nextHref). `next/navigation` mock.
- [ ] **Step 5** 검증: `pnpm test -- follow-up` PASS → `pnpm typecheck && pnpm lint`.
- [ ] **Step 6** 커밋: `feat(app): 꼬리질문 2단계 화면·라우트·해설 진입 CTA (#122)`

---

### Task 4: 통합 검증 (Playwright 육안 + 전체 게이트)

- [ ] **Step 1** `pnpm build` (프로덕션 컴파일 경로) + `pnpm check:design` PASS.
- [ ] **Step 2** `pnpm dev` 기동, Playwright로 시안 대조: (1) `/play` → 정답확인 → `/insight` → "꼬리 질문 풀기" → 답 가림 → 답 확인 → "해설로 돌아가기"/"다음 문제로", (2) 홈 → 히스토리 진입 시 탭바 유지 + 홈 복귀. 스크린샷 저장.
- [ ] **Step 3** 시안 불일치 발견 시 수정 후 재검증.

## Self-Review (spec 대조)

- 요구1 2단계(답 가림→확인): Task 3 Step 1 ✓
- "다음 문제로"=다음 본 문제: Task 3 `nextHref` ✓
- 해설 CTA 진입 + 양방향 복귀: Task 3 Step 3 + insightHref ✓
- 목업 데이터: Task 2 ✓
- 탭바 공용화 + 히스토리 복구: Task 1 ✓
- KeywordTooltipText 재사용: Task 3 Step 1 ✓
- Playwright 검증 + verify-app 게이트: Task 4 ✓
- 미사용 제네릭 `ui/bottom-tab-bar.tsx` 미변경(비목표): 어느 task도 건드리지 않음 ✓

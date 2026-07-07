# Home Today MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 루트 `/`에 Today 홈 MVP를 구현하고, `#2`, `#51`, `#52`, `#53` 범위를 mock 데이터와 테스트 포함으로 완료한 뒤 `verify-app` 게이트를 통과한다.

**Architecture:** 홈은 서버 호출 없이 mock 홈 응답 객체를 소비하는 App Router 페이지로 구현한다. 페이지는 shell, welcome, streak, today course card, bottom tab bar로 분리하고, 시간대 계산과 탭 상태처럼 분기 로직은 순수 함수로 빼서 테스트한다.

**Tech Stack:** Next.js App Router, React 19, TypeScript strict, Tailwind CSS v4, Biome, Vitest, Testing Library

---

### Task 1: Test Setup For Home Logic

**Files:**
- Modify: `app/package.json`
- Create: `app/vitest.config.ts`
- Create: `app/src/test/setup.ts`
- Create: `app/src/test/home-logic.test.ts`

- [ ] **Step 1: Add test dependencies and scripts**

Add dev dependencies for `vitest`, `jsdom`, `@testing-library/react`, `@testing-library/jest-dom`.

Update `app/package.json` scripts to include:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

- [ ] **Step 2: Add Vitest config**

Create `app/vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
  },
});
```

- [ ] **Step 3: Add test setup**

Create `app/src/test/setup.ts`:

```ts
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 4: Write failing home logic tests**

Create `app/src/test/home-logic.test.ts` covering:
- `getWelcomeVariant()` returns commute/after-work/night by hour
- `formatStreakDays(0)` returns hidden state
- `formatStreakDays(1)` returns `1일`

- [ ] **Step 5: Run tests to verify failure**

Run: `cd app && pnpm test`

Expected: FAIL because home logic functions do not exist yet

### Task 2: Home Data And Logic Units

**Files:**
- Create: `app/src/features/home/types.ts`
- Create: `app/src/features/home/mock-home-data.ts`
- Create: `app/src/features/home/home-logic.ts`
- Test: `app/src/test/home-logic.test.ts`

- [ ] **Step 1: Create home types**

Define a `HomeData` type with:

```ts
type HomeData = {
  streakDays: number;
  todayCourse: {
    title: string;
    subtitle: string;
    progress: number;
    durationLabel: string;
  };
};
```

- [ ] **Step 2: Create mock home data**

Add one mock home payload for the root page.

- [ ] **Step 3: Implement home logic**

Implement pure helpers:

```ts
export function getWelcomeVariant(date: Date): "commute" | "afterWork" | "night"
export function getWelcomeCopy(date: Date): { eyebrow: string; title: string; body: string }
export function shouldShowStreak(streakDays: number): boolean
export function formatStreakDays(streakDays: number): string
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd app && pnpm test`

Expected: PASS for logic tests

### Task 3: Home UI Components

**Files:**
- Create: `app/src/features/home/components/home-shell.tsx`
- Create: `app/src/features/home/components/welcome-block.tsx`
- Create: `app/src/features/home/components/streak-block.tsx`
- Create: `app/src/features/home/components/today-course-card.tsx`
- Create: `app/src/features/home/components/bottom-tab-bar.tsx`
- Create: `app/src/features/home/components/home-page.tsx`

- [ ] **Step 1: Build welcome block**

Render eyebrow, title, body from computed copy.

- [ ] **Step 2: Build streak block**

Render nothing when `streakDays` is `0`.

Render visible state like:

```tsx
<section aria-label="연속 학습">
  <p>연속 학습</p>
  <strong>{formatStreakDays(streakDays)}</strong>
</section>
```

- [ ] **Step 3: Build today course card**

Render title, subtitle, progress text, duration label, and a large `시작하기` button.

- [ ] **Step 4: Build bottom tab bar**

Render three tabs with only `홈` active.

Clicking `히스토리` or `프로필` should set a local “준비 중입니다” message.

- [ ] **Step 5: Build page composition component**

Compose welcome, conditional streak, today card, and bottom tabs in a mobile-first single-column layout.

### Task 4: UI Tests

**Files:**
- Create: `app/src/test/home-page.test.tsx`
- Test: `app/src/features/home/components/*.tsx`

- [ ] **Step 1: Write failing UI tests**

Create tests for:
- streak hidden when `streakDays` is `0`
- today course card renders required text
- inactive tabs show `준비 중입니다`

- [ ] **Step 2: Run tests to verify failure**

Run: `cd app && pnpm test`

Expected: FAIL until components/page are wired correctly

- [ ] **Step 3: Implement missing UI behavior**

Adjust component props/state until tests pass.

- [ ] **Step 4: Run tests to verify pass**

Run: `cd app && pnpm test`

Expected: PASS for logic + UI tests

### Task 5: Wire Root Page And Styling

**Files:**
- Modify: `app/src/app/page.tsx`
- Modify: `app/src/app/globals.css`
- Modify: `app/src/app/layout.tsx` (only if metadata needs updating)

- [ ] **Step 1: Replace placeholder root page**

Render the new home page component from `app/src/app/page.tsx`.

- [ ] **Step 2: Adjust global styling only as needed**

Remove conflicting global body styles if they fight the home layout.

- [ ] **Step 3: Run tests**

Run: `cd app && pnpm test`

Expected: PASS

### Task 6: Verification And Delivery

**Files:**
- Verify only

- [ ] **Step 1: Run app gate**

Run:

```bash
cd app && pnpm typecheck
cd app && pnpm lint
cd app && pnpm build
```

Expected: all PASS

- [ ] **Step 2: Run visual QA if feasible**

Run: `cd app && pnpm qa:visual`

Expected: home route screenshot/report generated or a clear note about why it could not run

- [ ] **Step 3: Commit in logical units**

Create at least:
- test/setup commit
- home UI commit
- verification fixup commit if needed

- [ ] **Step 4: Create PR**

Open a PR from `feat/2-home-mvp` to `main` with issue links for `#2`, `#51`, `#52`, `#53`.

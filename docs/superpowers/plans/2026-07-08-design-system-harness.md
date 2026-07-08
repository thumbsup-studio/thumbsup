# 디자인 시스템 + 3단 하네스 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thumbs Up 앱에 브랜드 디자인 토큰·공통 UI 컴포넌트·Storybook 카탈로그를 만들고, 규칙 위반을 자동 차단하는 3단 하네스(에이전트 스킬 · 정적 게이트 · 시각 QA)를 구축한다.

**Architecture:** Tailwind v4 `@theme` 토큰(globals.css)을 단일 소스로, `src/components/ui/`에 토큰만 참조하는 프레젠테이션 컴포넌트를 수제 작성한다. Storybook이 토큰·컴포넌트·디자인 룰의 카탈로그다. 하네스는 (①) `.claude/skills/design-system` 프로젝트 스킬, (②) `scripts/check-design.mjs` 정적 스캐너를 verify-app·CI에 연결, (③) 기존 `visual-qa` CI job의 시안 대조 모드로 구성한다.

**Tech Stack:** Next.js 16.2 (App Router) · React 19.2 · TypeScript strict · Tailwind CSS v4 · Biome 2.5 · Storybook 9 (`@storybook/nextjs-vite`, devDependency) · pnpm 10.11 · Node 22 · Node 내장 `node --test`(하네스 스크립트 테스트)

## Global Constraints

이 절의 값은 **모든 태스크의 요구사항에 암묵적으로 포함**된다.

- **런타임 의존성 0**: Storybook·테스트 러너는 전부 `devDependencies`. `dependencies`에는 next/react/react-dom 외 추가 금지.
- **토큰만 사용**: 컴포넌트·화면은 `bg-primary`·`rounded-card`처럼 **토큰 이름 유틸리티로만** 스타일링. `bg-[#2f63ff]`·`rounded-[36px]`·`text-[13px]` 같은 arbitrary value와 raw hex(`#rrggbb`) 금지. 불가피한 한 줄은 그 줄에 `// design-ok` 주석으로만 예외 처리.
- **컴포넌트=스토리 1:1**: `src/components/ui/<name>.tsx`를 만들면 반드시 `src/components/ui/<name>.stories.tsx`를 함께 만든다. (게이트 ②가 강제)
- **접근성 수치**: 터치 타깃 ≥ 44px(실무상 `min-h-12`=48px 유지), 본문 텍스트 대비 ≥ WCAG AA 4.5:1, 모션에는 `@media (prefers-reduced-motion: reduce)` 대안, z-index는 시맨틱 스케일(임의 999 금지).
- **테마**: 라이트 고정. `prefers-color-scheme: dark` 분기 제거. 다크는 그래프 화면(#10) 전용 `--color-graph-*` 토큰으로만(이번 범위에서 값 정의는 하지 않고 네이밍만 예약).
- **폰트**: 한국어 본문 = Pretendard Variable, 코드 = Geist Mono. create-next-app 잔재(Arial, Geist Sans 본문)를 교체.
- **커밋 규약**: `main` 직접 커밋 금지. 브랜치 `feat/38-design-system`. 커밋 메시지 `<type>(app): <한국어 요약> (#38)` (예: `feat(app): 디자인 토큰 정의 (#38)`). 각 태스크 끝에서 커밋.
- **작업 경로**: 모든 파일 읽기/수정은 워크트리 `~/DEV/thumbsup__worktrees/feat-38-design-system/` 기준. 명령은 `app/`에서 실행(별도 명시 없으면).

## 값 추출 원칙 (Task 1·2에서 확정, 이후 태스크는 이름으로 참조)

레퍼런스 시안(`docs/design/references/*.png`, 6장)의 **정확한 hex·radius·그림자 값**은 Task 2에서 추출해 `globals.css`에 박는다. Task 6 이후 컴포넌트는 **토큰 이름**(`primary`, `card`, …)만 참조하므로, 값이 나중에 바뀌어도 컴포넌트 코드는 불변이다. 이 플랜에서 컴포넌트 코드에 hex가 등장하면 그것은 버그다.

## 태스크 위상 (blocking 표시)

- **Task 1–13**: PR #85·엘리스 엔드포인트와 **무관 — 지금 전부 실행 가능**. 이 13개만으로 "동작하는 디자인 시스템 + Storybook + 하네스" 완성(화면 없이도 검증됨).
- **Task 14 ⛔ BLOCKED(#85 머지)**: 홈 화면 retrofit. PR #85가 main에 머지된 뒤 rebase 필요.
- **Task 15**: 최종 게이트 + PR 생성.
- **Task 16 ⛔ BLOCKED(엘리스 Gemini 엔드포인트 문의 응답)**: 시각 QA CI 리뷰 활성화·스모크.

---

## Task 1: DESIGN.md · PRODUCT.md (기준 문서)

디자인 언어를 레포에 문서로 박제한다. `impeccable` 스킬이 세션마다 자동 로드하는 문서이므로 하네스 ①의 토대다.

**Files:**
- Create: `app/PRODUCT.md`
- Create: `app/DESIGN.md`
- Read (참조): `docs/design/references/*.png` (6장), `docs/superpowers/specs/2026-07-08-design-system-harness-design.md` §3

**Interfaces:**
- Produces: `DESIGN.md`가 Task 2 토큰 값의 근거. 아래 "필수 섹션"의 항목명은 Task 2 토큰 이름과 1:1 대응해야 함.

- [ ] **Step 1: impeccable init 실행**

`/impeccable init`을 호출한다. `NO_PRODUCT_MD`가 뜨면 스킬의 `reference/init.md`를 따른다.
**중요:** 스킬이 자동 팔레트 시드(`palette.mjs`)를 제안하면 **스킵**한다 — 브랜드 컬러(블루 #2f63ff 계열)는 이미 확정이고 identity 보존이 우선(스킬 자체 규칙과 일치).

- [ ] **Step 2: DESIGN.md에 아래 필수 섹션을 6장 시안 기준으로 작성**

각 섹션은 시안에서 실제 관찰한 값/역할로 채운다(추상 서술 금지). 필수 섹션:

- **컬러 역할**: `primary`(블루, CTA·선택 상태) / `accent`(오렌지, 스트릭·긴급 — `today-streak-recovery.png`의 "지금 복구" 배너) / `ox-o`(그린)·`ox-x`(레드, `quiz-types-board.png` OX 대형 버튼) / `success`·`danger`·`warning`·`info`(피드백, `answer-insight.png` 정답 그린 배너) / 뉴트럴 `bg`·`surface`·`surface-muted`·`ink`·`ink-muted`·`border`
- **radius 스케일**: `card`(외곽 카드, `home-today.png`의 큰 라운드) / `control`(버튼·입력) / `chip`(pill)
- **그림자**: `card`(일반 카드) / `hero`(블루 코스 카드 강조)
- **타이포**: 본문 Pretendard, 코드 Geist Mono. 크기는 Tailwind 기본 스케일(rem) 사용 — 커스텀 타이포 토큰은 만들지 않는다(YAGNI, TC-38-28 rem 요구 충족)
- **스페이싱·터치 타깃**: Tailwind 기본 스페이싱(rem) 사용. 하단 CTA·탭 최소 높이 `min-h-12`(48px)
- **엄지 모티프**: 👍 그래픽 사용 규칙(장식 강조용, 정보 전달은 텍스트/아이콘 병행 — 색만으로 상태 구분 금지, TC-38-29)
- **다크 격리**: 라이트 고정. 그래프 화면(#10)만 `--color-graph-*`로 분리 예정

`PRODUCT.md`는 impeccable init 산출물(제품 성격: 개발자 학습 앱, register=product) 그대로 두되, 섹션에 엄지 모티프·오렌지 포인트·마스코트가 제네릭이 아닌 떰즈업 내용으로 들어갔는지 확인.

- [ ] **Step 3: 커밋**

```bash
git add app/PRODUCT.md app/DESIGN.md
git commit -m "docs(app): 디자인 기준 문서 PRODUCT·DESIGN 작성 (#38)"
```

**Acceptance:** 두 파일 존재. DESIGN.md의 컬러/ radius/그림자 섹션 항목명이 Task 2 토큰 이름과 매칭됨. "TBD"·빈 섹션 없음.

---

## Task 2: `@theme` 토큰 + 폰트 교체

DESIGN.md를 코드로 고정한다. 이 태스크가 확정하는 **토큰 이름**이 이후 모든 컴포넌트의 계약이다.

**Files:**
- Modify: `app/src/app/globals.css` (전면 교체)
- Modify: `app/src/app/layout.tsx` (폰트)
- Create: `app/src/app/fonts/PretendardVariable.woff2` (다운로드) — 또는 Google 폴백(Step 2 참고)

**Interfaces:**
- Produces: 아래 토큰 이름 집합. Tailwind v4는 `--color-primary` → `bg-primary`/`text-primary`, `--radius-card` → `rounded-card`, `--shadow-card` → `shadow-card` 유틸리티를 자동 생성한다.

- [ ] **Step 1: globals.css를 토큰 정의로 교체**

기존 파일(`--background`/`--foreground`/`prefers-color-scheme: dark`/Arial body) 전체를 아래로 대체. **hex 값은 6장 시안에서 추출한 실제 값으로 채운다**(아래는 이름과 역할을 고정한 골격 — 값은 근사 추출값, PR 리뷰에서 미세 조정).

```css
@import "tailwindcss";

@theme {
  /* 브랜드 */
  --color-primary: #2f63ff;       /* CTA·선택 상태 (값=시안 추출) */
  --color-primary-fg: #ffffff;    /* primary 위 텍스트 */
  --color-accent: #ff7a2f;        /* 스트릭·긴급 */
  /* OX 시맨틱 (quiz-types-board.png) */
  --color-ox-o: #22c55e;
  --color-ox-x: #ef4444;
  /* 피드백 시맨틱 */
  --color-success: #16a34a;
  --color-danger: #ef4444;
  --color-warning: #f59e0b;
  --color-info: #2f63ff;
  /* 뉴트럴 */
  --color-bg: #f4f7fb;            /* 페이지 배경 */
  --color-surface: #ffffff;       /* 흰 카드 */
  --color-surface-muted: #eef2f8; /* 연한 카드 */
  --color-ink: #0f172a;           /* 본문 (대비 AA↑ 확인) */
  --color-ink-muted: #64748b;     /* 보조 텍스트 */
  --color-border: #e2e8f0;

  /* radius */
  --radius-card: 2rem;
  --radius-control: 1rem;
  --radius-chip: 9999px;

  /* 그림자 */
  --shadow-card: 0 24px 60px rgba(15, 23, 42, 0.10);
  --shadow-hero: 0 24px 48px rgba(47, 99, 255, 0.24);

  /* 폰트 */
  --font-sans: var(--font-pretendard), ui-sans-serif, system-ui, sans-serif;
  --font-mono: var(--font-geist-mono), ui-monospace, monospace;
}

body {
  background: var(--color-bg);
  color: var(--color-ink);
  font-family: var(--font-sans);
}
```

`--color-ink`(본문)이 `--color-bg`·`--color-surface` 위에서 대비 4.5:1 이상인지 확인(안 되면 ink를 더 어둡게).

- [ ] **Step 2: Pretendard 폰트 적용 (layout.tsx)**

기본안 = `next/font/local`. `app/src/app/fonts/PretendardVariable.woff2`를 추가(출처: `https://github.com/orioncactus/pretendard` 릴리스의 `PretendardVariable.woff2`). layout.tsx를 교체:

```tsx
import type { Metadata } from "next";
import localFont from "next/font/local";
import { Geist_Mono } from "next/font/google";
import "./globals.css";

const pretendard = localFont({
  src: "./fonts/PretendardVariable.woff2",
  variable: "--font-pretendard",
  display: "swap",
  weight: "45 920",
});

const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Thumbs Up",
  description: "개발자 학습 앱",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko" className={`${pretendard.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
```

**폴백**(woff2 바이너리를 추가 못 할 때): `localFont`/fonts 파일 대신 `import { Noto_Sans_KR } from "next/font/google"` 사용, `variable: "--font-pretendard"` 그대로 두면 globals.css 변경 불필요. 어느 쪽이든 `--font-pretendard` 변수명은 유지.

- [ ] **Step 3: 빌드로 검증**

Run: `pnpm build`
Expected: 성공. 폰트·CSS 에러 없음.

- [ ] **Step 4: 커밋**

```bash
git add app/src/app/globals.css app/src/app/layout.tsx app/src/app/fonts
git commit -m "feat(app): 디자인 토큰·폰트 정의 (#38)"
```

**Acceptance:** `bg-primary`·`rounded-card`·`shadow-hero`·`font-mono` 유틸리티가 빌드에서 유효. body가 Pretendard·라이트 배경. dark 분기 제거됨.

---

## Task 3: check-design 정적 스캐너 (게이트 ②, TDD)

토큰 미준수(raw hex·arbitrary value)와 스토리 누락을 검출하는 순수 로직 + 테스트. Node 내장 러너로 TDD(신규 의존성 0).

**Files:**
- Create: `app/scripts/check-design.mjs`
- Test: `app/scripts/check-design.test.mjs`

**Interfaces:**
- Produces: `findStyleViolations(source: string, file: string) => {file,line,kind,text}[]`, `findMissingStories(uiFileNames: string[]) => {component,expected}[]`. CLI 진입점은 `app/`에서 `src`를 스캔하고 위반 시 `process.exit(1)`.

- [ ] **Step 1: 실패하는 테스트 작성**

`app/scripts/check-design.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { findStyleViolations, findMissingStories } from "./check-design.mjs";

test("raw hex와 arbitrary value를 검출한다", () => {
  const v = findStyleViolations('<div className="bg-[#2f63ff] rounded-[36px]" />', "a.tsx");
  assert.ok(v.some((x) => x.kind === "arbitrary-value"), "arbitrary 검출");
  assert.ok(v.some((x) => x.kind === "raw-hex"), "hex 검출");
});

test("design-ok 주석이 있는 줄은 예외", () => {
  const v = findStyleViolations('const brand = "#2f63ff"; // design-ok', "a.tsx");
  assert.equal(v.length, 0);
});

test("토큰 유틸리티는 통과", () => {
  const v = findStyleViolations('<div className="bg-primary rounded-card text-ink" />', "a.tsx");
  assert.equal(v.length, 0);
});

test("스토리 없는 컴포넌트를 찾는다", () => {
  const missing = findMissingStories(["button.tsx", "card.tsx", "card.stories.tsx", "index.ts"]);
  assert.deepEqual(missing.map((m) => m.component), ["button.tsx"]);
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd app && node --test scripts/check-design.test.mjs`
Expected: FAIL — `check-design.mjs`가 없어 import 에러.

- [ ] **Step 3: check-design.mjs 구현**

`app/scripts/check-design.mjs`:

```js
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url)); // app/
const SRC = join(ROOT, "src");

// 색상 길이(3/4/6/8)의 raw hex
const HEX = /#[0-9a-fA-F]{8}\b|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{4}\b|#[0-9a-fA-F]{3}\b/;
// Tailwind arbitrary value: `something-[...]`
const ARBITRARY = /\b[a-z][a-z-]*-\[[^\]]+\]/;

export function findStyleViolations(source, file) {
  const out = [];
  source.split("\n").forEach((line, i) => {
    if (line.includes("design-ok")) return;
    const hex = line.match(HEX);
    if (hex) out.push({ file, line: i + 1, kind: "raw-hex", text: hex[0] });
    const arb = line.match(ARBITRARY);
    if (arb) out.push({ file, line: i + 1, kind: "arbitrary-value", text: arb[0] });
  });
  return out;
}

export function findMissingStories(uiFileNames) {
  const isComponent = (f) =>
    f.endsWith(".tsx") && !f.endsWith(".stories.tsx");
  const stories = new Set(uiFileNames.filter((f) => f.endsWith(".stories.tsx")));
  return uiFileNames
    .filter(isComponent)
    .filter((f) => !stories.has(f.replace(/\.tsx$/, ".stories.tsx")))
    .map((f) => ({ component: f, expected: f.replace(/\.tsx$/, ".stories.tsx") }));
}

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (/\.tsx?$/.test(name)) out.push(p);
  }
  return out;
}

function main() {
  const files = walk(SRC);
  const style = files.flatMap((f) => findStyleViolations(readFileSync(f, "utf8"), relative(ROOT, f)));

  let missing = [];
  try {
    missing = findMissingStories(readdirSync(join(SRC, "components", "ui")));
  } catch {
    /* components/ui 아직 없음 */
  }

  if (style.length === 0 && missing.length === 0) {
    console.log("✅ check-design: 위반 없음");
    return;
  }
  for (const v of style) console.error(`🔴 ${v.file}:${v.line} ${v.kind} → ${v.text}`);
  for (const m of missing) console.error(`🔴 components/ui/${m.component}: 스토리 누락 (${m.expected} 필요)`);
  console.error(`\n총 ${style.length + missing.length}건 — 토큰/컴포넌트 규칙 위반. // design-ok 로만 예외.`);
  process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd app && node --test scripts/check-design.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: 커밋**

```bash
git add app/scripts/check-design.mjs app/scripts/check-design.test.mjs
git commit -m "feat(app): 디자인 토큰 준수 검사 스크립트 (#38)"
```

**Acceptance:** 4개 테스트 통과. `node scripts/check-design.mjs`가 현재 src(위반 없음)에서 `✅` 출력.

---

## Task 4: check-design을 verify-app·CI에 연결

게이트 ②를 실제 파이프라인에 배선한다.

**Files:**
- Modify: `app/package.json` (scripts)
- Modify: `.claude/skills/verify-app/SKILL.md`
- Modify: `.github/workflows/app-ci.yml`

- [ ] **Step 1: package.json scripts 추가**

`scripts`에 두 줄 추가(기존 유지):

```json
    "check:design": "node scripts/check-design.mjs",
    "test:design": "node --test scripts/check-design.test.mjs"
```

- [ ] **Step 2: 고의 위반으로 게이트 작동 확인**

임시로 `app/src/app/page.tsx`의 최상위 요소에 `className="bg-[#123456]"`를 넣고:

Run: `cd app && pnpm check:design`
Expected: `🔴 src/app/page.tsx:… arbitrary-value → bg-[#123456]` 출력 + exit 1.
확인 후 임시 변경 되돌린다. Run 재실행 → `✅`.

- [ ] **Step 3: verify-app 스킬에 4번 게이트 추가**

`.claude/skills/verify-app/SKILL.md`의 명령 블록을 아래로 교체:

```bash
cd app
pnpm typecheck   # 1. 타입 에러 0개
pnpm lint        # 2. 실패 시 pnpm lint:fix 후 재확인 (수정 diff 검토 필수)
pnpm build       # 3. 프로덕션 빌드 성공
pnpm check:design # 4. 토큰·스토리 규칙 위반 0건
```

"규칙" 목록에 한 줄 추가: `- check:design 위반(하드코딩 hex·arbitrary value·스토리 누락)이 있으면 완료 아님. 예외는 // design-ok 주석으로만.`

- [ ] **Step 4: app-ci.yml에 스텝 추가**

`gate` job의 `- run: pnpm build` 다음에 두 줄 추가:

```yaml
      - run: pnpm check:design
      - run: pnpm test:design
```

- [ ] **Step 5: 커밋**

```bash
git add app/package.json .claude/skills/verify-app/SKILL.md .github/workflows/app-ci.yml
git commit -m "chore(app): check-design을 verify-app·CI 게이트에 연결 (#38)"
```

**Acceptance:** `pnpm check:design`·`pnpm test:design` 동작. Step 2에서 위반이 실제 검출됨(스펙 완료기준 "고의 위반 테스트"). CI에 스텝 존재.

---

## Task 5: Storybook 셋업 + 토큰 MDX 문서

카탈로그 도구. devDependency만 추가.

**Files:**
- Create: `.storybook/main.ts`, `.storybook/preview.ts` (init 산출물, 수정)
- Modify: `app/package.json` (init이 scripts·devDeps 추가)
- Create: `app/src/components/ui/tokens.mdx`
- Delete: init이 만든 샘플 `src/stories/` 디렉터리

- [ ] **Step 1: Storybook init**

Run(app에서): `pnpm dlx storybook@latest init --yes`
`@storybook/nextjs-vite` 프레임워크 선택됨(Next 감지). devDeps·`storybook`/`build-storybook` scripts·`.storybook/`·샘플 스토리 생성.

- [ ] **Step 2: preview에서 globals.css import + 라이트 배경**

`.storybook/preview.ts`(또는 `.tsx`)에 앱 토큰을 주입:

```ts
import type { Preview } from "@storybook/nextjs-vite";
import "../src/app/globals.css";

const preview: Preview = {
  parameters: {
    backgrounds: { default: "app", values: [{ name: "app", value: "#f4f7fb" }] },
  },
};

export default preview;
```

(배경 hex는 `--color-bg`와 동일 — Storybook 설정 파일은 앱 소스가 아니므로 check-design 스캔 대상 밖. 스캔 범위는 `src/`.)

- [ ] **Step 3: stories glob 정리 + 샘플 삭제**

`.storybook/main.ts`의 `stories`를 `["../src/**/*.mdx", "../src/**/*.stories.@(ts|tsx)"]`로. init이 만든 `app/src/stories/` 샘플 디렉터리 삭제.

- [ ] **Step 4: 토큰 MDX 문서**

`app/src/components/ui/tokens.mdx` — 팀원이 코드 없이 브라우징하는 진입점. 컬러 스와치·radius·그림자를 토큰 유틸리티로 렌더:

```mdx
import { Meta } from "@storybook/addon-docs/blocks";

<Meta title="디자인/토큰" />

# 디자인 토큰

앱 스타일은 전부 이 토큰 이름으로만 참조한다. 값은 `src/app/globals.css`의 `@theme`.

## 컬러
<div className="flex flex-wrap gap-3">
  <div className="rounded-control bg-primary text-primary-fg p-4">primary</div>
  <div className="rounded-control bg-accent text-primary-fg p-4">accent</div>
  <div className="rounded-control bg-ox-o text-primary-fg p-4">ox-o</div>
  <div className="rounded-control bg-ox-x text-primary-fg p-4">ox-x</div>
  <div className="rounded-control bg-surface-muted text-ink p-4 border border-border">surface-muted</div>
</div>

## Radius
<div className="flex gap-3">
  <div className="rounded-card bg-surface border border-border p-6">card</div>
  <div className="rounded-control bg-surface border border-border p-6">control</div>
  <div className="rounded-chip bg-surface border border-border px-4 py-2">chip</div>
</div>

## 그림자
<div className="flex gap-6">
  <div className="rounded-card bg-surface shadow-card p-6">shadow-card</div>
  <div className="rounded-card bg-primary text-primary-fg shadow-hero p-6">shadow-hero</div>
</div>

## 룰
- arbitrary value(`bg-[#...]`)·raw hex 금지 — `check:design` 게이트가 차단
- 새 컴포넌트는 스토리 필수
- 색만으로 상태 구분 금지(아이콘·텍스트 병행)
```

- [ ] **Step 5: 기동 확인**

Run: `cd app && pnpm build-storybook`
Expected: 성공(스토리 빌드). `pnpm storybook`으로 로컬 확인 시 토큰 페이지 렌더.

- [ ] **Step 6: 커밋**

```bash
git add app/.storybook app/package.json app/pnpm-lock.yaml app/src/components/ui/tokens.mdx
git rm -r app/src/stories 2>/dev/null; git add -A app/src/stories
git commit -m "chore(app): Storybook 카탈로그·토큰 문서 도입 (#38)"
```

**Acceptance:** `pnpm build-storybook` 성공. Storybook devDeps만 추가(`dependencies` 불변). 토큰 MDX 렌더. 샘플 스토리 제거됨.

---

## Task 6: Button 컴포넌트 + 스토리

가장 복잡한 상호작용(loading 중 연타 차단) 포함 — 컴포넌트 패턴의 기준이 된다.

**Files:**
- Create: `app/src/components/ui/button.tsx`
- Create: `app/src/components/ui/button.stories.tsx`

**Interfaces:**
- Produces: `Button` — `variant: "primary" | "secondary" | "ghost"`(기본 primary), `loading?: boolean`, 그 외 `React.ComponentProps<"button">`. `loading` 시 `disabled`이며 클릭 무효(TC-38-10).

- [ ] **Step 1: button.tsx 구현 (토큰 클래스만)**

```tsx
import type { ComponentProps } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost";

const VARIANT: Record<ButtonVariant, string> = {
  primary: "bg-primary text-primary-fg",
  secondary: "bg-surface-muted text-ink",
  ghost: "bg-transparent text-ink",
};

type ButtonProps = ComponentProps<"button"> & {
  variant?: ButtonVariant;
  loading?: boolean;
};

export function Button({
  variant = "primary",
  loading = false,
  disabled,
  className = "",
  children,
  ...props
}: ButtonProps) {
  const isDisabled = disabled || loading;
  return (
    <button
      type="button"
      disabled={isDisabled}
      aria-busy={loading}
      className={`inline-flex min-h-12 items-center justify-center rounded-control px-4 py-3 text-base font-semibold transition-colors disabled:opacity-60 disabled:pointer-events-none ${VARIANT[variant]} ${className}`}
      {...props}
    >
      {loading ? "처리 중…" : children}
    </button>
  );
}
```

- [ ] **Step 2: button.stories.tsx — 전 variant·상태 열거**

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Button } from "./button";

const meta: Meta<typeof Button> = { title: "UI/Button", component: Button };
export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = { args: { children: "오늘의 문제 시작" } };
export const Secondary: Story = { args: { variant: "secondary", children: "다음 화" } };
export const Ghost: Story = { args: { variant: "ghost", children: "건너뛰기" } };
export const Loading: Story = { args: { loading: true, children: "정답 확인" } };
export const Disabled: Story = { args: { disabled: true, children: "정답 확인" } };
```

- [ ] **Step 3: 게이트 확인**

Run: `cd app && pnpm typecheck && pnpm check:design`
Expected: 통과(스토리 존재 → 누락 없음, 토큰 클래스 → 위반 없음).

- [ ] **Step 4: 커밋**

```bash
git add app/src/components/ui/button.tsx app/src/components/ui/button.stories.tsx
git commit -m "feat(app): Button 공통 컴포넌트 (#38)"
```

**Acceptance:** `loading`이면 `disabled` + `pointer-events-none`로 클릭 무효. 5개 스토리 렌더. check:design 통과.

---

## Task 7: Card · Chip 컴포넌트 + 스토리

**Files:**
- Create: `app/src/components/ui/card.tsx`, `app/src/components/ui/card.stories.tsx`
- Create: `app/src/components/ui/chip.tsx`, `app/src/components/ui/chip.stories.tsx`

**Interfaces:**
- Produces: `Card` — `variant: "surface" | "hero"`(기본 surface), `React.ComponentProps<"div">`. `Chip` — `tone?: "neutral" | "primary" | "success" | "danger"`(기본 neutral), `React.ComponentProps<"span">`.

- [ ] **Step 1: card.tsx**

```tsx
import type { ComponentProps } from "react";

type CardVariant = "surface" | "hero";

const VARIANT: Record<CardVariant, string> = {
  surface: "bg-surface text-ink shadow-card border border-border",
  hero: "bg-primary text-primary-fg shadow-hero",
};

type CardProps = ComponentProps<"div"> & { variant?: CardVariant };

export function Card({ variant = "surface", className = "", ...props }: CardProps) {
  return <div className={`rounded-card p-5 ${VARIANT[variant]} ${className}`} {...props} />;
}
```

- [ ] **Step 2: chip.tsx**

```tsx
import type { ComponentProps } from "react";

type ChipTone = "neutral" | "primary" | "success" | "danger";

const TONE: Record<ChipTone, string> = {
  neutral: "bg-surface-muted text-ink-muted",
  primary: "bg-primary text-primary-fg",
  success: "bg-success text-primary-fg",
  danger: "bg-danger text-primary-fg",
};

type ChipProps = ComponentProps<"span"> & { tone?: ChipTone };

export function Chip({ tone = "neutral", className = "", ...props }: ChipProps) {
  return (
    <span
      className={`inline-flex items-center rounded-chip px-3 py-1 text-xs font-semibold ${TONE[tone]} ${className}`}
      {...props}
    />
  );
}
```

- [ ] **Step 3: 스토리 2개**

`card.stories.tsx`:

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Card } from "./card";

const meta: Meta<typeof Card> = { title: "UI/Card", component: Card };
export default meta;
type Story = StoryObj<typeof Card>;

export const Surface: Story = { args: { children: "오늘의 학습 카드" } };
export const Hero: Story = { args: { variant: "hero", children: "TCP와 UDP의 차이" } };
```

`chip.stories.tsx`:

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Chip } from "./chip";

const meta: Meta<typeof Chip> = { title: "UI/Chip", component: Chip };
export default meta;
type Story = StoryObj<typeof Chip>;

export const Neutral: Story = { args: { children: "자료구조" } };
export const Primary: Story = { args: { tone: "primary", children: "네트워크" } };
export const Success: Story = { args: { tone: "success", children: "정답" } };
```

- [ ] **Step 4: 게이트 + 커밋**

```bash
cd app && pnpm typecheck && pnpm check:design
git add app/src/components/ui/card.tsx app/src/components/ui/card.stories.tsx app/src/components/ui/chip.tsx app/src/components/ui/chip.stories.tsx
git commit -m "feat(app): Card·Chip 공통 컴포넌트 (#38)"
```

**Acceptance:** 두 컴포넌트 + 스토리. check:design 통과.

---

## Task 8: BottomTabBar 컴포넌트 + 스토리

홈의 기존 탭바를 재사용 가능한 컴포넌트로 승격(레퍼런스: `home-today.png` 4탭, `today-streak-recovery.png` 3탭).

**Files:**
- Create: `app/src/components/ui/bottom-tab-bar.tsx`, `app/src/components/ui/bottom-tab-bar.stories.tsx`

**Interfaces:**
- Produces: `BottomTabBar` — `tabs: { key: string; label: string; active?: boolean; onSelect?: () => void }[]`. `nav[aria-label]` 래핑, 활성 탭은 `aria-current="page"`.

- [ ] **Step 1: bottom-tab-bar.tsx**

```tsx
type Tab = { key: string; label: string; active?: boolean; onSelect?: () => void };

export function BottomTabBar({ tabs, ariaLabel = "하단 탭" }: { tabs: Tab[]; ariaLabel?: string }) {
  return (
    <nav
      aria-label={ariaLabel}
      className="sticky bottom-0 flex gap-2 rounded-card border border-border bg-surface p-2 shadow-card"
    >
      {tabs.map((tab) =>
        tab.active ? (
          <span
            key={tab.key}
            aria-current="page"
            className="flex min-h-12 flex-1 items-center justify-center rounded-control bg-primary px-3 py-3 text-sm font-semibold text-primary-fg"
          >
            {tab.label}
          </span>
        ) : (
          <button
            key={tab.key}
            type="button"
            onClick={tab.onSelect}
            className="flex min-h-12 flex-1 items-center justify-center rounded-control bg-surface-muted px-3 py-3 text-sm font-medium text-ink-muted transition-colors"
          >
            {tab.label}
          </button>
        ),
      )}
    </nav>
  );
}
```

- [ ] **Step 2: bottom-tab-bar.stories.tsx**

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { BottomTabBar } from "./bottom-tab-bar";

const meta: Meta<typeof BottomTabBar> = { title: "UI/BottomTabBar", component: BottomTabBar };
export default meta;
type Story = StoryObj<typeof BottomTabBar>;

export const FourTabs: Story = {
  args: {
    tabs: [
      { key: "today", label: "투데이", active: true },
      { key: "course", label: "코스" },
      { key: "atlas", label: "아틀라스" },
      { key: "basecamp", label: "베이스캠프" },
    ],
  },
};
```

- [ ] **Step 3: 게이트 + 커밋**

```bash
cd app && pnpm typecheck && pnpm check:design
git add app/src/components/ui/bottom-tab-bar.tsx app/src/components/ui/bottom-tab-bar.stories.tsx
git commit -m "feat(app): BottomTabBar 공통 컴포넌트 (#38)"
```

**Acceptance:** 활성 탭 `aria-current`, 비활성 탭은 버튼. 터치 타깃 `min-h-12`. check:design 통과.

---

## Task 9: Feedback 컴포넌트 + 스토리

mock 화면 통일 안내(TC-38-17~19). 색만으로 구분하지 않도록 아이콘 문자 병행.

**Files:**
- Create: `app/src/components/ui/feedback.tsx`, `app/src/components/ui/feedback.stories.tsx`

**Interfaces:**
- Produces: `Feedback` — `tone: "info" | "pending" | "error" | "success"`(기본 info), `onRetry?: () => void`(error일 때 재시도 버튼 노출), children=메시지. `role="status"` + `aria-live="polite"`(정답/에러 낭독, TC-38-27).

- [ ] **Step 1: feedback.tsx**

```tsx
import type { ReactNode } from "react";
import { Button } from "./button";

type FeedbackTone = "info" | "pending" | "error" | "success";

const TONE: Record<FeedbackTone, { box: string; mark: string }> = {
  info: { box: "bg-surface-muted text-ink", mark: "ℹ" },
  pending: { box: "bg-surface-muted text-ink-muted", mark: "⏳" },
  error: { box: "bg-danger/10 text-danger", mark: "⚠" },
  success: { box: "bg-success/10 text-success", mark: "✓" },
};

export function Feedback({
  tone = "info",
  onRetry,
  children,
}: {
  tone?: FeedbackTone;
  onRetry?: () => void;
  children: ReactNode;
}) {
  const t = TONE[tone];
  return (
    <div
      role="status"
      aria-live="polite"
      className={`flex items-center gap-3 rounded-control px-4 py-3 text-sm font-medium ${t.box}`}
    >
      <span aria-hidden="true">{t.mark}</span>
      <span className="flex-1">{children}</span>
      {tone === "error" && onRetry ? (
        <Button variant="ghost" onClick={onRetry} className="min-h-0 px-2 py-1 text-sm">
          재시도
        </Button>
      ) : null}
    </div>
  );
}
```

`bg-danger/10`·`bg-success/10`은 토큰 색의 투명도 변형(arbitrary value 아님, check:design 통과). `text-danger`/`text-success`가 각 배경 위에서 대비 AA를 만족하는지 확인(안 되면 더 진한 ink 계열 텍스트).

- [ ] **Step 2: feedback.stories.tsx**

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Feedback } from "./feedback";

const meta: Meta<typeof Feedback> = { title: "UI/Feedback", component: Feedback };
export default meta;
type Story = StoryObj<typeof Feedback>;

export const Info: Story = { args: { children: "오늘의 목표 10문제 중 4문제 완료" } };
export const Pending: Story = { args: { tone: "pending", children: "히스토리는 준비 중입니다." } };
export const Success: Story = { args: { tone: "success", children: "정답이에요! +10P" } };
export const Error: Story = { args: { tone: "error", children: "불러오지 못했어요.", onRetry: () => {} } };
```

- [ ] **Step 3: 게이트 + 커밋**

```bash
cd app && pnpm typecheck && pnpm check:design
git add app/src/components/ui/feedback.tsx app/src/components/ui/feedback.stories.tsx
git commit -m "feat(app): Feedback 공통 컴포넌트 (#38)"
```

**Acceptance:** 4 tone. error+onRetry에 재시도 버튼. `aria-live`. 색+마크 병행. check:design 통과.

---

## Task 10: Progress · Skeleton · EmptyState + 스토리

간단한 표시 컴포넌트 3종(TC-38-15·20, 퀴즈 진행바).

**Files:**
- Create: `app/src/components/ui/progress.tsx` (+ `.stories.tsx`)
- Create: `app/src/components/ui/skeleton.tsx` (+ `.stories.tsx`)
- Create: `app/src/components/ui/empty-state.tsx` (+ `.stories.tsx`)

**Interfaces:**
- Produces: `Progress` — `value: number`, `max?: number`(기본 10), `role="progressbar"` + aria 값. `Skeleton` — `React.ComponentProps<"div">`(펄스 플레이스홀더). `EmptyState` — `title: string`, `description?: string`, `action?: ReactNode`.

- [ ] **Step 1: progress.tsx**

```tsx
export function Progress({ value, max = 10, label = "진행률" }: { value: number; max?: number; label?: string }) {
  const pct = Math.min(100, Math.max(0, (value / max) * 100));
  return (
    <div
      role="progressbar"
      aria-valuenow={value}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-label={label}
      className="h-2 w-full overflow-hidden rounded-chip bg-surface-muted"
    >
      <div className="h-full rounded-chip bg-primary transition-[width]" style={{ width: `${pct}%` }} />
    </div>
  );
}
```

`style={{ width }}`는 동적 값이라 인라인 스타일이 정당(arbitrary Tailwind 클래스 아님) — check:design은 className만 스캔하므로 통과.

- [ ] **Step 2: skeleton.tsx**

```tsx
import type { ComponentProps } from "react";

export function Skeleton({ className = "", ...props }: ComponentProps<"div">) {
  return (
    <div
      aria-hidden="true"
      className={`motion-safe:animate-pulse rounded-control bg-surface-muted ${className}`}
      {...props}
    />
  );
}
```

`motion-safe:` 접두사로 `prefers-reduced-motion` 자동 대응(Global Constraints).

- [ ] **Step 3: empty-state.tsx**

```tsx
import type { ReactNode } from "react";

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-card border border-border bg-surface px-6 py-10 text-center">
      <p className="text-base font-semibold text-ink">{title}</p>
      {description ? <p className="text-sm text-ink-muted">{description}</p> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}
```

- [ ] **Step 4: 스토리 3개**

`progress.stories.tsx`:

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Progress } from "./progress";
const meta: Meta<typeof Progress> = { title: "UI/Progress", component: Progress };
export default meta;
export const Half: StoryObj<typeof Progress> = { args: { value: 4, max: 10 } };
```

`skeleton.stories.tsx`:

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Skeleton } from "./skeleton";
const meta: Meta<typeof Skeleton> = { title: "UI/Skeleton", component: Skeleton };
export default meta;
export const Card: StoryObj<typeof Skeleton> = { args: { className: "h-24 w-full" } };
```

`empty-state.stories.tsx`:

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { EmptyState } from "./empty-state";
const meta: Meta<typeof EmptyState> = { title: "UI/EmptyState", component: EmptyState };
export default meta;
export const NoData: StoryObj<typeof EmptyState> = {
  args: { title: "오늘의 학습이 없어요", description: "새 코스를 골라보세요." },
};
```

- [ ] **Step 5: 게이트 + 커밋**

```bash
cd app && pnpm typecheck && pnpm check:design
git add app/src/components/ui/progress.tsx app/src/components/ui/progress.stories.tsx app/src/components/ui/skeleton.tsx app/src/components/ui/skeleton.stories.tsx app/src/components/ui/empty-state.tsx app/src/components/ui/empty-state.stories.tsx
git commit -m "feat(app): Progress·Skeleton·EmptyState 공통 컴포넌트 (#38)"
```

**Acceptance:** 3 컴포넌트 + 3 스토리. Progress `role=progressbar`+aria, Skeleton `motion-safe`, EmptyState 구조. check:design 통과.

---

## Task 11: design-system 프로젝트 스킬 (게이트 ①)

에이전트가 UI 작업 전 로드하는 규칙. 팀원 세션도 자동 수신.

**Files:**
- Create: `.claude/skills/design-system/SKILL.md`
- Modify: `app/CLAUDE.md`

- [ ] **Step 1: SKILL.md 작성**

`.claude/skills/design-system/SKILL.md`:

```markdown
---
name: design-system
description: app UI(화면·컴포넌트·스타일)를 만들거나 고칠 때 반드시 로드. 디자인 토큰·공통 컴포넌트 사용 규칙과 하네스를 강제한다. 사용자가 "화면 만들어", "컴포넌트 추가", "스타일 바꿔"라고 할 때도 트리거.
---

# design-system — 떰즈업 디자인 규약

UI 작업 전 이 규칙을 따른다. 상세는 `app/DESIGN.md`, 토큰은 `app/src/app/globals.css`, 카탈로그는 `pnpm storybook`.

## 규칙
- **토큰만 사용.** `bg-primary`·`rounded-card`·`shadow-hero`·`text-ink` 등 이름 유틸리티로만. `bg-[#...]`·`rounded-[36px]`·raw hex 금지.
- **새 스타일이 필요하면 토큰을 먼저 추가.** globals.css `@theme`에 이름을 정의하고 그 이름을 쓴다.
- **컴포넌트는 components/ui에서.** 화면은 `src/components/ui/`의 Button·Card·Chip·BottomTabBar·Feedback·Progress·Skeleton·EmptyState를 조립. 없는 것만 새로 만들되, **만들면 `<name>.stories.tsx`를 함께** 작성(게이트가 강제).
- **시안에 없는 상태**(에러·빈·로딩·오프라인·"준비중")는 감으로 짓지 말고 `lazyweb-quick-search`로 실서비스 레퍼런스 확보 후 디자인.
- **접근성**: 터치 타깃 ≥44px, 본문 대비 ≥4.5:1, 색만으로 상태 구분 금지(아이콘·텍스트 병행), 모션은 `motion-safe:`/`prefers-reduced-motion` 대응.
- **불가피한 예외**: 그 한 줄에 `// design-ok` 주석.

## 완료 전
`verify-app` 게이트(typecheck·lint·build·check:design)를 통과. UI를 바꿨으면 `visual-qa`도.
```

- [ ] **Step 2: app/CLAUDE.md 규약 교체**

`app/CLAUDE.md`의 스타일 조항을 교체:
- 기존: `- 스타일은 Tailwind 유틸리티 우선. **@theme 커스텀 토큰·공통 컴포넌트 도입 금지** — 디자인 시스템은 #38에서 설계한다`
- 변경: `- **UI 작업 시 design-system 스킬 필수 로드.** 스타일은 globals.css @theme 토큰·src/components/ui 컴포넌트만 사용(arbitrary value·raw hex 금지, check:design 게이트가 강제)`

"완료 기준" 절에 `check:design`이 verify-app에 포함됨을 반영(이미 Task 4에서 스킬 갱신됨 — 여기선 CLAUDE.md 문구만).

- [ ] **Step 3: 커밋**

```bash
git add .claude/skills/design-system/SKILL.md app/CLAUDE.md
git commit -m "docs(app): design-system 스킬 신설·CLAUDE.md 규약 전환 (#38)"
```

**Acceptance:** 스킬 파일 존재. app/CLAUDE.md의 "#38 전까지 금지" 조항이 "스킬 필수 로드"로 교체됨.

---

## Task 12: CodeRabbit app/** 지침에 디자인 룰 추가 (보조)

**Files:**
- Modify: `.coderabbit.yaml`

- [ ] **Step 1: app/** path_instructions에 한 줄 추가**

`.coderabbit.yaml`의 `path: 'app/**'` instructions의 "우선적으로 리뷰" 목록에 추가:

```
        - 디자인 토큰 준수 (globals.css @theme 이름만 사용, arbitrary value·raw hex 금지)
        - src/components/ui 공통 컴포넌트 재사용 (중복 구현 지양)
```

- [ ] **Step 2: 커밋**

```bash
git add .coderabbit.yaml
git commit -m "chore: CodeRabbit app 리뷰 지침에 디자인 룰 추가 (#38)"
```

**Acceptance:** yaml 유효(들여쓰기 유지). app/** 지침에 토큰·컴포넌트 항목 존재.

---

## Task 13: visual-qa 시안 대조 코드 (활성화는 Task 16)

시안 대조 모드로 전환하는 코드 변경. **키 없이도 안전**(soft skip). CI 리뷰 활성화는 엔드포인트 확보 후 Task 16.

**Files:**
- Modify: `app/e2e/qa-routes.ts`
- Modify: `app/e2e/visual-qa.ts`
- Create: `app/e2e/designs/home.png` (또는 심링크/복사)

**Interfaces:**
- Consumes: `docs/design/references/home-today.png`(홈 시안). `qa-routes.ts`의 `design` 필드.

- [ ] **Step 1: 홈 시안을 e2e/designs로 복사**

```bash
mkdir -p app/e2e/designs
cp docs/design/references/home-today.png app/e2e/designs/home.png
```

(`visual-qa.ts`의 `design` 경로는 app/ 기준 상대. `docs/`는 app 밖이라 복사한다.)

- [ ] **Step 2: qa-routes.ts에서 홈을 시안 대조로**

```ts
export const qaRoutes: QaRoute[] = [
  { path: "/", design: "e2e/designs/home.png" },
];
```

- [ ] **Step 3: visual-qa.ts에 .env.local 자동 로드 + 기본 모델 갱신**

파일 상단 import 아래에 추가(Node 22 `process.loadEnvFile`, 파일 없으면 무시):

```ts
try {
  process.loadEnvFile(".env.local");
} catch {
  /* .env.local 없음 — CI에서는 env로 주입됨 */
}
```

그리고 기본 모델을 발급 모델로 교체:

```ts
const model = process.env.ELICE_QA_MODEL || "google/gemini-3.1-pro-preview";
```

- [ ] **Step 4: soft skip 동작 확인 (키 없이)**

Run: `cd app && pnpm build && QA_TARGET_URL=http://localhost:3000 pnpm qa:visual`
(dev 서버 미기동이면 캡처에서 에러 후 soft-fail exit 0 — 리포트 미생성. Playwright 미설치면 설치 후 재시도: `pnpm exec playwright install chromium`.)
Expected: 크래시 없이 종료(soft gate). 키가 없으므로 리뷰는 스킵.

- [ ] **Step 5: 커밋**

```bash
git add app/e2e/qa-routes.ts app/e2e/visual-qa.ts app/e2e/designs
git commit -m "feat(app): 시각 QA 홈 시안 대조 모드·env 자동 로드 (#38)"
```

**Acceptance:** 홈 라우트가 `design` 지정됨. 키 없이 실행해도 soft skip. 기본 모델 = gemini.

---

## Task 14 ⛔ BLOCKED(#85 머지): 홈 화면 retrofit

**선행 조건: PR #85가 main에 머지되어야 함.** 미머지 상태면 여기서 중단하고 Task 15로.

**Files:**
- Modify(rebase 후): `app/src/features/home/components/*.tsx`, `app/src/app/page.tsx`

**Interfaces:**
- Consumes: `src/components/ui/*` (Task 6–10), 토큰(Task 2).

- [ ] **Step 1: #85 머지 확인 후 rebase**

```bash
gh pr view 85 --repo thumbsup-studio/thumbsup --json state   # "MERGED" 확인
git -C ~/DEV/thumbsup__worktrees/feat-38-design-system fetch origin main
git rebase origin/main
```

충돌 예상 파일: `app/package.json`·`app/pnpm-lock.yaml`(양쪽 devDeps 추가 — 둘 다 유지), `app/src/app/page.tsx`(retrofit 대상 — 다음 스텝에서 재작성). 충돌 해소 후 `pnpm install`.

- [ ] **Step 2: 홈 컴포넌트를 토큰·공통 컴포넌트로 재조립**

`features/home/components/*`의 arbitrary value(`bg-[#f4f7fb]`·`rounded-[36px]`·`shadow-[...]` 등)를 토큰으로, 인라인 버튼·카드·탭바를 `components/ui`의 `Button`·`Card`·`BottomTabBar`로 치환. **동작·접근성 구조는 유지**(시각만 변경). 예: `today-course-card.tsx`의 `<section className="rounded-[32px] bg-[linear-gradient(...)]">` → `<Card variant="hero">`, 내부 CTA → `<Button variant="secondary">`.

- [ ] **Step 3: 기존 홈 테스트 통과 확인 (vitest는 #85로 유입됨)**

Run: `cd app && pnpm test` (또는 #85가 등록한 스크립트)
Expected: 기존 홈 테스트 PASS(동작 불변).

- [ ] **Step 4: 게이트 — 홈에서 check:design 통과**

Run: `cd app && pnpm check:design`
Expected: `✅` — 홈의 하드코딩이 전부 토큰으로 치환되어 위반 0.

- [ ] **Step 5: 커밋**

```bash
git add app/src/features/home app/src/app/page.tsx
git commit -m "refactor(app): 홈 화면을 디자인 토큰·공통 컴포넌트로 재조립 (#38)"
```

**Acceptance:** 홈이 토큰·ui 컴포넌트만으로 렌더. 홈 vitest 통과. check:design이 홈에서 위반 0(실제 검증). #38 완료기준 4항 충족.

---

## Task 15: 최종 게이트 + PR

**Files:** 없음(검증·PR)

- [ ] **Step 1: 전체 verify-app 게이트**

Run: `cd app && pnpm typecheck && pnpm lint && pnpm build && pnpm check:design && pnpm test:design`
Expected: 전부 통과.

- [ ] **Step 2: Storybook 빌드 확인**

Run: `cd app && pnpm build-storybook`
Expected: 성공. 전 ui 컴포넌트 스토리 + 토큰 MDX 포함.

- [ ] **Step 3: PR 생성 (`pr` 스킬 사용)**

`pr` 스킬로 PR 작성. 본문에 `Closes #38`. 시각 QA CI 리뷰는 엔드포인트 등록(Task 16) 후 활성화됨을 명시.
(#85 미머지로 Task 14를 건너뛴 경우: PR 본문에 "홈 retrofit은 #85 머지 후 후속"이라 명시하고, #38 완료기준 4항은 후속으로 표시.)

**Acceptance:** 5개 게이트 통과. Storybook 빌드 성공. PR 오픈, Closes #38.

---

## Task 16 ⛔ BLOCKED(엘리스 Gemini 엔드포인트): 시각 QA CI 활성화

**선행 조건: 엘리스 스프린트 운영진의 Gemini 3.1 Pro 실제 엔드포인트 URL(`https://mlapi.run/<ID>/v1`) 확보.** (문의 발송됨)

- [ ] **Step 1: GitHub Secret·Variable 등록**

`gh` 계정이 `kmjnnhyk`인지 확인 후(아니면 403):

```bash
gh secret set ELICE_API_KEY -R thumbsup-studio/thumbsup --body "<발급 키>"
gh secret set ELICE_QA_BASE_URL -R thumbsup-studio/thumbsup --body "<Gemini 엔드포인트, /v1까지>"
gh variable set ELICE_QA_MODEL -R thumbsup-studio/thumbsup --body "google/gemini-3.1-pro-preview"
```

(값은 셸 히스토리·로그에 남지 않게 `app/.env.local`을 `source`해서 `$ELICE_API_KEY` 형태로 주입하는 방식 권장.)

- [ ] **Step 2: 엔드포인트 스모크 (등록 전 로컬 검증)**

`app/.env.local`을 채우고:

```bash
cd app && curl -sS -X POST "$ELICE_QA_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $ELICE_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-3.1-pro-preview","messages":[{"role":"user","content":"ping"}]}' | head -c 400
```

Expected: 정상 JSON 응답(choices 포함). 404/401이면 엔드포인트·키 재확인.

- [ ] **Step 3: PR에서 CI visual-qa 리뷰 확인**

PR에 빈 커밋 push 또는 재실행으로 `app-deploy.yml`의 `visual-qa` job 트리거. PR에 sticky `visual-qa` 코멘트(홈 시안 대조 결과)가 달리는지 확인.

- [ ] **Step 4: 🔴 해소**

리포트의 🔴 항목(시안 대비 색·radius·간격 이탈)을 토큰·컴포넌트로 수정 후 재실행. 🟡은 판단 처리.

**Acceptance:** CI visual-qa가 Gemini로 홈 시안 대조 리포트를 PR에 게시. 🔴 0.

---

## Self-Review 결과

**스펙 커버리지:**
- §3.1 레퍼런스 → 이미 커밋됨(선행). §3.2 문서 → Task 1. §3.3 토큰·폰트 → Task 2.
- §4.1 컴포넌트 8종 → Task 6–10(Button/Card/Chip/BottomTabBar/Feedback/Progress/Skeleton/EmptyState). §4.2 품질 → Global Constraints + 각 Acceptance. §4.3 Storybook·MDX → Task 5.
- §5① 스킬 → Task 11. §5② check-design → Task 3·4. §5③ 시각 QA → Task 13(코드)·16(활성화). 보조(coderabbit) → Task 12.
- §6 홈 retrofit → Task 14. §7 순서 → 태스크 위상. §8 키 운영 → Task 16(+ 기 커밋된 .env.example). §10 완료기준 → Task 15·16 Acceptance.

**미해결/의존:**
- 홈 retrofit(§6)·완료기준 4항은 PR #85 머지에 의존(Task 14 blocked). #85 미머지 시 Task 1–13·15로 "디자인 시스템 파운데이션" PR을 먼저 낼 수 있음(화면 없이도 하네스·컴포넌트 검증됨).
- 시각 QA CI 리뷰(§5③ 활성화)는 엘리스 Gemini 엔드포인트에 의존(Task 16 blocked). 코드(Task 13)는 무관하게 완료 가능.

**타입 일관성:** 컴포넌트 API(variant/tone/props)는 각 태스크 Interfaces에 고정. 토큰 이름은 Task 2에서 확정 후 Task 5–14가 동일 이름 참조.

# PR1 (#33) — 앱 스캐폴딩 + 에이전트 워크스페이스 + @claude 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `app/`에 Next.js+Tailwind+Biome을 스캐폴딩하고, AI 에이전트(사람 보조·봇 모두)가 규약대로 작동하는 기반(CLAUDE.md·스킬·CI·@claude 봇)을 깐다.

**Architecture:** 모노레포에 `app/` 독립 pnpm 패키지를 추가. 에이전트 규약은 CLAUDE.md(+AGENTS.md 심링크) 2개와 레포 스킬로, 품질 게이트는 GitHub Actions CI로, 구현 위임은 `anthropics/claude-code-action`으로 구성.

**Tech Stack:** Next.js(App Router)·TypeScript(strict)·Tailwind CSS v4·Biome·pnpm 10·Node 22·GitHub Actions

**참조 스펙:** `docs/superpowers/specs/2026-07-07-frontend-infra-design.md`

## Global Constraints

- 작업 위치: 워크트리 `~/DEV/thumbsup__worktrees/chore/33-nextjs-tailwind-setup` (브랜치 `chore/33-nextjs-tailwind-setup`)
- main 직접 커밋 금지. 커밋은 레포 `commit` 스킬 형식: `<type>(<scope>): 한국어 요약 (#33)`
- 커밋 트레일러: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- Node 22 (`.nvmrc`), pnpm 10 (워크플로우 `version: 10`과 major 일치 필수)
- Linter/Formatter는 **Biome만** — ESLint·Prettier 도입 금지
- **#38 영역 금지**: `@theme` 커스텀 토큰, 공통 컴포넌트, 디자인 규약 문서를 만들지 않는다
- **#39 영역 금지**: API 명세 문서를 만들지 않는다
- 시크릿 이름 고정: `CLAUDE_CODE_OAUTH_TOKEN` (이번 PR에서 사용)
- **표기 규칙**: 이 계획서에서 파일 내용 안의 중첩 코드블록은 `​````(제로폭 문자 선행)로 표기했다 — 실제 파일에는 **일반 ```** 로 쓴다

---

### Task 1: Next.js 스캐폴딩 + Node 고정 + 로컬 개발 문서

**Files:**
- Create: `app/` (create-next-app 산출물 전체), `.nvmrc`
- Modify: `app/src/app/page.tsx` (플레이스홀더 홈), `app/README.md` (교체), `README.md` (로컬 개발 섹션 추가)

**Interfaces:**
- Produces: `app/package.json`의 `dev`/`build`/`start` 스크립트, `.nvmrc`(내용 `22`) — 이후 모든 태스크·워크플로우가 사용

- [ ] **Step 1: 도구 버전 확인**

```bash
cd ~/DEV/thumbsup__worktrees/chore/33-nextjs-tailwind-setup
node -v   # 기대: v22.x — 아니면: nvm install 22 && nvm use 22
pnpm -v   # 기대: 10.x — 아니면: corepack prepare pnpm@10 --activate (9.x면 워크플로우의 version도 9로 맞출 것)
```

- [ ] **Step 2: 스캐폴딩 실행**

```bash
pnpm create next-app@latest app --ts --tailwind --app --src-dir --import-alias "@/*" --use-pnpm --no-eslint --yes
```

기대: `app/` 생성, `pnpm install` 자동 실행. 기존 git 레포 내부라 git init은 자동 생략됨. 추가 프롬프트가 나오면 기본값 선택.

- [ ] **Step 3: 산출물 확인**

```bash
ls app/src/app/            # page.tsx, layout.tsx, globals.css 존재
grep -c tailwindcss app/package.json   # 1 이상 (v4 의존성)
test ! -e app/eslint.config.mjs && echo "ESLint 없음 OK"
```

- [ ] **Step 4: Node 버전 고정**

```bash
echo "22" > .nvmrc
```

`app/package.json`에 추가 (기존 키 유지, 최상위에 병합):

```json
{
  "engines": { "node": ">=22" }
}
```

- [ ] **Step 5: 플레이스홀더 홈으로 교체** (`app/src/app/page.tsx` 전체 교체 — Tailwind 적용 확인용 샘플 페이지, 이슈 acceptance)

```tsx
export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-slate-50 text-slate-900">
      <h1 className="text-4xl font-bold">Thumbs Up 👍</h1>
      <p className="text-sm text-slate-500">개발자 학습 앱 — 환경 세팅 완료 (#33)</p>
    </main>
  );
}
```

`app/src/app/layout.tsx`의 metadata를 수정 (title/description만):

```tsx
export const metadata: Metadata = {
  title: "Thumbs Up",
  description: "개발자 학습 앱",
};
```

- [ ] **Step 6: dev 서버 구동 검증** (이슈 acceptance)

```bash
cd app && pnpm dev &
sleep 8 && curl -s http://localhost:3000 | grep "Thumbs Up" && echo "OK"
kill %1
```

기대: `Thumbs Up` 포함 HTML 응답. 브라우저로 http://localhost:3000 열어 슬레이트 배경+중앙 정렬(Tailwind 적용) 눈으로 확인.

- [ ] **Step 7: app/README.md 교체** (전체 내용)

```markdown
# app — Thumbs Up 프론트엔드

Next.js(App Router) · TypeScript · Tailwind CSS v4 · Biome · pnpm

## 실행

​```bash
pnpm install
pnpm dev        # http://localhost:3000
​```

## 품질 게이트

​```bash
pnpm typecheck && pnpm lint && pnpm build
​```

규약은 [`CLAUDE.md`](./CLAUDE.md), 레포 공통 규약은 [루트 README](../README.md)·[CONTRIBUTING](../CONTRIBUTING.md) 참고.
```

- [ ] **Step 8: 루트 README.md에 로컬 개발 섹션 추가** — `## CodeRabbit 리뷰` 섹션 **앞**에 삽입:

```markdown
## 로컬 개발 (app)

사전 요구사항: Node 22 (`.nvmrc`, `nvm use`), pnpm 10 (`corepack enable`)

​```bash
cd app
pnpm install
pnpm dev   # http://localhost:3000
​```

품질 게이트(머지 전 필수): `pnpm typecheck && pnpm lint && pnpm build`
```

- [ ] **Step 9: 커밋**

```bash
git add app .nvmrc README.md
git commit -m "chore(app): Next.js + Tailwind 스캐폴딩 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Biome 도입

**Files:**
- Create: `app/biome.json`
- Modify: `app/package.json` (devDependency + scripts)

**Interfaces:**
- Produces: 스크립트 `typecheck`·`lint`·`lint:fix`·`lint:ci` — Task 5(verify-app)·Task 6(CI)이 이 이름을 그대로 사용

- [ ] **Step 1: 설치**

```bash
cd app && pnpm add -D -E @biomejs/biome
```

- [ ] **Step 2: `app/biome.json` 생성** (`pnpm biome init` 후 아래로 교체 — `$schema` 버전은 init이 생성한 값 유지)

```json
{
  "$schema": "./node_modules/@biomejs/biome/configuration_schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "files": { "includes": ["src/**", "e2e/**", "*.ts", "*.tsx", "*.json"] },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2, "lineWidth": 100 },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true },
    "domains": { "next": "recommended", "react": "recommended" }
  },
  "assist": { "actions": { "source": { "organizeImports": "on" } } }
}
```

주의: 설치된 Biome 메이저에 따라 `domains` 위치가 다르면 `pnpm biome migrate --write`로 스키마 정합 후, next/react 도메인이 적용되는지 `pnpm biome check src/`로 확인.

- [ ] **Step 3: package.json scripts 추가** (`app/package.json`의 scripts에 병합 — 기존 dev/build/start 유지)

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "lint:ci": "biome ci ."
  }
}
```

- [ ] **Step 4: 게이트 첫 통과** (스캐폴드 산출물은 Biome 기본 포맷과 다를 수 있음)

```bash
cd app && pnpm lint:fix && pnpm lint && pnpm typecheck && pnpm build
```

기대: 모두 exit 0. `lint:fix`가 파일을 수정했다면 diff 확인(포맷 변경만인지).

- [ ] **Step 5: 커밋**

```bash
git add app/biome.json app/package.json app/pnpm-lock.yaml app/src
git commit -m "chore(app): Biome 린터·포매터 적용 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: 에이전트 워크스페이스 규약 문서

**Files:**
- Create: `CLAUDE.md`, `AGENTS.md`(심링크), `app/CLAUDE.md`, `app/AGENTS.md`(심링크)

**Interfaces:**
- Consumes: Task 2의 스크립트 이름들
- Produces: 에이전트 규약 — Task 5·7의 스킬/봇이 참조하는 표준. `next-best-practices`·`verify-app` 스킬명 언급(Task 4·5에서 생성)

- [ ] **Step 1: 루트 `CLAUDE.md` 작성** (전체 내용)

```markdown
# Thumbs Up 모노레포 — 에이전트 규약

학습 앱 모노레포: `app/`(Next.js 프론트) · `server/`(Spring Boot 백엔드 — 예정) · `shared/`(공용 — 예정)

## 필수 규칙

- **main 직접 커밋 금지.** 브랜치: `<type>/<이슈번호>-<슬러그>` (예: `feat/12-like-button`)
- 커밋 전 **`commit` 스킬**, PR 생성 전 **`pr` 스킬** 사용 (형식 강제)
- 커밋 형식: `<type>(<scope>): <한국어 요약> (#이슈)` — scope: `app`|`server`|`shared`
- PR 본문에 `Closes #이슈` 필수, Squash merge
- `app/` 작업 시: [`app/CLAUDE.md`](./app/CLAUDE.md) 규약 + **`next-best-practices` 스킬 필수 로드**
- 작업 완료 보고 전: **`verify-app` 스킬**로 게이트 통과 (app 변경 시)

상세 규약: [CONTRIBUTING.md](./CONTRIBUTING.md)

## 명령어

​```bash
cd app && pnpm install && pnpm dev   # http://localhost:3000
cd app && pnpm typecheck && pnpm lint && pnpm build   # 품질 게이트
​```

## 구조 참고

- 이슈·라벨·마일스톤 규약: CONTRIBUTING.md §4~6
- PR 자동 리뷰: CodeRabbit (`.coderabbit.yaml`) — `app/**`·`server/**` 경로별 지침
- 사양 문서: `docs/superpowers/specs/`
```

- [ ] **Step 2: `app/CLAUDE.md` 작성** (전체 내용)

```markdown
# app — Next.js 프론트엔드 규약

스택: Next.js(App Router) · TypeScript strict · Tailwind CSS v4 · Biome · pnpm · Node 22

## 명령어

​```bash
pnpm dev         # 개발 서버 (http://localhost:3000)
pnpm typecheck   # tsc --noEmit
pnpm lint        # biome check (자동수정: pnpm lint:fix)
pnpm build       # 프로덕션 빌드
​```

## 코드 규약

- **Next.js 작업 전 `next-best-practices` 스킬을 반드시 로드**하고 그 지침을 따른다
- Server Component가 기본. `'use client'`는 상호작용이 필요한 최소 단위 컴포넌트에만
- import alias: `@/*` → `src/*`
- 스타일은 Tailwind 유틸리티 우선. **`@theme` 커스텀 토큰·공통 컴포넌트 도입 금지** — 디자인 시스템은 #38에서 설계한다
- API 클라이언트/명세 관련 코드 생성 금지 — #39 이후

## 완료 기준

- `verify-app` 스킬 게이트(typecheck → lint → build) 전부 통과 후에만 완료 보고
- 게이트 실패 상태로 커밋 금지
```

- [ ] **Step 3: AGENTS.md 심링크 생성** (Codex가 같은 규약을 읽도록 — 레포의 기존 `.codex/skills → .claude/skills` 패턴과 동일)

```bash
cd ~/DEV/thumbsup__worktrees/chore/33-nextjs-tailwind-setup
ln -s CLAUDE.md AGENTS.md
cd app && ln -s CLAUDE.md AGENTS.md && cd ..
```

- [ ] **Step 4: 검증**

```bash
cat AGENTS.md | head -1        # "# Thumbs Up 모노레포 — 에이전트 규약"
cat app/AGENTS.md | head -1    # "# app — Next.js 프론트엔드 규약"
```

- [ ] **Step 5: 커밋**

```bash
git add CLAUDE.md AGENTS.md app/CLAUDE.md app/AGENTS.md
git commit -m "docs: 에이전트 워크스페이스 규약 문서 추가 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: next-best-practices 스킬 vendoring

**Files:**
- Create: `.claude/skills/next-best-practices/` (Vercel 공식 스킬 vendoring)

**Interfaces:**
- Produces: `.claude/skills/next-best-practices/SKILL.md` — Task 3 문서가 이미 참조하는 스킬 실체

- [ ] **Step 1: 스킬 설치**

```bash
cd ~/DEV/thumbsup__worktrees/chore/33-nextjs-tailwind-setup
npx skills add https://github.com/vercel/nextjs-skills --skill next-best-practices
```

CLI가 설치 대상 에이전트를 물으면 **Claude Code**(`.claude/skills/`) 선택. 다른 경로(`.agents/skills/` 등)에 설치되면 `.claude/skills/next-best-practices`로 이동:

```bash
[ -d .agents/skills/next-best-practices ] && mv .agents/skills/next-best-practices .claude/skills/ && rmdir -p .agents/skills 2>/dev/null || true
```

- [ ] **Step 2: 검증**

```bash
test -f .claude/skills/next-best-practices/SKILL.md && head -5 .claude/skills/next-best-practices/SKILL.md
ls .codex/skills/   # 심링크 경유로 next-best-practices 노출 확인
```

- [ ] **Step 3: 커밋** (설치 부산물이 있으면 스킬 디렉터리만 선별 스테이징)

```bash
git add .claude/skills/next-best-practices
git status --short   # 스킬 외 변경이 없는지 확인 (있으면 원인 확인 후 제외)
git commit -m "chore: next-best-practices 스킬 vendoring (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: verify-app 스킬

**Files:**
- Create: `.claude/skills/verify-app/SKILL.md`

**Interfaces:**
- Consumes: Task 2 스크립트(`typecheck`·`lint`·`lint:fix`·`build`)
- Produces: `verify-app` 스킬 — Task 3 문서가 참조, 모든 에이전트의 완료 게이트

- [ ] **Step 1: SKILL.md 작성** (전체 내용)

```markdown
---
name: verify-app
description: app/ 코드 변경 후 검증 게이트. app을 수정한 작업을 완료 보고하거나 커밋하기 전 반드시 실행. 사용자가 "검증해", "게이트 돌려"라고 할 때도 트리거.
---

# verify-app — app 품질 게이트

`app/` 디렉터리에서 순서대로 실행. **하나라도 실패하면 수정 후 1번부터 재실행.**

​```bash
cd app
pnpm typecheck   # 1. 타입 에러 0개
pnpm lint        # 2. 실패 시 pnpm lint:fix 후 재확인 (수정 diff 검토 필수)
pnpm build       # 3. 프로덕션 빌드 성공
​```

## 규칙

- 세 게이트 전부 통과하기 전에는 "완료"라고 보고하지 않는다
- 게이트 실패 상태로 커밋하지 않는다
- `lint:fix`가 만든 변경은 diff를 눈으로 확인한다 (자동 변환이 의미를 바꿀 수 있음)
```

- [ ] **Step 2: 검증** — 스킬 절차를 실제로 1회 수행

```bash
cd app && pnpm typecheck && pnpm lint && pnpm build && echo "verify-app GATE OK"
```

기대: `verify-app GATE OK`

- [ ] **Step 3: 커밋**

```bash
git add .claude/skills/verify-app
git commit -m "chore: verify-app 검증 스킬 추가 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: CI 게이트 워크플로우

**Files:**
- Create: `.github/workflows/app-ci.yml`

**Interfaces:**
- Consumes: Task 2 스크립트, `.nvmrc`
- Produces: PR hard gate — PR2의 배포 워크플로우와 독립

- [ ] **Step 1: `app-ci.yml` 작성** (전체 내용)

```yaml
name: App CI

on:
  pull_request:
    paths:
      - 'app/**'
      - '.github/workflows/app-ci.yml'
  push:
    branches: [main]
    paths:
      - 'app/**'
      - '.github/workflows/app-ci.yml'

concurrency:
  group: app-ci-${{ github.ref }}
  cancel-in-progress: true

defaults:
  run:
    working-directory: app

jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          cache: pnpm
          cache-dependency-path: app/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm lint:ci
      - run: pnpm build
```

- [ ] **Step 2: YAML 문법 검증**

```bash
npx --yes yaml-lint .github/workflows/app-ci.yml
```

기대: 통과. (실질 검증은 Task 9에서 PR 열릴 때 CI 실행으로 완료)

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/app-ci.yml
git commit -m "chore(app): CI 게이트 워크플로우 추가 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: @claude 봇 워크플로우

**Files:**
- Create: `.github/workflows/claude.yml`

**Interfaces:**
- Consumes: `.nvmrc`, 시크릿 `CLAUDE_CODE_OAUTH_TOKEN`(Task 9에서 사용자 등록)
- Produces: 이슈/PR 코멘트 `@claude` 멘션 → 구현 봇

- [ ] **Step 1: `claude.yml` 작성** (전체 내용)

```yaml
name: Claude

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  claude:
    if: contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
      actions: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

동작 메모: 액션 기본값으로 write 권한자의 멘션에만 반응한다. 이슈에서 멘션 시 브랜치 푸시 후 PR 생성 링크를 코멘트로 남긴다(봇이 연 PR은 CI가 안 돌기 때문 — 사람이 링크 클릭으로 오픈). pnpm/node 셋업을 앞에 두어 봇이 verify-app 게이트를 실행할 수 있게 한다.

- [ ] **Step 2: YAML 문법 검증** (Task 6 Step 2와 동일 방식, 대상 파일만 교체)

```bash
npx --yes yaml-lint .github/workflows/claude.yml
```

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/claude.yml
git commit -m "chore: @claude 구현 봇 워크플로우 추가 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: CodeRabbit 경로 정합 + README 갱신

**Files:**
- Modify: `.coderabbit.yaml` (frontend→app, backend→server), `README.md` (CodeRabbit 문단 경로)

**Interfaces:**
- Produces: `app/**`·`server/**` 기준으로 살아있는 CodeRabbit 경로별 리뷰 지침 — Task 9의 PR에서 즉시 검증됨

- [ ] **Step 1: `.coderabbit.yaml` 경로 치환** — `path_instructions`의 `'frontend/**'`→`'app/**'`, `'backend/**'`→`'server/**'`; `path_filters`의 6개 경로 치환:

```yaml
  path_filters:
    - '!app/.next/**'
    - '!app/dist/**'
    - '!app/build/**'
    - '!app/coverage/**'
    - '!server/dist/**'
    - '!server/build/**'
    - '!server/coverage/**'
    - '!**/node_modules/**'
    - '!**/package-lock.json'
    - '!**/pnpm-lock.yaml'
    - '!**/yarn.lock'
```

(instructions 본문 내 "이 경로는 React/Next.js..." 설명 텍스트는 그대로. `server/dist` 계열은 Spring Boot 기준 `server/build/**`가 실효지만 기존 목록 구조 유지 차원에서 치환만 한다)

- [ ] **Step 2: README CodeRabbit 문단 수정** — `frontend/**`·`backend/**` 언급을 `app/**`·`server/**`로:

기존: `` `frontend/**`와 `backend/**`에 각기 다른 리뷰 지침을 적용한다 ``
수정: `` `app/**`와 `server/**`에 각기 다른 리뷰 지침을 적용한다 ``

- [ ] **Step 3: 검증**

```bash
grep -c "frontend\|backend" .coderabbit.yaml README.md   # 각 0
```

- [ ] **Step 4: 커밋**

```bash
git add .coderabbit.yaml README.md
git commit -m "chore: CodeRabbit 경로를 실제 구조(app·server)로 정합 (#33)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: PR 오픈 + 통합 검증 (사용자 액션 포함)

**Files:** 없음 (푸시·PR·시크릿·스모크)

**Interfaces:**
- Consumes: Task 1~8 전체
- Produces: 머지된 main — PR2 계획의 시작점

- [ ] **Step 1: 최종 게이트 재확인**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm build
```

- [ ] **Step 2: 푸시 + PR 오픈** — 레포 **`pr` 스킬** 사용. 제목 `chore(app): Next.js + Tailwind 환경 세팅 (#33)`, 본문 템플릿 준수 + `Closes #33`

- [ ] **Step 3: PR 위에서 자동 검증 확인**
  - App CI의 gate 잡 green (typecheck·lint:ci·build)
  - CodeRabbit 리뷰 코멘트가 달리고, `app/**` 파일에 프론트 지침 기반 코멘트인지 확인

- [ ] **Step 4 (사용자): 시크릿 등록**

```bash
claude setup-token   # Max 구독 OAuth 토큰 발급 (로컬에서 사용자가 실행)
gh secret set CLAUDE_CODE_OAUTH_TOKEN -R thumbsup-studio/thumbsup   # 값 붙여넣기
```

- [ ] **Step 5: 머지(Squash) 후 @claude 스모크 (사용자와 함께)**
  - 가벼운 테스트 이슈 생성(예: "chore(app): 홈 문구 오타 수정") → 이슈에 `@claude 이 이슈 구현해줘` 코멘트
  - 기대: 봇이 `chore/<이슈번호>-...` 브랜치 푸시 + 구현 + PR 생성 링크 코멘트
  - 링크로 PR 열어 CI·CodeRabbit 자동 실행 확인 → 확인 후 테스트 PR/이슈 정리

- [ ] **Step 6: 이슈 #33 상태 갱신** — acceptance 체크박스 충족 확인, `status: in-progress` → PR 머지로 자동 close (`Closes #33`)

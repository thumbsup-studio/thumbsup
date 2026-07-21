# 릴리즈 자동화 + 배포·릴리즈 스킬 문서화 구현 계획 (#78)

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** release-please로 릴리즈(태그·GitHub Release·CHANGELOG·버전)를 자동화하고, 프로덕션 링크 노출 + 배포·릴리즈 스킬 문서화 + server 배포 제외 규약을 정비한다.

**Architecture:** main push마다 release-please-action이 Conventional Commits를 모아 Release PR을 만들고(CHANGELOG·version.txt·app/package.json bump), 그 PR을 머지하면 git 태그+GitHub Release가 생성된다. 배포(app-deploy.yml)와는 독립. 스킬 2개와 CONTRIBUTING 규약은 사람·에이전트용 문서.

**Tech Stack:** googleapis/release-please-action@v4, release-type "simple"(통합 버전), GitHub Actions, gh CLI

**참조 스펙:** `docs/specs/2026-07-07-release-automation-design.md`

## Global Constraints

- 작업 위치: 워크트리 `~/DEV/thumbsup__worktrees/chore/78-release-automation` (브랜치 `chore/78-release-automation`, origin/main 기준)
- main 직접 커밋 금지. 커밋은 `commit` 스킬 형식: `<type>(<scope>): 한국어 요약 (#78)`, scope는 루트 작업이면 생략 가능
- 커밋 트레일러: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- **통합 버전** — 컴포넌트 접두어 없는 태그(`v0.1.0`), 저장소 전체 단일 버전
- **첫 버전 0.1.0** — `.release-please-manifest.json`·`version.txt` 모두 `0.1.0`, 현재 `app/package.json`(0.1.0)과 일치
- `app/package.json`의 `$.version`은 `extra-files`로 동기화(단일 소스=version.txt/manifest, package.json은 파생)
- 프로덕션 URL: `https://thumbsup-app.vercel.app`
- 스킬 SKILL.md는 frontmatter(`name`·`description`) 필수. `.codex/skills`는 `.claude/skills` 심링크라 별도 작업 불필요(노출만 확인)
- YAML 문법 검증은 `npx --yes yaml-lint <파일>`
- 스킬 SKILL.md는 이 계획서에서 ```markdown 펜스로 감싸 제시했다 — 실제 파일에는 그 안의 내용만(바깥 ```markdown 래퍼 제외) 쓴다. 제로폭 문자가 파일에 남으면 결함

---

### Task 1: 프로덕션 링크 노출

**Files:**
- Modify: `README.md`(최상단), repo 설정(homepage)

**Interfaces:**
- Produces: 없음(독립 문서/설정 변경)

- [ ] **Step 1: repo homepage 설정**

```bash
gh repo edit thumbsup-studio/thumbsup --homepage https://thumbsup-app.vercel.app
gh repo view thumbsup-studio/thumbsup --json homepageUrl -q .homepageUrl   # 기대: https://thumbsup-app.vercel.app
```

- [ ] **Step 2: README 최상단에 프로덕션 링크 추가** — 2번째 줄(`Thumbs Up — 학습 앱 모노레포 (app + server)`) 바로 아래에 삽입:

```markdown
# thumbsup
Thumbs Up — 학습 앱 모노레포 (app + server)

**프로덕션**: https://thumbsup-app.vercel.app
```

(기존 3번째 줄 이하 `AI agent skills...`는 그대로 유지 — 위 블록과 사이에 빈 줄 1개)

- [ ] **Step 3: 검증**

```bash
head -4 README.md   # 프로덕션 링크 줄 존재 확인
```

- [ ] **Step 4: 커밋**

```bash
git add README.md
git commit -m "docs: 프로덕션 링크 노출 (#78)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: release-please 설정 + 워크플로우

**Files:**
- Create: `release-please-config.json`, `.release-please-manifest.json`, `version.txt`, `.github/workflows/release-please.yml`

**Interfaces:**
- Consumes: 없음
- Produces: 릴리즈 파이프라인 — Task 4(releasing 스킬)가 이 동작을 문서화

- [ ] **Step 1: `version.txt` 생성** (simple 타입의 버전 파일 — 개행 없이)

```bash
printf '0.1.0' > version.txt
cat version.txt   # 기대: 0.1.0 (개행 없음)
```

- [ ] **Step 2: `.release-please-manifest.json` 생성** (버전 단일 진실 소스)

```json
{
  ".": "0.1.0"
}
```

- [ ] **Step 3: `release-please-config.json` 생성**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "changelog-path": "CHANGELOG.md",
      "include-component-in-tag": false,
      "extra-files": [
        {
          "type": "json",
          "path": "app/package.json",
          "jsonpath": "$.version"
        }
      ]
    }
  }
}
```

- [ ] **Step 4: `.github/workflows/release-please.yml` 생성**

```yaml
name: Release Please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

- [ ] **Step 5: JSON·YAML 문법 검증**

```bash
node -e "JSON.parse(require('fs').readFileSync('release-please-config.json','utf8'));JSON.parse(require('fs').readFileSync('.release-please-manifest.json','utf8'));console.log('JSON OK')"
npx --yes yaml-lint .github/workflows/release-please.yml
```

기대: `JSON OK` + yaml-lint 통과

- [ ] **Step 6: dry-run 동작 검증 (핵심 게이트)** — release-please CLI로 config가 파싱되고 extra-files가 인식되는지 확인. gh 토큰이 있는 환경이므로 `GITHUB_TOKEN`을 넘겨 실행:

```bash
GITHUB_TOKEN=$(gh auth token) npx --yes release-please release-pr \
  --repo-url=thumbsup-studio/thumbsup \
  --config-file=release-please-config.json \
  --manifest-file=.release-please-manifest.json \
  --dry-run 2>&1 | tee /tmp/rp-dryrun.txt | tail -30
```

기대: config가 로드되고 패키지 `.`가 인식됨(에러 없이 종료). 출력에 config 파싱 에러나 "unknown release-type"·"extra-files" 관련 에러가 **없어야** 함.
- extra-files/simple 조합 관련 에러가 나오면 → **커밋하지 말고 BLOCKED로 보고** (스펙의 폴백 조항: release-type 유지하되 package.json 동기화 별도 처리 또는 에스컬레이션)
- dry-run이 네트워크/인증으로 실패하면(config 에러가 아닌 경우) → 문법 검증(Step 5)까지로 갈음하고, config 파싱 단계까지는 통과했음을 로그로 확인 후 진행. 실질 검증은 PR 머지 후 첫 Release PR 관찰로 이관(보고서에 명시)

- [ ] **Step 7: 커밋**

```bash
git add release-please-config.json .release-please-manifest.json version.txt .github/workflows/release-please.yml
git commit -m "chore: release-please 릴리즈 자동화 추가 (#78)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: deploying 스킬

**Files:**
- Create: `.claude/skills/deploying/SKILL.md`

**Interfaces:**
- Consumes: 배포 파이프라인 사실(app-deploy.yml, #46 산출)
- Produces: 배포 절차 문서

- [ ] **Step 1: `.claude/skills/deploying/SKILL.md` 작성** (전체 내용)

```markdown
---
name: deploying
description: app 배포 파이프라인 이해·운영. main→프로덕션·PR→프리뷰 배포, Vercel CLI 방식, server가 배포 대상이 아닌 이유, 시크릿·프리뷰 URL·시각 QA를 확인할 때. 사용자가 "배포 어떻게 돼", "프리뷰 안 떠"라고 할 때도 트리거.
---

# deploying — app 배포 파이프라인

Vercel에 GitHub Actions로 배포한다 (`.github/workflows/app-deploy.yml`). Git 연동이 아니라 **Vercel CLI** 방식 — thumbsup-studio는 GitHub org라 Vercel 무료 플랜의 Git 연동이 불가(Pro 필요)해서 CLI로 우회한다.

## 트리거

- **main push (`app/**` 변경)** → 프로덕션 배포 (`vercel deploy --prod`)
- **PR (`app/**` 변경)** → 프리뷰 배포 + PR에 프리뷰 URL sticky 코멘트
- **`server/**`만 변경** → 배포 안 됨 (paths 필터가 `app/**`만 감시). 서버 배포는 #47에서 별도로 다룬다.

## 도메인

- 프로덕션: `https://thumbsup-app.vercel.app`
- 프리뷰: `https://*-thumbsup.vercel.app` (배포마다 서브도메인 랜덤)

## 시각 QA (soft gate)

PR 프리뷰를 Playwright로 스크린샷 → 엘리스 멀티모달 모델이 리뷰 → PR sticky 코멘트. 머지를 막지 않는다. `ELICE_API_KEY` 미등록 시 스크린샷만 찍고 리뷰는 스킵. 검사 라우트는 `app/e2e/qa-routes.ts`에서 관리, 로컬 실행은 `visual-qa` 스킬 참고.

## 시크릿·변수

| 이름 | 위치 | 용도 |
|------|------|------|
| `VERCEL_TOKEN`·`VERCEL_ORG_ID`·`VERCEL_PROJECT_ID` | Secrets | CLI 배포 |
| `ELICE_API_KEY` | Secrets | 시각 QA (미등록 시 스킵) |
| `ELICE_BASE_URL`·`ELICE_QA_MODEL` | Variables | 엘리스 엔드포인트·모델 |

앱 런타임 env(`NEXT_PUBLIC_API_URL` 등)는 Vercel 프로젝트 → Settings → Environment Variables에서 관리. 자세한 표는 [README](../../../README.md) 참고.

## 막힐 때

- 프리뷰가 로그인 페이지로 튕김 → Vercel 프로젝트 Settings → Deployment Protection → Require Log In OFF
- 시크릿 미등록 → deploy 잡이 guard로 우아하게 스킵(배포 안 됨, 실패는 아님)
```

- [ ] **Step 2: 검증**

```bash
head -4 .claude/skills/deploying/SKILL.md   # frontmatter name/deploying 확인
ls .codex/skills/ | grep deploying          # 심링크 경유 노출
grep -rP '\x{200B}|\x{200C}|\x{FEFF}' .claude/skills/deploying/SKILL.md; echo "zwsp exit=$?"   # exit=1 정상(0건)
```

- [ ] **Step 3: 커밋**

```bash
git add .claude/skills/deploying
git commit -m "docs: deploying 스킬 추가 (#78)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: releasing 스킬

**Files:**
- Create: `.claude/skills/releasing/SKILL.md`

**Interfaces:**
- Consumes: Task 2의 release-please 동작
- Produces: 릴리즈 절차 문서

- [ ] **Step 1: `.claude/skills/releasing/SKILL.md` 작성** (전체 내용)

```markdown
---
name: releasing
description: 릴리즈(버전·태그·GitHub Release·CHANGELOG) 처리. release-please Release PR 확인·머지, 버전 규칙(feat→minor 등), Conventional Commits와의 관계를 알아야 할 때. 사용자가 "릴리즈 어떻게 해", "버전 어떻게 올라가"라고 할 때도 트리거.
---

# releasing — release-please 릴리즈

릴리즈는 `release-please`가 자동화한다 (`.github/workflows/release-please.yml`). 저장소 **통합 버전**(컴포넌트 접두어 없는 `vX.Y.Z` 태그) — app·server 공통 단일 버전.

## 흐름 (2단계)

1. **main에 `feat`/`fix` 등이 머지되면** → release-please가 **"chore(main): release X.Y.Z" Release PR**을 자동 생성/갱신한다. 이 PR 안에서 CHANGELOG·`version.txt`·`app/package.json` version이 함께 갱신된다.
2. **그 Release PR을 사람이 머지하면** → git 태그 `vX.Y.Z` + GitHub Release(노트 게시)가 생성된다.

즉 릴리즈하려면: **Release PR을 확인하고 머지**하면 끝. 태그·노트는 자동.

## 버전 규칙 (Conventional Commits)

| 커밋 | 버전 |
|------|------|
| `feat:` | minor (0.1.0 → 0.2.0) |
| `fix:` | patch (0.1.0 → 0.1.1) |
| `feat!:` 또는 본문 `BREAKING CHANGE:` | major (0.1.0 → 1.0.0) |
| `chore:`·`docs:`·`refactor:`·`test:` | 버전 미변경 (CHANGELOG "Other") |

정확한 버전 계산은 release-please가 커밋 타입을 보고 한다 — 사람이 버전을 직접 정하지 않는다.

## 버전의 단일 소스

`.release-please-manifest.json`이 현재 버전의 진실 소스다. `version.txt`와 `app/package.json`의 version은 릴리즈 시 여기에 맞춰 갱신된다(수동 편집 금지 — Release PR이 관리).

## 배포와의 관계

릴리즈와 배포는 **독립**이다. 배포는 main push마다(`app/**` 변경 시) 즉시 일어나고(→ `deploying` 스킬), 릴리즈는 태그·노트만 관리한다. 태그가 배포를 트리거하지 않는다.
```

- [ ] **Step 2: 검증**

```bash
head -4 .claude/skills/releasing/SKILL.md
ls .codex/skills/ | grep releasing
grep -rP '\x{200B}|\x{200C}|\x{FEFF}' .claude/skills/releasing/SKILL.md; echo "zwsp exit=$?"   # exit=1 정상
```

- [ ] **Step 3: 커밋**

```bash
git add .claude/skills/releasing
git commit -m "docs: releasing 스킬 추가 (#78)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: CONTRIBUTING에 server 배포 제외 명문화

**Files:**
- Modify: `CONTRIBUTING.md`(말미에 배포 섹션 추가)

**Interfaces:**
- Consumes: 없음
- Produces: 배포 규약 문서

- [ ] **Step 1: CONTRIBUTING.md 말미에 섹션 추가** — 파일 맨 끝(마일스톤 §6 뒤)에 추가:

```markdown

---

## 7. 배포 · 릴리즈

- **배포는 `app/**` 변경에만 반응한다.** `.github/workflows/app-deploy.yml`이 main push(`app/**`)를 프로덕션에, PR(`app/**`)을 프리뷰에 배포한다. **server 작업은 Vercel 배포 대상이 아니다** — 서버 배포는 #47에서 별도로 다룬다. 상세는 `deploying` 스킬.
- **릴리즈는 release-please가 자동화한다.** main 머지 시 Release PR이 생성되고, 이를 머지하면 통합 버전 태그(`vX.Y.Z`)와 GitHub Release가 만들어진다. 버전은 Conventional Commits 타입으로 결정된다(`feat`→minor, `fix`→patch). 상세는 `releasing` 스킬.
```

- [ ] **Step 2: 검증**

```bash
grep -n "server 작업은 Vercel 배포 대상이 아니다" CONTRIBUTING.md   # 존재 확인
tail -6 CONTRIBUTING.md
```

- [ ] **Step 3: 커밋**

```bash
git add CONTRIBUTING.md
git commit -m "docs: server 배포 제외·릴리즈 규약 명문화 (#78)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: PR 오픈 + 검증

**Files:** 없음

**Interfaces:**
- Consumes: Task 1~5
- Produces: 머지된 main — 첫 Release PR 자동 생성의 시작점

- [ ] **Step 1: 푸시 + PR 오픈** — `pr` 스킬 사용. 제목 `chore: 릴리즈 자동화 + 배포·릴리즈 스킬 문서화 (#78)`, 본문 `Closes #78`, base main

- [ ] **Step 2: PR 위에서 확인**
  - CodeRabbit 리뷰 대응(있으면 트리아지)
  - release-please.yml은 PR에선 안 돎(main push 트리거) — 정상. 실질 검증은 머지 후

- [ ] **Step 3: 머지 후 release-please 첫 동작 관찰 (사용자와 함께)**
  - main 머지 후, main에 그다음 `feat`/`fix` 커밋이 쌓이면 release-please가 Release PR을 생성하는지 확인
  - 이 PR 자체는 전부 `docs`/`chore`라 버전은 안 오름 — Release PR은 다음 `feat`/`fix`부터 생성됨(정상). 최초 부트스트랩 동작(첫 Release PR에 CHANGELOG·version.txt·app/package.json 3곳 갱신)을 그때 확인
  - Release PR 머지 → 태그 `v0.2.0`(등) + GitHub Release 생성 확인

- [ ] **Step 4: 이슈 상태** — PR 머지로 `Closes #78` 자동 close

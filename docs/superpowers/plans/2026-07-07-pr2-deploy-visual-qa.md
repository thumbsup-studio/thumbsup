# PR2 (#46) — 배포 인프라 + AI 시각 QA 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** main 머지 시 자동 프로덕션 배포 + PR마다 프리뷰 URL 코멘트 + 프리뷰 스크린샷을 엘리스 멀티모달 모델이 리뷰하는 시각 QA를 구축한다.

**Architecture:** GitHub Actions에서 Vercel CLI로 배포(Git 연동 없이 — org 레포+Hobby 무료 제약 우회). 배포 잡의 URL 출력을 프리뷰 코멘트 잡과 시각 QA 잡이 소비. QA는 Playwright 스크린샷 → 엘리스 OpenAI 호환 API → sticky 코멘트. soft gate(PR 안 막음), 키 부재 시 우아한 스킵.

**Tech Stack:** Vercel CLI · Playwright(chromium) · tsx · 엘리스AX API(OpenAI 호환) · marocchino/sticky-pull-request-comment

**참조 스펙:** `docs/superpowers/specs/2026-07-07-frontend-infra-design.md`
**선행 조건:** PR1(#33) 머지 완료

## Global Constraints

- 작업 위치: 새 워크트리 `~/DEV/thumbsup__worktrees/chore/46-deploy-infra` (브랜치 `chore/46-deploy-infra`, 갱신된 main 기준)
- main 직접 커밋 금지, `commit`/`pr` 스킬 사용, 커밋 형식 `<type>(<scope>): 한국어 요약 (#46)`
- 커밋 트레일러: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- Node 22·pnpm 10 (PR1과 동일), Biome만 사용
- 시크릿(Secrets): `VERCEL_TOKEN` `VERCEL_ORG_ID` `VERCEL_PROJECT_ID` `ELICE_API_KEY` / 변수(Variables): `ELICE_BASE_URL`(`/v1`로 끝남) `ELICE_QA_MODEL`
- 시각 QA는 **soft gate** — 어떤 실패로도 PR을 막지 않는다 (스크립트는 항상 exit 0, 단 `QA_TARGET_URL` 부재만 exit 1)
- **#38 영역 금지** 유지 — QA의 시안 대조 모드는 구현하되 시안 파일은 만들지 않는다
- **표기 규칙**: 이 계획서에서 파일 내용 안의 중첩 코드블록은 `​````(제로폭 문자 선행)로 표기했다 — 실제 파일에는 **일반 ```** 로 쓴다

---

### Task 1: 브랜치 + 워크트리 준비

**Files:** 없음

- [ ] **Step 1: main 갱신 후 워크트리 생성**

```bash
cd ~/DEV/thumbsup && git checkout main && git pull
git worktree add ~/DEV/thumbsup__worktrees/chore/46-deploy-infra -b chore/46-deploy-infra
cd ~/DEV/thumbsup__worktrees/chore/46-deploy-infra && ls app/package.json   # PR1 산출물 존재 확인
```

- [ ] **Step 2: 의존성 설치 (워크트리 격리)**

```bash
cd ~/DEV/thumbsup__worktrees/chore/46-deploy-infra/app && pnpm install --frozen-lockfile && pnpm build   # 기준선 green 확인
```

---

### Task 2: Vercel 프로젝트 연결 (사용자 개입 필요)

**Files:**
- Modify: `app/.gitignore` (`.vercel` 추가)

**Interfaces:**
- Produces: GitHub 시크릿 3개(`VERCEL_TOKEN`·`VERCEL_ORG_ID`·`VERCEL_PROJECT_ID`) — Task 5 워크플로우가 소비

- [ ] **Step 1 (사용자): Vercel 토큰 발급** — vercel.com → Settings → Tokens → Create (scope: 개인 Hobby 계정, 만료 No Expiration 권장). 값을 환경변수로 준비:

```bash
export VERCEL_TOKEN=<발급값>
```

- [ ] **Step 2: 프로젝트 생성+링크** (app 디렉터리에서)

```bash
cd app && npx vercel@latest link --yes --project thumbsup-app --token "$VERCEL_TOKEN"
cat .vercel/project.json   # {"orgId":"...","projectId":"..."}
```

- [ ] **Step 3: `.vercel` gitignore** — `app/.gitignore` 맨 아래 추가:

```
# vercel
.vercel
```

- [ ] **Step 4: GitHub 시크릿 등록** (`app/` 디렉터리에서 — `.vercel/project.json` 상대경로 사용)

```bash
cd ~/DEV/thumbsup__worktrees/chore/46-deploy-infra/app
gh secret set VERCEL_TOKEN -R thumbsup-studio/thumbsup --body "$VERCEL_TOKEN"
gh secret set VERCEL_ORG_ID -R thumbsup-studio/thumbsup --body "$(node -p "require('./.vercel/project.json').orgId")"
gh secret set VERCEL_PROJECT_ID -R thumbsup-studio/thumbsup --body "$(node -p "require('./.vercel/project.json').projectId")"
```

- [ ] **Step 5 (사용자): 프리뷰 공개 설정** — Vercel 대시보드 → thumbsup-app → Settings → Deployment Protection → **Vercel Authentication OFF** (프리뷰 URL을 로그인 없이 접근 가능하게 — 시각 QA 봇과 팀원 접근에 필요. MVP 단계 공개 허용 합의됨)

- [ ] **Step 6: 수동 프리뷰 배포로 연결 검증**

```bash
cd app && npx vercel@latest deploy --token "$VERCEL_TOKEN"
```

기대: `https://thumbsup-app-*.vercel.app` URL 출력, 접속 시 "Thumbs Up 👍" 홈 렌더

- [ ] **Step 7: 커밋**

```bash
git add app/.gitignore
git commit -m "chore(app): Vercel 링크 산출물 gitignore (#46)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: 시각 QA 스크립트 (qa-routes + visual-qa)

**Files:**
- Create: `app/e2e/qa-routes.ts`, `app/e2e/visual-qa.ts`
- Modify: `app/package.json` (devDeps: `playwright`·`tsx`, script `qa:visual`), `app/.gitignore` (QA 산출물)

**Interfaces:**
- Consumes: env `QA_TARGET_URL`(필수) `ELICE_API_KEY` `ELICE_BASE_URL`(`/v1`로 끝남) `ELICE_QA_MODEL`(기본 `gpt-5.2`)
- Produces: `pnpm qa:visual` → `app/e2e/qa-report.md`(리뷰 리포트)·`app/e2e/screenshots/*.png` — Task 5 워크플로우가 소비. `QaRoute` 타입(`{ path: string; design: string | null }`)

- [ ] **Step 1: 의존성 설치**

```bash
cd app && pnpm add -D playwright tsx && pnpm exec playwright install chromium
```

- [ ] **Step 2: `app/e2e/qa-routes.ts` 작성** (전체 내용)

```ts
export type QaRoute = {
  /** 검사할 라우트 경로 */
  path: string;
  /** 원본 디자인 시안 이미지 경로(app/ 기준 상대). null이면 휴리스틱 모드. #38 이후 시안이 생기면 지정 → 시안 대조 모드 */
  design: string | null;
};

export const qaRoutes: QaRoute[] = [
  { path: "/", design: null },
  // 예) #38 이후: { path: "/quiz", design: "e2e/designs/quiz.png" },
];
```

- [ ] **Step 3: `app/e2e/visual-qa.ts` 작성** (전체 내용)

```ts
import { existsSync } from "node:fs";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";
import { type QaRoute, qaRoutes } from "./qa-routes";

const targetUrl = process.env.QA_TARGET_URL?.replace(/\/+$/, "");
const apiKey = process.env.ELICE_API_KEY;
const apiBase = process.env.ELICE_BASE_URL?.replace(/\/+$/, "");
const model = process.env.ELICE_QA_MODEL || "gpt-5.2";

const OUT_DIR = path.resolve("e2e/screenshots");
const REPORT_PATH = path.resolve("e2e/qa-report.md");

const VIEWPORTS = [
  { name: "mobile", width: 390, height: 844 },
  { name: "desktop", width: 1280, height: 800 },
] as const;

const HEURISTIC_PROMPT = `당신은 웹 프론트엔드 시각 QA 리뷰어다. 주어진 스크린샷(모바일 390px, 데스크톱 1280px)을 보고 다음 항목만 점검해 한국어로 보고하라.
- 깨진 레이아웃, 요소 겹침·잘림, 가로 스크롤 흔적
- 텍스트 대비 부족, 읽기 어려운 크기
- 터치 타깃 과소(44px 미만으로 보이는 버튼/링크)
- 모바일·데스크톱 반응형 불일치
형식: 문제가 없으면 "✅ 특이사항 없음" 한 줄만. 문제가 있으면 항목당 한 줄로 "🔴|🟡 [뷰포트] 위치 — 증상". 확신 없는 추측성 지적은 쓰지 않는다.`;

const COMPARE_PROMPT = `당신은 디자인 충실도 검사관이다. 첫 번째 이미지는 원본 디자인 시안, 나머지는 실제 구현 스크린샷(모바일, 데스크톱)이다. 시안 대비 구현의 차이만 한국어로 보고하라: 색상, 간격·정렬, 타이포그래피, 누락·변형된 컴포넌트.
형식: 차이가 없으면 "✅ 시안과 일치" 한 줄만. 차이가 있으면 항목당 한 줄로 "🔴|🟡 무엇이 — 어떻게 다른지". 해상도·렌더링 미세 차이는 무시한다.`;

type Shot = { viewport: string; file: string };

async function capture(route: QaRoute): Promise<Shot[]> {
  const browser = await chromium.launch();
  const shots: Shot[] = [];
  try {
    for (const vp of VIEWPORTS) {
      const page = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
      await page.goto(`${targetUrl}${route.path}`, { waitUntil: "networkidle", timeout: 30_000 });
      const slug = route.path === "/" ? "home" : route.path.replaceAll("/", "_").replace(/^_/, "");
      const file = path.join(OUT_DIR, `${slug}-${vp.name}.png`);
      await page.screenshot({ path: file, fullPage: true });
      await page.close();
      shots.push({ viewport: vp.name, file });
      console.log(`📸 ${route.path} [${vp.name}] → ${path.relative(process.cwd(), file)}`);
    }
  } finally {
    await browser.close();
  }
  return shots;
}

async function toImagePart(file: string) {
  const b64 = (await readFile(file)).toString("base64");
  return { type: "image_url", image_url: { url: `data:image/png;base64,${b64}` } };
}

async function review(route: QaRoute, shots: Shot[]): Promise<string> {
  const compareMode = route.design !== null;
  const content: unknown[] = [
    {
      type: "text",
      text: compareMode
        ? `라우트 ${route.path} — 첫 이미지가 시안, 이후 ${shots.map((s) => s.viewport).join(", ")} 구현 스크린샷.`
        : `라우트 ${route.path} — ${shots.map((s) => s.viewport).join(", ")} 스크린샷.`,
    },
  ];
  if (compareMode) content.push(await toImagePart(path.resolve(route.design as string)));
  for (const shot of shots) content.push(await toImagePart(shot.file));

  const res = await fetch(`${apiBase}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: compareMode ? COMPARE_PROMPT : HEURISTIC_PROMPT },
        { role: "user", content },
      ],
    }),
  });
  if (!res.ok) throw new Error(`엘리스 API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = (await res.json()) as { choices: { message: { content: string } }[] };
  return data.choices[0]?.message?.content?.trim() || "(빈 응답)";
}

async function main() {
  if (!targetUrl) {
    console.error("QA_TARGET_URL이 필요합니다 (예: https://thumbsup-app-xxx.vercel.app)");
    process.exit(1);
  }
  await rm(REPORT_PATH, { force: true });
  await mkdir(OUT_DIR, { recursive: true });

  const captured: { route: QaRoute; shots: Shot[] }[] = [];
  for (const route of qaRoutes) captured.push({ route, shots: await capture(route) });

  if (!apiKey || !apiBase) {
    console.log("⏭️ ELICE_API_KEY / ELICE_BASE_URL 미설정 — 스크린샷만 저장하고 AI 리뷰는 건너뜁니다.");
    return; // soft skip: 리포트 없음, exit 0
  }

  const sections: string[] = [];
  for (const { route, shots } of captured) {
    try {
      const result = await review(route, shots);
      const mode = route.design ? "시안 대조" : "휴리스틱";
      sections.push(`## \`${route.path}\` (${mode})\n\n${result}`);
      console.log(`✅ 리뷰 완료: ${route.path}`);
    } catch (err) {
      console.error(`⚠️ 리뷰 실패(${route.path}): ${(err as Error).message} — 시각 QA를 중단합니다 (soft).`);
      return; // API 장애 시 리포트 미생성, exit 0
    }
  }

  const header = `# 🎨 AI 시각 QA\n\n- 대상: ${targetUrl}\n- 모델: \`${model}\` · 라우트 ${qaRoutes.length}개 × 뷰포트 ${VIEWPORTS.length}종\n- 스크린샷 원본: 워크플로우 아티팩트 \`qa-screenshots\`\n`;
  await writeFile(REPORT_PATH, `${header}\n${sections.join("\n\n")}\n`);
  console.log(`📝 리포트 저장: ${path.relative(process.cwd(), REPORT_PATH)}`);
}

main().catch((err) => {
  console.error(`⚠️ 시각 QA 실패: ${(err as Error).message} — soft gate이므로 성공 종료합니다.`);
  if (existsSync(REPORT_PATH)) rm(REPORT_PATH, { force: true });
});
```

- [ ] **Step 4: package.json script + gitignore**

`app/package.json` scripts에 추가:

```json
{
  "scripts": {
    "qa:visual": "tsx e2e/visual-qa.ts"
  }
}
```

`app/.gitignore` 맨 아래 추가:

```
# visual QA 산출물
/e2e/screenshots
/e2e/qa-report.md
```

- [ ] **Step 5: 계약 검증 3종** (dev 서버 필요: 별도 터미널에서 `pnpm dev`)

```bash
cd app
# (1) URL 없음 → exit 1 + 안내
pnpm qa:visual; echo "exit=$?"                       # 기대: exit=1, "QA_TARGET_URL이 필요합니다"
# (2) 키 없음 → 스크린샷만, exit 0
QA_TARGET_URL=http://localhost:3000 pnpm qa:visual; echo "exit=$?"
ls e2e/screenshots/                                  # home-mobile.png home-desktop.png
test ! -f e2e/qa-report.md && echo "리포트 없음 OK"   # 기대: exit=0, 스킵 메시지
# (3) 가짜 키 → API 실패해도 exit 0 (soft)
QA_TARGET_URL=http://localhost:3000 ELICE_API_KEY=dummy ELICE_BASE_URL=https://invalid.example/v1 pnpm qa:visual; echo "exit=$?"   # 기대: exit=0, "리뷰 실패" 로그
```

- [ ] **Step 6: 게이트 + 커밋**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm build
git add app/e2e app/package.json app/pnpm-lock.yaml app/.gitignore
git commit -m "feat(app): AI 시각 QA 스크립트 — 스크린샷·엘리스 리뷰 (#46)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: visual-qa 로컬 스킬

**Files:**
- Create: `.claude/skills/visual-qa/SKILL.md`

**Interfaces:**
- Consumes: Task 3의 `pnpm qa:visual` 계약(env·산출물 경로)

- [ ] **Step 1: SKILL.md 작성** (전체 내용)

```markdown
---
name: visual-qa
description: UI 변경 후 로컬에서 AI 시각 QA 실행. 스크린샷 → 엘리스 멀티모달 리뷰 → 리포트 확인. UI 작업 완료 전 자가 점검용, 사용자가 "시각 QA 돌려"라고 할 때도 트리거.
---

# visual-qa — 로컬 AI 시각 QA

1. dev 서버 기동: `cd app && pnpm dev` (별도 터미널/백그라운드)
2. QA 실행:

​```bash
cd app && QA_TARGET_URL=http://localhost:3000 \
  ELICE_API_KEY=<키> ELICE_BASE_URL=<엘리스 OpenAI 호환 엔드포인트, /v1까지> \
  pnpm qa:visual
​```

3. `app/e2e/qa-report.md` 확인 — 🔴 항목은 수정 후 재실행, 🟡은 판단해서 처리
4. 스크린샷 원본은 `app/e2e/screenshots/`에서 직접 확인

메모: 키가 없으면 스크린샷만 저장되고 리뷰는 스킵된다(그 경우 스크린샷을 직접 눈으로 점검). 검사 라우트 추가는 `app/e2e/qa-routes.ts`에 한 줄 — 새 화면 이슈를 구현하면 그 라우트를 반드시 추가한다. #38 이후 시안이 생기면 `design` 필드에 경로를 지정해 시안 대조 모드로 전환.
```

- [ ] **Step 2: 검증** — `.codex/skills/visual-qa` 심링크 경유 노출 확인:

```bash
ls .codex/skills/ | grep visual-qa
```

- [ ] **Step 3: 커밋**

```bash
git add .claude/skills/visual-qa
git commit -m "chore: visual-qa 로컬 스킬 추가 (#46)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: 배포 워크플로우 (배포 + 프리뷰 코멘트 + 시각 QA)

**Files:**
- Create: `.github/workflows/app-deploy.yml`

**Interfaces:**
- Consumes: 시크릿 4개+변수 2개(Global Constraints), Task 3의 `pnpm qa:visual` 계약, PR1의 `.nvmrc`
- Produces: main→프로덕션 / PR→프리뷰 URL sticky 코멘트(header: `preview`) + QA sticky 코멘트(header: `visual-qa`) + 아티팩트 `qa-screenshots`

- [ ] **Step 1: `app-deploy.yml` 작성** (전체 내용)

```yaml
name: App Deploy

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - '.github/workflows/app-deploy.yml'
  pull_request:
    paths:
      - 'app/**'
      - '.github/workflows/app-deploy.yml'

concurrency:
  group: app-deploy-${{ github.ref }}
  cancel-in-progress: true

env:
  VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
  VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    outputs:
      url: ${{ steps.deploy.outputs.url }}
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - name: 시크릿 가드 (fork PR·미등록 시 스킵)
        id: guard
        env:
          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
        run: |
          if [ -z "$VERCEL_TOKEN" ]; then
            echo "skip=true" >> "$GITHUB_OUTPUT"
            echo "::notice::VERCEL_TOKEN 미설정 — 배포를 건너뜁니다"
          fi
      - uses: pnpm/action-setup@v4
        if: steps.guard.outputs.skip != 'true'
        with:
          version: 10
      - uses: actions/setup-node@v4
        if: steps.guard.outputs.skip != 'true'
        with:
          node-version-file: .nvmrc
          cache: pnpm
          cache-dependency-path: app/pnpm-lock.yaml
      - name: Vercel 배포
        id: deploy
        if: steps.guard.outputs.skip != 'true'
        env:
          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
        run: |
          if [ "${{ github.event_name }}" = "push" ]; then FLAG="--prod"; ENV_NAME="production"; else FLAG=""; ENV_NAME="preview"; fi
          npx vercel@latest pull --yes --environment=$ENV_NAME --token="$VERCEL_TOKEN"
          npx vercel@latest build $FLAG --token="$VERCEL_TOKEN"
          URL=$(npx vercel@latest deploy --prebuilt $FLAG --token="$VERCEL_TOKEN")
          echo "url=$URL" >> "$GITHUB_OUTPUT"
          echo "배포 완료: $URL"

  preview-comment:
    needs: deploy
    if: github.event_name == 'pull_request' && needs.deploy.outputs.url != ''
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: preview
          message: |
            🔍 **프리뷰 배포**: ${{ needs.deploy.outputs.url }}

            `app/**` 변경이 반영된 미리보기입니다. 푸시할 때마다 갱신됩니다.

  visual-qa:
    needs: deploy
    if: github.event_name == 'pull_request' && needs.deploy.outputs.url != ''
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    defaults:
      run:
        working-directory: app
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
      - run: pnpm exec playwright install --with-deps chromium
      - name: 시각 QA 실행
        env:
          QA_TARGET_URL: ${{ needs.deploy.outputs.url }}
          ELICE_API_KEY: ${{ secrets.ELICE_API_KEY }}
          ELICE_BASE_URL: ${{ vars.ELICE_BASE_URL }}
          ELICE_QA_MODEL: ${{ vars.ELICE_QA_MODEL }}
        run: pnpm qa:visual
      - name: QA 리포트 코멘트
        if: hashFiles('app/e2e/qa-report.md') != ''
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: visual-qa
          path: app/e2e/qa-report.md
      - name: 스크린샷 아티팩트 업로드
        if: always() && hashFiles('app/e2e/screenshots/**') != ''
        uses: actions/upload-artifact@v4
        with:
          name: qa-screenshots
          path: app/e2e/screenshots
```

- [ ] **Step 2: YAML 문법 검증**

```bash
npx --yes yaml-lint .github/workflows/app-deploy.yml
```

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/app-deploy.yml
git commit -m "chore(app): 배포·프리뷰·시각 QA 워크플로우 (#46)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: README 배포·환경변수 문서화

**Files:**
- Modify: `README.md` (배포 섹션 추가 — 로컬 개발 섹션 뒤)

**Interfaces:**
- Consumes: Task 2·5의 시크릿/변수 이름 — 문서와 실물이 1:1이어야 함

- [ ] **Step 1: README에 섹션 추가** (`## 로컬 개발 (app)` 섹션 뒤에 삽입, 전체 내용)

```markdown
## 배포 (app)

Vercel에 GitHub Actions로 배포한다 (`.github/workflows/app-deploy.yml`, Git 연동 아님).

- **main 머지** → 프로덕션 자동 배포
- **PR (app/** 변경)** → 프리뷰 배포 + PR에 프리뷰 URL 코멘트 자동 게시
- **AI 시각 QA** → 프리뷰를 Playwright로 스크린샷 → 엘리스 멀티모달 모델이 리뷰 → PR 코멘트 (soft — 머지를 막지 않음). 검사 라우트는 `app/e2e/qa-routes.ts`에서 관리, 로컬 실행은 `visual-qa` 스킬 참고

### 환경변수·시크릿

| 이름 | 위치 | 용도 |
|------|------|------|
| `VERCEL_TOKEN` | GitHub Secrets | CLI 배포 인증 |
| `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` | GitHub Secrets | 대상 프로젝트 식별 |
| `ELICE_API_KEY` | GitHub Secrets | 시각 QA 모델 호출 (미등록 시 QA 자동 스킵) |
| `ELICE_BASE_URL` | GitHub Variables | 엘리스 OpenAI 호환 엔드포인트 (`/v1`까지) |
| `ELICE_QA_MODEL` | GitHub Variables | QA 모델 ID (기본 `gpt-5.2`) |
| `CLAUDE_CODE_OAUTH_TOKEN` | GitHub Secrets | `@claude` 봇 인증 |

앱 런타임 환경변수(추후 `NEXT_PUBLIC_API_URL` 등)는 Vercel 프로젝트 → Settings → Environment Variables에서 관리하고 이 표에 추가한다.
```

- [ ] **Step 2: 커밋**

```bash
git add README.md
git commit -m "docs: 배포·환경변수 관리 문서화 (#46)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: PR 오픈 + 통합 검증 (사용자 액션 포함)

**Files:** 없음

- [ ] **Step 1: 게이트 재확인**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm build
```

- [ ] **Step 2: 푸시 + PR 오픈** — `pr` 스킬 사용. 제목 `chore(app): 앱 배포 인프라 세팅 (#46)`, 본문 `Closes #46`

- [ ] **Step 3: PR 자체가 통합 테스트** (이 PR이 `app/**`·워크플로우를 변경하므로 배포 워크플로우가 이 PR에서 실행됨)
  - `deploy` 잡 green + 로그에 프리뷰 URL
  - PR에 🔍 프리뷰 코멘트 자동 게시 → URL 접속해 홈 렌더 확인
  - `visual-qa` 잡: `ELICE_API_KEY` 미등록 상태면 "⏭️ 스킵" 로그 + 리포트 코멘트 없음 + 스크린샷 아티팩트 존재 확인

- [ ] **Step 4 (사용자): 엘리스 키 수령 후 등록** (키 수령 시점에)

```bash
gh secret set ELICE_API_KEY -R thumbsup-studio/thumbsup
gh variable set ELICE_BASE_URL -R thumbsup-studio/thumbsup --body "<엘리스 문서의 OpenAI 호환 base URL, /v1까지>"
gh variable set ELICE_QA_MODEL -R thumbsup-studio/thumbsup --body "<모델 ID, 예: gpt-5.2>"
```

등록 후 PR 브랜치에 빈 커밋 푸시(`git commit --allow-empty -m "chore(app): 시각 QA 재실행 (#46)"`)로 워크플로우 재실행 → "🎨 AI 시각 QA" 코멘트 게시 확인. 모델 ID·base URL은 엘리스 콘솔에서 실제 값 확인(모델 ID가 다르면 `ELICE_QA_MODEL` 변수만 수정).

- [ ] **Step 5: 머지(Squash) 후 프로덕션 확인**
  - main의 `App Deploy` 실행 → 프로덕션 URL 접속 확인
  - 이슈 #46 acceptance 4항목 체크 확인 (`Closes #46`으로 자동 close)

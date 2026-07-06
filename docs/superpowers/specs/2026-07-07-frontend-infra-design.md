# 프론트 인프라 세팅 디자인 — #33 · #46

- **날짜**: 2026-07-07
- **상태**: 승인됨 (구현 전)
- **관련 이슈**: [#33 chore(app): Next.js + Tailwind 환경 세팅](https://github.com/thumbsup-studio/thumbsup/issues/33), [#46 chore(app): 앱 배포 인프라 세팅](https://github.com/thumbsup-studio/thumbsup/issues/46)

## 배경과 목표

레포는 규약(CONTRIBUTING, 이슈/PR 템플릿, CodeRabbit, 에이전트 스킬)만 있고 코드가 없는 상태다. #33이 모든 M1 앱 이슈의 선행 작업이고, #46이 그 위의 배포 인프라다.

핵심 요구: **프론트 인프라를 세팅하면서 AI를 최대한 활용한 자동화를 기반으로 깐다.** 구체적으로 세 레이어를 도입한다.

1. **에이전트 워크스페이스** — 사람이 Claude Code/Codex로 작업할 때 규약 설명 없이 첫 시도에 정확히 움직이게 하는 문서·스킬
2. **GitHub 자동화** — 이슈에 `@claude` 멘션으로 구현을 위임하는 봇
3. **AI 시각 QA** — PR 프리뷰 배포를 스크린샷 찍어 멀티모달 모델이 리뷰

모델 비용 전략: 자동·고빈도 작업(시각 QA 등)은 **엘리스AX 무료 제공 모델**(OpenAI 호환 API, GPT-5.x·Gemini 3.x 등)로, `@claude` 구현 작업은 **Claude Max 구독 OAuth 토큰**(추가 과금 없음)으로 돌린다.

## 결정 기록

| 결정 | 선택 | 근거 |
|------|------|------|
| 자동화 범위 | 워크스페이스 + @claude + 시각 QA (3종 모두) | 사용자 선택 |
| 봇 API 조합 | 엘리스(고빈도) + Claude Max OAuth(@claude) | 비용 0 + 품질 보장 |
| 배포처 | Vercel Hobby + **CLI 배포**(GitHub Actions) | org 레포는 Vercel 무료 Git 연동 불가(Pro 필요) → CLI로 우회. 비용 0, Next.js 100% 호환 |
| 작업 구조 | 2-PR 적층 (PR1=#33, PR2=#46) | 이슈 경계와 일치 |
| #38(디자인 토큰·컴포넌트) 영역 | **선세팅 안 함** | 사용자 지시. 디자인 규약 문서·컴포넌트 뼈대·`@theme` 토큰은 #38의 몫 |
| 시각 QA 진화 | 1단계 휴리스틱 → 2단계 원본 디자인 대조 | #38이 이슈별 디자인 시안을 만들면 "시안 vs 구현" 차이 비교로 전환 |
| 워크스페이스 구조 | pnpm, `app/` 단독 패키지 (루트 워크스페이스 없음) | 서버는 Spring Boot(Java), JS 패키지는 당분간 하나 → YAGNI. `shared/` 생길 때 도입 |
| Node | 22 LTS 고정 (`.nvmrc` + CI) | 로컬/CI/Vercel 런타임 통일 |

## 전체 구조 (두 PR 완료 후)

```
thumbsup/
├── app/                          # ← PR1
│   ├── src/app/                  #    Next.js App Router (create-next-app 기본 구조)
│   ├── e2e/                      # ← PR2: Playwright 시각 QA (qa-routes.ts, 스크립트)
│   ├── biome.json                #    Linter+Formatter
│   ├── package.json              #    pnpm 독립 패키지
│   └── CLAUDE.md (+AGENTS.md 심링크)
├── .github/workflows/
│   ├── app-ci.yml                # ← PR1: typecheck·lint·build (paths: app/**)
│   ├── claude.yml                # ← PR1: @claude 봇
│   └── app-deploy.yml            # ← PR2: 배포 + 프리뷰 코멘트 + 시각 QA
├── CLAUDE.md (+AGENTS.md 심링크)   # ← PR1: 루트 규약
├── .claude/skills/
│   ├── commit/ · pr/             #    기존 유지
│   ├── verify-app/               # ← PR1: 검증 게이트 절차
│   └── next-best-practices/      # ← PR1: Vercel 공식 스킬 vendoring
├── .coderabbit.yaml              # ← PR1: frontend→app, backend→server 경로 수정
├── docs/superpowers/specs/       #    이 문서
└── README.md                     # ← PR1: dev 서버 구동 문서화 (+CodeRabbit 문단 경로 갱신)
```

## PR1 — #33: 스캐폴딩 + 에이전트 워크스페이스 + @claude

### 스캐폴딩

- `create-next-app` 최신 안정판: App Router, TypeScript(strict), Tailwind CSS v4, `src/` 디렉터리, import alias `@/*`
- ESLint 대신 **Biome**: `biome.json` 하나로 lint+format, CI에서는 `biome ci`
- Tailwind v4는 CSS-first 설정(`globals.css`의 `@import "tailwindcss"`) — `@theme` 커스텀 토큰 선언은 #38 몫이라 기본값 그대로 둔다
- 샘플 페이지(기본 홈)에서 Tailwind 클래스 적용 확인 (이슈 acceptance)
- `.nvmrc`(Node 22) + `app/package.json` engines 명시

### 에이전트 워크스페이스

- **루트 `CLAUDE.md`**: 레포 지도(`app/`=Next.js, `server/`=Spring Boot 예정), 커밋·브랜치·PR 규약 요약과 CONTRIBUTING 링크, 금지사항(main 직접 커밋 금지, `Closes #N` 필수 등)
- **`app/CLAUDE.md`**: 스택 명세, 명령어(`pnpm dev/build/typecheck/lint`), 코드 규약(Server Component 기본, `'use client'` 최소화 — CodeRabbit 지침과 동일 기준), **"app 작업 시 `next-best-practices` 스킬 필수 로드"**, 작업 완료 전 `verify-app` 실행 의무
- 두 위치 모두 `AGENTS.md`는 `CLAUDE.md`로의 심링크 — Codex가 같은 규약을 읽음 (기존 `.codex/skills → .claude/skills` 패턴과 동일)
- **`verify-app` 스킬**: `pnpm typecheck → pnpm lint → pnpm build` 3단 게이트를 절차화. 에이전트가 "완료" 주장 전 반드시 통과
- **`next-best-practices` 스킬**: `npx skills add https://github.com/vercel/nextjs-skills --skill next-best-practices`로 레포에 vendoring

### CI — `app-ci.yml`

- 트리거: PR + main push, `paths: app/**` (+ 워크플로우 자신)
- 잡: pnpm 셋업 → `pnpm typecheck` → `pnpm lint`(biome ci) → `pnpm build`
- **hard gate** — 실패 시 머지 불가

### @claude 봇 — `claude.yml`

- 공식 `anthropics/claude-code-action`, 트리거는 이슈/PR 코멘트의 `@claude` 멘션 (write 권한자만 — 액션 기본 동작)
- 인증: `CLAUDE_CODE_OAUTH_TOKEN` secret (Max 구독에서 `claude setup-token`으로 발급 — 추가 과금 없음, 사용량은 토큰 소유자 Max 한도 차감. 팀 합의됨)
- 플로우: 이슈 본문+코멘트를 컨텍스트로 브랜치 생성 → CLAUDE.md·스킬 규약대로 구현·푸시 → **PR 생성 링크 코멘트** (GitHub 재귀 방지 정책상 봇이 연 PR은 CI가 안 돌므로, 사람이 링크 클릭으로 PR 오픈 — 의도된 최소 게이트키핑)
- PR 오픈 후에는 사람 PR과 동일하게 CI·CodeRabbit·(PR2 이후) 배포·QA 자동 적용

### CodeRabbit 정합

- `.coderabbit.yaml`: `frontend/**`→`app/**`, `backend/**`→`server/**` (path_instructions·path_filters 모두)
- README의 CodeRabbit 문단도 같은 경로로 갱신
- 이유: 현재 설정은 존재하지 않을 폴더명을 가리켜 경로별 리뷰 지침이 전혀 적용되지 않음

### 이슈 #33 acceptance 매핑

| Acceptance | 구현 |
|---|---|
| `app/`에 Next.js(App Router, TS) 초기화 | create-next-app 스캐폴딩 |
| Tailwind 설정 + 샘플 페이지 적용 확인 | v4 기본 설정 + 홈 페이지 검증 |
| Biome 적용 | biome.json + CI `biome ci` |
| 로컬 dev 서버 구동 문서화 | README에 사전 요구사항·명령어 |
| (본문 메모) 디자인 규약/API 명세 | **범위 제외** — #38·#39의 몫 (사용자 확인) |

## PR2 — #46: 배포 + 시각 QA

### `app-deploy.yml` — 잡 3개 체이닝, `app/**` 변경 시만

**잡 1 — 배포**: `vercel build` + `vercel deploy --prebuilt` (PR=프리뷰, main push=`--prod`). Git 연동이 아닌 CLI 배포라 org 레포+Hobby 무료 제약을 우회. 프리뷰 URL을 잡 output으로 전달. 시크릿: `VERCEL_TOKEN`·`VERCEL_ORG_ID`·`VERCEL_PROJECT_ID`

**잡 2 — 프리뷰 코멘트**: PR에 프리뷰 URL을 **sticky 코멘트**(푸시마다 기존 코멘트 갱신)로 게시

**잡 3 — 시각 QA**:

```ts
// app/e2e/qa-routes.ts — 라우트별 QA 설정
export const qaRoutes = [
  { path: '/', design: null },
  // #38 이후: { path: '/quiz', design: 'designs/quiz.png' } → 시안 대조 모드
]
```

1. `qa-routes.ts`의 라우트를 Playwright로 순회, 모바일(390px)·데스크톱(1280px) 스크린샷
2. 엘리스 OpenAI 호환 API로 **GPT-5.2**(멀티모달)에 전송
   - `design: null` → **휴리스틱 모드**: 깨진 레이아웃·겹침·대비·터치 타깃·반응형 점검
   - `design` 지정 → **대조 모드**: 원본 시안 + 구현 스크린샷을 나란히 주고 색·간격·타이포·누락 컴포넌트 차이 리포트
3. 결과를 "🎨 AI 시각 QA" sticky 코멘트로 게시, 스크린샷 원본은 워크플로우 아티팩트 첨부
4. **soft gate** — PR을 막지 않음(오탐 감안, 신뢰 쌓이면 승격 검토). `ELICE_API_KEY` 부재 시 QA만 우아하게 스킵(배포·프리뷰는 정상) — 키는 별도 등록 예정이며 등록 즉시 활성화

### 환경변수 관리 (이슈 acceptance)

- 런타임 env(`NEXT_PUBLIC_API_URL` 등)는 Vercel 프로젝트 env에서 관리, README에 목록 표 문서화
- CI 시크릿 5개: `VERCEL_TOKEN` `VERCEL_ORG_ID` `VERCEL_PROJECT_ID` `ELICE_API_KEY` `CLAUDE_CODE_OAUTH_TOKEN`

## 보안

- 시크릿은 GitHub secret으로만 존재. fork PR에는 GitHub이 secret을 제공하지 않으므로 외부 유출 경로 차단 (팀은 내부 브랜치 기반 작업)
- `@claude`는 write 권한자 멘션만 반응
- 엘리스로 나가는 데이터는 스크린샷·공개 코드 컨텍스트로 한정

## 에러 처리

| 상황 | 동작 |
|------|------|
| CI 게이트 실패 | PR 머지 블록 (hard) |
| Vercel 배포 실패 | 워크플로우 실패 표시, 프리뷰 코멘트 미게시 |
| 엘리스 API 장애·키 부재 | QA만 스킵, 배포·프리뷰 정상 (soft) |
| @claude 작업 실패 | 이슈 코멘트로 실패 보고, 사람 인계 |

## 검증 계획

**PR1**: ① 로컬 `pnpm dev` + 샘플 페이지 Tailwind 적용 확인 ② `verify-app` 3단 게이트 통과 ③ 테스트 이슈에 `@claude` 멘션 스모크(브랜치·구현·코멘트 확인) ④ CodeRabbit이 `app/**` 지침으로 리뷰하는지 확인

**PR2**: ① PR 오픈 → 프리뷰 URL 코멘트 확인 + 실제 접속 ② main 머지 → 프로덕션 배포 확인 ③ 키 부재 시 QA 스킵 확인 → 키 등록 후 QA 코멘트 재확인

## 범위 제외 (명시)

- 디자인 규약 문서·디자인 토큰(`@theme`)·공통 컴포넌트 뼈대 → **#38**
- API 명세 문서·타입 codegen → **#39** (서버 API 규격 설계 후)
- `shared/` 및 pnpm 워크스페이스 → 필요 시점에 도입
- e2e 테스트 스위트 → 시각 QA용 Playwright만 도입 (기능 테스트는 화면 이슈에서)
- GitHub App 토큰 기반 PR 자동 오픈 → 필요해지면 후속

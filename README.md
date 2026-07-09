# thumbsup
Thumbs Up — 학습 앱 모노레포 (app + server)

**프로덕션**: https://thumbsup-app.vercel.app

AI agent skills are shared across clients:
- Claude Code: `.claude/skills/`
- Codex: `.codex/skills/` -> `.claude/skills/` symlink

## 로컬 개발 (app)

사전 요구사항: Node 22 (`.nvmrc`, `nvm use`), pnpm 10 (`corepack enable`)

```bash
cd app
pnpm install
pnpm dev   # http://localhost:3000
```

품질 게이트(머지 전 필수): `pnpm typecheck && pnpm lint && pnpm build`

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
| `ELICE_QA_BASE_URL` | GitHub Secrets | 시각 QA 엔드포인트 (`/v1`까지, public 레포 로그 노출 방지로 Secret) |
| `ELICE_QA_MODEL` | GitHub Variables | QA 모델 ID (기본 `gpt-5.2`) |
| `CLAUDE_CODE_OAUTH_TOKEN` | GitHub Secrets | `@claude` 봇 인증 |
| `NEXT_PUBLIC_API_URL` | 로컬 `.env.local` / 배포는 **Vercel 환경변수 필수** | 앱이 호출할 API base URL. 로컬(`next dev`)은 미설정 시 로컬 서버 `:8080` 기본. 배포(Preview·Prod)는 이 값을 **반드시 등록**한다(운영 주소는 소스에 두지 않음). 미설정 시 앱이 부팅에 실패해 누락을 즉시 드러낸다 |

> `QA_TARGET_URL`(시각 QA 대상 주소)은 위 표에 없다 — CI가 배포 잡의 프리뷰 URL을 자동으로 주입한다. 로컬에서 QA를 직접 돌릴 때만 `QA_TARGET_URL=http://localhost:3000` 형태로 지정하며, 자세한 사용법은 `visual-qa` 스킬을 참고한다.

> 배포(Preview·Production)에서는 `NEXT_PUBLIC_API_URL`을 Vercel 프로젝트 → Settings → Environment Variables에 **반드시 등록**한다 — 운영 API 주소를 공개 소스 레포에 하드코딩하지 않기 위함이다. 미설정 상태로 배포하면 앱이 부팅 시 명시적으로 실패해 누락을 즉시 드러낸다. 로컬 개발은 `next dev`가 자동으로 로컬 서버(`:8080`)를 기본값으로 쓴다.

## CodeRabbit 리뷰

이 저장소는 CodeRabbit를 사용해 Pull Request 단위의 자동 코드 리뷰를 수행한다.

- 목적: PR에서 놓치기 쉬운 구현 결함, 타입/에러 처리, 보안·접근성 이슈를 빠르게 점검한다.
- 적용 범위: `.coderabbit.yaml` 기준으로 PR 변경 파일을 리뷰하며, `app/**`와 `server/**`에 각기 다른 리뷰 지침을 적용한다.
- 제외 범위: 빌드 산출물, 커버리지, `node_modules`, 락파일 등 리뷰 가치가 낮은 경로는 제외한다.

리뷰가 달리면 PR 대화와 Checks에서 CodeRabbit 코멘트를 확인하고, 필요한 수정 커밋을 같은 브랜치에 추가한다. 설정 변경이 필요하면 `.coderabbit.yaml`을 수정하고 관련 문서도 함께 갱신한다.

---
name: frontend-onboarding
description: 백엔드 개발자가 app/(Next.js) 프론트 작업을 맡을 때의 온보딩 지도. 환경 준비물·개발 서버, 프론트 코드 3층 구조(Spring 대응), 작업 순서, 단계별 필수 스킬 라우팅을 안내한다. 규칙 정본은 각 스킬·문서 링크로 참조. 사용자가 "프론트 처음인데", "app 작업 뭐부터 해", "화면 어떻게 만들어", "프론트 환경 세팅", "서버만 하다가 프론트 맡았어"라고 할 때 트리거.
---

# frontend-onboarding — 백엔드 개발자를 위한 프론트 개발 지도

서버만 하던 사람이 `app/` 이슈를 맡았을 때 "무엇을 준비하고, 어디에 코드를 쓰고, 어떤 스킬로 작업하는가". [`docs/frontend-server-dev-guide.md`](../../../docs/frontend-server-dev-guide.md)(FE→서버)의 반대 방향 지도다. 규칙의 **정본은 `app/CLAUDE.md`와 각 스킬** — 여기서 규칙을 다시 쓰지 않는다.

## 30초 빠른 시작

준비물은 Node ≥22, pnpm 10(`package.json`의 `packageManager` — corepack이면 자동). Java·Docker·AWS 전부 불필요.

```bash
cd app && pnpm install
pnpm dev         # http://localhost:3000

# 별도 터미널에서 (dev가 포그라운드를 점유):
pnpm storybook   # http://localhost:6006 — 공통 컴포넌트 카탈로그(뭐가 있는지 먼저 본다)
```

- **백엔드 서버는 띄울 필요 없다.** `NEXT_PUBLIC_API_URL` 미설정 시 클라이언트가 prod API(`https://thumbsup-api.duckdns.org`)로 폴백하고, 서버 CORS가 `localhost:3000`을 허용한다. 서버부터 기동하려는 습관은 여기선 불필요 — 로컬 서버에 붙일 때만 `.env.local` 설정(`frontend-api` 스킬 참조).
- ⚠️ **그 폴백은 진짜 운영 API·운영 DB다.** 회원가입·쓰기 요청이 실데이터로 남는다 — 개발용 더미 계정만 쓰고 실명·실이메일을 넣지 말 것. 삭제·수정 같은 쓰기 동작을 반복 테스트할 땐 로컬 서버를 띄워서(`thumbsup-local-server` 스킬) 한다.
- **git worktree라면 그 worktree 안에서 `pnpm install`부터.** 다른 체크아웃의 `node_modules`를 심링크로 끌어오면 Turbopack이 패닉해 빌드가 깨진다.
- API 대부분이 Bearer 인증 — 개발용 계정이 없으면 앱에서 회원가입해 하나 만들어 둔다.

## 구조 — Spring에 대응시키면

화면 하나는 3층으로 나뉜다. 최소 완전 예제는 `/profile` — **새 화면은 이 다섯 파일을 열어 그대로 모사**한다.

| 파일 | 역할 | Spring 비유 |
|---|---|---|
| `src/app/profile/page.tsx` | 라우트 껍데기(12줄) — 인증 게이트로 감싸고 Screen 렌더 | Controller |
| `src/features/profile/components/profile-screen.tsx` | 데이터 로딩 + 로딩/에러/성공 상태 분기 | Service |
| `src/features/profile/components/profile-page.tsx` | 순수 UI — props로 받은 데이터만 그림 | View |
| `src/features/profile/api.ts` · `types.ts` | 서버 응답 타입 → 화면용 타입 매핑 | DTO 매퍼 |

공통 부품: `src/components/ui/`(Button·Card·Chip·Progress·Skeleton·EmptyState…)에서 조립하고, 없는 것만 만든다. 두 API를 합쳐야 하면 `src/features/home/api.ts`(`Promise.all` 매핑)가 레퍼런스.

## 작업 순서

1. **이슈 확인·분리** — 같은 화면이라도 앱/서버 작업은 티켓 분리(CONTRIBUTING §4). 필요한 데이터가 서버 응답에 없으면 서버 이슈를 따로 끊고 **응답 스키마부터 확정**(프론트는 목 데이터로 병렬 진행 가능).
2. **브랜치** `<type>/<이슈번호>-<슬러그>` — main 직접 커밋 금지.
3. **스킬 로드** — 아래 라우팅 표의 필수 3종을 코드 작성 전에.
4. **구현** — `/profile` 패턴 모사.
5. **검증** — `verify-app` 게이트 전부 통과. UI를 바꿨으면 `visual-qa`도.
6. **커밋·PR** — `commit` 스킬 → `pr` 스킬(`Closes #이슈` 필수, Squash merge).

## 스킬 라우팅

| 상황 | 로드할 스킬 |
|---|---|
| Next.js 코드를 만지는 모든 작업 | `next-best-practices` (필수) |
| UI·스타일·컴포넌트 | `design-system` (필수) — 토큰·`components/ui`·스토리 규칙 |
| API 연동·소비 | `frontend-api` (필수) — envelope·토큰·에러 분기 |
| 완료 보고 전 | `verify-app` — typecheck→lint→build→check:design |
| UI 변경 후 자가 점검 | `visual-qa` |
| FE e2e용 로컬 서버가 필요할 때 | `thumbsup-local-server` |
| 배포·프리뷰 확인 | `deploying` |

## 백엔드 습관이 일으키는 함정

각 항목의 세부 규칙은 여기 다시 쓰지 않는다 — 함정의 존재만 알리고, 정본 스킬에서 확인한다.

- **`fetch()` 직접 호출 금지** — `src/lib/api`의 `apiRequest()`만 쓴다. 인증·응답 처리 규칙의 정본은 `frontend-api`.
- **CSS 파일 생성·`style={{}}` 금지** — 토큰 유틸리티만 허용되고 `check:design` 게이트가 강제한다. 스타일 규칙의 정본은 `design-system`.
- **`userId`를 쿼리/바디로 보내지 않는다** — 서버가 토큰에서 식별한다(상세는 `frontend-api`).
- **`'use client'` 남발 금지** — Server Component가 기본(`next-best-practices`).
- **엔드포인트 존재 여부의 정본은 Swagger UI·서버 컨트롤러 코드** — 스킬·문서 속 엔드포인트 표는 낡을 수 있다. 표만 믿고 "없다"고 단정하지 말 것.

## 막힐 때

| 증상 | 먼저 확인할 것 |
|---|---|
| API가 401 | 로그인 상태·토큰. 재발급까지 실패했다면 로그인 화면으로 이동하는 것이 정상 동작 |
| CORS 에러 | origin이 `localhost:3000`인지, `.env.local` 값 끝 슬래시(더블 슬래시 유발) |
| 빌드가 Turbopack 패닉 | worktree에서 심링크 `node_modules` 쓰지 않았는지 — 그 자리에서 `pnpm install` |
| `check:design` 실패 | raw hex·arbitrary value·스토리 누락(`design-system` 스킬) |
| 포트 충돌 | `lsof -nP -iTCP:3000 -sTCP:LISTEN` |

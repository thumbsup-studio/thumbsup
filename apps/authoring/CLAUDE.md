# authoring — 문제 저작 도구 규약

스택: Next.js(App Router) · TypeScript strict · Tailwind CSS v4 · Biome · pnpm · Node 22 — `apps/web`과 같다.

ADMIN 전용 도구다. 회원가입이 없고 일반 사용자 화면도 없다. 문제 생성·검수·개선·승인만 한다.

## 명령어

```bash
pnpm dev          # http://localhost:3000 (apps/web과 포트가 겹친다)
pnpm typecheck    # tsc --noEmit
pnpm lint         # biome check (자동수정: pnpm lint:fix)
pnpm build        # 프로덕션 빌드
pnpm test         # vitest
pnpm check:design # 토큰 규칙 검사
```

## 제일 먼저 알아야 할 것

- **승인에 되돌리는 API가 없다.** 로컬 개발 시 `.env.local`에 `NEXT_PUBLIC_API_URL=http://localhost:8080`을 반드시 넣는다. 미설정 시 기본값이 운영 API라, 로컬 화면으로 운영 데이터를 건드리게 된다.
- **라이브 반영 시점은 draft의 origin에 따라 다르다.** `NEW`와 `IMPROVE`는 승인 즉시 라이브에 쓰인다. `OUTLINE_STEP`은 승인 시 검증만 하고 별도 발행(`POST /authoring/outlines/{id}/publish`)에서 한꺼번에 라이브로 간다. 서버의 `AuthoringApprovalService`가 정본이다. outline 승인을 발행 완료로 오해하지 않는다.
- 문제 생성·개선·브리지 작업은 **`quiz-authoring` 스킬**이 정본이다. 앱은 잡을 만들고 로그를 보여줄 뿐 브리지와 직접 통신하지 않는다.
- Next.js 코드를 만지면 **`next-best-practices` 스킬을 반드시 로드**한다.
- 배포·CORS·도메인의 정본은 [`docs/deploy.md`](./docs/deploy.md)다.

## 코드 구조

`apps/web`의 3층 구조를 따른다. 라우트 파일은 얇게, 화면은 `features/` 아래, 서버 계약은 `api.ts`·`types.ts`에 둔다.

```text
src/
├─ app/                    라우트. (dashboard) 그룹이 RequireAdmin으로 감싼다
├─ features/
│  ├─ auth/                RequireAdmin · 로그인 폼 · 로그아웃
│  └─ authoring/           api.ts · types.ts · sse.ts · components/
├─ lib/api/                @thumbsup/api 클라이언트 인스턴스
└─ test/                   테스트 (소스 옆이 아니라 여기 모은다)
```

- 화면은 `features/authoring/` 단일 도메인에 모여 있다. `apps/web`처럼 도메인별로 쪼개지 않는다.
- **`src/components/`를 만들지 않는다.** 공용 UI는 `@thumbsup/ui-web`에서 **직접** import한다. `apps/web`은 `src/components/ui`에 re-export shim을 두지만 저작 앱은 두지 않는다.
- 대시보드 page는 전부 `export const dynamic = "force-dynamic"`이다.
- 동적 세그먼트는 `await params` 후 숫자 검증에 실패하면 `redirect()`로 방어한다.

새 화면을 추가하면 라우트 파일, `features/authoring/components/<이름>-screen.tsx`, `api.ts`, `types.ts`, `src/test/`의 테스트를 함께 만든다. 내비게이션이 필요하면 `src/app/(dashboard)/layout.tsx`도 고친다.

## 인증

- 게이트는 **클라이언트 사이드**다. `features/auth/require-admin.tsx`가 마운트 시 프로필을 조회해 `role === "ADMIN"`이 아니면 로그인으로 보낸다. 미들웨어나 서버 세션 검사는 없다.
- 화면마다 2차 방어를 둔다. `ApiError.status`가 401이면 `/login`, 403이면 목록으로 돌린다. 세션 중 권한이 바뀌는 경우를 위한 것이므로 새 화면에서도 빼지 않는다. 목록·draft 상세·코스 화면은 둘 다 처리하지만 **잡 화면은 401만 처리하고 403 분기가 없다.** 기존 코드를 복사할 때 그대로 따라가지 않는다.
- API 호출은 `@thumbsup/api` 공용 클라이언트만 쓴다. envelope 언랩, Bearer 부착, 토큰 재발급이 그 안에 있다. **`fetch()`를 직접 쓰지 않는다.** 규칙의 정본은 `frontend-api` 스킬이고, 계층 위치만 `src/lib/api`로 다르다.

예외가 하나 있다. 잡 로그 스트림은 `EventSource`가 Authorization 헤더를 못 붙여서 `features/authoring/sse.ts`가 `fetch` + `ReadableStream`으로 직접 파싱한다. 스트림을 건드릴 때는 그 파일의 주석을 먼저 읽는다.

## 스타일

`globals.css`가 `apps/web`과 바이트 단위로 같고 `check:design` 스크립트도 주석 한 줄 빼고 동일하다. 따라서 토큰 규칙이 그대로 강제된다.

- 원시 hex와 Tailwind arbitrary value(`x-[...]`)를 쓰지 않는다. 예외는 그 줄에 `design-ok` 주석으로만.
- 색은 `@thumbsup/tokens`에 추가한 뒤 토큰으로 참조한다.
- 새 공용 컴포넌트를 만들면 `packages/ui-web/stories/`에 스토리를 함께 만든다. `check:design`이 누락을 잡는다. **저작 앱에는 Storybook 스크립트가 없으므로** 카탈로그 확인은 `apps/web`에서 `pnpm storybook`으로 한다.

`design-system` 스킬의 토큰·접근성·모션 규칙은 그대로 적용된다. 다만 그 스킬이 가리키는 `apps/web/DESIGN.md`와 `src/components/ui`는 저작 앱에 없다. 컴포넌트 출처는 `@thumbsup/ui-web`, 토큰 정의는 `packages/tokens`로 바꿔 읽는다. 사용자 화면 시안 매핑은 저작 도구에 해당하지 않는다.

## 테스트

`vitest` + `jsdom`. 테스트는 `src/test/`에 평평하게 모은다. 화면 테스트는 렌더 중심이고, **401·403 리다이렉트를 필수 케이스로 다룬다.** 새 화면을 추가하면 그 두 케이스를 빼지 않는다.

## 완료 기준

- `verify-app` 스킬의 Authoring 게이트 다섯 가지를 모두 통과한 뒤에만 완료 보고한다
- 게이트 실패 상태로 커밋하지 않는다
- 커밋 scope는 `authoring`이다

## 의존하는 공용 패키지

| 패키지 | 쓰임 |
| --- | --- |
| `@thumbsup/api` | 서버 API 클라이언트. 유일한 호출 경로다 |
| `@thumbsup/ui-web` | 공용 UI. 서브패스로 직접 import한다 |
| `@thumbsup/tokens` | 디자인 토큰. `globals.css`에서 한 번 import |

`@thumbsup/core`는 **직접 의존하지 않는다.** 문제를 푸는 도메인 로직(채점·진행률·정답 연출)이라 저작 화면에서 쓸 일이 없다. 다만 `@thumbsup/api`가 공유 타입 때문에 core를 자체 선언하므로 전이 의존은 남아 있다. 저작 앱 코드에서 core를 직접 import하지 않는다는 뜻이다.

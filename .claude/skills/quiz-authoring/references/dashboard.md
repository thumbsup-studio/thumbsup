# 저작 대시보드 (`app/src/features/authoring/`)

ADMIN 전용 웹 화면. 여기서 잡을 만들면 브리지가 집어가고([bridge.md](./bridge.md)), 결과 초안을 검수·승인하면 라이브에 반영된다.

## 화면 지도

| 라우트 | 화면 | 하는 일 |
|---|---|---|
| `/authoring` | `drafts-screen` | 초안 목록. `DRAFT`/`APPROVED` 필터, "문제 생성" 버튼 |
| `/authoring/drafts/[draftId]` | `draft-detail-screen` | 초안 전문 + 검수 이력. `status=DRAFT`일 때만 검수·승인 버튼 노출 |
| `/authoring/jobs/[jobId]` | `job-screen` | 잡 실행 터미널(xterm + SSE) |
| `/authoring/quizzes` | `courses-index-screen` | 라이브 코스 목록 |
| `/authoring/quizzes/[course]` | `course-quizzes-screen` | 스텝·문제 아코디언 + "개선" 진입 |

레이아웃(`app/src/app/authoring/layout.tsx`)이 전체를 `<RequireAdmin>`으로 감싸고, 각 페이지는 다시 `<RequireAuth>`로 감싼다(이중 가드). 5개 페이지 모두 `force-dynamic`.

**앱 어디에도 `/authoring`으로 가는 링크가 없다.** ADMIN이 홈에 있다가 저작으로 가려면 URL을 직접 치거나 재로그인해야 한다. 반대로 저작 화면에서 나가는 로그아웃 진입점도 없다(#216).

## 워크플로우

세 가지 잡 생성 액션은 **예외 없이 잡 터미널 화면으로 강제 이동**한다. 목록으로 돌아오는 길은 상단 nav나 브라우저 뒤로가기뿐이다.

```text
생성   /authoring → "문제 생성" → 주제 입력 → POST /drafts/generate → /jobs/{id}
                                                    → 완료 시 "Draft 보러가기" → /drafts/{id}

검수   /drafts/{id} → "검수 시작" → 피드백(선택) → POST /drafts/{id}/reviews → /jobs/{id}
                                                    → 완료 후 돌아오면 revisions 1건 증가

개선   /authoring/quizzes → 코스 → 스텝 펼침 → 문제 펼침 → "개선" → 지시(필수)
                        → POST /quizzes/{quizId}/improve → /jobs/{id} → origin=IMPROVE 초안

승인   /drafts/{id} → "승인" → 경고 확인 → POST /drafts/{id}/approve
                        → 즉시 라이브. status=APPROVED가 되며 검수·승인 버튼이 사라진다
```

검수 피드백은 **선택**(비우면 일반 검수), 개선 지시는 **필수**다.

## API

전부 `apiRequest`(`lib/api/client.ts`) 경유 — envelope 언랩 · Bearer 자동 부착 · 401 `TOKEN_EXPIRED` 1회 refresh 재시도. 규약은 `frontend-api` 스킬 참조.

`app/src/features/authoring/api.ts`에 전량 모여 있으니 목록은 그 파일을 읽어라. 계약을 바꾸면 `app/src/test/authoring-api.test.ts`가 먼저 깨진다(URL·메서드·body·언랩까지 검증).

주의할 두 가지:
- `getAuthoringQuizzes`(`GET /authoring/quizzes`)는 **어느 화면도 쓰지 않는 죽은 코드**다. 라이브 화면은 `/authoring/courses` 계열을 쓴다.
- `getDrafts()`를 status 없이 부르면 **서버가 400**이다(`@RequestParam`이 필수). UI는 항상 필터를 넘겨서 현재는 드러나지 않는다.

## ⚠️ 로컬에서 운영 DB를 건드릴 수 있다

`NEXT_PUBLIC_API_URL`이 없으면 기본값이 **운영 API**다(`lib/api/client.ts`). 로컬 `pnpm dev`로 대시보드를 켜면 그대로 **운영에 초안을 만들고 운영 문제를 승인**한다.

로컬 풀스택 테스트 시 `.env.local`에 `NEXT_PUBLIC_API_URL=http://localhost:8080`을 **반드시** 넣어라. 서버 기동은 `thumbsup-local-server` 스킬.

## SSE 터미널 — 오해하기 쉬운 동작

`sse.ts` + `use-job-log-stream.ts`. EventSource가 아니라 `fetch` + `ReadableStream` 수동 파싱이다(Authorization 헤더를 붙여야 해서).

| 관찰 | 실제 |
|---|---|
| 30분 넘긴 잡이 "로그를 불러오지 못했어요"로 바뀜 | 서버 emitter 타임아웃이 **30분**(`JobLogStreamService`). 조용한 EOF 뒤 `getJob` 재확인에서 아직 RUNNING이면 error 표시 — **잡은 살아 있다** |
| 재시도·새 탭마다 로그가 처음부터 쏟아짐 | `fromSeq`를 안 보내서 서버가 매번 seq 0부터 전량 리플레이한다 |
| 에러 화면이 되면 그때까지 로그가 통째로 사라짐 | `phase==="error"`면 TerminalViewer가 언마운트된다. **로그 정본은 `job_log` 테이블** |
| SSE에서 401이 나도 로그인으로 안 보냄 | `sse.ts`가 평범한 `Error`를 던져 `unauthorized` 분기를 못 탄다. 로그인 유도는 선행 `getJob`이 401일 때만 |
| "브리지 대기 중"이 계속 뜸 / 첫 로그에 바로 RUNNING | 이건 **휴리스틱**이다 — `streaming && 초기상태 QUEUED && 로그 0줄`. SSE가 QUEUED→RUNNING 전이를 안 알려줘서 첫 줄 도착으로 대신 판정한다. 서버 실제 상태와 별개 |

**자동 재연결이 없다.** 새로고침이나 화면의 "재시도" 버튼(스트림 리마운트)뿐이다.

서버 팬아웃은 **인메모리 = 단일 인스턴스 전제**다. 서버를 2대 이상으로 늘리면 로그 스트림이 깨진다.

## 폴링·갱신이 없다

목록·상세·코스 화면 모두 **마운트 시 1회 조회**가 전부다. 낙관적 업데이트도 없다.

- 잡이 끝나고 목록으로 돌아와도 **자동 갱신되지 않는다**. 필터 버튼을 눌러 재조회하거나 새로고침해야 한다.
- 로딩 중엔 부분 갱신이 아니라 **전체 스켈레톤**으로 되돌아간다. 필터를 바꿀 때마다 리스트가 사라졌다 나타나는 건 정상이다.

"승인했는데 목록에 그대로네?" 는 버그가 아니라 이 설계다.

## 에러 토스트

전용 문구가 있는 건 두 개뿐이다 — `AUTHORING_DRAFT_JOB_ACTIVE`("진행 중인 잡이 있습니다"), `AUTHORING_IMPROVE_DRAFT_EXISTS`("이미 열린 개선 draft가 있습니다"). 나머지 `AUTHORING_*` 코드(`AuthoringErrorType`)는 **서버 message를 그대로** 보여준다.

시트에서 실패하면 입력값과 시트를 그대로 유지한다(성공했을 때만 닫고 이동).

## 인증 가드

Next.js **미들웨어가 없다.** 라우트 보호가 전부 클라이언트 컴포넌트 가드라, 비ADMIN이 `/authoring`을 직접 열면 `fetchMe` 왕복만큼 빈 화면을 본 뒤 `/`로 튕긴다. 서버는 fail-closed라 데이터 유출은 없다.

ADMIN 판정은 **오직 `GET /auth/me`의 `role`** 이다 — 프론트에서 JWT를 디코드하지 않는다. 로그인 후 `/authoring`으로 보내는 분기는 `login-form.tsx`와 `redirect-if-authenticated.tsx` 두 곳. `RequireAdmin`은 레이아웃 마운트당 1회만 검증하므로 저작 내부 이동에선 재검증되지 않는다.

**회원가입 직후엔 role 분기가 없다** — 무조건 홈으로 간다.

권한이 안 풀리는 문제는 [ADMIN 게이트](../SKILL.md#admin-게이트-fail-closed)를 볼 것.

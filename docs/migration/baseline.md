# 웹 사용자 라우트 마이그레이션 기준선

이 문서는 React Native 이식이 끝났는지 판단하는 웹 기준선이다. 기준 코드는 `origin/main`의 `75f4579ad21c`(2026-09-06)이며, 2026-09-08에 실제 코드를 읽어 표를 작성했다. `/authoring/*` 5개 라우트는 모바일 사용자 앱 범위가 아니므로 제외한다.

## 실측 근거

다음 명령은 저장소 루트에서 실행했다.

| 확인 항목 | 명령 | 결과 |
|---|---|---:|
| 전체 페이지 | `find app/src/app -name page.tsx \| wc -l` | 17 |
| 저작 페이지 | `find app/src/app/authoring -name page.tsx \| wc -l` | 5 |
| 사용자 페이지 | `find app/src/app -name page.tsx ! -path '*/authoring/*' \| wc -l` | 12 |
| 사용자 `page.tsx`의 `use client` | `find app/src/app -name page.tsx ! -path '*/authoring/*' -print0 \| xargs -0 grep -lE "^[\"']use client[\"']" \| wc -l` | 0 |
| `redirect()`를 직접 쓰는 사용자 페이지 | `find app/src/app -name page.tsx ! -path '*/authoring/*' -print0 \| xargs -0 grep -l 'redirect(' \| wc -l` | 3 |
| `metadata`를 직접 선언하는 사용자 페이지 | `find app/src/app -name page.tsx ! -path '*/authoring/*' -print0 \| xargs -0 grep -l 'metadata' \| wc -l` | 2 |
| `force-dynamic` 사용자 페이지 | `find app/src/app -name page.tsx ! -path '*/authoring/*' -print0 \| xargs -0 grep -l 'force-dynamic' \| wc -l` | 10 |
| 라우트별 상태 파일 | `find app/src/app -type f \( -name 'loading.tsx' -o -name 'error.tsx' -o -name 'not-found.tsx' -o -name 'offline.tsx' \) \| wc -l` | 0 |

API 연결은 `rg -n 'apiRequest' app/src/lib/api app/src/features --glob '*.ts' --glob '*.tsx'`로 정의를 찾고, 각 `page.tsx`의 import에서 화면 컴포넌트까지 따라가 호출부를 확인했다. 접근성 후보는 `rg -n 'aria-|alt=|tabIndex|onKey|focus\\(|prefers-reduced-motion|usePrefersReducedMotion' app/src --glob '*.tsx' --glob '*.ts' --glob '*.css'`로 찾은 다음 해당 컴포넌트를 읽었다.

## 라우트와 상태 기준선

여기서 구성은 `page.tsx` 자체를 가리킨다. 모든 페이지는 서버 컴포넌트다. `클라이언트 화면`으로 표시한 하위 컴포넌트가 실제 상태와 상호작용을 맡는다. `metadata`가 없는 라우트는 루트 레이아웃의 `Thumbs Up`·`개발자 학습 앱` 값을 상속한다. 상태 표기의 `전용 없음`은 오프라인을 일반 오류와 구분하지 않는다는 뜻이다.

| 경로 | 담당 feature | 구성 | 서버 기능 | 로딩 | 빈 상태 | 오류 | 오프라인 |
|---|---|---|---|---|---|---|---|
| `/` | `features/home` | 서버 → `HomeScreen` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | `HomeSkeleton` | 별도 UI 없음. API 계약상 코스 1개 이상 | 전체 `EmptyState`와 재시도; 401은 `/login` | 전용 없음 |
| `/login` | `features/auth`, `features/profile` | 서버 → 인증 가드·폼 클라이언트 | metadata 직접 선언; force-dynamic·redirect 없음 | 제출 버튼 및 인증 확인 중 빈 화면 | 해당 없음 | 통합 로그인 오류와 재시도 버튼 | `NetworkError` 전용 문구 |
| `/signup` | `features/auth` | 서버 → 인증 가드·폼 클라이언트 | metadata 직접 선언; force-dynamic·redirect 없음 | 제출 버튼 및 인증 확인 중 빈 화면 | 해당 없음 | 필드·폼 오류 | `NetworkError` 전용 문구 |
| `/course` | `features/course` | 서버 → `CoursePage` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | 카드 skeleton | 코스 0개 `EmptyState` | 인라인 오류와 재시도; 401은 `/login` | 전용 없음 |
| `/briefing` | `features/briefing`, `features/play` | 서버 → `BriefingScreen` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | 화면 skeleton | `courseId` 누락 안내 | 네트워크 문구와 재시도; API 코드에 따라 `/play`·`/course`로 우회 | 전용 분기 없이 오류 문구에서 연결 확인 안내 |
| `/play` | `features/play`, `features/history`, `features/home` | 서버 → `PlayPage` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | 문제 skeleton | 별도 UI 없음 | 로드·힌트·제출 오류를 각각 표시; 401은 `/login` | 전용 없음 |
| `/insight` | `features/play`, `features/history` | 서버 → `InsightPage` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | 해설 skeleton | 꼬리질문이 없으면 비활성 버튼 | 해설 오류와 재시도; 401은 `/login` | 전용 없음 |
| `/follow-up` | `features/play` | 서버 → `FollowUpPage` 클라이언트 | `force-dynamic`; 잘못된 `fq`는 `redirect()`; metadata 없음 | 화면 skeleton | 상세 404는 `준비 중` `EmptyState` | 전체 오류, 재시도·해설 복귀; 401은 `/login` | 전용 없음 |
| `/history` | `features/history-graph`, `features/history` | 서버 → `HistoryGraphPage` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | 그래프·상세 skeleton | 노드 0개 `EmptyState` | 인라인 오류와 재시도; 401은 `/login` | 전용 없음 |
| `/history/graph` | 없음 | 서버 전용 | `force-dynamic`; 즉시 `redirect('/history')`; metadata 없음 | 해당 없음 | 해당 없음 | 해당 없음 | 해당 없음 |
| `/history/done` | `features/history` | 서버 → 정적 `ReviewSummaryPage` | `force-dynamic`; 복습 문맥 누락 시 `redirect('/course')`; metadata 없음 | 해당 없음 | 해당 없음 | 해당 없음 | 해당 없음 |
| `/profile` | `features/profile`, `features/auth` | 서버 → `ProfileScreen`·`ProfilePage` 클라이언트 | `force-dynamic`; 직접 metadata·redirect 없음 | 프로필 skeleton, 전송·로그아웃 진행 표시 | 해당 없음 | 전체 오류와 재시도, 의견 전송 오류 토스트; 401은 `/login` | 전용 없음 |

`/`, `/course`, `/briefing`, `/play`, `/insight`, `/history`, `/history/done`, `/profile`은 `RequireAuth`로 감싼다. 이 가드는 `localStorage` 토큰만 확인해 비로그인 사용자를 클라이언트에서 `/login`으로 보낸다. `/follow-up`은 `RequireAuth`로 감싸지 않지만 인증 기본값인 API를 호출하며 401이면 `/login`으로 보낸다.

## API와 인증 기준선

표의 경로에는 공통 접두사 `/api/v1`을 붙인다. `apiRequest`는 별도 설정이 없으면 Bearer 토큰을 넣는다. `TOKEN_EXPIRED`일 때는 `POST /auth/refresh`를 한 번 호출한 뒤 원 요청을 다시 시도한다. 로그인 필수 라우트의 모든 호출에 이 재발급 요청이 조건부로 따라올 수 있다. ADMIN 전용 사용자 라우트는 없으며, ADMIN은 로그인 뒤 `/authoring`으로 이동한다.

| 경로 | 직접 또는 화면 액션으로 호출하는 엔드포인트 | 필요한 인증 상태 |
|---|---|---|
| `/` | `GET /home`, `GET /mascot` | 로그인 필수 |
| `/login` | `POST /auth/login`; 성공 뒤 `GET /auth/me`; 기존 토큰이 있으면 진입 가드도 `GET /auth/me` | 로그인 요청은 비로그인 허용; `/auth/me`는 로그인 필수 |
| `/signup` | `POST /auth/signup`; 기존 토큰이 있으면 진입 가드가 `GET /auth/me` | 가입 요청은 비로그인 허용; `/auth/me`는 로그인 필수 |
| `/course` | `GET /courses` | 로그인 필수 |
| `/briefing` | `GET /courses/{courseId}/next-step/briefing` | 로그인 필수 |
| `/play` | 일반 진입 `GET /quizzes/next?courseId={courseId}` 또는 `GET /quizzes/next`; 브리핑 진입 `GET /quiz-steps/{quizStepId}/quizzes/next`; 복습 `GET /quizzes/steps/{stepOrder}/{slotOrder}`; `POST /quizzes/{quizId}/hints`; `POST /quizzes/{quizId}/answers`; 마지막 문제 뒤 `POST /mascot/feed` | 로그인 필수 |
| `/insight` | `GET /quizzes/{quizId}/explanation` | 로그인 필수 |
| `/follow-up` | `GET /follow-up-questions/{followUpQuestionId}` | 로그인 필수(API 기준) |
| `/history` | `GET /history/graph` | 로그인 필수 |
| `/history/graph` | 없음. `/history`로 리다이렉트 | 로그인 판정 전에 리다이렉트 |
| `/history/done` | 없음 | 로그인 필수(`RequireAuth`) |
| `/profile` | `GET /auth/me`; 의견 보내기 `POST /feedbacks`; 로그아웃 `POST /auth/logout` | 로그인 필수 |

## 접근성 기준선

### 공통 기준

- 포커스 순서는 DOM 순서를 따른다. 화면을 이식할 때도 헤더의 뒤로 가기, 본문 입력·선택·주요 동작, 보조 동작, 하단 탭 순서를 유지한다. 로딩 중에는 중복 제출을 막도록 컨트롤을 비활성화한다. 오류 뒤 재시도 컨트롤은 키보드와 스크린리더로 접근할 수 있어야 한다.
- 모든 텍스트 입력은 보이는 레이블과 연결한다. 상태 변화는 기존 `aria-live`, `role="status"`, `role="alert"`, `aria-busy`에 대응하는 네이티브 접근성 알림으로 전달한다.
- 정보성 이미지에는 대체 텍스트를 제공하고 장식 이미지는 접근성 트리에서 제외한다. 현재 유일한 raster 이미지인 하단 탭 아이콘은 `alt=""`와 `aria-hidden="true"`를 함께 써 장식으로 처리하며, 탭의 텍스트 레이블과 `aria-current="page"`가 의미를 전달한다. 공용 SVG 아이콘도 기본적으로 `aria-hidden="true"`, `focusable="false"`다.
- 모든 버튼, 링크, 체크박스, 퀴즈 선택지, 키워드 툴팁은 키보드로 조작할 수 있어야 한다. 모달은 열릴 때 내부로 포커스를 옮기고 Tab을 가두며 Esc로 닫은 뒤 트리거로 되돌린다. 현재 `BottomSheet`는 이 동작을 구현하지만 키워드 툴팁은 Esc 닫기만 있고 포커스 이동·트랩·복귀가 없다.
- `globals.css`의 `prefers-reduced-motion: reduce` 규칙은 모든 CSS 애니메이션과 전환을 `0.01ms`로 줄인다. `motion-safe`는 skeleton·spinner·캐러셀·코스 펼침·그래프·프로필 오버레이·바텀시트에 쓰인다. `usePrefersReducedMotion` 훅의 실제 소비처는 `InsightPage`와 `FanfareOverlay`이며, 해설 축하 등급과 팡파레 유지 시간을 낮추거나 연출을 생략한다.

### 라우트별 포커스와 키보드 확인점

| 경로 | 현재 포커스·키보드 동선 | 이식 때 보존하거나 보완할 항목 |
|---|---|---|
| `/` | 코스 CTA → 캐러셀 이전/다음 → 하단 탭 | 스와이프만 강제하지 않고 이전/다음 버튼과 현재 위치 알림 유지 |
| `/login` | 이메일 → 비밀번호 → 표시 토글 → 비밀번호 찾기 → 제출 → 회원가입·약관·개인정보·도움말 | Enter 제출, 오류 알림, 로딩 중 비활성 유지 |
| `/signup` | 뒤로 → 이메일 → 비밀번호·표시 → 확인·표시 → 약관 체크 → 약관·개인정보 → 제출 → 로그인 | 체크박스의 `aria-labelledby` 대응 관계와 필드별 오류 연결 유지 |
| `/course` | 코스 펼침 버튼 → 열린 스텝 링크 → 하단 탭 | 펼침 상태 알림과 잠긴 스텝 비활성 상태 유지 |
| `/briefing` | 자세히 보기 → 문제 풀기 | 펼침 버튼의 제어 대상·상태 연결 유지 |
| `/play` | 뒤로 및 복습 이동 → 답안 선택·입력 → 힌트 → 정답 확인 | fieldset 레이블, 진행률 알림, 비활성·채점 상태 유지 |
| `/insight` | 뒤로 → 본문 키워드 버튼·툴팁 닫기 → 꼬리질문·다음 문제 | 키워드 모달에 포커스 이동·트랩·복귀를 추가하고 Esc 닫기 유지 |
| `/follow-up` | 해설 복귀 → 키워드 버튼·툴팁 닫기 → 답 확인·복귀·다음 | `/insight`와 같은 키워드 모달 보완 적용 |
| `/history` | canvas 노드 포인터 선택 → 관련 스텝 링크 → 하단 탭 | canvas 노드는 현재 키보드 선택 불가. 네이티브 이식에서는 탐색 가능한 노드 목록과 선택 상태를 제공 |
| `/history/graph` | 인터랙션 없이 리다이렉트 | `/history` 딥링크 치환 또는 호환 리다이렉트 검증 |
| `/history/done` | 코스로 돌아가기 → 다시 풀기 | 제목과 완료 상태를 먼저 읽고 두 CTA 순서 유지 |
| `/profile` | 설정·의견·로그아웃 → 하단 탭; 시트는 포커스 트랩·복귀; 로그아웃 완료 시 버튼으로 이동 | 모달 포커스 관리, 의견 입력 자동 포커스, 완료 알림 유지 |

## 라우트별 이식 완료 판정표

행 하나가 라우트 하나의 완료 게이트다. 각 칸의 기준을 모두 증빙한 뒤에만 체크한다. `/history/graph`처럼 호환 리다이렉트만 있는 경로도 딥링크 계약이므로 제외하지 않는다.

| 웹 경로 | 화면 | 상태 | API·인증 | 접근성 | 모바일 고유 |
|---|---|---|---|---|---|
| `/` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/login` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/signup` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/course` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/briefing` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/play` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/insight` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/follow-up` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/history` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/history/graph` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/history/done` | [ ] | [ ] | [ ] | [ ] | [ ] |
| `/profile` | [ ] | [ ] | [ ] | [ ] | [ ] |

각 칸은 다음 체크리스트로 판정한다.

#### 화면

- [ ] 정상 화면의 정보 구조, 문구, 진행 표시, 활성·비활성 조건과 주요 이동 목적지가 웹 기준선과 같다.
- [ ] URL 검색 파라미터에 대응하는 네이티브 라우트 파라미터와 딥링크를 검증했다.

#### 상태

- [ ] 로딩, 빈 상태, 오류와 재시도, 인증 만료, 오프라인·15초 타임아웃을 각각 재현하고 기대 화면을 확인했다.
- [ ] 웹에 전용 상태가 없는 경우에도 모바일에서 무한 대기나 빈 화면이 되지 않도록 명시적인 결과를 정했다.

#### API·인증

- [ ] 이 문서에 적힌 모든 엔드포인트의 method, path·query·body, 성공 응답 매핑을 검증했다.
- [ ] 비로그인 허용, 로그인 필수, ADMIN 분기와 access token 재발급·실패 동작을 검증했다.
- [ ] 중복 탭, 취소, 늦게 도착한 응답, 화면 이탈 뒤 응답을 안전하게 처리한다.

#### 접근성

- [ ] 스크린리더 읽기 순서와 키보드·외부 키보드 포커스 순서가 위 기준선과 같다.
- [ ] 이미지·아이콘의 대체 텍스트 또는 장식 제외, 상태 알림, 입력 레이블·오류 연결을 검증했다.
- [ ] 모든 동작을 터치 없이 실행할 수 있고 모달의 포커스 이동·트랩·복귀와 reduce motion을 검증했다.

#### 모바일 고유

- [ ] 상·하단 safe area에서 콘텐츠와 고정 CTA가 가리지 않는다.
- [ ] 소프트 키보드가 입력·오류·제출 버튼을 가리지 않고, 표시·숨김과 완료 액션이 정상 동작한다.
- [ ] 시스템 back button과 iOS back gesture의 목적지·차단 조건·미저장 상태 처리를 검증했다.
- [ ] background 전환 뒤 foreground로 복귀할 때 인증, 진행 상태, 요청 재시도·중복 실행이 안전하다.
- [ ] offline과 15초 timeout을 구분해 안내하고 연결 회복 뒤 재시도할 수 있다.
- [ ] 지원·비지원 회전 정책을 정하고 회전 뒤 레이아웃, 스크롤, 입력값, 선택 상태를 보존한다.
- [ ] Pretendard와 Geist Mono font loading 중 대체 글꼴, 로드 뒤 레이아웃 이동, 오프라인 캐시를 확인했다.

이후 모바일 이식 이슈 #342~#346은 PR 본문이나 검증 기록에서 해당 라우트 행과 증빙을 연결한다. 다섯 칸이 모두 체크되지 않은 라우트는 이식 완료로 보지 않는다.

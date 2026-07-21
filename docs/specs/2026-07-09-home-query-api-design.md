# 홈 화면 조회 API 디자인 — #45

- **날짜**: 2026-07-09
- **상태**: 구현 완료 (빌드·테스트 그린, 커밋/PR 대기) — 단, 아래 "보류 결정"이 남아있어 그 결론에 따라 이번 구현이 바뀔 수 있음
- **관련 이슈**: [#45 feat(server): 홈 화면 조회 API](https://github.com/thumbsup-studio/thumbsup/issues/45)
- **선행**: #40(문제 세트 DB 저장, closed) — 이번 작업은 결과적으로 `quiz` 스키마를 확장하지 않고 별도 `learning` 피처를 신설했다(아래 결정 기록 참조)
- **연계**: #2/#51/#52(앱 홈, closed·mock 기반) — 응답 필드명은 앱이 이미 쓰는 `courseTitle`/`unitTitle`/`streakDays`(`app/src/features/play/types.ts`, `app/src/features/home/types.ts`)에 맞췄다. 실 연동(mock 제거)은 후속.

## 배경과 목표

홈 화면(S2)이 스트릭·포인트 잔액·오늘의 학습 진입점을 한 번에 그릴 수 있도록 `GET /api/v1/home`을 만든다.

서버에는 이 API에 필요한 데이터 모델이 전혀 없었다:
- 포인트·스트릭 개념 자체가 없음(엔티티·컬럼 모두 부재). PR #42의 `AnswerSubmitResponse`는 `isCorrect`만 반환.
- 기존 `quiz`는 `stepOrder`/`slotOrder`로만 문제를 묶고, 코스·화(목차) 개념이 없음.

## 결정 기록

| 결정 | 선택 | 근거 |
|------|------|------|
| 피처 분리 vs `quiz` 확장 | 새 `learning` 피처(Course/Unit/UserProgress) 신설, `quiz`는 무수정 | `quiz`에 `courseId`/스트릭/포인트를 얹으면 이미 머지된 #40/#42 스키마·서비스를 다시 여는 것 — "광범위 리팩터링과 feature 구현을 한 PR에 섞지 않는다"(backend-development-guide.md §7)에 위배. 분리하면 #45 범위(조회 API)만으로 완결 |
| `learning`이 `quiz`/`auth` 데이터를 어떻게 얻는가 | 얻지 않는다 — 자기 소유 테이블(course/unit/user_progress)만 가진다 | ArchUnit `피처_간_직접_의존_금지`(`ArchitectureTest.java`)가 `common` 제외 모든 feature 슬라이스 간 의존을 전면 차단한다. `dto-and-query-patterns.md`의 크로스 도메인 조회 예시(`userRepository.findAllById(...)`)는 실제로는 이 규칙과 충돌하는 아직 검증 안 된 아상적 예시였다 — 이번이 그 충돌을 실제로 만난 첫 케이스라, 회피 대신 애초에 크로스 피처 조회가 필요 없도록 도메인을 분리하는 쪽을 택함 |
| 엔티티 명칭 | `Course` / `Unit` / `UserProgress`, 패키지 `learning` | 프론트가 이미 `courseTitle`/`unitTitle`(`app/src/features/play/types.ts`)·`streakDays`(`app/src/features/home/types.ts`)를 쓰고 있어 앱 변환 없이 그대로 소비 가능. 진행상태는 유저별 값이라 `UserProgress`로 — 기존 `quiz.QuizProgress`(커리큘럼 스텝 진행)와 클래스·테이블명(`user_progress` vs `quiz_progress`) 모두 구분 |
| 스트릭·포인트 범위 | **조회만** — `user_progress`에 저장된 값을 그대로 읽어 반환 | 이슈 제목이 "조회 API". 문제 완료 시 streak+1/포인트 적립 같은 쓰기 로직은 `quiz.submitAnswer` 흐름과 맞물려야 하는데(cross-feature), 이는 별도 티켓의 몫 — 이번 PR은 시드 데이터로 조회 동작만 검증 |
| `lastCompletedDate` 등 복구 배너(#55)용 컬럼 | 이번 PR에 추가하지 않음 | #55는 M2이고 착수 여부·컬럼 형태 모두 미확정 — 쓰지도 않는 컬럼을 지금 넣는 것은 YAGNI. 필요해지면 그 PR에서 새 마이그레이션으로 추가 |
| 커서가 전체 화 수를 넘는 경우(코스 완주) | 마지막 화로 clamp | 에러 대신 "완주 상태"를 표현 — 앱 쪽 "코스 완주" UX 정책은 미확정이라 최소한 크래시 없는 값을 내려줌 |
| 진행 기록이 없는 신규 유저 | 에러 아님 — streak 0·points 0·1화부터 시작하는 기본 상태 | 앱 홈(#2) TC-2-06 "스트릭 0·학습 이력 0 · 홈 렌더 → 레이아웃 깨짐 없이 기본 상태로 표시"와 정합 |
| 테스트 데이터 격리 | 공용 `DatabaseCleanUp`(TRUNCATE 전체 테이블 + AUTO_INCREMENT 리셋, `server/src/test/.../common/DatabaseCleanUp.java`) 신설 | Flyway 시드(course id=1, user_progress user_id=1/2)와 "첫 코스"·"특정 user_id" 같은 절대값을 검증하는 리포지토리 테스트가 충돌 — `learning`이 이런 절대값 테스트를 쓰는 첫 feature라 처음 드러난 문제. `deleteAll()+flush()`도 시도했으나 Hibernate flush 순서(삭제가 삽입보다 나중)로 여전히 실패해 TRUNCATE 기반으로 전환. 테이블명은 `@Table(name=...)` 애노테이션 값을 직접 읽는다 — 클래스명→스네이크케이스 변환은 `User`(테이블 `users`, 복수)에서 어긋난다 |

## 보류 결정 — 홈을 비로그인 상태에서도 볼 수 있어야 하는가

"개인화 영역(스트릭·포인트)은 숨기고, 비로그인 상태에서도 홈(오늘의 학습 카드)은 보여주면 되는 거 아니냐"는 질문에 대한 두 접근.
`docs/api-standard.md` §8("서버는 항상 토큰에서 유저를 식별한다")과 직접 부딪히는 지점이라 다음 세션에서 결정한다.

### A안 — `/api/v1/home`을 optional-auth로

**방식:** `SecurityConfig.PUBLIC_PATHS`에 `/api/v1/home` 추가 + Spring Security 기본 익명 인증(`.anonymous(...)`)을 꺼서 무토큰 요청 시 `@AuthenticationPrincipal Long userId`가 `null`로 들어오게 함. `HomeResponse`에 `authenticated` 필드를 추가해 `false`면 FE가 개인화 블록을 숨기게 함.

- 👍 서버 변경이 `learning`/`common(SecurityConfig)`에만 국한, `auth` 피처 자체는 무수정
- 👍 "그냥 구경하는" 방문자마다 계정이 생기지 않음(DB 오염 없음)
- 👎 **이 레포에서 유일하게 인증 없이 동작하는 API가 된다** — `api-standard.md` §8은 "모든 API 공통" 계약이고, 이 문서는 "계약 변경은 FE·서버 모두에 파급 — 단독 PR로 올리고 양쪽 개발자 확인"이라고 명시한 정본 문서. 이걸 홈 하나 때문에 조용히 깨는 셈
- 👎 Spring Security 기본 익명 인증을 끄는 건 `SecurityConfig` 전역 변경 — 지금은 다른 모든 API가 어차피 인증 필수라 영향 없지만, "왜 껐는지"를 아는 사람이 없으면 다음 사람이 다시 켜서 이 버그가 재발할 수 있음
- 👎 **앱이 지금 이 변경의 혜택을 전혀 못 받는다** — `RequireAuth`(`app/src/features/auth/require-auth.tsx`)가 비로그인 방문자를 무조건 `/login`으로 보내버리고, 홈 페이지는 애초에 실 API를 안 부르고 `mock-home-data.ts`만 쓴다. 서버만 고쳐서는 아무 것도 안 바뀌고, 앱까지 같이 고쳐야 실제로 의미가 생김(= 서버 #45 범위를 넘어서는 앱 작업이 필연적으로 따라붙음)

### B안 — 게스트 계정 자동 발급 (듀오링고 방식)

**방식:** 앱이 첫 방문 시(저장된 토큰 없음) 뒤에서 조용히 "게스트 로그인"을 호출해 실제 `User` row + 진짜 JWT를 받아 저장. 이후 모든 요청(홈 포함)은 진짜 토큰을 들고 있어 **서버는 익명 모드를 아예 몰라도 된다.**

- 👍 `api-standard.md` §8을 전혀 깨지 않음 — 홈도 다른 API와 완전히 동일하게 "항상 인증 필요"
- 👍 이번에 만든 `HomeResponse`/`HomeService` 그대로 재사용(무변경) — 게스트도 진짜 유저라 `user_progress` 로직이 그대로 맞음
- 👍 `authenticated` 같은 임시방편 필드가 API에 안 생김
- 👎 **서버에 새 엔드포인트(게스트 발급)가 필요** — 순수 앱 작업이 아니라 서버에도 새 스코프가 생김(기존 `/signup`을 재사용하면 가짜 이메일로 `users` 테이블이 오염됨)
- 👎 "게스트 → 실계정 전환" 시 스트릭·포인트를 승계할지 스펙이 아직 없음
- 👎 안 쓰는 게스트 row 정리(TTL/배치) 인프라가 이 레포에 없음 — 새로 만들어야 함

### 다음에 정할 것

이건 서버 #45 하나로 끝낼 수 있는 결정이 아니다 — 앱의 `RequireAuth` 게이트·홈의 mock→실API 전환과 묶여 있는 제품 결정이라, 서버·앱 양쪽 스코프를 같이 잡고 다음 세션에서 A/B 중 하나로 정하거나 제3안을 논의한다.

## 아키텍처

```text
studio.thumbsup.server.learning/
├─ Course.java              (Entity — title, category, units 컬렉션. aggregate root)
├─ Unit.java                (Entity — course, orderIndex, title, estimatedMinutes)
├─ UserProgress.java        (Entity — userId/courseId는 ID값 참조, cursorUnitIndex, streak, points)
├─ CourseRepository.java    (findFirstByOrderByIdAsc — MVP 단일 코스의 "기본 코스")
├─ UnitRepository.java      (findByCourseIdAndOrderIndex, countByCourseId)
├─ UserProgressRepository.java (findByUserId)
├─ HomeController.java      (GET /api/v1/home, @AuthenticationPrincipal Long userId)
├─ HomeService.java         (@Transactional(readOnly=true) — 조회만)
├─ LearningErrorType.java   (COURSE_NOT_FOUND)
└─ dto/
   └─ HomeResponse.java     (streakDays, points, today{courseId,courseTitle,unitId,unitTitle,order,completedCount,totalCount,estimatedMinutes})
```

`notice/`·`quiz/` 레퍼런스 패턴(정적 팩토리 `create()`, `@Transactional(readOnly=true)` 클래스 기본값, ErrorType enum, DTO record + `from()`)을 그대로 따른다.

### Flyway

- `V20260709161009__create_learning_tables.sql` — `course`/`unit`(FK→course, CASCADE)/`user_progress`(FK 없음, `uk_user_progress_user_course` unique) DDL.
- `V20260709161024__seed_learning_sample.sql` — "CS 기초" 코스 + 화 10개 + `user_progress` 데모 2건(user_id 1·2).

### 비범위 (후속 티켓)

- streak/points 증가(쓰기) 로직 — `quiz.submitAnswer` 완료 후 KST 일 경계로 갱신. cross-feature라 별도 티켓.
- unit ↔ quiz 실제 문제 매핑 — "시작하기"는 기존 `GET /api/v1/quizzes/next`로 라우팅.
- 복구 배너(#55, M2) 관련 스키마.
- 앱 홈의 mock 데이터 → 이 API 실연동(FE 작업, 별도 이슈).

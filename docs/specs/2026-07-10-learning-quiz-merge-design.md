# learning을 quiz로 통합 — Unit 제거, 홈 진행 상태 일원화 — #117

- **날짜**: 2026-07-10
- **상태**: 구현 완료 (빌드·테스트 그린, 커밋/PR 대기)
- **관련 이슈**: [#117 refactor(server): learning을 quiz로 통합](https://github.com/thumbsup-studio/thumbsup/issues/117)
- **선행**: #45(홈 화면 조회 API, `docs/specs/2026-07-09-home-query-api-design.md`) — 이번 작업이 그 설계를 뒤집는다

## 배경과 문제

퀴즈 스텝(5문제)을 다 풀어도 홈 화면의 "오늘의 학습"이 갱신되지 않았다. 원인은 진행 상태가 두 곳에 따로 있었기 때문:
- `learning.UserProgress.cursorUnitIndex` — 홈이 보여줄 화(`learning.Unit`)를 가리키는 커서
- `quiz.QuizProgress.currentStepOrder` — 퀴즈가 실제로 갱신하는 진행 커서

`learning.Unit`과 `quiz.QuizStep`은 둘 다 "오늘 배우는 주제 하나"를 가리키는 사실상 같은 개념이었는데, 두 다른 feature(`learning`/`quiz`)가 각자 중복으로 갖고 있어 서로 동기화가 안 됐다.

## 검토한 대안과 막힌 지점

**1차 시도 — 이벤트 기반 동기화**: `quiz`가 스텝 완료 이벤트를 발행하고 `learning`이 구독해 자기 테이블을 갱신하는 방식을 검토했다. 이유는 `ArchitectureTest.피처_간_직접_의존_금지`(`slices().matching("studio.thumbsup.server.(*)..").should().notDependOnEachOther()`, `common` 제외)가 `common`을 뺀 모든 feature 패키지 간 의존을 전면 차단하기 때문 — `learning`이 `quiz`의 Repository/Service/Entity를 직접 import하면 빌드가 깨진다.

`docs/dto-and-query-patterns.md` §2("크로스 도메인 조회 패턴")가 예시로 든 "Repository로 따로 조회해 조립"은, 실제로는 이 ArchUnit 규칙과 충돌하는 **검증 안 된 예시**였다 — #45 구현 당시(`2026-07-09-home-query-api-design.md` "결정 기록" 표) 이미 이 벽에 부딪혔었고, 그때는 회피책으로 `learning`이 `quiz`를 아예 참조하지 않도록 도메인을 완전히 분리하는 쪽을 택했었다.

**2차 시도 — ArchUnit 예외 추가**: `.ignoreDependency(resideInAPackage("learning.."), resideInAPackage("quiz.."))`처럼 `learning → quiz` 한 방향만 예외로 뚫는 안. 근데 확인해보니 반대 방향(퀴즈 풀이 화면이 `Course.title`을 표시해야 하는 경우, `app/src/features/play/types.ts`의 `PlaySession.courseTitle`)도 필요해서 **양방향** 예외가 불가피했다. 양방향으로 뚫으면 두 feature가 실질적으로 하나처럼 동작하면서 코드만 두 패키지에 나뉘어 있는, 격리의 장점 없이 결합의 단점만 남는 상태가 된다.

**최종 결정 — `learning`을 `quiz`로 물리적으로 합친다.** 두 도메인이 이 정도로 상호 의존적이면 애초에 하나의 feature가 맞고, 코드 구조가 그 사실을 정직하게 반영해야 한다고 판단했다.

## 변경 사항

### 삭제
- `learning.Unit`, `learning.UnitRepository` — `quiz.QuizStep`과 중복 개념이라 제거. `unit` 테이블 DROP.
- `learning` 패키지 전체(디렉터리) — 아래 클래스들이 `quiz`로 이동하며 비워짐.

### 이동 (`learning` → `quiz`, 패키지 선언만 변경, 내용은 최소 수정)
- `Course.java` — `units`(`OneToMany<Unit>`) 컬렉션·`addUnit()` 제거.
- `UserProgress.java` — `courseId`/`cursorUnitIndex` 필드 제거, `userId`/`streak`/`points`만 남김. Unique 제약 `(user_id, course_id)` → `(user_id)`.
- `CourseRepository.java`, `UserProgressRepository.java` — 내용 변화 없음(패키지만 이동).
- `HomeService.java` — `QuizProgressRepository`/`QuizStepRepository`를 직접 주입해 조립하도록 재작성(아래 참조).
- `HomeController.java` — 변화 없음.
- `LearningErrorType.java` — 변화 없음(클래스명 유지, `quiz` 패키지로 이동).
- `dto/HomeResponse.java` — `TodayLearning.of()`가 `Unit` 대신 `QuizStep`을 받도록 변경 (`unitId`→`QuizStep.id`, `unitTitle`→`QuizStep.topic`, `order`→`QuizStep.stepOrder`, `estimatedMinutes`→`QuizStep.estimatedMinutes`). JSON 필드명은 앱과의 계약이라 그대로 유지.

### 수정
- `quiz.QuizStep`에 `estimatedMinutes`(int) 컬럼 추가 — 원래 `Unit`이 갖던 "예상 소요 시간" 표시 데이터. `courseId`는 추가하지 않음 — MVP가 코스 1개뿐이라 홈은 `CourseRepository.findFirstByOrderByIdAsc()`로 독립적으로 조회하면 충분하고, 멀티 코스가 실제로 생기면 그때 추가한다(YAGNI).
- `quiz.generation.QuizPersister` — `QuizStep.create()`에 `estimatedMinutes` 인자 추가, 생성 파이프라인은 소요 시간을 산출하지 않으므로 `DEFAULT_ESTIMATED_MINUTES = 3`(MVP 임시값, 콘텐츠 저작 시 수동 조정 예정)을 채운다.

### 새 HomeService 조립 흐름 (읽기 시점, 쓰기 없음)
```
1. CourseRepository.findFirstByOrderByIdAsc()         → 기본 코스
2. QuizStepRepository.count()                          → 전체 스텝 수(진행률 분모)
3. QuizProgressRepository.findByUserId(userId)          → currentStepOrder (없으면 1)
4. clamp(currentStepOrder, count)                       → 코스 완주 시 마지막 스텝 고정
5. QuizStepRepository.findByStepOrder(cursor)           → 오늘의 스텝(topic, estimatedMinutes)
6. UserProgressRepository.findByUserId(userId)          → streak/points (없으면 0/0)
7. 위 값 조립 → HomeResponse
```
진행 커서를 쓰는 곳은 여전히 `QuizService.advanceProgressIfStepCompleted` 하나뿐이다 — `HomeService`는 순수 조회만 하고 아무것도 갱신하지 않는다. 두 진행 상태가 없으므로 동기화 문제 자체가 사라졌다.

### Flyway
- `V20260710133908__merge_learning_into_quiz.sql` — `quiz_step.estimated_minutes` 추가(백필 3), `unit` 테이블 DROP, `user_progress`에서 `cursor_unit_index`/`course_id` 컬럼 제거 + unique 제약을 `(user_id)`로 변경.

## 비범위 (후속 티켓)

- `quiz_step`에 `courseId` 추가 — 실제로 두 번째 코스가 생길 때, `(course_id, step_order)` 복합 유니크와 함께 추가.
- 퀴즈 풀이 화면(`/quizzes/next`)에 `Course.title` 노출 — `app`의 `play` 화면이 아직 목데이터 기반이라 실 연동 시점에 결정.
- "하루 문제 수 제한"(오늘 스텝 다 풀면 다음 스텝 진행을 막을지) — 서버·앱 모두 현재 제한 없음, 별도 정책 결정 필요.
- 퀴즈 풀이 중 "스텝 전환" 신호 — `AnswerSubmitResponse`가 스텝 완료 여부를 안 알려줘서, 유저가 여러 스텝을 연속으로 풀면 홈에 돌아올 때까지 전환을 못 느낀다.
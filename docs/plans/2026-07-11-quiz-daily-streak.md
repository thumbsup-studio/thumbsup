# 오늘의 학습(1스텝) 완료 → 스트릭 갱신·완료 플래그 Implementation Plan

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유저가 오늘의 학습(커리큘럼 1스텝, 문제 5개)을 처음 완료하면 스트릭이 KST 기준으로 하루 1회만 갱신되고, 홈 응답(`GET /api/v1/home`)이 "오늘 완료" 플래그와 함께 실제 갱신된 스트릭을 내려준다.

**Architecture:** `learning`이 `quiz`로 물리적으로 합쳐진 상태(#117)라 이벤트·별도 오케스트레이션 계층 없이, 기존 `QuizService.submitAnswer` → `advanceProgressIfStepCompleted`의 같은 트랜잭션·같은 유저 락 안에 스트릭 갱신을 편승시킨다. 스트릭 계산 로직은 `UserProgress` 엔티티가 직접 소유(`recordCompletion`/`getEffectiveStreak`)하고, 배치 없이 쓰기 시점(스텝 완료)과 읽기 시점(홈 조회)에 그때그때 계산한다.

**Tech Stack:** Spring Boot 3 / Java 21, Spring Data JPA, MySQL 8.4 (Testcontainers in tests), Flyway, JUnit5 + Mockito + AssertJ.

## Global Constraints

- 시간은 항상 주입받은 `Clock`을 사용한다 — `LocalDateTime.now()`/`LocalDate.now()` 직접 호출 금지 (`server/CLAUDE.md` 규칙 6). KST 변환은 `studio.thumbsup.server.common.time.TimeZones.KST` 재사용.
- 저장은 UTC, 표시/계산은 KST — `LocalDate.now(clock.withZone(TimeZones.KST))` 패턴을 그대로 따른다.
- JPA 엔티티를 API로 직접 노출 금지 — `HomeResponse`는 기존처럼 record DTO + 정적 팩토리 `from()`을 유지.
- 생성자 주입만 사용, `@Transactional`은 Service 레이어에만.
- 표준 예외(`IllegalArgumentException` 등) 생성 금지 — 이번 변경에서 새 에러 케이스는 없다(기존 `BusinessException` 그대로).
- 도메인 경계를 넘는 JPA 연관관계 금지 — 단, `UserProgress`/`QuizProgress`/`QuizService`/`HomeService`는 모두 같은 `quiz` 패키지(같은 ArchUnit 슬라이스)이므로 이 규칙에 저촉되지 않는다.
- Flyway 마이그레이션은 `V{yyyyMMddHHmmss}__{설명}.sql` 이름으로 추가하고, 이미 적용된 파일은 수정하지 않는다.
- 테스트 4종 컨벤션(Service Mockito / Controller standalone MockMvc / Repository `@DataJpaTest`+Testcontainers / Fixture)을 그대로 따르고, `@Nested`/`@DisplayName`으로 케이스를 구분한다.
- **커밋/푸시는 이 세션에서 직접 하지 않는다** — 모든 태스크 구현이 끝난 뒤 사용자가 직접 리뷰하고 커밋한다. 각 태스크는 "Run tests" 까지만 수행하고 git commit 단계를 포함하지 않는다.
- 참고 문서(정본): `docs/specs/2026-07-11-quiz-daily-streak-design.md` (데이터 모델·훅 위치·복습과의 상호작용·비범위 전부 여기 있음), 이슈 [#152](https://github.com/thumbsup-studio/thumbsup/issues/152).

---

## Task 0: 작업 브랜치 생성

**Files:** 없음 (git 브랜치 작업만)

- [ ] **Step 1: main 최신 상태에서 이슈 브랜치 생성**

```bash
cd /Users/jisu/IdeaProjects/thumbsup
git checkout -b feat/152-quiz-daily-streak
```

Expected: `Switched to a new branch 'feat/152-quiz-daily-streak'`. (main에 이미 있던 미커밋 변경사항 — `server/docker-compose.yml` 수정, `docs/specs/*` 두 파일 — 은 그대로 새 브랜치로 이어진다. 이 변경들은 건드리지 않는다.)

---

## Task 1: `UserProgress` 엔티티에 스트릭 계산 로직 추가

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/quiz/UserProgress.java`
- Create: `server/src/main/resources/db/migration/V{timestamp}__add_last_completed_date_to_user_progress.sql`
- Test: `server/src/test/java/studio/thumbsup/server/quiz/UserProgressTest.java` (new file)

**Interfaces:**
- Produces: `UserProgress.recordCompletion(LocalDate today): void` — 스텝을 처음 완료했을 때 호출, 같은 날 재호출해도 멱등. `UserProgress.getEffectiveStreak(LocalDate today): int` — 화면 표시용, DB를 갱신하지 않는 순수 계산. `UserProgress.getLastCompletedDate(): LocalDate` (Lombok `@Getter`가 자동 생성).

- [ ] **Step 1: 실패하는 엔티티 단위 테스트 작성**

`server/src/test/java/studio/thumbsup/server/quiz/UserProgressTest.java` 새로 생성:

```java
package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class UserProgressTest {

    private static final Long USER_ID = 1L;

    @Nested
    @DisplayName("스텝 완료 기록")
    class RecordCompletion {

        @Test
        @DisplayName("처음 완료하면 스트릭을 1로 시작한다")
        void starts_streak_at_one_on_first_completion() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);

            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getStreak()).isEqualTo(1);
            assertThat(progress.getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 11));
        }

        @Test
        @DisplayName("어제에 이어 오늘 완료하면 스트릭이 1 증가한다")
        void increments_streak_when_continued_from_yesterday() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 10));

            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getStreak()).isEqualTo(2);
        }

        @Test
        @DisplayName("같은 날 두 번 완료해도 스트릭은 그대로다(멱등)")
        void does_not_double_increment_on_same_day() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getStreak()).isEqualTo(1);
        }

        @Test
        @DisplayName("하루를 건너뛰고 완료하면 스트릭이 1로 리셋된다")
        void resets_streak_when_a_day_is_skipped() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 9));
            progress.recordCompletion(LocalDate.of(2026, 7, 10)); // streak=2로 연속

            progress.recordCompletion(LocalDate.of(2026, 7, 12)); // 7/11을 건너뜀

            assertThat(progress.getStreak()).isEqualTo(1);
            assertThat(progress.getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 12));
        }
    }

    @Nested
    @DisplayName("화면 표시용 유효 스트릭")
    class EffectiveStreak {

        @Test
        @DisplayName("한 번도 완료한 적 없으면 0을 반환한다")
        void returns_zero_when_never_completed() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);

            assertThat(progress.getEffectiveStreak(LocalDate.of(2026, 7, 11))).isZero();
        }

        @Test
        @DisplayName("오늘 완료했으면 저장된 스트릭 그대로 반환한다")
        void returns_stored_streak_when_completed_today() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getEffectiveStreak(LocalDate.of(2026, 7, 11))).isEqualTo(1);
        }

        @Test
        @DisplayName("어제 완료했으면(오늘 아직 안 풀었어도) 저장된 스트릭을 그대로 보여준다")
        void returns_stored_streak_when_completed_yesterday() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 10));

            assertThat(progress.getEffectiveStreak(LocalDate.of(2026, 7, 11))).isEqualTo(1);
        }

        @Test
        @DisplayName("이틀 이상 건너뛰었으면 화면에는 0으로 보여준다(DB 값은 그대로 둔다)")
        void returns_zero_when_streak_is_stale() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 9));

            int effective = progress.getEffectiveStreak(LocalDate.of(2026, 7, 11));

            assertThat(effective).isZero();
            assertThat(progress.getStreak()).isEqualTo(1);
        }
    }
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인 (컴파일 실패)**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.UserProgressTest"`
Expected: FAIL — `cannot find symbol: method recordCompletion` / `getEffectiveStreak` (아직 엔티티에 없음).

- [ ] **Step 3: `UserProgress` 엔티티에 필드·메서드 추가**

`server/src/main/java/studio/thumbsup/server/quiz/UserProgress.java` 전체를 다음으로 교체:

```java
package studio.thumbsup.server.quiz;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 유저의 게이미피케이션 상태(스트릭·포인트) — 유저당 1행(DB unique). {@code userId}는 다른 도메인(auth)의
 * 참조라 연관관계가 아니라 ID 값으로만 둔다(server/docs/dto-and-query-patterns.md #2).
 *
 * <p>"지금 어느 스텝까지 왔는지"는 {@link QuizProgress#getCurrentStepOrder()}가 유일한 소스다(#117) —
 * 예전엔 이 엔티티가 {@code cursorUnitIndex}/{@code courseId}로 화면 커서를 따로 들고 있었으나, 두 진행
 * 상태가 따로 갱신되며 어긋나는 문제가 있어 제거했다.
 */
@Getter
@Entity
@Table(name = "user_progress")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserProgress extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private int streak;

    @Column(nullable = false)
    private int points;

    private LocalDate lastCompletedDate;

    private UserProgress(Long userId, int streak, int points) {
        this.userId = userId;
        this.streak = streak;
        this.points = points;
    }

    public static UserProgress create(Long userId, int streak, int points) {
        return new UserProgress(userId, streak, points);
    }

    /**
     * 오늘의 학습(1스텝)을 처음 완료했을 때 호출한다. 같은 날 두 번 불려도 안전(멱등) — 스트릭이
     * 두 번 오르지 않는다. 어제까지 이어졌으면 +1, 하루라도 건너뛰었으면 1로 리셋한다.
     */
    public void recordCompletion(LocalDate today) {
        if (today.equals(lastCompletedDate)) {
            return;
        }
        boolean continuedFromYesterday = lastCompletedDate != null && lastCompletedDate.equals(today.minusDays(1));
        streak = continuedFromYesterday ? streak + 1 : 1;
        lastCompletedDate = today;
    }

    /**
     * 화면 표시용 스트릭. DB는 건드리지 않는다 — "끊긴 상태"를 저장하지 않고 조회 시점에 계산해서
     * 이틀 이상 건너뛰었으면 0으로 보여준다.
     */
    public int getEffectiveStreak(LocalDate today) {
        if (lastCompletedDate == null || lastCompletedDate.isBefore(today.minusDays(1))) {
            return 0;
        }
        return streak;
    }
}
```

- [ ] **Step 4: 테스트 재실행해서 통과 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.UserProgressTest"`
Expected: PASS (9개 테스트 전부).

- [ ] **Step 5: Flyway 마이그레이션 파일 생성**

```bash
cd /Users/jisu/IdeaProjects/thumbsup/server
TS=$(date +%Y%m%d%H%M%S)
cat > "src/main/resources/db/migration/V${TS}__add_last_completed_date_to_user_progress.sql" <<'EOF'
ALTER TABLE user_progress
    ADD COLUMN last_completed_date DATE NULL;
EOF
echo "Created: V${TS}__add_last_completed_date_to_user_progress.sql"
```

Expected: 파일이 `server/src/main/resources/db/migration/`에 생성됨. (이 파일은 아직 아무 곳에도 적용되지 않았으므로 Task 5의 Repository 테스트가 Testcontainers로 처음 검증한다.)

---

## Task 2: `UserProgressService` 추가 — 스텝 완료 기록 담당

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/quiz/UserProgressService.java`
- Test: `server/src/test/java/studio/thumbsup/server/quiz/UserProgressServiceTest.java` (new file)

**Interfaces:**
- Consumes: `UserProgress.recordCompletion(LocalDate)` (Task 1), `UserProgressRepository.findByUserId(Long): Optional<UserProgress>`, `UserProgressRepository.save(UserProgress)` (기존 `JpaRepository` 상속 메서드).
- Produces: `UserProgressService.recordStepCompletion(Long userId, LocalDate today): void` — Task 3에서 `QuizService`가 이 메서드를 호출한다.

- [ ] **Step 1: 실패하는 서비스 단위 테스트 작성**

`server/src/test/java/studio/thumbsup/server/quiz/UserProgressServiceTest.java` 새로 생성:

```java
package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserProgressServiceTest {

    @Mock
    private UserProgressRepository userProgressRepository;

    private static final Long USER_ID = 1L;

    private UserProgressService service() {
        return new UserProgressService(userProgressRepository);
    }

    @Nested
    @DisplayName("스텝 완료 기록")
    class RecordStepCompletion {

        @Test
        @DisplayName("기존 진행 상태가 있으면 그 행에 완료를 기록하고 저장한다")
        void records_completion_on_existing_progress() {
            UserProgress progress = UserProgress.create(USER_ID, 3, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 10));
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));

            service().recordStepCompletion(USER_ID, LocalDate.of(2026, 7, 11));

            ArgumentCaptor<UserProgress> captor = ArgumentCaptor.forClass(UserProgress.class);
            verify(userProgressRepository).save(captor.capture());
            assertThat(captor.getValue().getStreak()).isEqualTo(2);
            assertThat(captor.getValue().getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 11));
        }

        @Test
        @DisplayName("진행 상태 행이 없으면(최초 완료) 새로 만들어 저장한다")
        void creates_progress_row_on_first_completion() {
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());

            service().recordStepCompletion(USER_ID, LocalDate.of(2026, 7, 11));

            ArgumentCaptor<UserProgress> captor = ArgumentCaptor.forClass(UserProgress.class);
            verify(userProgressRepository).save(captor.capture());
            assertThat(captor.getValue().getUserId()).isEqualTo(USER_ID);
            assertThat(captor.getValue().getStreak()).isEqualTo(1);
        }
    }
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.UserProgressServiceTest"`
Expected: FAIL — `UserProgressService`가 존재하지 않음(컴파일 실패).

- [ ] **Step 3: `UserProgressService` 구현**

`server/src/main/java/studio/thumbsup/server/quiz/UserProgressService.java` 새로 생성:

```java
package studio.thumbsup.server.quiz;

import java.time.LocalDate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * {@link UserProgress}(스트릭·포인트) 갱신만 담당한다. 유일한 쓰기 호출자는
 * {@link QuizService#advanceProgressIfStepCompleted}다 — 오늘의 학습(1스텝)을 처음 완료한
 * 시점에만 불린다.
 */
@Service
public class UserProgressService {

    private final UserProgressRepository userProgressRepository;

    public UserProgressService(UserProgressRepository userProgressRepository) {
        this.userProgressRepository = userProgressRepository;
    }

    @Transactional
    public void recordStepCompletion(Long userId, LocalDate today) {
        UserProgress progress =
                userProgressRepository.findByUserId(userId).orElseGet(() -> UserProgress.create(userId, 0, 0));
        progress.recordCompletion(today);
        userProgressRepository.save(progress);
    }
}
```

- [ ] **Step 4: 테스트 재실행해서 통과 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.UserProgressServiceTest"`
Expected: PASS (2개 테스트).

---

## Task 3: `QuizService`에 스트릭 갱신 훅 연결

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/quiz/QuizService.java`
- Modify: `server/src/test/java/studio/thumbsup/server/quiz/QuizServiceTest.java`
- Modify: `server/src/test/java/studio/thumbsup/server/quiz/QuizExplanationServiceTest.java` (생성자 시그니처만 맞춤, 로직 변경 없음)

**Interfaces:**
- Consumes: `UserProgressService.recordStepCompletion(Long, LocalDate)` (Task 2), `studio.thumbsup.server.common.time.TimeZones.KST` (기존).
- Produces: `QuizService`의 새 생성자 시그니처 `(QuizRepository, CourseRepository, QuizStepRepository, QuizAttemptRepository, QuizProgressRepository, UserProgressService, Clock)` — 이후 태스크에서 참조할 일 없음(마지막 소비자).

- [ ] **Step 1: `QuizServiceTest`에 실패하는 테스트 추가 + 기존 `service()` 팩토리 갱신**

`server/src/test/java/studio/thumbsup/server/quiz/QuizServiceTest.java` 수정.

import 블록에 추가 (기존 import들 아래):

```java
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
```

`private QuizService quizService;` 아래, `private static final Long USER_ID = 1L;` 다음 줄에 상수·mock·팩토리 추가/교체:

```java
    private static final Long USER_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");
    private static final LocalDate TODAY_KST = LocalDate.of(2026, 7, 11);

    @Mock
    private UserProgressService userProgressService;

    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                userProgressService,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }
```

(`@Mock private UserProgressService userProgressService;` 선언은 기존 `@Mock private QuizProgressRepository quizProgressRepository;` 필드 바로 아래에 넣는다. `USER_ID`/`NOW`/`TODAY_KST` 상수는 기존 `private static final Long USER_ID = 1L;` 자리를 그대로 대체한다. 기존 `service()` 메서드 본문은 위 코드로 교체한다.)

`"정답 제출"` `@Nested` 클래스 안, 기존 `does_not_advance_progress_when_step_incomplete` 테스트 다음에 새 테스트 3개 추가:

```java
        @Test
        @DisplayName("스텝을 처음 완료하면 오늘(KST) 날짜로 스트릭 기록을 요청한다")
        void records_streak_when_step_first_completed() {
            quizService = service();
            Quiz last = quizWithId(10L, 1, 5);
            List<Quiz> stepQuizzes = List.of(
                    quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
            given(quizRepository.findById(10L)).willReturn(Optional.of(last));
            given(quizRepository.findIdsByStepOrder(1))
                    .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
            List<QuizAttempt> allAttempted = stepQuizzes.stream()
                    .map(q -> QuizAttempt.create(q, USER_ID, true))
                    .toList();
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(allAttempted);
            given(quizProgressRepository.findByUserIdForUpdate(USER_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID)));

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(userProgressService).recordStepCompletion(USER_ID, TODAY_KST);
        }

        @Test
        @DisplayName("아직 시도하지 않은 문제가 남아있으면 스트릭 기록을 요청하지 않는다")
        void does_not_record_streak_when_step_incomplete() {
            quizService = service();
            Quiz quiz = quizWithId(10L, 1, 1);
            given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(10L, 11L));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(userProgressService, never()).recordStepCompletion(any(), any());
        }

        @Test
        @DisplayName("이미 지난 스텝을 복습으로 완료해도 진행·스트릭 갱신을 요청하지 않는다")
        void does_not_record_progress_or_streak_for_past_step_review_completion() {
            quizService = service();
            Quiz last = quizWithId(10L, 1, 5);
            List<Quiz> stepQuizzes = List.of(
                    quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
            given(quizRepository.findById(10L)).willReturn(Optional.of(last));
            given(quizRepository.findIdsByStepOrder(1))
                    .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
            List<QuizAttempt> allAttempted = stepQuizzes.stream()
                    .map(q -> QuizAttempt.create(q, USER_ID, true))
                    .toList();
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(allAttempted);
            QuizProgress aheadProgress = QuizProgress.create(USER_ID);
            aheadProgress.advanceToNextStep(); // currentStepOrder=2, 이미 스텝1을 지나감
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(aheadProgress));
            given(quizProgressRepository.findByUserIdForUpdate(USER_ID)).willReturn(Optional.of(aheadProgress));

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(quizProgressRepository, never()).save(any());
            verify(userProgressService, never()).recordStepCompletion(any(), any());
        }
```

- [ ] **Step 2: `QuizExplanationServiceTest`의 `service()` 팩토리도 새 생성자에 맞춰 수정**

`server/src/test/java/studio/thumbsup/server/quiz/QuizExplanationServiceTest.java` 수정. import 블록에 추가:

```java
import java.time.Clock;
import java.time.ZoneOffset;
```

기존 `@Mock private QuizProgressRepository quizProgressRepository;` 필드 아래에 추가:

```java
    @Mock
    private UserProgressService userProgressService;
```

기존 `service()` 메서드를 다음으로 교체:

```java
    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                userProgressService,
                Clock.fixed(Instant.parse("2026-07-11T00:00:00Z"), ZoneOffset.UTC));
    }
```

(`Instant`가 아직 import 안 되어 있으면 `import java.time.Instant;`도 추가한다. 이 파일은 해설 조회만 테스트하므로 streak 관련 동작을 검증할 필요는 없다 — 생성자 시그니처만 맞추면 된다.)

- [ ] **Step 3: 테스트 실행해서 실패 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.QuizServiceTest" --tests "studio.thumbsup.server.quiz.QuizExplanationServiceTest"`
Expected: FAIL — 생성자 인자 개수 불일치로 컴파일 실패.

- [ ] **Step 4: `QuizService`에 `UserProgressService`·`Clock` 주입 및 훅 연결**

`server/src/main/java/studio/thumbsup/server/quiz/QuizService.java` 수정.

import 블록 상단(`import java.util.List;` 위)에 추가:

```java
import java.time.Clock;
import java.time.LocalDate;
```

`import studio.thumbsup.server.common.exception.BusinessException;` 다음 줄에 추가:

```java
import studio.thumbsup.server.common.time.TimeZones;
```

필드·생성자 교체 (`private final QuizProgressRepository quizProgressRepository;` 다음, 생성자 전체):

```java
    private final QuizProgressRepository quizProgressRepository;
    private final UserProgressService userProgressService;
    private final Clock clock;

    public QuizService(
            QuizRepository quizRepository,
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizAttemptRepository quizAttemptRepository,
            QuizProgressRepository quizProgressRepository,
            UserProgressService userProgressService,
            Clock clock) {
        this.quizRepository = quizRepository;
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizAttemptRepository = quizAttemptRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.userProgressService = userProgressService;
        this.clock = clock;
    }
```

`advanceProgressIfStepCompleted` 메서드 안의 마지막 `if` 블록을 다음으로 교체:

```java
        if (progress.getCurrentStepOrder() == stepOrder) {
            progress.advanceToNextStep();
            quizProgressRepository.save(progress);
            userProgressService.recordStepCompletion(userId, LocalDate.now(clock.withZone(TimeZones.KST)));
        }
```

- [ ] **Step 5: 테스트 재실행해서 통과 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.QuizServiceTest" --tests "studio.thumbsup.server.quiz.QuizExplanationServiceTest"`
Expected: PASS (전체 — 기존 테스트 포함 회귀 없음, 신규 3개 포함).

---

## Task 4: 홈 응답에 `todayCompleted` 플래그 추가

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/quiz/dto/HomeResponse.java`
- Modify: `server/src/main/java/studio/thumbsup/server/quiz/HomeService.java`
- Modify: `server/src/test/java/studio/thumbsup/server/quiz/HomeServiceTest.java`
- Modify: `server/src/test/java/studio/thumbsup/server/quiz/HomeControllerTest.java`
- Modify: `server/src/test/java/studio/thumbsup/server/quiz/QuizFixture.java`

**Interfaces:**
- Consumes: `UserProgress.getEffectiveStreak(LocalDate)`, `UserProgress.getLastCompletedDate()` (Task 1).
- Produces: `HomeResponse(int streakDays, int points, boolean todayCompleted, TodayLearning today)` — JSON 필드 `todayCompleted` 추가. 이 태스크가 마지막 소비자(앱 연동은 이번 스코프 밖).

- [ ] **Step 1: `QuizFixture.userProgress`에 `lastCompletedDate` 파라미터 추가**

`server/src/test/java/studio/thumbsup/server/quiz/QuizFixture.java` 수정. 상단 import에 추가:

```java
import java.time.LocalDate;
```

기존 메서드:

```java
    public static UserProgress userProgress(Long id, Long userId, int streak, int points) {
        UserProgress progress = UserProgress.create(userId, streak, points);
        ReflectionTestUtils.setField(progress, "id", id);
        return progress;
    }
```

를 다음으로 교체:

```java
    public static UserProgress userProgress(Long id, Long userId, int streak, int points, LocalDate lastCompletedDate) {
        UserProgress progress = UserProgress.create(userId, streak, points);
        ReflectionTestUtils.setField(progress, "id", id);
        ReflectionTestUtils.setField(progress, "lastCompletedDate", lastCompletedDate);
        return progress;
    }
```

- [ ] **Step 2: `HomeServiceTest`에 실패하는 테스트 작성 + 기존 호출부 갱신**

`server/src/test/java/studio/thumbsup/server/quiz/HomeServiceTest.java` 수정.

import 블록에 추가:

```java
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
```

`private static final Long COURSE_ID = 1L;` 다음 줄에 추가:

```java
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");
    private static final LocalDate TODAY_KST = LocalDate.of(2026, 7, 11);
```

기존 `service()` 메서드:

```java
    private HomeService service() {
        return new HomeService(courseRepository, quizStepRepository, quizProgressRepository, userProgressRepository);
    }
```

를 다음으로 교체:

```java
    private HomeService service() {
        return new HomeService(
                courseRepository,
                quizStepRepository,
                quizProgressRepository,
                userProgressRepository,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }
```

기존 3개 테스트에서 `QuizFixture.userProgress(1L, USER_ID, 5, 320)` 및 `QuizFixture.userProgress(1L, USER_ID, 10, 1000)` 호출부를 각각 `QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST)`, `QuizFixture.userProgress(1L, USER_ID, 10, 1000, TODAY_KST)`로 교체한다 (5번째 인자로 오늘 날짜를 넣어 "저장된 스트릭이 그대로 보인다"는 기존 기대값을 유지).

`returns_default_state_when_no_progress` 테스트의 마지막 assert 다음 줄에 추가:

```java
            assertThat(response.todayCompleted()).isFalse();
```

`"홈 화면 조회"` `@Nested` 클래스 안, 마지막 기존 테스트 다음에 새 테스트 3개 추가:

```java
        @Test
        @DisplayName("오늘 이미 완료했으면 todayCompleted=true를 반환한다")
        void returns_today_completed_true_when_completed_today() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByStepOrderGreaterThan(0)).willReturn(3L);
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST)));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.todayCompleted()).isTrue();
        }

        @Test
        @DisplayName("어제 완료하고 오늘은 아직이면 todayCompleted=false지만 스트릭은 유지된다")
        void returns_today_completed_false_when_not_completed_today() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByStepOrderGreaterThan(0)).willReturn(3L);
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST.minusDays(1))));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.todayCompleted()).isFalse();
            assertThat(response.streakDays()).isEqualTo(5);
        }

        @Test
        @DisplayName("이틀 이상 스트릭이 끊겼으면 streakDays를 0으로 보여준다(DB 값은 그대로 둔다)")
        void returns_zero_streak_when_stale() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByStepOrderGreaterThan(0)).willReturn(3L);
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 7, 320, TODAY_KST.minusDays(3))));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.streakDays()).isZero();
            assertThat(response.todayCompleted()).isFalse();
        }
```

- [ ] **Step 3: `HomeControllerTest` 갱신**

`server/src/test/java/studio/thumbsup/server/quiz/HomeControllerTest.java` 수정.

```java
            HomeResponse response =
                    new HomeResponse(5, 320, new HomeResponse.TodayLearning(1L, "CS 기초", 2L, "스택과 큐", 2, 1, 3, 3));
```

를 다음으로 교체:

```java
            HomeResponse response = new HomeResponse(
                    5, 320, true, new HomeResponse.TodayLearning(1L, "CS 기초", 2L, "스택과 큐", 2, 1, 3, 3));
```

같은 테스트 메서드의 마지막 `.andExpect(...)` 체인에 한 줄 추가:

```java
                    .andExpect(jsonPath("$.data.todayCompleted").value(true));
```

- [ ] **Step 4: 테스트 실행해서 실패 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.HomeServiceTest" --tests "studio.thumbsup.server.quiz.HomeControllerTest"`
Expected: FAIL — `HomeResponse`에 `todayCompleted` 생성자 인자가 없어 컴파일 실패.

- [ ] **Step 5: `HomeResponse` DTO에 `todayCompleted` 필드 추가**

`server/src/main/java/studio/thumbsup/server/quiz/dto/HomeResponse.java` 전체를 다음으로 교체:

```java
package studio.thumbsup.server.quiz.dto;

import studio.thumbsup.server.quiz.Course;
import studio.thumbsup.server.quiz.QuizStep;

/**
 * 홈 화면 조회 응답 — 스트릭·포인트·오늘의 학습 진입점을 한 번에 담는다.
 * 필드명은 앱 홈(#2/#52)이 이미 쓰는 courseTitle/unitTitle/streakDays와 정렬한다
 * (app/src/features/play/types.ts, app/src/features/home/types.ts 참조).
 */
public record HomeResponse(int streakDays, int points, boolean todayCompleted, TodayLearning today) {

    /** 오늘의 학습 카드에 필요한 진입점 정보 — 정답을 맞히는 데 필요한 문제 본문은 담지 않는다(퀴즈 조회 API 몫). */
    public record TodayLearning(
            Long courseId,
            String courseTitle,
            Long unitId,
            String unitTitle,
            int order,
            int completedCount,
            int totalCount,
            int estimatedMinutes) {

        static TodayLearning of(Course course, QuizStep current, int completedCount, int totalCount) {
            return new TodayLearning(
                    course.getId(),
                    course.getTitle(),
                    current.getId(),
                    current.getTopic(),
                    current.getStepOrder(),
                    completedCount,
                    totalCount,
                    current.getEstimatedMinutes());
        }
    }

    public static HomeResponse from(
            int streakDays, int points, boolean todayCompleted, Course course, QuizStep current, int totalCount) {
        int completedCount = current.getStepOrder() - 1;
        return new HomeResponse(
                streakDays, points, todayCompleted, TodayLearning.of(course, current, completedCount, totalCount));
    }
}
```

- [ ] **Step 6: `HomeService`에 `Clock` 주입 및 `todayCompleted`/`getEffectiveStreak` 연결**

`server/src/main/java/studio/thumbsup/server/quiz/HomeService.java` 전체를 다음으로 교체:

```java
package studio.thumbsup.server.quiz;

import java.time.Clock;
import java.time.LocalDate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.dto.HomeResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 *
 * <p>"오늘의 학습" 커서는 {@link QuizProgress#getCurrentStepOrder()} 하나뿐이다(#117) — 예전엔
 * 별도 학습 진행 엔티티가 화면용 커서를 따로 들고 있었으나, 퀴즈 진행 상태와 따로 갱신되며 어긋나는
 * 문제가 있어 없앴다. 홈은 이 커서로 {@link QuizStep}을 찾아 표시할 뿐, 커서를 갱신하지 않는다
 * (갱신은 {@link QuizService#advanceProgressIfStepCompleted}의 몫).
 */
@Service
@Transactional(readOnly = true)
public class HomeService {

    private static final int INITIAL_STEP_ORDER = 1;

    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;
    private final UserProgressRepository userProgressRepository;
    private final Clock clock;

    public HomeService(
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizProgressRepository quizProgressRepository,
            UserProgressRepository userProgressRepository,
            Clock clock) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.userProgressRepository = userProgressRepository;
        this.clock = clock;
    }

    /**
     * 진행 기록이 없으면(신규 유저) 스트릭 0·포인트 0·1스텝부터 시작하는 기본 상태로 응답한다
     * (에러가 아니다 — 앱 홈은 이 상태를 빈 값이 아니라 기본 화면으로 표시한다).
     *
     * <p>스트릭·완료 플래그는 배치 없이 이 조회 시점에 KST 기준 오늘 날짜로 그때그때 계산한다
     * ({@link UserProgress#getEffectiveStreak}) — 이틀 이상 건너뛴 스트릭은 DB를 갱신하지 않고
     * 응답에서만 0으로 보여준다.
     */
    public HomeResponse getHome(Long userId) {
        Course course = courseRepository
                .findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        long totalCount = quizStepRepository.countByStepOrderGreaterThan(0);

        int cursor = clamp(currentStepOrder(userId), totalCount);
        QuizStep step = quizStepRepository
                .findByStepOrder(cursor)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));

        LocalDate todayKst = LocalDate.now(clock.withZone(TimeZones.KST));
        UserProgress progress = userProgressRepository.findByUserId(userId).orElse(null);
        int streak = progress == null ? 0 : progress.getEffectiveStreak(todayKst);
        int points = progress == null ? 0 : progress.getPoints();
        boolean todayCompleted = progress != null && todayKst.equals(progress.getLastCompletedDate());

        return HomeResponse.from(streak, points, todayCompleted, course, step, (int) totalCount);
    }

    private int currentStepOrder(Long userId) {
        return quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);
    }

    /** 코스를 완주했으면(커서가 전체 스텝 수를 넘으면) 마지막 스텝으로 고정한다. */
    private int clamp(int stepOrder, long totalCount) {
        if (totalCount <= 0) {
            return stepOrder;
        }
        return Math.min(stepOrder, (int) totalCount);
    }
}
```

- [ ] **Step 7: 테스트 재실행해서 통과 확인**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.HomeServiceTest" --tests "studio.thumbsup.server.quiz.HomeControllerTest"`
Expected: PASS (전체 — 기존 테스트 포함 회귀 없음, 신규 3개 포함).

---

## Task 5: Repository 통합 테스트로 `last_completed_date` 컬럼 검증

**Files:**
- Modify: `server/src/test/java/studio/thumbsup/server/quiz/CourseAndUserProgressRepositoryTest.java`

**Interfaces:**
- Consumes: Task 1의 Flyway 마이그레이션(`last_completed_date` 컬럼), `UserProgress.recordCompletion(LocalDate)`.
- Produces: 없음 (최종 검증 계층).

- [ ] **Step 1: 실패하는 Repository 테스트 작성**

`server/src/test/java/studio/thumbsup/server/quiz/CourseAndUserProgressRepositoryTest.java` 수정. import 블록에 추가:

```java
import java.time.LocalDate;
```

`"유저 진행상태"` `@Nested` 클래스(`UserProgressPersistence`) 안, 기존 `rejects_duplicate_user_progress` 테스트 다음에 추가:

```java
        @Test
        @DisplayName("완료일(lastCompletedDate)을 저장·조회한다")
        void persists_last_completed_date() {
            UserProgress progress = UserProgress.create(1L, 1, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            userProgressRepository.saveAndFlush(progress);

            Optional<UserProgress> found = userProgressRepository.findByUserId(1L);
            assertThat(found).isPresent();
            assertThat(found.get().getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 11));
        }
```

- [ ] **Step 2: 테스트 실행해서 통과 확인 (Testcontainers로 실제 마이그레이션 적용)**

Run: `./gradlew --no-daemon test --tests "studio.thumbsup.server.quiz.CourseAndUserProgressRepositoryTest"`
Expected: PASS (Docker가 로컬에서 떠 있어야 함 — Testcontainers가 MySQL 8.4 컨테이너를 띄운다). 이 테스트가 통과하면 Task 1에서 만든 마이그레이션이 실제로 유효하다는 뜻이다.

---

## Task 6: 전체 빌드 게이트 통과 확인

**Files:** 없음 (검증만)

- [ ] **Step 1: 전체 빌드 실행 (테스트·ArchUnit·Spotless·Checkstyle 포함)**

```bash
cd /Users/jisu/IdeaProjects/thumbsup/server
./gradlew --no-daemon spotlessApply build
```

Expected: `BUILD SUCCESSFUL`. 실패 시 원인:
- ArchUnit 실패 → 이번 변경은 전부 `quiz` 패키지 내부이므로 발생하면 안 되지만, 발생하면 어떤 클래스가 다른 패키지를 참조했는지 확인.
- Checkstyle 파일 길이 초과 → `QuizServiceTest.java`가 400줄을 넘으면 `QuizExplanationServiceTest.java`처럼 분리 검토(이번 추가분은 3테스트뿐이라 가능성 낮음, 실제로 넘으면 사용자와 상의).
- Spotless → `spotlessApply`가 자동 포맷하므로 보통 자동 해결됨.

- [ ] **Step 2: 변경 파일 목록 확인 (커밋은 사용자가 직접 진행)**

```bash
git status --short
```

이 플랜의 모든 태스크가 끝나면 위 명령으로 변경된 파일 목록만 확인하고 멈춘다 — **git add/commit/push는 하지 않는다.** 사용자가 diff를 리뷰한 뒤 `commit`/`pr` 스킬 규약대로 직접 커밋·PR을 진행한다 (브랜치는 Task 0에서 만든 `feat/152-quiz-daily-streak`, 이슈는 `#152`).

---

## Self-Review 메모 (플랜 작성자용, 실행 시 참고)

- **스펙 커버리지**: 설계 문서의 "결정 사항" 표 8개 항목 모두 태스크에 반영됨 — 스텝=1커리큘럼(기존 QuizStep 재사용, 변경 없음), 스트릭 계산 시점(쓰기=Task 3, 읽기=Task 4), 끊김 표시(즉시 반영, Task 1의 `getEffectiveStreak`), 하루 여러 스텝 멱등(Task 1의 `recordCompletion` 멱등 체크 + Task 3 테스트), 하드 블록 없음(비범위, 태스크 없음 — 의도적), 커서 진행 안 막음(기존 로직 유지, 변경 없음), 복습 무영향(Task 3 Step 1의 세 번째 신규 테스트), 히스토리 비스코프(변경 없음, 확장 지점은 `UserProgressService.recordStepCompletion` 한 곳으로 이미 모여 있음).
- **플레이스홀더 스캔**: "TBD"/"추후 구현" 등 없음. 모든 코드 스텝에 완전한 코드 포함.
- **타입 일관성**: `UserProgressService.recordStepCompletion(Long, LocalDate)` 시그니처가 Task 2 정의 → Task 3 호출부에서 동일하게 사용됨 확인. `HomeResponse.from(int, int, boolean, Course, QuizStep, int)` 시그니처가 Task 4 DTO 정의 → HomeService 호출부와 일치 확인. `QuizService` 생성자 파라미터 순서가 Task 3 본문·테스트 파일 3곳(QuizServiceTest, QuizExplanationServiceTest) 모두 동일 순서(`quizRepository, courseRepository, quizStepRepository, quizAttemptRepository, quizProgressRepository, userProgressService, clock`)로 일치 확인.
- **points 스코프**: 설계 문서 "비범위"대로 이번 플랜은 `points` 갱신 로직을 건드리지 않는다(항상 0, 별도 후속 티켓).
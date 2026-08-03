package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.user.UserProgressPort;
import studio.thumbsup.server.common.user.UserProgressSnapshot;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.HomeResponse;

@ExtendWith(MockitoExtension.class)
class HomeServiceTest {

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    @Mock
    private UserProgressPort userProgressPort;

    private HomeService homeService;

    private static final Long USER_ID = 1L;
    private static final Long COURSE_A = 1L;
    private static final Long COURSE_B = 2L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");
    private static final LocalDate TODAY_KST = LocalDate.of(2026, 7, 11);

    private HomeService service() {
        return new HomeService(
                courseRepository,
                quizStepRepository,
                quizProgressRepository,
                userProgressPort,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static QuizStep step(int stepOrder, Long courseId, String topic) {
        return QuizStep.create(stepOrder, courseId, topic, 3);
    }

    private static QuizProgress progressAt(Long courseId, int stepOrder) {
        return QuizProgress.create(USER_ID, courseId, stepOrder);
    }

    @Nested
    @DisplayName("홈 화면 조회 — 진행 중인 코스 목록")
    class GetHomeCourses {

        @Test
        @DisplayName("리포지토리가 준 최근 푼 순서를 그대로 유지해 코스 목록을 조립한다")
        void keeps_recently_solved_order_from_repository() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_B, 4), progressAt(COURSE_A, 1)));
            given(courseRepository.findAllById(List.of(COURSE_B, COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A"), QuizFixture.course(COURSE_B, "코스B")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_B, COURSE_A)))
                    .willReturn(List.of(
                            step(1, COURSE_A, "A1"),
                            step(2, COURSE_A, "A2"),
                            step(4, COURSE_B, "B1"),
                            step(5, COURSE_B, "B2")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(new UserProgressSnapshot(5, 320, true));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.courses())
                    .extracting(HomeResponse.CourseLearning::courseId)
                    .containsExactly(COURSE_B, COURSE_A);
            assertThat(response.courses().get(0).courseTitle()).isEqualTo("코스B");
            assertThat(response.courses().get(0).unitTitle()).isEqualTo("B1");
            assertThat(response.streakDays()).isEqualTo(5);
            assertThat(response.points()).isEqualTo(320);
            assertThat(response.todayCompleted()).isTrue();
        }

        @Test
        @DisplayName("완료한 스텝 수는 정렬된 스텝 목록에서 현재 스텝 앞의 개수, 전체 스텝 수는 그 코스의 스텝 개수로 계산한다")
        void computes_completed_and_total_counts_per_course() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_B, 6)));
            given(courseRepository.findAllById(List.of(COURSE_B)))
                    .willReturn(List.of(QuizFixture.course(COURSE_B, "코스B")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_B)))
                    .willReturn(List.of(step(4, COURSE_B, "B1"), step(5, COURSE_B, "B2"), step(6, COURSE_B, "B3")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            HomeResponse.CourseLearning item = response.courses().get(0);
            assertThat(item.order()).isEqualTo(6);
            assertThat(item.completedCount()).isEqualTo(2);
            assertThat(item.totalCount()).isEqualTo(3);
        }

        @Test
        @DisplayName("스텝 번호가 비연속인 코스(중간 스텝 삭제)에서도 완료 수는 실제 앞 스텝 개수로 계산한다")
        void computes_completed_count_by_position_when_step_orders_are_non_contiguous() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_A, 3)));
            given(courseRepository.findAllById(List.of(COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1"), step(3, COURSE_A, "A3")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            // 번호 뺄셈(3-1=2)이면 2/2로 완주처럼 보인다 — 마지막 스텝에 머무는 동안은 완료 수 < 전체여야 한다.
            HomeResponse.CourseLearning item = response.courses().get(0);
            assertThat(item.completedCount()).isEqualTo(1);
            assertThat(item.totalCount()).isEqualTo(2);
            assertThat(item.completedCount()).isLessThan(item.totalCount());
        }

        @Test
        @DisplayName("저장된 커서가 그 코스의 마지막 스텝을 넘으면 마지막 스텝으로 고정한다(코스 완주)")
        void clamps_cursor_to_last_step_when_course_completed() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_A, 99)));
            given(courseRepository.findAllById(List.of(COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1"), step(2, COURSE_A, "A2"), step(3, COURSE_A, "A3")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.courses().get(0).order()).isEqualTo(3);
            assertThat(response.courses().get(0).unitTitle()).isEqualTo("A3");
        }

        @Test
        @DisplayName("진행 기록의 코스가 삭제됐으면 그 코스만 목록에서 빠진다")
        void skips_course_that_no_longer_exists() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_B, 4), progressAt(COURSE_A, 1)));
            given(courseRepository.findAllById(List.of(COURSE_B, COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_B, COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1"), step(4, COURSE_B, "B1")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.courses())
                    .extracting(HomeResponse.CourseLearning::courseId)
                    .containsExactly(COURSE_A);
        }

        @Test
        @DisplayName("스텝이 하나도 없는 코스는 목록에서 빠진다")
        void skips_course_without_steps() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_B, 4), progressAt(COURSE_A, 1)));
            given(courseRepository.findAllById(List.of(COURSE_B, COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A"), QuizFixture.course(COURSE_B, "코스B")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_B, COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.courses())
                    .extracting(HomeResponse.CourseLearning::courseId)
                    .containsExactly(COURSE_A);
        }

        @Test
        @DisplayName("커서 위치에 해당하는 스텝이 없으면(중간 스텝 삭제) 그 코스만 목록에서 빠진다")
        void skips_course_when_step_missing_at_cursor() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_A, 2)));
            given(courseRepository.findAllById(List.of(COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A")));
            // 조립·폴백 둘 다 같은 인자로 스텝을 조회하므로 스텁 하나로 충분하다.
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1"), step(3, COURSE_A, "A3")));
            given(courseRepository.findFirstByOrderByIdAsc())
                    .willReturn(Optional.of(QuizFixture.course(COURSE_A, "코스A")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            // 커서 스텝이 사라진 코스는 빠지고, 목록이 비어 폴백(첫 코스 첫 스텝)이 담긴다.
            assertThat(response.courses()).hasSize(1);
            assertThat(response.courses().get(0).order()).isEqualTo(1);
            assertThat(response.courses().get(0).completedCount()).isZero();
        }
    }

    @Nested
    @DisplayName("홈 화면 조회 — 신규 유저 폴백")
    class GetHomeFallback {

        @Test
        @DisplayName("진행 기록이 없으면 첫 번째 코스의 첫 스텝을 담은 목록과 기본 상태를 반환한다")
        void returns_first_course_when_no_progress() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of());
            given(courseRepository.findFirstByOrderByIdAsc())
                    .willReturn(Optional.of(QuizFixture.course(COURSE_A, "코스A")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1"), step(2, COURSE_A, "A2")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(UserProgressSnapshot.empty());

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.streakDays()).isZero();
            assertThat(response.points()).isZero();
            assertThat(response.todayCompleted()).isFalse();
            assertThat(response.courses()).hasSize(1);
            HomeResponse.CourseLearning item = response.courses().get(0);
            assertThat(item.courseId()).isEqualTo(COURSE_A);
            assertThat(item.order()).isEqualTo(1);
            assertThat(item.completedCount()).isZero();
            assertThat(item.totalCount()).isEqualTo(2);
        }

        @Test
        @DisplayName("코스가 하나도 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_no_course_exists() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of());
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.empty());

            assertThatThrownBy(() -> homeService.getHome(USER_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }

        @Test
        @DisplayName("첫 번째 코스에 스텝이 하나도 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_first_course_has_no_steps() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of());
            given(courseRepository.findFirstByOrderByIdAsc())
                    .willReturn(Optional.of(QuizFixture.course(COURSE_A, "코스A")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A)))
                    .willReturn(List.of());

            assertThatThrownBy(() -> homeService.getHome(USER_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }
    }

    @Nested
    @DisplayName("홈 화면 조회 — 스트릭·포인트 스냅샷")
    class GetHomeSnapshot {

        @Test
        @DisplayName("포트가 이틀 이상 끊긴 스트릭을 0으로 계산해 주면 그 값을 그대로 보여준다")
        void returns_zero_streak_when_stale() {
            homeService = service();
            given(quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID))
                    .willReturn(List.of(progressAt(COURSE_A, 2)));
            given(courseRepository.findAllById(List.of(COURSE_A)))
                    .willReturn(List.of(QuizFixture.course(COURSE_A, "코스A")));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A)))
                    .willReturn(List.of(step(1, COURSE_A, "A1"), step(2, COURSE_A, "A2")));
            given(userProgressPort.getSnapshot(USER_ID, TODAY_KST)).willReturn(new UserProgressSnapshot(0, 320, false));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.streakDays()).isZero();
            assertThat(response.points()).isEqualTo(320);
            assertThat(response.todayCompleted()).isFalse();
        }
    }
}

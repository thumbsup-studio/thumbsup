package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.common.exception.BusinessException;
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
    private UserProgressRepository userProgressRepository;

    private HomeService homeService;

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");
    private static final LocalDate TODAY_KST = LocalDate.of(2026, 7, 11);

    private HomeService service() {
        return new HomeService(
                courseRepository,
                quizStepRepository,
                quizProgressRepository,
                userProgressRepository,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static QuizStep step(int stepOrder, String topic, int estimatedMinutes) {
        return QuizStep.create(stepOrder, COURSE_ID, topic, estimatedMinutes);
    }

    @Nested
    @DisplayName("홈 화면 조회")
    class GetHome {

        @Test
        @DisplayName("진행 기록이 있으면 저장된 streak/points와 커서 위치의 스텝을 반환한다")
        void returns_saved_progress_and_current_step() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST)));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.streakDays()).isEqualTo(5);
            assertThat(response.points()).isEqualTo(320);
            assertThat(response.today().unitTitle()).isEqualTo("스택과 큐");
            assertThat(response.today().order()).isEqualTo(2);
            assertThat(response.today().totalCount()).isEqualTo(3);
        }

        @Test
        @DisplayName("진행 기록이 없으면 streak 0·points 0·그 코스의 첫 스텝부터 시작하는 기본 상태를 반환한다")
        void returns_default_state_when_no_progress() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.of(step(1, "배열과 리스트", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.streakDays()).isZero();
            assertThat(response.points()).isZero();
            assertThat(response.today().order()).isEqualTo(1);
            assertThat(response.today().completedCount()).isZero();
            assertThat(response.todayCompleted()).isFalse();
        }

        @Test
        @DisplayName("저장된 커서가 그 코스의 마지막 스텝을 넘으면 마지막 스텝으로 고정한다(코스 완주)")
        void clamps_cursor_to_last_step_when_course_completed() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progressAtStep(99)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 10, 1000, TODAY_KST)));
            given(quizStepRepository.findByStepOrder(3)).willReturn(Optional.of(step(3, "해시 테이블", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.today().order()).isEqualTo(3);
            assertThat(response.today().unitTitle()).isEqualTo("해시 테이블");
        }

        @Test
        @DisplayName("완료한 스텝 수는 커서-시작스텝으로 계산한다")
        void computes_completed_count_as_cursor_minus_start_step() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progressAtStep(3)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST)));
            given(quizStepRepository.findByStepOrder(3)).willReturn(Optional.of(step(3, "해시 테이블", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.today().completedCount()).isEqualTo(2);
        }

        @Test
        @DisplayName("오늘 이미 완료했으면 todayCompleted=true를 반환한다")
        void returns_today_completed_true_when_completed_today() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST)));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.todayCompleted()).isTrue();
        }

        @Test
        @DisplayName("어제 완료하고 오늘은 아직이면 todayCompleted=false지만 스트릭은 유지된다")
        void returns_today_completed_false_when_not_completed_today() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 5, 320, TODAY_KST.minusDays(1))));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.todayCompleted()).isFalse();
            assertThat(response.streakDays()).isEqualTo(5);
        }

        @Test
        @DisplayName("이틀 이상 스트릭이 끊겼으면 streakDays를 0으로 보여준다(DB 값은 그대로 둔다)")
        void returns_zero_streak_when_stale() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progressAtStep(2)));
            given(userProgressRepository.findByUserId(USER_ID))
                    .willReturn(Optional.of(QuizFixture.userProgress(1L, USER_ID, 7, 320, TODAY_KST.minusDays(3))));
            given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(step(2, "스택과 큐", 3)));

            HomeResponse response = homeService.getHome(USER_ID, null);

            assertThat(response.streakDays()).isZero();
            assertThat(response.todayCompleted()).isFalse();
        }

        @Test
        @DisplayName("기본 코스가 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_no_default_course() {
            homeService = service();
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.empty());

            assertThatThrownBy(() -> homeService.getHome(USER_ID, null))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }

        @Test
        @DisplayName("커서 위치에 해당하는 스텝이 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_step_missing_at_cursor() {
            homeService = service();
            Course course = QuizFixture.course(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(quizStepRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.empty());

            assertThatThrownBy(() -> homeService.getHome(USER_ID, null))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }

        private QuizProgress progressAtStep(int stepOrder) {
            QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
            for (int i = 1; i < stepOrder; i++) {
                progress.advanceToNextStep();
            }
            return progress;
        }
    }
}

package studio.thumbsup.server.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;

import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.learning.dto.HomeResponse;

@ExtendWith(MockitoExtension.class)
class HomeServiceTest {

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private UnitRepository unitRepository;

    @Mock
    private UserProgressRepository userProgressRepository;

    private HomeService homeService;

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;

    private HomeService service() {
        return new HomeService(courseRepository, unitRepository, userProgressRepository);
    }

    @Nested
    @DisplayName("홈 화면 조회")
    class GetHome {

        @Test
        @DisplayName("진행 기록이 있으면 저장된 streak/points와 커서 위치의 화를 반환한다")
        void returns_saved_progress_and_current_unit() {
            homeService = service();
            Course course = LearningFixture.courseWithUnits(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(unitRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            UserProgress progress = LearningFixture.userProgress(1L, USER_ID, COURSE_ID, 2, 5, 320);
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));
            Unit secondUnit = course.getUnits().get(1);
            given(unitRepository.findByCourseIdAndOrderIndex(COURSE_ID, 2)).willReturn(Optional.of(secondUnit));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.streakDays()).isEqualTo(5);
            assertThat(response.points()).isEqualTo(320);
            assertThat(response.today().unitTitle()).isEqualTo("스택과 큐");
            assertThat(response.today().order()).isEqualTo(2);
            assertThat(response.today().totalCount()).isEqualTo(3);
        }

        @Test
        @DisplayName("진행 기록이 없으면 streak 0·points 0·1화부터 시작하는 기본 상태를 반환한다")
        void returns_default_state_when_no_progress() {
            homeService = service();
            Course course = LearningFixture.courseWithUnits(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(unitRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            Unit firstUnit = course.getUnits().get(0);
            given(unitRepository.findByCourseIdAndOrderIndex(COURSE_ID, 1)).willReturn(Optional.of(firstUnit));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.streakDays()).isZero();
            assertThat(response.points()).isZero();
            assertThat(response.today().order()).isEqualTo(1);
            assertThat(response.today().completedCount()).isZero();
        }

        @Test
        @DisplayName("저장된 커서가 전체 화 수를 넘으면 마지막 화로 고정한다(코스 완주)")
        void clamps_cursor_to_last_unit_when_course_completed() {
            homeService = service();
            Course course = LearningFixture.courseWithUnits(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(unitRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            UserProgress progress = LearningFixture.userProgress(1L, USER_ID, COURSE_ID, 99, 10, 1000);
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));
            Unit lastUnit = course.getUnits().get(2);
            given(unitRepository.findByCourseIdAndOrderIndex(COURSE_ID, 3)).willReturn(Optional.of(lastUnit));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.today().order()).isEqualTo(3);
            assertThat(response.today().unitTitle()).isEqualTo("해시 테이블");
        }

        @Test
        @DisplayName("완료한 화 수는 커서-1로 계산한다")
        void computes_completed_count_as_cursor_minus_one() {
            homeService = service();
            Course course = LearningFixture.courseWithUnits(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(unitRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            UserProgress progress = LearningFixture.userProgress(1L, USER_ID, COURSE_ID, 3, 5, 320);
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));
            Unit thirdUnit = course.getUnits().get(2);
            given(unitRepository.findByCourseIdAndOrderIndex(COURSE_ID, 3)).willReturn(Optional.of(thirdUnit));

            HomeResponse response = homeService.getHome(USER_ID);

            assertThat(response.today().completedCount()).isEqualTo(2);
        }

        @Test
        @DisplayName("기본 코스가 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_no_default_course() {
            homeService = service();
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.empty());

            assertThatThrownBy(() -> homeService.getHome(USER_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }

        @Test
        @DisplayName("커서 위치에 해당하는 화가 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_unit_missing_at_cursor() {
            homeService = service();
            Course course = LearningFixture.courseWithUnits(COURSE_ID);
            given(courseRepository.findFirstByOrderByIdAsc()).willReturn(Optional.of(course));
            given(unitRepository.countByCourseId(COURSE_ID)).willReturn(3L);
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            given(unitRepository.findByCourseIdAndOrderIndex(eq(COURSE_ID), anyInt()))
                    .willReturn(Optional.empty());

            assertThatThrownBy(() -> homeService.getHome(USER_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }
    }
}

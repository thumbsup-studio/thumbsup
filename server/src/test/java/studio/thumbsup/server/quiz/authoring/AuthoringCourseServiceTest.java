package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedQuizResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedStepResponse;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

@ExtendWith(MockitoExtension.class)
class AuthoringCourseServiceTest {

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    private AuthoringCourseService service() {
        return new AuthoringCourseService(courseRepository, quizRepository, quizStepRepository);
    }

    @Nested
    @DisplayName("getCourseQuizzes")
    class GetCourseQuizzes {

        private List<Quiz> scrambledQuizzes() {
            // 스텝 2: slotOrder 역순으로 저장돼도 응답에서는 slotOrder 오름차순이어야 한다.
            Quiz stepTwoSlotTwo = QuizFixture.oxQuiz();
            ReflectionTestUtils.setField(stepTwoSlotTwo, "id", 201L);
            stepTwoSlotTwo.assignPosition(2, 2);

            Quiz stepTwoSlotOne = QuizFixture.oxQuiz2();
            ReflectionTestUtils.setField(stepTwoSlotOne, "id", 202L);
            stepTwoSlotOne.assignPosition(2, 1);

            // 스텝 1: 리포지토리 반환 순서상 스텝 2보다 뒤에 오지만 응답에서는 stepOrder 오름차순으로 앞에 와야 한다.
            Quiz stepOneSlotOne = QuizFixture.multipleChoiceQuiz();
            ReflectionTestUtils.setField(stepOneSlotOne, "id", 101L);
            stepOneSlotOne.assignPosition(1, 1);

            // stepOrder=0은 "스텝 밖" placeholder sentinel — 응답에서 완전히 제외돼야 한다.
            Quiz sentinel = QuizFixture.keywordBlankQuiz();
            ReflectionTestUtils.setField(sentinel, "id", 999L);
            sentinel.assignPosition(0, 1);

            return List.of(stepTwoSlotTwo, sentinel, stepOneSlotOne, stepTwoSlotOne);
        }

        private List<QuizStep> steps() {
            return List.of(QuizStep.create(1, 1L, "자료구조 기초", 10), QuizStep.create(2, 1L, "네트워크 기초", 10));
        }

        private void stubCourseAndQuizzes() {
            Course course = QuizFixture.course(1L);
            given(courseRepository.findById(1L)).willReturn(Optional.of(course));
            given(quizRepository.findAll()).willReturn(scrambledQuizzes());
            given(quizStepRepository.findAll()).willReturn(steps());
        }

        @Test
        @DisplayName("stepOrder=0 sentinel을 제외하고 (stepOrder, slotOrder) 순으로 스텝별로 묶어 반환한다")
        void groups_and_orders_quizzes_by_step_and_slot() {
            stubCourseAndQuizzes();

            AuthoringCourseDetailResponse response = service().getCourseQuizzes(1L);

            assertThat(response.courseId()).isEqualTo(1L);
            assertThat(response.title()).isEqualTo("CS 기초");
            assertThat(response.steps())
                    .extracting(AuthoringDetailedStepResponse::stepOrder)
                    .containsExactly(1, 2);

            AuthoringDetailedStepResponse stepTwo = response.steps().get(1);
            assertThat(stepTwo.quizzes())
                    .extracting(AuthoringDetailedQuizResponse::quizId)
                    .containsExactly(202L, 201L);
            assertThat(stepTwo.quizzes())
                    .extracting(AuthoringDetailedQuizResponse::slotOrder)
                    .containsExactly(1, 2);

            assertThat(response.steps())
                    .flatExtracting(AuthoringDetailedStepResponse::quizzes)
                    .extracting(AuthoringDetailedQuizResponse::quizId)
                    .doesNotContain(999L);
        }

        @Test
        @DisplayName("스텝 topic을 조회해 채우고 각 quiz의 generated 콘텐츠를 포함한다")
        void populates_step_topic_and_generated_quiz_content() {
            stubCourseAndQuizzes();

            AuthoringCourseDetailResponse response = service().getCourseQuizzes(1L);

            AuthoringDetailedStepResponse stepOne = response.steps().get(0);
            assertThat(stepOne.topic()).isEqualTo("자료구조 기초");
            assertThat(stepOne.quizzes()).hasSize(1);
            assertThat(stepOne.quizzes().get(0).quizId()).isEqualTo(101L);
            assertThat(stepOne.quizzes().get(0).slotOrder()).isEqualTo(1);
            assertThat(stepOne.quizzes().get(0).generated()).isNotNull();
            assertThat(stepOne.quizzes().get(0).generated().questionText()).isEqualTo("다음 코드의 시간복잡도는?");

            AuthoringDetailedStepResponse stepTwo = response.steps().get(1);
            assertThat(stepTwo.topic()).isEqualTo("네트워크 기초");
            assertThat(stepTwo.quizzes().get(0).generated()).isNotNull();
            assertThat(stepTwo.quizzes().get(0).generated().questionText()).isEqualTo("UDP는 신뢰성을 보장한다.");
            assertThat(stepTwo.quizzes().get(1).generated()).isNotNull();
            assertThat(stepTwo.quizzes().get(1).generated().questionText()).isEqualTo("TCP는 연결 지향 프로토콜이다.");
        }

        @Test
        @DisplayName("없는 코스면 AUTHORING_COURSE_NOT_FOUND")
        void throws_when_course_not_found() {
            given(courseRepository.findById(999L)).willReturn(Optional.empty());

            assertThatThrownBy(() -> service().getCourseQuizzes(999L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_COURSE_NOT_FOUND);
        }
    }
}

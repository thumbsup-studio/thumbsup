package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.BDDMockito.given;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;

/**
 * 해설 조회(#43)의 응답 조립 규칙을 검증한다 — 어떤 필드가 어떤 순서로 담기는가.
 * 같은 서비스를 다루지만 {@code QuizServiceTest}에서 분리했다(checkstyle 파일 길이 상한 400줄).
 *
 * <p>마커 파싱 자체의 분기는 {@link ExplanationTextParserTest}가 전수 검증하므로 여기서 반복하지 않는다.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("해설 조회")
class QuizExplanationServiceTest {

    private static final Long QUIZ_ID = 10L;
    private static final Long ABSENT_QUIZ_ID = 999L;
    private static final int STEP_ORDER = 7;
    private static final int SLOT_ORDER = 3;
    private static final long TOTAL_COUNT = 5L;
    private static final String COURSE_TITLE = "운영체제";
    private static final String UNIT_TITLE = "동기화 심화";

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    @Mock
    private QuizAttemptRepository quizAttemptRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    @Mock
    private ApplicationEventPublisher eventPublisher;

    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                eventPublisher,
                Clock.fixed(Instant.parse("2026-07-11T00:00:00Z"), ZoneOffset.UTC));
    }

    private static Quiz annotatedQuizWithId(Long id) {
        Quiz quiz = QuizFixture.annotatedExplanationQuiz();
        quiz.assignPosition(STEP_ORDER, SLOT_ORDER);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static Quiz plainQuizWithId(Long id) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(STEP_ORDER, SLOT_ORDER);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static final Long COURSE_ID = 1L;

    private void givenExplanationContext(Quiz quiz) {
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(quiz));
        given(quizStepRepository.findByStepOrder(STEP_ORDER))
                .willReturn(Optional.of(QuizStep.create(STEP_ORDER, COURSE_ID, UNIT_TITLE, 5)));
        given(courseRepository.findById(COURSE_ID)).willReturn(Optional.of(Course.create(COURSE_TITLE, "CS")));
        given(quizRepository.countByStepOrder(STEP_ORDER)).willReturn(TOTAL_COUNT);
    }

    @Nested
    @DisplayName("응답 조립")
    class ResponseAssembly {

        @Test
        @DisplayName("마커를 제거한 본문과 하이라이트 구간을 함께 반환한다")
        void returns_summary_with_highlights() {
            Quiz quiz = annotatedQuizWithId(QUIZ_ID);
            givenExplanationContext(quiz);

            QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

            assertThat(response.quizId()).isEqualTo(QUIZ_ID);
            assertThat(response.questionText()).isEqualTo(quiz.getQuestionText());
            assertThat(response.type()).isEqualTo(QuizType.OX);
            assertThat(response.difficulty()).isEqualTo(QuizDifficulty.EASY);
            assertThat(response.currentNumber()).isEqualTo(SLOT_ORDER);
            assertThat(response.totalCount()).isEqualTo(TOTAL_COUNT);
            assertThat(response.courseTitle()).isEqualTo(COURSE_TITLE);
            assertThat(response.unitTitle()).isEqualTo(UNIT_TITLE);
            assertThat(response.explanationSummary()).hasSize(2);

            QuizExplanationResponse.AnnotatedText firstLine =
                    response.explanationSummary().get(0);
            assertThat(firstLine.text()).isEqualTo("TCP는 연결 지향 프로토콜이다.");
            assertThat(firstLine.highlights()).containsExactly(new QuizExplanationResponse.Highlight("연결 지향", 5, 10));
        }

        @Test
        @DisplayName("해설 본문에 없는 키워드도 오답 해설에서 하이라이트된다")
        void highlights_keyword_found_only_in_wrong_answer_explanation() {
            givenExplanationContext(annotatedQuizWithId(QUIZ_ID));

            QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

            assertThat(response.wrongAnswerExplanation().text()).isEqualTo("UDP는 비연결형이라 handshake가 없다.");
            assertThat(response.wrongAnswerExplanation().highlights())
                    .extracting(QuizExplanationResponse.Highlight::keyword)
                    .containsExactly("비연결형");
        }

        @Test
        @DisplayName("대표 꼬리질문을 저작 순서와 무관하게 맨 앞에 두고, 상세가 없는 질문은 제외한다")
        void puts_primary_follow_up_question_first_and_drops_the_ones_without_detail() {
            givenExplanationContext(annotatedQuizWithId(QUIZ_ID));

            QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

            assertThat(response.followUpQuestions())
                    .extracting(
                            QuizExplanationResponse.FollowUpQuestionItem::followUpQuestionId,
                            QuizExplanationResponse.FollowUpQuestionItem::content,
                            QuizExplanationResponse.FollowUpQuestionItem::isPrimary)
                    .containsExactly(tuple(10L, "대표 질문입니다.", true), tuple(20L, "보조 질문입니다.", false));
        }

        @Test
        @DisplayName("예시가 없으면 null이고, 마커가 없는 본문은 하이라이트 없이 내려간다")
        void returns_null_example_and_no_highlights_without_markers() {
            givenExplanationContext(plainQuizWithId(QUIZ_ID));

            QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

            assertThat(response.explanationExample()).isNull();
            assertThat(response.explanationSummary()).hasSize(1);
            assertThat(response.explanationSummary().get(0).highlights()).isEmpty();
        }

        @Test
        @DisplayName("기본 코스가 아닌 다른 코스(예: 디자인 패턴)의 문제는 그 코스의 courseTitle을 반환한다")
        void returns_course_title_of_the_quizs_actual_course_not_the_default_course() {
            Long otherCourseId = 2L;
            Quiz quiz = plainQuizWithId(QUIZ_ID);
            given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(quiz));
            given(quizStepRepository.findByStepOrder(STEP_ORDER))
                    .willReturn(Optional.of(QuizStep.create(STEP_ORDER, otherCourseId, UNIT_TITLE, 5)));
            given(courseRepository.findById(otherCourseId)).willReturn(Optional.of(Course.create("디자인 패턴", "CS")));
            given(quizRepository.countByStepOrder(STEP_ORDER)).willReturn(TOTAL_COUNT);

            QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

            assertThat(response.courseTitle()).isEqualTo("디자인 패턴");
        }
    }

    @Nested
    @DisplayName("예외 처리")
    class ExceptionHandling {

        @Test
        @DisplayName("존재하지 않는 문제면 QUIZ_NOT_FOUND")
        void throws_quiz_not_found_when_absent() {
            given(quizRepository.findById(ABSENT_QUIZ_ID)).willReturn(Optional.empty());

            QuizService quizService = service();
            assertThatThrownBy(() -> quizService.getExplanation(ABSENT_QUIZ_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
        }

        @Test
        @DisplayName("문제가 속한 코스가 없으면 COURSE_NOT_FOUND")
        void throws_course_not_found_when_course_is_absent() {
            given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(annotatedQuizWithId(QUIZ_ID)));
            given(quizStepRepository.findByStepOrder(STEP_ORDER))
                    .willReturn(Optional.of(QuizStep.create(STEP_ORDER, COURSE_ID, UNIT_TITLE, 5)));
            given(courseRepository.findById(COURSE_ID)).willReturn(Optional.empty());

            QuizService quizService = service();
            assertThatThrownBy(() -> quizService.getExplanation(QUIZ_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(LearningErrorType.COURSE_NOT_FOUND));
        }
    }
}

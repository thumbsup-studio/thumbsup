package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.quiz.FollowUpBlockType;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizChoice;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizFollowUpBlock;
import studio.thumbsup.server.quiz.QuizFollowUpKeyword;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.course.CourseRepository;

@ExtendWith(MockitoExtension.class)
class QuizPersisterTest {

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    @Mock
    private CourseRepository courseRepository;

    private QuizPersister persister() {
        return new QuizPersister(quizRepository, quizStepRepository, courseRepository);
    }

    private static GeneratedQuizSet.GeneratedFollowUpQuestion followUpQuestion() {
        return new GeneratedQuizSet.GeneratedFollowUpQuestion(
                "꼬리질문",
                true,
                QuizDifficulty.MEDIUM,
                "한 줄 답",
                List.of(new GeneratedQuizSet.GeneratedFollowUpBlock("해설", "블록 본문")),
                List.of(new GeneratedQuizSet.GeneratedKeyword("LIFO", "설명")));
    }

    private static GeneratedQuizSet.GeneratedQuiz oxQuiz() {
        return oxQuizWith(followUpQuestion());
    }

    private static GeneratedQuizSet.GeneratedQuiz oxQuizWith(GeneratedQuizSet.GeneratedFollowUpQuestion followUp) {
        return new GeneratedQuizSet.GeneratedQuiz(
                QuizType.OX,
                QuizDifficulty.EASY,
                "질문 본문",
                "판단에 필요한 핵심 조건을 떠올려 보세요.",
                null, // codeSnippet
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.", // explanationSummary
                null, // explanationExample
                "오답 해설", // wrongAnswerExplanation
                "O", // correctAnswer
                null, // choices
                null, // answerKeywords
                List.of(followUp),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("키워드1", "설명")));
    }

    private static GeneratedQuizSet.GeneratedQuiz keywordBlankQuizWithSynonyms() {
        return new GeneratedQuizSet.GeneratedQuiz(
                QuizType.KEYWORD_BLANK,
                QuizDifficulty.HARD,
                "빈칸 ___ 문제",
                "자료가 드나드는 순서의 기준을 떠올려 보세요.",
                null, // codeSnippet
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.", // explanationSummary
                null, // explanationExample
                "오답 해설", // wrongAnswerExplanation
                null, // correctAnswer
                null, // choices
                List.of(List.of("LIFO", "Last In First Out")), // answerKeywords
                List.of(followUpQuestion()),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("LIFO", "설명")));
    }

    @Test
    @DisplayName("기존 스텝이 없으면 1스텝부터 시작해 문제들을 슬롯 순서대로 저장한다")
    void assigns_step_and_slot_order_from_one_when_no_existing_step() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz(), oxQuiz()));

        int stepOrder = persister().persist(1L, "운영체제", generated);

        assertThat(stepOrder).isEqualTo(1);
        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository, times(2)).save(captor.capture());
        assertThat(captor.getAllValues()).extracting(Quiz::getSlotOrder).containsExactly(1, 2);
        assertThat(captor.getAllValues())
                .allSatisfy(quiz -> assertThat(quiz.getStepOrder()).isEqualTo(1));
        assertThat(captor.getAllValues())
                .allSatisfy(quiz -> assertThat(quiz.getHint()).isEqualTo("판단에 필요한 핵심 조건을 떠올려 보세요."));
    }

    @Test
    @DisplayName("기존 스텝이 있으면 다음 번호로 이어서 저장한다")
    void assigns_next_step_order_when_existing_steps_present() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.of(3));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz()));

        int stepOrder = persister().persist(1L, "운영체제", generated);

        assertThat(stepOrder).isEqualTo(4);
    }

    @Test
    @DisplayName("문제 세트를 지정한 step_order와 예상 시간으로 저장한다")
    void persists_at_explicit_step_order_and_estimated_minutes() {
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz()));

        int stepOrder = persister().persistAt(1L, 42, "명시적 스텝", 7, generated);

        assertThat(stepOrder).isEqualTo(42);
        ArgumentCaptor<QuizStep> captor = ArgumentCaptor.forClass(QuizStep.class);
        verify(quizStepRepository).save(captor.capture());
        assertThat(captor.getValue().getStepOrder()).isEqualTo(42);
        assertThat(captor.getValue().getTopic()).isEqualTo("명시적 스텝");
        assertThat(captor.getValue().getEstimatedMinutes()).isEqualTo(7);
    }

    @Test
    @DisplayName("quiz에는 비어 있어도 quiz_step에 이미 있는 마지막 순서를 재사용하지 않는다")
    void does_not_reuse_step_order_that_exists_only_in_quiz_step() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        given(quizStepRepository.findMaxStepOrder()).willReturn(Optional.of(7));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz()));

        int stepOrder = persister().persist(1L, "빈 문제 스텝", generated);

        assertThat(stepOrder).isEqualTo(8);
    }

    @Test
    @DisplayName("스텝 주제(QuizStep)도 함께 저장한다")
    void saves_quiz_step_topic() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.of(3));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz()));

        persister().persist(1L, "CPU 스케줄링 기초", generated);

        ArgumentCaptor<QuizStep> captor = ArgumentCaptor.forClass(QuizStep.class);
        verify(quizStepRepository).save(captor.capture());
        assertThat(captor.getValue().getStepOrder()).isEqualTo(4);
        assertThat(captor.getValue().getTopic()).isEqualTo("CPU 스케줄링 기초");
        assertThat(captor.getValue().getEstimatedMinutes()).isEqualTo(3);
    }

    @Test
    @DisplayName("동의어 여러 개가 등록된 빈칸도 같은 슬롯으로 저장한다")
    void saves_multiple_synonyms_for_one_blank_in_same_slot() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(keywordBlankQuizWithSynonyms()));

        persister().persist(1L, "운영체제", generated);

        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository).save(captor.capture());
        assertThat(captor.getValue().getAnswerKeywords()).hasSize(2);
        assertThat(captor.getValue().getAnswerKeywords())
                .allSatisfy(k -> assertThat(k.getSlotOrder()).isEqualTo(1));
    }

    @Test
    @DisplayName("꼬리질문의 상세·블록·키워드를 함께 저장하고, 블록에 표시 순서를 1부터 부여한다")
    void saves_follow_up_question_detail_with_ordered_blocks() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        GeneratedQuizSet.GeneratedFollowUpQuestion detailed = new GeneratedQuizSet.GeneratedFollowUpQuestion(
                "큐와 스택의 차이는?",
                true,
                QuizDifficulty.HARD,
                "스택은 [[LIFO]]입니다.",
                List.of(
                        new GeneratedQuizSet.GeneratedFollowUpBlock("해설", "한쪽 끝에서만 넣고 뺀다."),
                        new GeneratedQuizSet.GeneratedFollowUpBlock("실무 사용처", "함수 호출 스택이 대표적이다.")),
                List.of(new GeneratedQuizSet.GeneratedKeyword("LIFO", "마지막에 넣은 데이터가 먼저 나오는 순서")));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuizWith(detailed)));

        persister().persist(1L, "자료구조", generated);

        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository).save(captor.capture());
        QuizFollowUpQuestion saved = captor.getValue().getFollowUpQuestions().get(0);

        assertThat(saved.hasDetail()).isTrue();
        assertThat(saved.getDifficulty()).isEqualTo(QuizDifficulty.HARD);
        assertThat(saved.getOneLineAnswer()).isEqualTo("스택은 [[LIFO]]입니다.");
        assertThat(saved.getBlocks())
                .extracting(QuizFollowUpBlock::getLabel, QuizFollowUpBlock::getDisplayOrder)
                .containsExactly(tuple("해설", 1), tuple("실무 사용처", 2));
        assertThat(saved.getBlocks())
                .allSatisfy(block -> assertThat(block.getType()).isEqualTo(FollowUpBlockType.TEXT));
        assertThat(saved.getKeywords())
                .extracting(QuizFollowUpKeyword::getKeyword)
                .containsExactly("LIFO");
    }

    @Test
    @DisplayName("사지선다는 선택지를 정답 여부·순서와 함께 저장한다")
    void saves_multiple_choice_with_choices() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        GeneratedQuizSet.GeneratedQuiz mc = new GeneratedQuizSet.GeneratedQuiz(
                QuizType.MULTIPLE_CHOICE,
                QuizDifficulty.MEDIUM,
                "질문 본문",
                "각 개념이 맡는 역할의 차이를 비교해 보세요.",
                null, // codeSnippet
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.", // explanationSummary
                null, // explanationExample
                "오답 해설", // wrongAnswerExplanation
                null, // correctAnswer
                List.of(
                        new GeneratedQuizSet.GeneratedChoice("a", false),
                        new GeneratedQuizSet.GeneratedChoice("b", true)), // choices
                null, // answerKeywords
                List.of(followUpQuestion()),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("키워드1", "설명")));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(mc));

        persister().persist(1L, "운영체제", generated);

        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository).save(captor.capture());
        assertThat(captor.getValue().getChoices()).hasSize(2);
        assertThat(captor.getValue().getChoices())
                .filteredOn(QuizChoice::isCorrect)
                .extracting(QuizChoice::getContent)
                .containsExactly("b");
    }

    @Test
    @DisplayName("뒤쪽 슬롯의 hint가 정답을 노출하면 어떤 스텝이나 문제도 저장하지 않는다")
    void validates_every_hint_before_any_database_write() {
        GeneratedQuizSet.GeneratedQuiz invalidQuiz = new GeneratedQuizSet.GeneratedQuiz(
                QuizType.OX,
                QuizDifficulty.EASY,
                "질문 본문",
                "정답은 O입니다.",
                null,
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.",
                null,
                "오답 해설",
                "O",
                null,
                null,
                List.of(followUpQuestion()),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("키워드1", "설명")));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz(), invalidQuiz));

        assertThatThrownBy(() -> persister().persist(1L, "운영체제", generated))
                .isInstanceOf(QuizGenerationException.class)
                .hasMessageContaining("슬롯 2")
                .hasMessageContaining("정답을 직접 지시");

        verifyNoInteractions(quizRepository);
        verify(quizStepRepository, never()).save(org.mockito.ArgumentMatchers.any(QuizStep.class));
    }
}

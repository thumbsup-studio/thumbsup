package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizChoice;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;

@ExtendWith(MockitoExtension.class)
class QuizPersisterTest {

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    private QuizPersister persister() {
        return new QuizPersister(quizRepository, quizStepRepository);
    }

    private static GeneratedQuizSet.GeneratedQuiz oxQuiz() {
        return new GeneratedQuizSet.GeneratedQuiz(
                QuizType.OX,
                QuizDifficulty.EASY,
                "질문 본문",
                null, // codeSnippet
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.", // explanationSummary
                null, // explanationExample
                "오답 해설", // wrongAnswerExplanation
                "O", // correctAnswer
                null, // choices
                null, // answerKeywords
                List.of(new GeneratedQuizSet.GeneratedFollowUpQuestion("꼬리질문", true)),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("키워드1", "설명")));
    }

    private static GeneratedQuizSet.GeneratedQuiz keywordBlankQuizWithSynonyms() {
        return new GeneratedQuizSet.GeneratedQuiz(
                QuizType.KEYWORD_BLANK,
                QuizDifficulty.HARD,
                "빈칸 ___ 문제",
                null, // codeSnippet
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.", // explanationSummary
                null, // explanationExample
                "오답 해설", // wrongAnswerExplanation
                null, // correctAnswer
                null, // choices
                List.of(List.of("LIFO", "Last In First Out")), // answerKeywords
                List.of(new GeneratedQuizSet.GeneratedFollowUpQuestion("꼬리질문", true)),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("LIFO", "설명")));
    }

    @Test
    @DisplayName("기존 스텝이 없으면 1스텝부터 시작해 문제들을 슬롯 순서대로 저장한다")
    void assigns_step_and_slot_order_from_one_when_no_existing_step() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz(), oxQuiz()));

        int stepOrder = persister().persist("운영체제", generated);

        assertThat(stepOrder).isEqualTo(1);
        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository, times(2)).save(captor.capture());
        assertThat(captor.getAllValues()).extracting(Quiz::getSlotOrder).containsExactly(1, 2);
        assertThat(captor.getAllValues())
                .allSatisfy(quiz -> assertThat(quiz.getStepOrder()).isEqualTo(1));
    }

    @Test
    @DisplayName("기존 스텝이 있으면 다음 번호로 이어서 저장한다")
    void assigns_next_step_order_when_existing_steps_present() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.of(3));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz()));

        int stepOrder = persister().persist("운영체제", generated);

        assertThat(stepOrder).isEqualTo(4);
    }

    @Test
    @DisplayName("스텝 주제(QuizStep)도 함께 저장한다")
    void saves_quiz_step_topic() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.of(3));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(oxQuiz()));

        persister().persist("CPU 스케줄링 기초", generated);

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

        persister().persist("운영체제", generated);

        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository).save(captor.capture());
        assertThat(captor.getValue().getAnswerKeywords()).hasSize(2);
        assertThat(captor.getValue().getAnswerKeywords())
                .allSatisfy(k -> assertThat(k.getSlotOrder()).isEqualTo(1));
    }

    @Test
    @DisplayName("사지선다는 선택지를 정답 여부·순서와 함께 저장한다")
    void saves_multiple_choice_with_choices() {
        given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
        GeneratedQuizSet.GeneratedQuiz mc = new GeneratedQuizSet.GeneratedQuiz(
                QuizType.MULTIPLE_CHOICE,
                QuizDifficulty.MEDIUM,
                "질문 본문",
                null, // codeSnippet
                "핵심 요약 1줄.\n핵심 요약 2줄.\n핵심 요약 3줄.", // explanationSummary
                null, // explanationExample
                "오답 해설", // wrongAnswerExplanation
                null, // correctAnswer
                List.of(
                        new GeneratedQuizSet.GeneratedChoice("a", false),
                        new GeneratedQuizSet.GeneratedChoice("b", true)), // choices
                null, // answerKeywords
                List.of(new GeneratedQuizSet.GeneratedFollowUpQuestion("꼬리질문", true)),
                List.of("개념1"),
                List.of(new GeneratedQuizSet.GeneratedKeyword("키워드1", "설명")));
        GeneratedQuizSet generated = new GeneratedQuizSet(List.of(mc));

        persister().persist("운영체제", generated);

        ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
        verify(quizRepository).save(captor.capture());
        assertThat(captor.getValue().getChoices()).hasSize(2);
        assertThat(captor.getValue().getChoices())
                .filteredOn(QuizChoice::isCorrect)
                .extracting(QuizChoice::getContent)
                .containsExactly("b");
    }
}

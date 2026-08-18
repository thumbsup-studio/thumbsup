package studio.thumbsup.server.quiz.concept;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;
import studio.thumbsup.server.quiz.QuizRepository;

/**
 * 학습 개념 기록 로직 단위 테스트(#233) — 스텝 완료라는 사실이 주어졌을 때
 * user_concept(최초 학습)과 user_concept_step(관련 스텝)이 정확히 남는지 검증한다.
 * 호출 시점(스텝을 처음 완료할 때만)은 {@code QuizServiceLearnedConceptTest}의 소관이다.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("학습 개념 기록기")
class LearnedConceptRecorderTest {

    private static final Long USER_ID = 1L;
    private static final Long QUIZ_STEP_ID = 1L;
    private static final List<Long> STEP_QUIZ_IDS = List.of(6L, 7L, 8L, 9L, 10L);

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizConceptRepository quizConceptRepository;

    @Mock
    private UserConceptRepository userConceptRepository;

    @Mock
    private UserConceptStepRepository userConceptStepRepository;

    @InjectMocks
    private LearnedConceptRecorder learnedConceptRecorder;

    @Test
    @DisplayName("스텝 완료 이벤트를 받으면 그 스텝의 퀴즈 id를 직접 조회해 기록한다")
    void looks_up_step_quiz_ids_on_event_and_records() {
        given(quizRepository.findIdsByQuizStepId(QUIZ_STEP_ID)).willReturn(STEP_QUIZ_IDS);
        given(quizConceptRepository.findDistinctConceptIdsByQuizIdIn(STEP_QUIZ_IDS))
                .willReturn(List.of(100L));
        given(userConceptRepository.findByUserIdAndConceptIdIn(USER_ID, List.of(100L)))
                .willReturn(List.of());

        learnedConceptRecorder.onStepCompleted(
                new QuizStepCompletedEvent(USER_ID, LocalDate.of(2026, 7, 8), QUIZ_STEP_ID));

        verify(userConceptRepository).save(any(UserConcept.class));
        ArgumentCaptor<UserConceptStep> stepCaptor = ArgumentCaptor.forClass(UserConceptStep.class);
        verify(userConceptStepRepository).save(stepCaptor.capture());
        assertThat(stepCaptor.getValue().getQuizStepId()).isEqualTo(QUIZ_STEP_ID);
    }

    @Test
    @DisplayName("처음 배우는 개념은 user_concept과 user_concept_step을 모두 남긴다")
    void records_user_concept_and_step_for_new_concepts() {
        given(quizConceptRepository.findDistinctConceptIdsByQuizIdIn(STEP_QUIZ_IDS))
                .willReturn(List.of(100L, 200L));
        given(userConceptRepository.findByUserIdAndConceptIdIn(USER_ID, List.of(100L, 200L)))
                .willReturn(List.of());

        learnedConceptRecorder.record(USER_ID, QUIZ_STEP_ID, STEP_QUIZ_IDS);

        ArgumentCaptor<UserConcept> conceptCaptor = ArgumentCaptor.forClass(UserConcept.class);
        verify(userConceptRepository, times(2)).save(conceptCaptor.capture());
        assertThat(conceptCaptor.getAllValues())
                .extracting(UserConcept::getConceptId)
                .containsExactlyInAnyOrder(100L, 200L);

        ArgumentCaptor<UserConceptStep> stepCaptor = ArgumentCaptor.forClass(UserConceptStep.class);
        verify(userConceptStepRepository, times(2)).save(stepCaptor.capture());
        assertThat(stepCaptor.getAllValues())
                .extracting(UserConceptStep::getConceptId, UserConceptStep::getQuizStepId)
                .containsExactlyInAnyOrder(tuple(100L, QUIZ_STEP_ID), tuple(200L, QUIZ_STEP_ID));
    }

    @Test
    @DisplayName("이미 학습한 개념이면 user_concept은 다시 만들지 않고, user_concept_step만 추가한다")
    void does_not_duplicate_already_learned_concept() {
        given(quizConceptRepository.findDistinctConceptIdsByQuizIdIn(STEP_QUIZ_IDS))
                .willReturn(List.of(100L));
        given(userConceptRepository.findByUserIdAndConceptIdIn(USER_ID, List.of(100L)))
                .willReturn(List.of(UserConcept.create(USER_ID, 100L)));

        learnedConceptRecorder.record(USER_ID, 4L, STEP_QUIZ_IDS);

        verify(userConceptRepository, never()).save(any());
        verify(userConceptStepRepository).save(any(UserConceptStep.class));
    }

    @Test
    @DisplayName("정규화된 개념 링크가 없는 스텝은 아무 기록도 남기지 않는다")
    void skips_recording_when_no_concept_ids() {
        given(quizConceptRepository.findDistinctConceptIdsByQuizIdIn(STEP_QUIZ_IDS))
                .willReturn(List.of());

        learnedConceptRecorder.record(USER_ID, QUIZ_STEP_ID, STEP_QUIZ_IDS);

        verify(userConceptRepository, never()).findByUserIdAndConceptIdIn(any(), anyCollection());
        verify(userConceptStepRepository, never()).save(any());
    }
}

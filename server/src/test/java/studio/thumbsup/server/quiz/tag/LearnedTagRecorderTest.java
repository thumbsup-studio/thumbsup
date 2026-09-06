package studio.thumbsup.server.quiz.tag;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Instant;
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
 * 학습 태그 기록 로직 단위 테스트(#233, #324) — 스텝 완료라는 사실이 주어졌을 때
 * user_tag(최초 학습)과 user_tag_step(관련 스텝)이 정확히 남는지 검증한다.
 * 태그가 여러 코스에서 재사용될 수 있게 되면서 "조회 후 저장" 방식은 경합 상태에서
 * 유니크 제약 위반을 일으킬 수 있어, user_tag는 네이티브 upsert로만 기록한다 —
 * 그래서 이 테스트는 "이미 학습했는지" 여부와 무관하게 upsert가 항상 호출되고,
 * user_tag_step은 upsert 성패와 독립적으로 항상 저장되는지를 검증한다.
 * 호출 시점(스텝을 처음 완료할 때만)은 {@code QuizServiceLearnedTagTest}의 소관이다.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("학습 태그 기록기")
class LearnedTagRecorderTest {

    private static final Long USER_ID = 1L;
    private static final Long QUIZ_STEP_ID = 1L;
    private static final List<Long> STEP_QUIZ_IDS = List.of(6L, 7L, 8L, 9L, 10L);
    private static final Instant NOW = Instant.parse("2026-07-08T00:00:00Z");

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizTagRepository quizTagRepository;

    @Mock
    private UserTagRepository userTagRepository;

    @Mock
    private UserTagStepRepository userTagStepRepository;

    @Mock
    private Clock clock;

    @InjectMocks
    private LearnedTagRecorder learnedTagRecorder;

    @Test
    @DisplayName("스텝 완료 이벤트를 받으면 그 스텝의 퀴즈 id를 직접 조회해 기록한다")
    void looks_up_step_quiz_ids_on_event_and_records() {
        given(quizRepository.findIdsByQuizStepId(QUIZ_STEP_ID)).willReturn(STEP_QUIZ_IDS);
        given(quizTagRepository.findDistinctTagIdsByQuizIdIn(STEP_QUIZ_IDS)).willReturn(List.of(100L));
        given(clock.instant()).willReturn(NOW);

        learnedTagRecorder.onStepCompleted(new QuizStepCompletedEvent(USER_ID, LocalDate.of(2026, 7, 8), QUIZ_STEP_ID));

        verify(userTagRepository).upsert(USER_ID, 100L, NOW);
        ArgumentCaptor<UserTagStep> stepCaptor = ArgumentCaptor.forClass(UserTagStep.class);
        verify(userTagStepRepository).save(stepCaptor.capture());
        assertThat(stepCaptor.getValue().getQuizStepId()).isEqualTo(QUIZ_STEP_ID);
    }

    @Test
    @DisplayName("스텝에 연결된 태그가 여럿이면 각 태그마다 user_tag와 user_tag_step을 모두 남긴다")
    void records_user_tag_and_step_for_each_tag() {
        given(quizTagRepository.findDistinctTagIdsByQuizIdIn(STEP_QUIZ_IDS)).willReturn(List.of(100L, 200L));
        given(clock.instant()).willReturn(NOW);

        learnedTagRecorder.record(USER_ID, QUIZ_STEP_ID, STEP_QUIZ_IDS);

        verify(userTagRepository, times(1)).upsert(USER_ID, 100L, NOW);
        verify(userTagRepository, times(1)).upsert(USER_ID, 200L, NOW);

        ArgumentCaptor<UserTagStep> stepCaptor = ArgumentCaptor.forClass(UserTagStep.class);
        verify(userTagStepRepository, times(2)).save(stepCaptor.capture());
        assertThat(stepCaptor.getAllValues())
                .extracting(UserTagStep::getTagId, UserTagStep::getQuizStepId)
                .containsExactlyInAnyOrder(tuple(100L, QUIZ_STEP_ID), tuple(200L, QUIZ_STEP_ID));
    }

    @Test
    @DisplayName("이미 학습한 태그라도 upsert를 호출하고, user_tag_step은 매번 추가한다")
    void upserts_and_records_step_even_when_already_learned() {
        given(quizTagRepository.findDistinctTagIdsByQuizIdIn(STEP_QUIZ_IDS)).willReturn(List.of(100L));
        given(clock.instant()).willReturn(NOW);

        learnedTagRecorder.record(USER_ID, 4L, STEP_QUIZ_IDS);

        verify(userTagRepository).upsert(eq(USER_ID), eq(100L), any(Instant.class));
        verify(userTagStepRepository).save(any(UserTagStep.class));
    }

    @Test
    @DisplayName("정규화된 태그 링크가 없는 스텝은 아무 기록도 남기지 않는다")
    void skips_recording_when_no_tag_ids() {
        given(quizTagRepository.findDistinctTagIdsByQuizIdIn(STEP_QUIZ_IDS)).willReturn(List.of());

        learnedTagRecorder.record(USER_ID, QUIZ_STEP_ID, STEP_QUIZ_IDS);

        verify(userTagRepository, never()).upsert(any(), any(), any());
        verify(userTagStepRepository, never()).save(any());
    }
}

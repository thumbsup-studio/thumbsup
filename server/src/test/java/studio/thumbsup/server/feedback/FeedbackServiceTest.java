package studio.thumbsup.server.feedback;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.feedback.dto.FeedbackCreateRequest;
import studio.thumbsup.server.feedback.dto.FeedbackCreateResponse;

/** Service 단위 테스트 — Spring 없이 Mockito로 비즈니스 로직만 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
class FeedbackServiceTest {

    @Mock
    private FeedbackRepository feedbackRepository;

    @InjectMocks
    private FeedbackService feedbackService;

    @Test
    void 의견을_생성하면_저장된_id를_반환한다() {
        given(feedbackRepository.save(any(Feedback.class))).willReturn(FeedbackFixture.feedback(1L, 7L, "좋아요"));

        FeedbackCreateResponse response = feedbackService.create(7L, new FeedbackCreateRequest("좋아요"));

        assertThat(response.id()).isEqualTo(1L);
    }

    @Test
    void 토큰의_userId와_요청_내용으로_엔티티를_생성해_저장한다() {
        given(feedbackRepository.save(any(Feedback.class))).willReturn(FeedbackFixture.feedback(1L, 7L, "개선해주세요"));

        feedbackService.create(7L, new FeedbackCreateRequest("개선해주세요"));

        ArgumentCaptor<Feedback> captor = ArgumentCaptor.forClass(Feedback.class);
        verify(feedbackRepository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(7L);
        assertThat(captor.getValue().getContent()).isEqualTo("개선해주세요");
    }
}

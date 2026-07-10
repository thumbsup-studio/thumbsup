package studio.thumbsup.server.feedback;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
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

    @Nested
    @DisplayName("의견 생성")
    class CreateFeedback {

        @Test
        @DisplayName("저장된 id를 반환한다")
        void returns_saved_id() {
            given(feedbackRepository.save(any(Feedback.class))).willReturn(FeedbackFixture.feedback(1L, 7L, "좋아요"));

            FeedbackCreateResponse response = feedbackService.create(7L, new FeedbackCreateRequest("좋아요"));

            assertThat(response.id()).isEqualTo(1L);
        }

        @Test
        @DisplayName("토큰의 userId와 요청 내용으로 엔티티를 생성해 저장한다")
        void creates_entity_from_token_user_id_and_request_content() {
            given(feedbackRepository.save(any(Feedback.class))).willReturn(FeedbackFixture.feedback(1L, 7L, "개선해주세요"));

            feedbackService.create(7L, new FeedbackCreateRequest("개선해주세요"));

            ArgumentCaptor<Feedback> captor = ArgumentCaptor.forClass(Feedback.class);
            verify(feedbackRepository).save(captor.capture());
            assertThat(captor.getValue().getUserId()).isEqualTo(7L);
            assertThat(captor.getValue().getContent()).isEqualTo("개선해주세요");
        }
    }
}

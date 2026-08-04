package studio.thumbsup.server.feedback;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 쿼리·스키마·감사 필드를 함께 검증한다 (피라미드 3층).
 * 슬라이스에는 @Configuration이 없으므로 Auditing/Clock을 @Import로 가져온다.
 */
class FeedbackRepositoryTest extends RepositoryTestSupport {

    private final FeedbackRepository feedbackRepository;

    FeedbackRepositoryTest(@Autowired FeedbackRepository feedbackRepository) {
        this.feedbackRepository = feedbackRepository;
    }

    @Nested
    @DisplayName("의견 저장")
    class SaveFeedback {

        @Test
        @DisplayName("id가 채번된다")
        void assigns_id_on_save() {
            Feedback saved = feedbackRepository.save(Feedback.create(7L, "좋아요"));

            assertThat(saved.getId()).isNotNull();
        }
    }

    @Nested
    @DisplayName("감사 필드")
    class AuditFields {

        @Test
        @DisplayName("저장 시 자동으로 채워진다")
        void populated_on_save() {
            Feedback saved = feedbackRepository.save(Feedback.create(7L, "좋아요"));

            assertThat(saved.getCreatedAt()).isNotNull(); // Flyway NOT NULL 컬럼 + Auditing 동작 확인
            assertThat(saved.getUpdatedAt()).isNotNull();
        }
    }
}

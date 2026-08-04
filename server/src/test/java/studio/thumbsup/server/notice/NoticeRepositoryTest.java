package studio.thumbsup.server.notice;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 쿼리·스키마·감사 필드를 함께 검증한다 (피라미드 3층).
 * 슬라이스에는 @Configuration이 없으므로 Auditing/Clock을 @Import로 가져온다.
 */
@DisplayName("공지 리포지토리")
class NoticeRepositoryTest extends RepositoryTestSupport {

    private final NoticeRepository noticeRepository;

    NoticeRepositoryTest(@Autowired NoticeRepository noticeRepository) {
        this.noticeRepository = noticeRepository;
    }

    @Test
    @DisplayName("커서 페이지네이션은 id 내림차순으로 이어진다")
    void paginates_by_id_desc_with_cursor() {
        Notice first = noticeRepository.save(Notice.create("첫째", "내용"));
        Notice second = noticeRepository.save(Notice.create("둘째", "내용"));
        Notice third = noticeRepository.save(Notice.create("셋째", "내용"));

        List<Notice> firstPage = noticeRepository.findAllByOrderByIdDesc(PageRequest.of(0, 2));
        List<Notice> nextPage = noticeRepository.findByIdLessThanOrderByIdDesc(
                firstPage.get(firstPage.size() - 1).getId(), PageRequest.of(0, 2));

        assertThat(firstPage).extracting(Notice::getId).containsExactly(third.getId(), second.getId());
        assertThat(nextPage).extracting(Notice::getId).containsExactly(first.getId());
    }

    @Test
    @DisplayName("감사 필드는 저장 시 자동으로 채워진다")
    void fills_audit_fields_on_save() {
        Notice saved = noticeRepository.save(Notice.create("공지", "내용"));

        assertThat(saved.getCreatedAt()).isNotNull(); // Flyway NOT NULL 컬럼 + Auditing 동작 확인
        assertThat(saved.getUpdatedAt()).isNotNull();
    }
}

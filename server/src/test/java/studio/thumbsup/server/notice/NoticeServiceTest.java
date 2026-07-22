package studio.thumbsup.server.notice;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.common.response.CursorCodec;
import studio.thumbsup.server.common.response.CursorPage;
import studio.thumbsup.server.notice.dto.NoticeDetailResponse;
import studio.thumbsup.server.notice.dto.NoticeListResponse;

/** Service 단위 테스트 — Spring 없이 Mockito로 비즈니스 로직만 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("공지 서비스")
class NoticeServiceTest {

    @Mock
    private NoticeRepository noticeRepository;

    @InjectMocks
    private NoticeService noticeService;

    @Nested
    @DisplayName("목록 조회")
    class GetNotices {

        @Test
        @DisplayName("size보다 1개 더 조회해 hasNext를 판별한다")
        void fetches_one_extra_row_to_detect_has_next() {
            given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class)))
                    .willReturn(List.of(
                            NoticeFixture.notice(3L, "셋"),
                            NoticeFixture.notice(2L, "둘"),
                            NoticeFixture.notice(1L, "하나")));

            CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

            ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
            verify(noticeRepository).findAllByOrderByIdDesc(pageable.capture());
            assertThat(pageable.getValue().getPageSize()).isEqualTo(3); // size + 1
            assertThat(page.data().items()).hasSize(2);
            assertThat(page.meta().hasNext()).isTrue();
            assertThat(page.meta().nextCursor()).isEqualTo(CursorCodec.encodeId(2L)); // 마지막으로 내려준 항목의 id
        }

        @Test
        @DisplayName("정확히 size개면 hasNext는 false다")
        void has_next_is_false_when_exactly_size() {
            // 경계 케이스 — 이게 없으면 `>`를 `>=`로 바꿔도(off-by-one) 테스트가 통과한다
            given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class)))
                    .willReturn(List.of(NoticeFixture.notice(2L, "둘"), NoticeFixture.notice(1L, "하나")));

            CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

            assertThat(page.data().items()).hasSize(2);
            assertThat(page.meta().hasNext()).isFalse();
            assertThat(page.meta().nextCursor()).isNull();
        }

        @Test
        @DisplayName("빈 결과는 hasNext false, nextCursor null")
        void empty_result_has_no_next_and_null_cursor() {
            given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class))).willReturn(List.of());

            CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

            assertThat(page.data().items()).isEmpty();
            assertThat(page.meta().hasNext()).isFalse();
            assertThat(page.meta().nextCursor()).isNull();
        }

        @Test
        @DisplayName("마지막 페이지는 hasNext false, nextCursor null")
        void last_page_has_no_next() {
            given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class)))
                    .willReturn(List.of(NoticeFixture.notice(1L, "하나")));

            CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

            assertThat(page.data().items()).hasSize(1);
            assertThat(page.meta().hasNext()).isFalse();
            assertThat(page.meta().nextCursor()).isNull();
        }

        @Test
        @DisplayName("커서가 있으면 디코딩한 id 미만을 이어서 조회한다")
        void decodes_cursor_and_fetches_below_it() {
            given(noticeRepository.findByIdLessThanOrderByIdDesc(eq(10L), any(Pageable.class)))
                    .willReturn(List.of(NoticeFixture.notice(9L, "아홉")));

            noticeService.getNotices(CursorCodec.encodeId(10L), 2);

            verify(noticeRepository).findByIdLessThanOrderByIdDesc(eq(10L), any(Pageable.class));
        }

        @Test
        @DisplayName("디코딩 불가능한 커서는 INVALID_INPUT")
        void rejects_undecodable_cursor_with_invalid_input() {
            assertThatThrownBy(() -> noticeService.getNotices("!!not-base64!!", 2))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                            .isEqualTo(CommonErrorType.INVALID_INPUT));
        }
    }

    @Nested
    @DisplayName("상세 조회")
    class GetNotice {

        @Test
        @DisplayName("없는 공지 상세는 NOTICE_NOT_FOUND")
        void throws_notice_not_found_when_absent() {
            given(noticeRepository.findById(99L)).willReturn(Optional.empty());

            assertThatThrownBy(() -> noticeService.getNotice(99L))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                            .isEqualTo(NoticeErrorType.NOTICE_NOT_FOUND));
        }

        @Test
        @DisplayName("상세의 시간은 KST로 변환된다")
        void converts_created_at_to_kst() {
            given(noticeRepository.findById(1L)).willReturn(Optional.of(NoticeFixture.notice(1L, "공지")));

            NoticeDetailResponse response = noticeService.getNotice(1L);

            // 저장은 UTC(2026-07-07T00:00Z) → 직렬화는 KST(+09:00)
            assertThat(response.createdAt())
                    .isEqualTo(OffsetDateTime.of(2026, 7, 7, 9, 0, 0, 0, ZoneOffset.ofHours(9)));
        }
    }
}

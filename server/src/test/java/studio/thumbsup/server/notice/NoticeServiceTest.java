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
class NoticeServiceTest {

    @Mock
    private NoticeRepository noticeRepository;

    @InjectMocks
    private NoticeService noticeService;

    @Test
    void 목록은_size보다_1개_더_조회해_hasNext를_판별한다() {
        given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class)))
                .willReturn(List.of(
                        NoticeFixture.notice(3L, "셋"), NoticeFixture.notice(2L, "둘"), NoticeFixture.notice(1L, "하나")));

        CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(noticeRepository).findAllByOrderByIdDesc(pageable.capture());
        assertThat(pageable.getValue().getPageSize()).isEqualTo(3); // size + 1
        assertThat(page.data().items()).hasSize(2);
        assertThat(page.meta().hasNext()).isTrue();
        assertThat(page.meta().nextCursor()).isEqualTo(CursorCodec.encodeId(2L)); // 마지막으로 내려준 항목의 id
    }

    @Test
    void 정확히_size개면_hasNext_false다() {
        // 경계 케이스 — 이게 없으면 `>`를 `>=`로 바꿔도(off-by-one) 테스트가 통과한다
        given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class)))
                .willReturn(List.of(NoticeFixture.notice(2L, "둘"), NoticeFixture.notice(1L, "하나")));

        CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

        assertThat(page.data().items()).hasSize(2);
        assertThat(page.meta().hasNext()).isFalse();
        assertThat(page.meta().nextCursor()).isNull();
    }

    @Test
    void 빈_결과는_hasNext_false_nextCursor_null() {
        given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class))).willReturn(List.of());

        CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

        assertThat(page.data().items()).isEmpty();
        assertThat(page.meta().hasNext()).isFalse();
        assertThat(page.meta().nextCursor()).isNull();
    }

    @Test
    void 마지막_페이지는_hasNext_false_nextCursor_null() {
        given(noticeRepository.findAllByOrderByIdDesc(any(Pageable.class)))
                .willReturn(List.of(NoticeFixture.notice(1L, "하나")));

        CursorPage<NoticeListResponse> page = noticeService.getNotices(null, 2);

        assertThat(page.data().items()).hasSize(1);
        assertThat(page.meta().hasNext()).isFalse();
        assertThat(page.meta().nextCursor()).isNull();
    }

    @Test
    void 커서가_있으면_디코딩한_id_미만을_이어서_조회한다() {
        given(noticeRepository.findByIdLessThanOrderByIdDesc(eq(10L), any(Pageable.class)))
                .willReturn(List.of(NoticeFixture.notice(9L, "아홉")));

        noticeService.getNotices(CursorCodec.encodeId(10L), 2);

        verify(noticeRepository).findByIdLessThanOrderByIdDesc(eq(10L), any(Pageable.class));
    }

    @Test
    void 디코딩_불가능한_커서는_INVALID_INPUT() {
        assertThatThrownBy(() -> noticeService.getNotices("!!not-base64!!", 2))
                .isInstanceOf(BusinessException.class)
                .satisfies(e ->
                        assertThat(((BusinessException) e).getErrorType()).isEqualTo(CommonErrorType.INVALID_INPUT));
    }

    @Test
    void 없는_공지_상세는_NOTICE_NOT_FOUND() {
        given(noticeRepository.findById(99L)).willReturn(Optional.empty());

        assertThatThrownBy(() -> noticeService.getNotice(99L))
                .isInstanceOf(BusinessException.class)
                .satisfies(e ->
                        assertThat(((BusinessException) e).getErrorType()).isEqualTo(NoticeErrorType.NOTICE_NOT_FOUND));
    }

    @Test
    void 상세의_시간은_KST로_변환된다() {
        given(noticeRepository.findById(1L)).willReturn(Optional.of(NoticeFixture.notice(1L, "공지")));

        NoticeDetailResponse response = noticeService.getNotice(1L);

        // 저장은 UTC(2026-07-07T00:00Z) → 직렬화는 KST(+09:00)
        assertThat(response.createdAt()).isEqualTo(OffsetDateTime.of(2026, 7, 7, 9, 0, 0, 0, ZoneOffset.ofHours(9)));
    }
}

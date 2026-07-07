package studio.thumbsup.server.notice;

import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.response.CursorCodec;
import studio.thumbsup.server.common.response.CursorMeta;
import studio.thumbsup.server.common.response.CursorPage;
import studio.thumbsup.server.notice.dto.NoticeDetailResponse;
import studio.thumbsup.server.notice.dto.NoticeListResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * <b>쓰기 메서드(create/update/delete)를 추가하면 반드시 그 메서드에
 * {@code @Transactional}(readOnly=false)를 붙여 오버라이드한다</b> — 빠뜨리면 readOnly가 상속돼
 * INSERT/UPDATE가 예외 없이 무음으로 유실된다.
 */
@Service
@Transactional(readOnly = true)
public class NoticeService {

    private final NoticeRepository noticeRepository;

    public NoticeService(NoticeRepository noticeRepository) {
        this.noticeRepository = noticeRepository;
    }

    public CursorPage<NoticeListResponse> getNotices(String cursor, int size) {
        List<Notice> fetched = fetchPage(cursor, size + 1); // hasNext 판별용으로 1개 더 조회
        boolean hasNext = fetched.size() > size;
        List<Notice> pageItems = hasNext ? fetched.subList(0, size) : fetched;
        String nextCursor = pageItems.isEmpty()
                ? null
                : CursorCodec.encodeId(pageItems.get(pageItems.size() - 1).getId());
        return new CursorPage<>(NoticeListResponse.from(pageItems), CursorMeta.of(hasNext, nextCursor));
    }

    public NoticeDetailResponse getNotice(Long noticeId) {
        Notice notice = noticeRepository
                .findById(noticeId)
                .orElseThrow(() -> new BusinessException(NoticeErrorType.NOTICE_NOT_FOUND));
        return NoticeDetailResponse.from(notice);
    }

    private List<Notice> fetchPage(String cursor, int fetchSize) {
        Pageable pageable = PageRequest.of(0, fetchSize);
        if (cursor == null) {
            return noticeRepository.findAllByOrderByIdDesc(pageable);
        }
        return noticeRepository.findByIdLessThanOrderByIdDesc(CursorCodec.decodeId(cursor), pageable);
    }
}

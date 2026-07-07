package studio.thumbsup.server.notice;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NoticeRepository extends JpaRepository<Notice, Long> {

    /** 첫 페이지 — id 내림차순 (커서 페이지네이션의 정렬 기준) */
    List<Notice> findAllByOrderByIdDesc(Pageable pageable);

    /** 다음 페이지 — 커서(마지막으로 본 id) 미만을 이어서 조회 */
    List<Notice> findByIdLessThanOrderByIdDesc(Long id, Pageable pageable);
}

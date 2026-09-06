package studio.thumbsup.server.quiz.tag;

import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserTagRepository extends JpaRepository<UserTag, Long> {

    /** 지식 그래프 조회 — 유저가 학습한 모든 태그(learnedAt 포함). */
    List<UserTag> findByUserId(Long userId);

    /**
     * 유저·태그당 최초 1행만 남기는 멱등 upsert(#324) — 이미 있으면 아무것도 바꾸지 않는다
     * (id = id는 실제 갱신 없이 "성공"으로 처리해 unique 제약 위반 예외를 피하기 위한 관용구다).
     * JPA Auditing을 우회하므로 호출부가 주입받은 {@code Clock}으로 계산한 시각을 직접 넘긴다.
     */
    @Modifying
    @Query(
            value = "INSERT INTO user_tag (user_id, tag_id, created_at, updated_at) "
                    + "VALUES (:userId, :tagId, :now, :now) ON DUPLICATE KEY UPDATE id = id",
            nativeQuery = true)
    void upsert(@Param("userId") Long userId, @Param("tagId") Long tagId, @Param("now") Instant now);
}

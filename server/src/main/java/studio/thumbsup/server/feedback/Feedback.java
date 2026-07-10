package studio.thumbsup.server.feedback;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 의견 보내기 엔티티.
 *
 * <p>규칙: 생성은 정적 팩토리 {@link #create}로만. 작성자는 연관관계가 아닌 {@code userId} 값으로만 보관한다
 * (도메인 경계를 넘는 JPA 연관관계 금지 — server/docs/dto-and-query-patterns.md §2).
 */
@Getter
@Entity
@Table(name = "feedbacks") // 마이그레이션의 테이블명과 명시적으로 일치 (validate 안전)
@NoArgsConstructor(access = AccessLevel.PROTECTED) // JPA 스펙용 — 코드에서 직접 호출 금지
public class Feedback extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 1000)
    private String content;

    private Feedback(Long userId, String content) {
        this.userId = userId;
        this.content = content;
    }

    public static Feedback create(Long userId, String content) {
        return new Feedback(userId, content);
    }
}

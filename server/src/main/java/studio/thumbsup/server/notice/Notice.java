package studio.thumbsup.server.notice;

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
 * 공지사항 엔티티 — 레퍼런스 feature.
 *
 * <p>규칙: 생성은 정적 팩토리 {@link #create}로만. 다른 도메인 엔티티를 연관관계로 참조하지 않는다
 * (필요하면 {@code Long xxxId} 값으로 — server/docs/dto-and-query-patterns.md §2).
 */
@Getter
@Entity
@Table(name = "notice") // 마이그레이션의 테이블명과 명시적으로 일치 (validate 안전)
@NoArgsConstructor(access = AccessLevel.PROTECTED) // JPA 스펙용 — 코드에서 직접 호출 금지
public class Notice extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    private Notice(String title, String content) {
        this.title = title;
        this.content = content;
    }

    public static Notice create(String title, String content) {
        return new Notice(title, content);
    }
}

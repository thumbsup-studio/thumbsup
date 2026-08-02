package studio.thumbsup.server.quiz.authoring;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/** 발행 전 코스 뼈대를 보관하는 저작 스테이징 엔티티. */
@Getter
@Entity
@Table(name = "authoring_outline")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AuthoringOutline extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 50)
    private String category;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private AuthoringOutlineStatus status;

    @Column(name = "toc_source", columnDefinition = "MEDIUMTEXT")
    private String tocSource;

    private Long publishedCourseId;

    @Column(nullable = false)
    private Long createdBy;

    private AuthoringOutline(String title, String category, String tocSource, Long createdBy) {
        this.title = title;
        this.category = category;
        this.status = AuthoringOutlineStatus.DRAFT;
        this.tocSource = tocSource;
        this.createdBy = createdBy;
    }

    public static AuthoringOutline create(String title, String category, String tocSource, Long createdBy) {
        return new AuthoringOutline(title, category, tocSource, createdBy);
    }

    public void markPublished(Long courseId) {
        this.status = AuthoringOutlineStatus.PUBLISHED;
        this.publishedCourseId = courseId;
    }

    public boolean isPublished() {
        return status == AuthoringOutlineStatus.PUBLISHED;
    }
}

package studio.thumbsup.server.quiz.course;

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
 * 학습 코스 엔티티 — 유저의 명시적 구독 없이 진행 기록({@code QuizProgress}) 존재 여부로 "학습 중"을
 * 판정한다(#240). 홈은 진행 기록이 없는 신규 유저에게만 가장 먼저 생성된 코스(id 최솟값)를 기본
 * 코스로 보여준다.
 */
@Getter
@Entity
@Table(name = "course")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Course extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 50)
    private String category;

    private Course(String title, String category) {
        this.title = title;
        this.category = category;
    }

    public static Course create(String title, String category) {
        return new Course(title, category);
    }
}

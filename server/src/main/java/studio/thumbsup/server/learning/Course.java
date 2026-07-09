package studio.thumbsup.server.learning;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 학습 코스 엔티티 — 화({@link Unit})의 aggregate root. MVP는 코스 1개("CS 기초")뿐이라 유저의 관심 코스
 * 선택 같은 기능은 없다 — 홈은 항상 가장 먼저 생성된 코스(id 최솟값)를 "기본 코스"로 취급한다.
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

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("orderIndex ASC")
    private List<Unit> units = new ArrayList<>();

    private Course(String title, String category) {
        this.title = title;
        this.category = category;
    }

    public static Course create(String title, String category) {
        return new Course(title, category);
    }

    public void addUnit(int orderIndex, String title, int estimatedMinutes) {
        units.add(Unit.create(this, orderIndex, title, estimatedMinutes));
    }
}

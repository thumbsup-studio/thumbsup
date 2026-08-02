package studio.thumbsup.server.quiz.concept;

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
 * 유저가 실제로 학습(완료)한 개념(#233) — 지식 그래프 조회의 유일한 데이터 소스다.
 * {@link #getCreatedAt()}이 곧 이슈가 요구하는 "개념을 최초 학습/완료한 날짜"(learnedAt)다.
 *
 * <p>{@code QuizService}가 유저의 스텝을 처음 완료시키는 순간에만 기록한다(이슈 원문 "스텝을 완료한
 * 날짜" 그대로) — 문제 하나를 풀 때마다가 아니라 스텝(5문제) 전체를 완료했을 때다. 같은 개념이 여러
 * 스텝에 걸쳐 나올 수 있어 유저·개념 조합당 한 번만 기록되도록 유니크 제약을 둔다.
 *
 * <p>{@code userId}는 다른 도메인(auth) 참조라 ID 값으로만 둔다(server/docs/dto-and-query-patterns.md #2).
 */
@Getter
@Entity
@Table(name = "user_concept")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserConcept extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long conceptId;

    private UserConcept(Long userId, Long conceptId) {
        this.userId = userId;
        this.conceptId = conceptId;
    }

    public static UserConcept create(Long userId, Long conceptId) {
        return new UserConcept(userId, conceptId);
    }
}

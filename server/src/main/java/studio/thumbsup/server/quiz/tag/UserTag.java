package studio.thumbsup.server.quiz.tag;

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
 * 유저가 실제로 학습(완료)한 태그(#233, #324) — 지식 그래프 조회의 유일한 데이터 소스다.
 * {@link #getCreatedAt()}이 곧 이슈가 요구하는 "태그를 최초 학습/완료한 날짜"(learnedAt)다.
 *
 * <p>{@code QuizService}가 유저의 스텝을 처음 완료시키는 순간에만 기록한다(이슈 원문 "스텝을 완료한
 * 날짜" 그대로) — 문제 하나를 풀 때마다가 아니라 스텝(5문제) 전체를 완료했을 때다. 같은 태그가 여러
 * 스텝에 걸쳐, 그리고 여러 코스에 걸쳐 나올 수 있어(#324) 유저·태그 조합당 한 번만 기록되도록 유니크
 * 제약을 둔다. 이 유니크 제약 위반을 안전하게 흡수하는 방법은 {@link UserTagRepository#upsert}와
 * {@code LearnedTagRecorder}의 Javadoc을 참고한다.
 *
 * <p>{@code userId}는 다른 도메인(auth) 참조라 ID 값으로만 둔다(server/docs/dto-and-query-patterns.md #2).
 */
@Getter
@Entity
@Table(name = "user_tag")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserTag extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long tagId;

    private UserTag(Long userId, Long tagId) {
        this.userId = userId;
        this.tagId = tagId;
    }

    public static UserTag create(Long userId, Long tagId) {
        return new UserTag(userId, tagId);
    }
}

package studio.thumbsup.server.quiz.tag;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 퀴즈-태그 링크(#233, #324) — 퀴즈당 저작된 파생태그(최대 3개) 중 문제 지문·해설을 직접 읽고 판단한
 * 태그를 정규화된 {@link Tag}에 연결한다. 퀴즈당 최대 3개까지 연결할 수 있다(#324로 1개→최대 3개
 * 카디널리티 확장). {@code quiz}(퀴즈 도메인)와 {@code quiz.tag}(정규화 도메인) 사이의 다대다 링크를
 * 별도 테이블로 분리해, 퀴즈 저작·제출 등 기존 퀴즈 도메인 코드는 이 정규화 관심사를 전혀 몰라도 되게
 * 한다. {@code quizId}는 같은 quiz 슬라이스 안이지만 {@code Quiz}를 이 정규화 전용 링크에 끌어들이지
 * 않기 위해 ID 값으로만 참조한다.
 *
 * <p>"퀴즈당 최대 3개"는 DB 제약이 아니라 저작 파이프라인(앱 레벨)이 강제하는 규칙이다 — 저작 시점
 * 자동 채움(AI가 퀴즈 생성과 동시에 태그를 연결)이 생기면 동시 쓰기로 인한 TOCTOU(상한 위반 가능성)를
 * 재검토해야 한다.
 *
 * <p>지금은 기존 콘텐츠를 1회 백필한 정적 데이터다 — 신규 퀴즈 생성 시 자동으로 채우는 것은 범위 밖(후속 이슈).
 */
@Getter
@Entity
@Table(
        name = "quiz_tag",
        uniqueConstraints =
                @UniqueConstraint(
                        name = "uk_quiz_tag_pair",
                        columnNames = {"quiz_id", "tag_id"}))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizTag extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long quizId;

    @Column(nullable = false)
    private Long tagId;
}

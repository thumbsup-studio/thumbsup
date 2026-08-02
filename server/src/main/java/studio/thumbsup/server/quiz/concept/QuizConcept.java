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
 * 퀴즈의 핵심 개념 링크(#233) — 퀴즈당 저작된 파생개념(최대 3개) 중 문제 지문·해설을 직접 읽고 판단한
 * "핵심 개념" 1개만 정규화된 {@link Concept}에 연결한다. {@code quiz}(퀴즈 도메인)와 {@code
 * quiz.concept}(정규화 도메인) 사이의 다대일 링크를 별도 테이블로 분리해, 퀴즈 저작·제출 등 기존
 * 퀴즈 도메인 코드는 이 정규화 관심사를 전혀 몰라도 되게 한다. {@code quizId}는 같은 quiz 슬라이스
 * 안이지만 {@code Quiz}를 이 정규화 전용 링크에 끌어들이지 않기 위해 ID 값으로만 참조한다.
 *
 * <p>지금은 기존 콘텐츠를 1회 백필한 정적 데이터다 — 신규 퀴즈 생성 시 자동으로 채우는 것은 범위 밖(후속 이슈).
 */
@Getter
@Entity
@Table(name = "quiz_concept")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizConcept extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private Long quizId;

    @Column(nullable = false)
    private Long conceptId;
}

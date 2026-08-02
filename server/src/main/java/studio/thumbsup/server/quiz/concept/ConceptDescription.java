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
 * {@link Concept}의 설명 문장(#233) — 개념 하나에 문자열 하나가 아니라 {@code step_order} 단위로 쪼갠다.
 * 같은 개념이라도 그 개념을 다루는 퀴즈가 서로 다른 스텝에 걸쳐 있으면 스텝마다 다른 뉘앙스를 설명할 수
 * 있기 때문이다. 조회 시 유저가 실제로 완료한 step_order의 문장만 골라 노출해, 아직 학습하지 않은
 * 스텝의 내용이 먼저 노출되는 것을 막는다.
 */
@Getter
@Entity
@Table(name = "concept_description")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ConceptDescription extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long conceptId;

    @Column(nullable = false, length = 500)
    private String content;

    @Column(nullable = false)
    private int stepOrder;
}

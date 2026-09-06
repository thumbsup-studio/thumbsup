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
 * {@link Tag}의 설명 문장(#233, #324) — 태그 하나에 문자열 하나가 아니라 스텝(quiz_step) 단위로 쪼갠다.
 * 같은 태그라도 그 태그를 다루는 퀴즈가 서로 다른 스텝에 걸쳐 있으면 스텝마다 다른 뉘앙스를 설명할 수
 * 있기 때문이다. 조회 시 유저가 실제로 완료한 스텝의 문장만 골라 노출해, 아직 학습하지 않은
 * 스텝의 내용이 먼저 노출되는 것을 막는다.
 *
 * <p>Java 코드로 생성되지 않고 시드 마이그레이션이 직접 INSERT한다 — 이 클래스는 조회 전용이다.
 */
@Getter
@Entity
@Table(name = "tag_description")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TagDescription extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long tagId;

    @Column(nullable = false, length = 500)
    private String content;

    /** 이 설명이 속한 스텝의 PK(#292) — step_order는 코스마다 겹칠 수 있어 식별에 쓰지 않는다. */
    @Column(nullable = false)
    private Long quizStepId;
}

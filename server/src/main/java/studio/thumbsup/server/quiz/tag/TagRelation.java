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
 * 태그 간 관계(#233, #324) — 지식 그래프의 엣지. co-occurrence(같은 문제에 태깅됐는지) 통계가 아니라
 * CS 도메인 의미를 기준으로 직접 큐레이션한 정적 데이터라, 코스·스텝 경계를 넘어 연결될 수 있다.
 * 방향은 없는 관계로 취급한다 — source/target 순서는 저장 편의상 구분일 뿐 의미를 갖지 않는다.
 *
 * <p>population 방식을 사람의 수동 큐레이션에서 LLM 판단으로 전환하는 것은 이 스펙(#324)의 범위 밖이다
 * — 재태깅과 같은 후속 이슈에서 다룬다. 이번엔 테이블 구조(rename)만 그대로 이관한다.
 */
@Getter
@Entity
@Table(name = "tag_relation")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TagRelation extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "source_tag_id", nullable = false)
    private Long sourceTagId;

    @Column(name = "target_tag_id", nullable = false)
    private Long targetTagId;
}

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
 * 정규화된 개념 마스터(#233) — {@code quiz.QuizDerivedConcept}의 자유 텍스트 이름을 표기 차이 없이
 * 하나로 모은 것이다. {@code quiz}(파생개념 연결)와 {@code history}(그래프 조회) 양쪽에서 참조되므로
 * ArchUnit 피처 슬라이스 규칙상 별도 최상위 feature가 아니라 quiz 슬라이스 하위에 둔다.
 *
 * <p>설명 문장은 이 엔티티가 아니라 {@link ConceptDescription}이 스텝 단위로 들고 있다 — 같은 개념이
 * 여러 스텝에 걸쳐 다른 뉘앙스로 등장할 수 있어, 유저가 아직 완료하지 않은 스텝의 설명이 미리 노출되는
 * 것을 막기 위함이다.
 *
 * <p>지금은 기존 콘텐츠를 1회 백필한 정적 데이터다 — 신규 퀴즈 생성 시 자동으로 채우는 것은 범위 밖(후속 이슈).
 */
@Getter
@Entity
@Table(name = "concept")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Concept extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 200)
    private String name;

    @Column(nullable = false, length = 50)
    private String category;
}

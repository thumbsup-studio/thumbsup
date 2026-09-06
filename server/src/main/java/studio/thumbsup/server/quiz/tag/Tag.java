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
 * 정규화된 태그 마스터(#233, #324) — {@code quiz.QuizDerivedTag}의 자유 텍스트 이름을 표기 차이 없이
 * 하나로 모은 것이다. {@code quiz}(파생태그 연결)와 {@code history}(그래프 조회) 양쪽에서 참조되므로
 * ArchUnit 피처 슬라이스 규칙상 별도 최상위 feature가 아니라 quiz 슬라이스 하위에 둔다.
 *
 * <p>같은 태그가 여러 코스에서 재사용될 수 있어(#324), 정확 일치 unique 제약(DB collation 덕에 이미
 * 대소문자 무시)에 더해 앞뒤 공백까지 무시하는 {@code normalized_name} 생성 컬럼에 별도 unique 제약을
 * 둔다 — 내부 공백 차이나 동의어까지는 잡지 않는다(그 이상은 저작 프로세스의 몫).
 *
 * <p>설명 문장은 이 엔티티가 아니라 {@link TagDescription}이 스텝 단위로 들고 있다 — 같은 태그가
 * 여러 스텝에 걸쳐 다른 뉘앙스로 등장할 수 있어, 유저가 아직 완료하지 않은 스텝의 설명이 미리 노출되는
 * 것을 막기 위함이다.
 *
 * <p>지금은 기존 콘텐츠를 1회 백필한 정적 데이터다 — 신규 퀴즈 생성 시 자동으로 채우는 것은 범위 밖(후속 이슈).
 */
@Getter
@Entity
@Table(name = "tag")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Tag extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 200)
    private String name;

    @Column(nullable = false, length = 50)
    private String category;
}

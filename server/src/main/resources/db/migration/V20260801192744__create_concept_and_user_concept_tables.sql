-- #233 지식 그래프: Concept 마스터·관계, 유저별 학습 개념 기록 테이블 생성.
-- Concept/ConceptRelation은 quiz(파생개념)와 history(그래프 조회) 양쪽에서 참조되므로
-- ArchUnit 피처 슬라이스 규칙상 quiz 슬라이스 하위(quiz.concept 패키지)에 둔다.

CREATE TABLE concept (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    name        VARCHAR(200) NOT NULL,
    category    VARCHAR(50)  NOT NULL,
    created_at  DATETIME(6)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_concept_name UNIQUE (name)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- 한 개념이 여러 스텝에 걸쳐 다른 뉘앙스로 등장할 수 있어(예: "문맥 전환") 설명을 개념에 1:1로
-- 두지 않고 스텝 단위로 쪼갠다. 조회 시 유저가 실제로 완료한 step_order의 문장만 골라 응답한다
-- (아직 안 배운 스텝의 설명이 미리 노출되는 것을 막기 위함 — #233).
CREATE TABLE concept_description (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    concept_id BIGINT       NOT NULL,
    content    VARCHAR(500) NOT NULL,
    step_order INT          NOT NULL,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_concept_description_concept_step UNIQUE (concept_id, step_order),
    CONSTRAINT fk_concept_description_concept FOREIGN KEY (concept_id) REFERENCES concept (id) ON DELETE CASCADE,
    -- quiz.step_order → quiz_step FK 선례(V20260709201632)와 동일 — 시드 오타·스텝 재번호 시
    -- 설명 문장이 API에서 조용히 사라지는 대신 마이그레이션이 즉시 실패하게 한다.
    CONSTRAINT fk_concept_description_step FOREIGN KEY (step_order) REFERENCES quiz_step (step_order)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE concept_relation (
    id                BIGINT      NOT NULL AUTO_INCREMENT,
    source_concept_id BIGINT      NOT NULL,
    target_concept_id BIGINT      NOT NULL,
    created_at        DATETIME(6) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_concept_relation_pair UNIQUE (source_concept_id, target_concept_id),
    CONSTRAINT fk_concept_relation_source FOREIGN KEY (source_concept_id) REFERENCES concept (id) ON DELETE CASCADE,
    CONSTRAINT fk_concept_relation_target FOREIGN KEY (target_concept_id) REFERENCES concept (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- 유저가 실제로 학습(완료)한 개념 — user_id는 다른 도메인(auth) 참조라 FK 없이 ID 값으로만 둔다
-- (server/docs/dto-and-query-patterns.md #2). created_at이 곧 그 개념을 최초 학습한 시각(learnedAt)이다.
CREATE TABLE user_concept (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    user_id    BIGINT      NOT NULL,
    concept_id BIGINT      NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_concept UNIQUE (user_id, concept_id),
    CONSTRAINT fk_user_concept_concept FOREIGN KEY (concept_id) REFERENCES concept (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- 유저가 그 개념을 학습하는 데 관련된(완료한) 스텝 — 지식 그래프 상세 카드의 relatedSteps 조립용.
CREATE TABLE user_concept_step (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    user_id    BIGINT      NOT NULL,
    concept_id BIGINT      NOT NULL,
    step_order INT         NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_concept_step UNIQUE (user_id, concept_id, step_order),
    CONSTRAINT fk_user_concept_step_concept FOREIGN KEY (concept_id) REFERENCES concept (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_concept_step_step FOREIGN KEY (step_order) REFERENCES quiz_step (step_order)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- 퀴즈당 핵심 개념 1개만 정규화된 concept로 연결한다 — quiz_derived_concept(저작 원본, 퀴즈당 최대 3개
-- 자유 텍스트)를 건드리지 않고 별도 링크 테이블로 분리해, 퀴즈 도메인 코드가 이 정규화 관심사를
-- 몰라도 되게 한다. UNIQUE(quiz_id)로 "퀴즈당 핵심 개념 1개" 불변식을 DB 레벨에서도 강제한다.
CREATE TABLE quiz_concept (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    quiz_id    BIGINT      NOT NULL,
    concept_id BIGINT      NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quiz_concept_quiz UNIQUE (quiz_id),
    CONSTRAINT fk_quiz_concept_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE,
    CONSTRAINT fk_quiz_concept_concept FOREIGN KEY (concept_id) REFERENCES concept (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

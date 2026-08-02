-- 저작 2단계 플로우(#258) — 발행 전 코스 뼈대와 스텝 채움 참조
-- 이미 적용된 Flyway 마이그레이션은 수정하지 않고 새 변경만 추가한다.
CREATE TABLE authoring_outline (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    title               VARCHAR(200) NOT NULL,
    category            VARCHAR(50)  NOT NULL,
    status              VARCHAR(10)  NOT NULL,
    toc_source          MEDIUMTEXT   NULL,
    published_course_id BIGINT       NULL,
    created_by          BIGINT       NOT NULL,
    created_at          DATETIME(6)  NOT NULL,
    updated_at          DATETIME(6)  NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE authoring_outline_step (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    outline_id    BIGINT       NOT NULL,
    order_no      INT          NOT NULL,
    topic         VARCHAR(200) NOT NULL,
    learning_goal VARCHAR(500) NULL,
    draft_id      BIGINT       NULL,
    created_at    DATETIME(6)  NOT NULL,
    updated_at    DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_outline_step_order UNIQUE (outline_id, order_no),
    CONSTRAINT fk_outline_step_outline FOREIGN KEY (outline_id) REFERENCES authoring_outline (id),
    INDEX idx_outline_step_draft (draft_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

ALTER TABLE generation_job
    ADD COLUMN outline_id      BIGINT      NULL,
    ADD COLUMN outline_step_id BIGINT      NULL,
    ADD COLUMN preset          VARCHAR(10) NULL;

ALTER TABLE quiz_draft
    MODIFY COLUMN origin VARCHAR(20) NOT NULL,
    ADD COLUMN preset VARCHAR(10) NULL;

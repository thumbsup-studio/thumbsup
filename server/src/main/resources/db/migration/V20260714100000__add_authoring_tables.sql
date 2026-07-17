-- 문제 저작 파이프라인(#174) — 잡 큐 + draft 스테이징
-- 규칙: 버전 = 타임스탬프(yyyyMMddHHmmss), PR당 마이그레이션 1개, 적용된 파일 수정 금지(수정은 새 파일로)
CREATE TABLE quiz_draft (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    origin          VARCHAR(10)  NOT NULL,
    status          VARCHAR(10)  NOT NULL,
    topic           VARCHAR(255) NOT NULL,
    source_quiz_id  BIGINT       NULL,
    current_payload MEDIUMTEXT   NOT NULL,
    created_by      BIGINT       NOT NULL,
    approved_by     BIGINT       NULL,
    approved_at     DATETIME(6)  NULL,
    created_at      DATETIME(6)  NOT NULL,
    updated_at      DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    KEY idx_quiz_draft_status (status),
    KEY idx_quiz_draft_source (source_quiz_id, status),
    CONSTRAINT fk_quiz_draft_source_quiz FOREIGN KEY (source_quiz_id) REFERENCES quiz (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE generation_job (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    kind             VARCHAR(10)  NOT NULL,
    status           VARCHAR(10)  NOT NULL,
    assignee_user_id BIGINT       NOT NULL,
    cli              VARCHAR(10)  NULL,
    draft_id         BIGINT       NULL,
    topic            VARCHAR(255) NULL,
    feedback         TEXT         NULL,
    prompt           MEDIUMTEXT   NOT NULL,
    error            TEXT         NULL,
    started_at       DATETIME(6)  NULL,
    finished_at      DATETIME(6)  NULL,
    created_at       DATETIME(6)  NOT NULL,
    updated_at       DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    KEY idx_generation_job_pick (status, assignee_user_id, id),
    KEY idx_generation_job_draft (draft_id, status),
    CONSTRAINT fk_generation_job_draft FOREIGN KEY (draft_id) REFERENCES quiz_draft (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_draft_revision (
    id             BIGINT      NOT NULL AUTO_INCREMENT,
    draft_id       BIGINT      NOT NULL,
    revision_no    INT         NOT NULL,
    payload        MEDIUMTEXT  NOT NULL,
    review_summary TEXT        NULL,
    reviewed_by    BIGINT      NULL,
    job_id         BIGINT      NOT NULL,
    created_at     DATETIME(6) NOT NULL,
    updated_at     DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_quiz_draft_revision (draft_id, revision_no),
    CONSTRAINT fk_revision_draft FOREIGN KEY (draft_id) REFERENCES quiz_draft (id),
    CONSTRAINT fk_revision_job FOREIGN KEY (job_id) REFERENCES generation_job (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE job_log (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    job_id     BIGINT      NOT NULL,
    seq        INT         NOT NULL,
    line       TEXT        NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_job_log_seq (job_id, seq),
    CONSTRAINT fk_job_log_job FOREIGN KEY (job_id) REFERENCES generation_job (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

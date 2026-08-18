-- #297 문제 풀이 전 스텝 단위 개념 브리핑.
-- quiz_step의 PK를 참조해 표시 순서(step_order) 변경과 독립적으로 연결한다.
CREATE TABLE quiz_step_briefing (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    quiz_step_id BIGINT       NOT NULL,
    summary      VARCHAR(500) NOT NULL,
    created_at   DATETIME(6)  NOT NULL,
    updated_at   DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quiz_step_briefing_step UNIQUE (quiz_step_id),
    CONSTRAINT fk_quiz_step_briefing_step
        FOREIGN KEY (quiz_step_id) REFERENCES quiz_step (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_step_briefing_block (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    briefing_id   BIGINT       NOT NULL,
    type          VARCHAR(20)  NOT NULL,
    heading       VARCHAR(100) NOT NULL,
    content       TEXT         NOT NULL,
    display_order INT          NOT NULL,
    created_at    DATETIME(6)  NOT NULL,
    updated_at    DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quiz_step_briefing_block_order UNIQUE (briefing_id, display_order),
    CONSTRAINT fk_quiz_step_briefing_block_briefing
        FOREIGN KEY (briefing_id) REFERENCES quiz_step_briefing (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

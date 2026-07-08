-- 유저별 퀴즈 풀이 이력 — user는 다른 도메인이라 user_id는 FK 없이 ID 값으로만 참조한다
-- (server/docs/dto-and-query-patterns.md #2, 도메인 경계를 넘는 JPA 연관관계 금지).
CREATE TABLE quiz_attempt (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    quiz_id    BIGINT      NOT NULL,
    user_id    BIGINT      NOT NULL,
    is_correct BIT(1)      NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_attempt_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE,
    CONSTRAINT uk_quiz_attempt_user_quiz UNIQUE (user_id, quiz_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- 유저별 커리큘럼 진행 상태 — 스텝(5문제 세트) 단위로 진행도를 추적한다.
CREATE TABLE quiz_progress (
    id                BIGINT      NOT NULL AUTO_INCREMENT,
    user_id           BIGINT      NOT NULL,
    current_step_order INT        NOT NULL DEFAULT 1,
    created_at        DATETIME(6) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quiz_progress_user UNIQUE (user_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

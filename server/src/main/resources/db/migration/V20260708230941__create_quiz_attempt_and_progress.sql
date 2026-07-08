-- 유저별 퀴즈 풀이 이력 — 복습을 위해 같은 유저·퀴즈 조합도 여러 번 기록될 수 있다(재시도 허용).
-- "다음 문제" 판정은 이 이력 중 is_correct=true인 행이 하나라도 있는지로 서비스 레이어에서 계산한다.
-- quiz_id는 ON DELETE RESTRICT — 풀이 이력이 남은 퀴즈는 삭제할 수 없다.
-- CASCADE로 두면 콘텐츠 수정을 위해 퀴즈를 삭제·재생성할 때 유저의 풀이 이력이 함께 사라져
-- 위 재시도 이력 보존 취지가 깨진다.
-- user는 다른 도메인이라 user_id는 FK 없이 ID 값으로만 참조한다
-- (server/docs/dto-and-query-patterns.md #2, 도메인 경계를 넘는 JPA 연관관계 금지).
CREATE TABLE quiz_attempt (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    quiz_id    BIGINT      NOT NULL,
    user_id    BIGINT      NOT NULL,
    is_correct BIT(1)      NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_attempt_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE RESTRICT,
    INDEX idx_quiz_attempt_user_quiz (user_id, quiz_id)
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

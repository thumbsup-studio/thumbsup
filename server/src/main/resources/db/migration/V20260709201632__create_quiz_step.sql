-- 스텝(문제 5개 세트) 단위 주제 메타데이터 — #26 생성 파이프라인이 스텝을 만들 때 함께 저장한다.
-- 홈 화면 등에서 "이번 스텝: CPU 스케줄링 기초" 같은 표시에 쓰인다.
CREATE TABLE quiz_step (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    step_order INT          NOT NULL,
    topic      VARCHAR(200) NOT NULL,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quiz_step_order UNIQUE (step_order)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- quiz.step_order=0은 스텝 밖 placeholder 샘플(V20260708171651)을 가리키는 sentinel이다.
-- 아래 FK를 만족시키기 위해 "미배정" 상태를 나타내는 행을 등록해둔다.
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (0, '(미배정)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- quiz.step_order 값이 실제로 존재하는 스텝을 가리키도록 FK로 강제한다(느슨한 정수 매칭 방지).
ALTER TABLE quiz
    ADD CONSTRAINT fk_quiz_step_order FOREIGN KEY (step_order) REFERENCES quiz_step (step_order);

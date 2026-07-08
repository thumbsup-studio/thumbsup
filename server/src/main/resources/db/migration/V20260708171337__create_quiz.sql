-- 퀴즈 문제 세트 (루트 + 자식 5종)
-- 유형별로 정답 구조가 달라 가변 데이터는 자식 테이블로 분리한다:
--   OX          -> quiz.correct_answer 만 사용
--   MULTIPLE_CHOICE -> quiz_choice 사용
--   KEYWORD_BLANK    -> quiz_answer_keyword 사용
CREATE TABLE quiz (
    id                       BIGINT       NOT NULL AUTO_INCREMENT,
    type                     VARCHAR(30)  NOT NULL, -- OX / MULTIPLE_CHOICE / KEYWORD_BLANK
    difficulty               VARCHAR(10)  NOT NULL, -- EASY / MEDIUM / HARD
    question_text            TEXT         NOT NULL,
    code_snippet             TEXT         NULL,
    correct_answer           VARCHAR(10)  NULL,      -- OX 전용 ("O" / "X")
    explanation_summary      TEXT         NOT NULL,
    explanation_example      TEXT         NULL,
    wrong_answer_explanation TEXT         NOT NULL,
    created_at               DATETIME(6)  NOT NULL,
    updated_at               DATETIME(6)  NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_choice (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    quiz_id       BIGINT       NOT NULL,
    content       VARCHAR(500) NOT NULL,
    is_correct    BIT(1)       NOT NULL,
    display_order INT          NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_choice_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_answer_keyword (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    quiz_id    BIGINT       NOT NULL,
    slot_order INT          NOT NULL,
    keyword    VARCHAR(200) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_answer_keyword_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_follow_up_question (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    quiz_id       BIGINT       NOT NULL,
    content       VARCHAR(500) NOT NULL,
    is_primary    BIT(1)       NOT NULL DEFAULT 0, -- 해설 화면 대표 꼬리질문(#9)
    display_order INT          NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_follow_up_question_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_derived_concept (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    quiz_id       BIGINT       NOT NULL,
    name          VARCHAR(200) NOT NULL,
    display_order INT          NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_derived_concept_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE quiz_keyword (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    quiz_id     BIGINT        NOT NULL,
    keyword     VARCHAR(200)  NOT NULL,
    description VARCHAR(1000) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_keyword_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- 학습 코스·화(에피소드)·유저 진행상태 (#45 홈 화면 조회 API)
-- 규칙: 버전 = 타임스탬프(yyyyMMddHHmmss), PR당 마이그레이션 1개, 적용된 파일 수정 금지(수정은 새 파일로)
-- user_progress는 다른 도메인(quiz)의 quiz_progress와 별개 개념이다 — 테이블명을 user_progress로 두어 구분한다.
CREATE TABLE course (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    title      VARCHAR(200) NOT NULL,
    category   VARCHAR(50)  NOT NULL,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE unit (
    id                BIGINT       NOT NULL AUTO_INCREMENT,
    course_id         BIGINT       NOT NULL,
    order_index       INT          NOT NULL,
    title             VARCHAR(200) NOT NULL,
    estimated_minutes INT          NOT NULL,
    created_at        DATETIME(6)  NOT NULL,
    updated_at        DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_unit_course FOREIGN KEY (course_id) REFERENCES course (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- user_id/course_id는 다른/같은 도메인이라도 유저당 코스별 1행 조회에만 쓰이므로 FK 없이 ID 값으로 참조한다
-- (server/docs/dto-and-query-patterns.md #2).
CREATE TABLE user_progress (
    id                BIGINT      NOT NULL AUTO_INCREMENT,
    user_id           BIGINT      NOT NULL,
    course_id         BIGINT      NOT NULL,
    cursor_unit_index INT         NOT NULL DEFAULT 1,
    streak            INT         NOT NULL DEFAULT 0,
    points            INT         NOT NULL DEFAULT 0,
    created_at        DATETIME(6) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_progress_user_course UNIQUE (user_id, course_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

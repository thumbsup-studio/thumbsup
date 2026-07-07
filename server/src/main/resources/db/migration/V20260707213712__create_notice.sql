-- 공지사항 (레퍼런스 feature)
-- 규칙: 버전 = 타임스탬프(yyyyMMddHHmmss), PR당 마이그레이션 1개, 적용된 파일 수정 금지(수정은 새 파일로)
CREATE TABLE notice (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    title      VARCHAR(200) NOT NULL,
    content    TEXT         NOT NULL,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

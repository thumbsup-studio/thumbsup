-- 저작 보안 하드닝(#174) — users.role(ADMIN 가드) + generation_job.version(낙관적 락)
-- 규칙: 버전 = 타임스탬프(yyyyMMddHHmmss), PR당 마이그레이션 1개, 적용된 파일 수정 금지(수정은 새 파일로)
ALTER TABLE users
    ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'USER';

ALTER TABLE generation_job
    ADD COLUMN version BIGINT NOT NULL DEFAULT 0;

-- #324: concept → tag 재설계
-- 1) 테이블/컬럼/제약을 concept_* → tag_* 로 rename
-- 2) quiz_tag 카디널리티를 퀴즈당 1개 → 최대 3개로 확장 (uk_quiz_concept_quiz 제거, (quiz_id, tag_id) 복합 유니크로 대체)
-- 3) tag.name에 대소문자/공백 무시 정규화 유니크 제약 추가 (같은 태그가 여러 코스에서 재사용되므로 표기 중복 방지)

-- ── concept → tag ─────────────────────────────────────────────
RENAME TABLE concept TO tag;
ALTER TABLE tag
    DROP INDEX uk_concept_name;

-- ── concept_description → tag_description ────────────────────
RENAME TABLE concept_description TO tag_description;
ALTER TABLE tag_description
    DROP FOREIGN KEY fk_concept_description_concept,
    DROP FOREIGN KEY fk_concept_description_step,
    DROP INDEX uk_concept_description_concept_step,
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;
ALTER TABLE tag_description
    ADD CONSTRAINT uk_tag_description_tag_step UNIQUE (tag_id, quiz_step_id),
    ADD CONSTRAINT fk_tag_description_tag FOREIGN KEY (tag_id) REFERENCES tag (id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_tag_description_step FOREIGN KEY (quiz_step_id) REFERENCES quiz_step (id);

-- ── concept_relation → tag_relation ───────────────────────────
RENAME TABLE concept_relation TO tag_relation;
ALTER TABLE tag_relation
    DROP FOREIGN KEY fk_concept_relation_source,
    DROP FOREIGN KEY fk_concept_relation_target,
    DROP INDEX uk_concept_relation_pair,
    CHANGE COLUMN source_concept_id source_tag_id BIGINT NOT NULL,
    CHANGE COLUMN target_concept_id target_tag_id BIGINT NOT NULL;
ALTER TABLE tag_relation
    ADD CONSTRAINT uk_tag_relation_pair UNIQUE (source_tag_id, target_tag_id),
    ADD CONSTRAINT fk_tag_relation_source FOREIGN KEY (source_tag_id) REFERENCES tag (id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_tag_relation_target FOREIGN KEY (target_tag_id) REFERENCES tag (id) ON DELETE CASCADE;

-- ── user_concept → user_tag ────────────────────────────────────
RENAME TABLE user_concept TO user_tag;
ALTER TABLE user_tag
    DROP FOREIGN KEY fk_user_concept_concept,
    DROP INDEX uk_user_concept,
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;
ALTER TABLE user_tag
    ADD CONSTRAINT uk_user_tag UNIQUE (user_id, tag_id),
    ADD CONSTRAINT fk_user_tag_tag FOREIGN KEY (tag_id) REFERENCES tag (id) ON DELETE CASCADE;

-- ── user_concept_step → user_tag_step ──────────────────────────
RENAME TABLE user_concept_step TO user_tag_step;
ALTER TABLE user_tag_step
    DROP FOREIGN KEY fk_user_concept_step_concept,
    DROP FOREIGN KEY fk_user_concept_step_step,
    DROP INDEX uk_user_concept_step,
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;
ALTER TABLE user_tag_step
    ADD CONSTRAINT uk_user_tag_step UNIQUE (user_id, tag_id, quiz_step_id),
    ADD CONSTRAINT fk_user_tag_step_tag FOREIGN KEY (tag_id) REFERENCES tag (id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_user_tag_step_step FOREIGN KEY (quiz_step_id) REFERENCES quiz_step (id);

-- ── quiz_concept → quiz_tag (카디널리티 확장: 퀴즈당 1개 → 최대 3개) ──
RENAME TABLE quiz_concept TO quiz_tag;
ALTER TABLE quiz_tag
    DROP FOREIGN KEY fk_quiz_concept_quiz,
    DROP FOREIGN KEY fk_quiz_concept_concept,
    DROP INDEX uk_quiz_concept_quiz,
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;
ALTER TABLE quiz_tag
    ADD CONSTRAINT uk_quiz_tag_pair UNIQUE (quiz_id, tag_id),
    ADD CONSTRAINT fk_quiz_tag_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_quiz_tag_tag FOREIGN KEY (tag_id) REFERENCES tag (id) ON DELETE CASCADE;

-- ── quiz_derived_concept → quiz_derived_tag (컬럼 변경 없음) ───
RENAME TABLE quiz_derived_concept TO quiz_derived_tag;
ALTER TABLE quiz_derived_tag
    DROP FOREIGN KEY fk_quiz_derived_concept_quiz;
ALTER TABLE quiz_derived_tag
    ADD CONSTRAINT fk_quiz_derived_tag_quiz FOREIGN KEY (quiz_id) REFERENCES quiz (id) ON DELETE CASCADE;

-- ── tag.name 정규화(대소문자·공백 무시) 유니크 제약 ───────────
-- 같은 태그가 여러 코스에서 재사용되므로, 표기만 다른 중복 생성을 막는다.
ALTER TABLE tag
    ADD COLUMN normalized_name VARCHAR(200) GENERATED ALWAYS AS (LOWER(TRIM(name))) STORED NOT NULL,
    ADD CONSTRAINT uk_tag_normalized_name UNIQUE (normalized_name);
-- #292: quiz/concept_description/user_concept_step가 quiz_step을 참조하는 방식을
-- (FK가 UNIQUE 컬럼인 step_order를 가리키는 값 참조)에서 (quiz_step.id, PK를 가리키는 진짜 FK)로 전환한다.
-- step_order는 다음 마이그레이션(V20260814205343)에서 코스별 상대 순번으로 재정의되므로,
-- 그 전에 "지금의" 전역 유일 step_order 값으로 quiz_step_id를 먼저 백필해둔다.

ALTER TABLE quiz
    ADD COLUMN quiz_step_id BIGINT NULL;

UPDATE quiz q
    JOIN quiz_step qs ON q.step_order = qs.step_order
SET q.quiz_step_id = qs.id;

ALTER TABLE quiz
    MODIFY COLUMN quiz_step_id BIGINT NOT NULL;

ALTER TABLE quiz
    DROP FOREIGN KEY fk_quiz_step_order;

ALTER TABLE quiz
    ADD CONSTRAINT fk_quiz_quiz_step FOREIGN KEY (quiz_step_id) REFERENCES quiz_step (id);

-- concept_description.step_order → quiz_step.step_order FK도 같은 이유로 전환한다.
-- 이 테이블은 Java 코드로 생성되지 않고 시드 마이그레이션(V20260801192745)이 직접 INSERT하므로
-- quiz_step_id 백필 후에는 step_order 컬럼 자체가 더 이상 필요 없어 제거한다.
ALTER TABLE concept_description
    ADD COLUMN quiz_step_id BIGINT NULL;

UPDATE concept_description cd
    JOIN quiz_step qs ON cd.step_order = qs.step_order
SET cd.quiz_step_id = qs.id;

ALTER TABLE concept_description
    MODIFY COLUMN quiz_step_id BIGINT NOT NULL;

-- uk_concept_description_concept_step(concept_id, step_order)는 leftmost prefix(concept_id) 덕에
-- fk_concept_description_concept의 지지 인덱스 역할도 겸하고 있다 — 그 유니크를 드롭하면 이 FK가
-- 인덱스를 잃어 같은 에러 1553이 난다. 대체 인덱스를 먼저 만들어 지지를 끊기지 않게 한다.
ALTER TABLE concept_description
    ADD INDEX ix_concept_description_concept_id_tmp (concept_id);

-- fk_concept_description_step(step_order 단일 컬럼)은 leftmost prefix가 안 맞아 자체 자동 생성 인덱스를
-- 따로 갖는다 — DROP FOREIGN KEY만으로 그 인덱스까지 같이 지워지는데, 이를 uk_concept_description_concept_step
-- 드롭과 별도 ALTER TABLE 문으로 나누면 MySQL이 "방금 지운 FK가 아직 참조 중"이라고 오판해 에러 1553을
-- 낸다 — 두 DROP을 한 ALTER TABLE 문으로 묶는다. uk_concept_description_concept_step 자체는 (앞서 설명한
-- 대로) fk_concept_description_concept의 지지 인덱스라서 지우는 것이지 이 FK와는 무관하다.
ALTER TABLE concept_description
    DROP FOREIGN KEY fk_concept_description_step,
    DROP INDEX uk_concept_description_concept_step;

ALTER TABLE concept_description
    DROP COLUMN step_order;

ALTER TABLE concept_description
    ADD CONSTRAINT fk_concept_description_step FOREIGN KEY (quiz_step_id) REFERENCES quiz_step (id),
    ADD CONSTRAINT uk_concept_description_concept_step UNIQUE (concept_id, quiz_step_id);

-- 새 유니크(concept_id, quiz_step_id)가 다시 leftmost prefix로 concept_id FK를 지지하니 임시 인덱스는 제거한다.
ALTER TABLE concept_description
    DROP INDEX ix_concept_description_concept_id_tmp;

-- user_concept_step.step_order → quiz_step.step_order FK도 동일하게 전환한다.
ALTER TABLE user_concept_step
    ADD COLUMN quiz_step_id BIGINT NULL;

UPDATE user_concept_step ucs
    JOIN quiz_step qs ON ucs.step_order = qs.step_order
SET ucs.quiz_step_id = qs.id;

ALTER TABLE user_concept_step
    MODIFY COLUMN quiz_step_id BIGINT NOT NULL;

ALTER TABLE user_concept_step
    DROP FOREIGN KEY fk_user_concept_step_step,
    DROP INDEX uk_user_concept_step;

ALTER TABLE user_concept_step
    DROP COLUMN step_order;

ALTER TABLE user_concept_step
    ADD CONSTRAINT fk_user_concept_step_step FOREIGN KEY (quiz_step_id) REFERENCES quiz_step (id),
    ADD CONSTRAINT uk_user_concept_step UNIQUE (user_id, concept_id, quiz_step_id);

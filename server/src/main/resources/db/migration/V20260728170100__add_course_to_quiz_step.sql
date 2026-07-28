-- quiz_step에 course_id를 추가한다 — 지금까지는 course와 quiz_step이 구조적으로 전혀 연결돼 있지 않아,
-- HomeService가 "id가 가장 작은 코스"와 "지금 진행 중인 스텝"을 각자 따로 가져와 우연히 같은 커리큘럼이라고
-- 가정하고 붙여 보여주고 있었다. 디자인패턴처럼 성격이 다른 커리큘럼이 추가되면서 이 가정이 깨졌다.
--
-- step_order는 계속 전역 유일 순번을 유지한다(코스별로 다시 세지 않음) — course_id는 그 위에 붙는
-- "소속 태그"일 뿐이다.
ALTER TABLE quiz_step
    ADD COLUMN course_id BIGINT NULL;

-- 기존 0~12번 스텝(0번은 미배정 placeholder, 1~12번은 실제 커리큘럼)은 전부 운영체제(OS) 코스(id=1)였다.
-- 0번을 빼먹으면 course_id IS NULL로 남아 아래 두 번째 UPDATE(디자인패턴 배정)가 그대로 주워가 버린다.
UPDATE quiz_step
SET course_id = 1
WHERE step_order BETWEEN 0 AND 12;

-- 13번부터는 디자인패턴 커리큘럼(#26 생성 파이프라인으로 만든 것) — 새 코스 행을 만들고 배정한다.
INSERT INTO course (title, category, created_at, updated_at)
VALUES ('디자인 패턴', 'CS', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

UPDATE quiz_step
SET course_id = LAST_INSERT_ID()
WHERE course_id IS NULL;

ALTER TABLE quiz_step
    MODIFY COLUMN course_id BIGINT NOT NULL;

ALTER TABLE quiz_step
    ADD CONSTRAINT fk_quiz_step_course FOREIGN KEY (course_id) REFERENCES course (id);

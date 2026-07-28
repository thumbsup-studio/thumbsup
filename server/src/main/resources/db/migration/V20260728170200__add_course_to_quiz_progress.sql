-- quiz_progress에 course_id를 추가하고 유니크 제약을 (user_id) -> (user_id, course_id)로 바꾼다.
-- 지금까지는 유저당 진행 커서(current_step_order)가 전역으로 하나뿐이라, 코스가 여러 개면 한 코스의
-- 진행이 다른 코스 진행 위치를 덮어써 버린다.
--
-- 이 정확한 패턴((user_id, course_id) UNIQUE)은 V20260710133908__merge_learning_into_quiz.sql에서
-- user_progress.course_id를 없애며 한 번 폐기됐다 — 당시엔 커서 필드가 QuizProgress와 UserProgress
-- 두 곳에 나뉘어 있어 서로 어긋나는 버그가 있었다. 이번엔 커서(current_step_order)를 실제로 갖는
-- QuizProgress 자신에게 course_id를 둬서 그 실수를 반복하지 않는다.
ALTER TABLE quiz_progress
    ADD COLUMN course_id BIGINT NULL;

-- 기존 진행 기록은 전부 운영체제(OS) 코스(id=1) 기준으로 쌓인 것이다.
UPDATE quiz_progress
SET course_id = 1;

ALTER TABLE quiz_progress
    MODIFY COLUMN course_id BIGINT NOT NULL;

ALTER TABLE quiz_progress
    DROP INDEX uk_quiz_progress_user;

ALTER TABLE quiz_progress
    ADD CONSTRAINT uk_quiz_progress_user_course UNIQUE (user_id, course_id);

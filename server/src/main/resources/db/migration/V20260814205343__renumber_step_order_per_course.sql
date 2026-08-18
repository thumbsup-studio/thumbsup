-- #292: step_order를 커리큘럼 전역 순번에서 코스별 1부터 시작하는 상대 순번으로 재정의한다.
-- step_order=0("미배정" placeholder, #257)은 실제 커리큘럼이 아니므로 재번호 대상에서 제외하고 0으로 남긴다.
-- FK는 이제 quiz_step_id(PK) 기준이라(V20260814205342) step_order 값을 바꿔도 참조 무결성이 깨지지 않는다.

ALTER TABLE quiz_step
    DROP INDEX uk_quiz_step_order;

UPDATE quiz_step qs
    JOIN (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY course_id ORDER BY step_order) AS new_order
        FROM quiz_step
        WHERE step_order > 0
    ) ranked ON qs.id = ranked.id
SET qs.step_order = ranked.new_order;

ALTER TABLE quiz_step
    ADD CONSTRAINT uk_quiz_step_course_order UNIQUE (course_id, step_order);

-- quiz.step_order는 quiz_step_id를 통해서만 무결성이 보장되는 비정규화 캐시 컬럼으로 남는다 —
-- 조회 편의를 위해 직접 읽는 곳이 많아 컬럼 자체는 유지하되, 값은 quiz_step_id를 통해
-- 새로 매겨진(코스별 상대) step_order로 다시 채운다. 이후 쓰기 경로(QuizPersister)가 항상 같은 값으로 채운다.
UPDATE quiz q
    JOIN quiz_step qs ON q.quiz_step_id = qs.id
SET q.step_order = qs.step_order;

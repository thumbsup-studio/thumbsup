-- learning(Course/Unit/UserProgress)을 quiz 패키지로 통합한다 (#117).
-- 홈 진행 상태(UserProgress.cursorUnitIndex)와 퀴즈 진행 상태(QuizProgress.currentStepOrder)가
-- 따로 있어 동기화가 안 되던 문제를, Unit을 없애고 QuizStep을 유일한 커리큘럼 소스로 삼아 해결한다.

-- QuizStep에 estimatedMinutes 추가 — Unit이 갖고 있던 "예상 소요시간" 표시 데이터를 대체한다.
ALTER TABLE quiz_step
    ADD COLUMN estimated_minutes INT NULL;

UPDATE quiz_step SET estimated_minutes = 3;

ALTER TABLE quiz_step
    MODIFY COLUMN estimated_minutes INT NOT NULL;

-- Unit은 QuizStep과 중복 개념이라 삭제한다.
DROP TABLE unit;

-- UserProgress는 진행 커서(cursorUnitIndex/courseId)를 더 이상 갖지 않는다 — 유일한 커서는
-- quiz_progress.current_step_order다. UserProgress는 streak/points 전용으로 남는다.
ALTER TABLE user_progress
    DROP INDEX uk_user_progress_user_course,
    DROP COLUMN cursor_unit_index,
    DROP COLUMN course_id,
    ADD CONSTRAINT uk_user_progress_user UNIQUE (user_id);
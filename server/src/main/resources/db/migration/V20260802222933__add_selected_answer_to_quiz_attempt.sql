-- #261: 풀이 기록 열람(#191)을 위해 선택한 답을 저장한다.
-- 이 컬럼 도입 이전 시도는 실제로 값을 알 수 없으므로 NULL을 허용한다(가짜 기본값을 지어내지 않는다).
ALTER TABLE quiz_attempt
    ADD COLUMN selected_answer TEXT NULL AFTER is_correct;

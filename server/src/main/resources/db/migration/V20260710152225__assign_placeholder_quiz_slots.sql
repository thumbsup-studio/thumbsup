-- 기존 placeholder 문제(step_order=0)는 해설 조회 API의 성공 계약을 유지하되,
-- 화면에 유효한 현재 순번을 표시할 수 있도록 id 순서대로 slot_order를 부여한다.
UPDATE quiz AS q
JOIN (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS slot_order
    FROM quiz
    WHERE step_order = 0
      AND slot_order = 0
) AS ranked ON ranked.id = q.id
SET q.slot_order = ranked.slot_order;

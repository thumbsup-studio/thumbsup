-- 정답 제출(#42)마다 step_order로 조회하는 핫패스(findByStepOrderOrderBySlotOrderAsc,
-- findIdsByStepOrder)를 위한 인덱스. slot_order를 함께 포함해 정렬 조회도 인덱스로 커버한다.
ALTER TABLE quiz
    ADD INDEX idx_quiz_step_order (step_order, slot_order);

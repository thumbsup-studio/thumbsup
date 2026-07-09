-- 유저가 실제로 제출한 답을 함께 저장한다 — 오답 사유 표시 등 향후 복습 기능 참고용(채점 근거 아님).
ALTER TABLE quiz_attempt
    ADD COLUMN submitted_answer VARCHAR(500) NOT NULL DEFAULT '';

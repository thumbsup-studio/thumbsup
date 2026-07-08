-- 커리큘럼 진행 순서 — MVP는 코스 1개(운영체제)뿐이라 course 테이블 없이 quiz에 순서만 부여한다.
-- step_order: 몇 번째 스텝(5문제 세트: 하2·중2·상1)인지, slot_order: 스텝 내 출제 순서(1~5).
-- 기본값 0은 "스텝 밖"(정식 커리큘럼 미배정) 의미 — 정식 스텝은 1부터 시작한다.
ALTER TABLE quiz
    ADD COLUMN step_order INT NOT NULL DEFAULT 0,
    ADD COLUMN slot_order INT NOT NULL DEFAULT 0;

-- 기존 샘플 데이터(V20260708171651)는 실제 커리큘럼이 아닌 임시 placeholder라 step_order=0으로 남겨
-- 1번 스텝 조회(#41)와 겹치지 않게 한다. 실제 커리큘럼은 #26이 채운다.

-- course id 1의 이름표를 실제 콘텐츠(운영체제 커리큘럼)에 맞게 바로잡는다 (#145).
-- 데모 시드(V20260710021230__seed_learning_sample.sql)는 'CS 기초'로 두고 UPDATE로 덮어쓴다
-- (적용된 마이그레이션은 수정 금지 규칙이라 새 마이그레이션으로 값만 갱신).
UPDATE course SET title = '운영체제' WHERE id = 1;

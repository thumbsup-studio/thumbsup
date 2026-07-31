-- #193: 풀이 중 즉시 조회하는 안전한 한 문장 힌트의 nullable 스키마 단계.
-- MySQL의 비트랜잭션 DDL과 데이터 백필을 분리해, 백필 실패 시에도
-- 다음 기동이 컬럼 중복으로 막히지 않고 후속 DML migration만 재시도할 수 있게 한다.
ALTER TABLE quiz
    ADD COLUMN hint TEXT NULL AFTER code_snippet;

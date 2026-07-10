-- 꼬리질문 상세 백필이 두 번 적용돼 블록과 키워드가 정확히 두 배로 늘어난 것을 되돌린다.
--
-- 무슨 일이 있었나: PR #140과 PR #141이 같은 백필 스크립트를 각자 리네임해 26초 간격으로 머지됐다.
-- V20260710223718 과 V20260710223922 는 내용이 한 바이트도 다르지 않지만, Flyway는 버전 번호로만
-- 적용 여부를 판단하므로 두 파일을 별개의 마이그레이션으로 보고 INSERT를 두 번 실행했다.
-- UPDATE(난이도·한 줄 답)는 멱등이라 무사하고, INSERT만 중복됐다.
--
-- 두 파일 모두 이미 적용됐으므로 지울 수 없다 — 지우면 Flyway가 "applied migration not resolved
-- locally"로 기동을 거부한다. 데이터만 여기서 되돌리고, 재발은 아래 UNIQUE 제약으로 막는다.

-- 같은 꼬리질문 안에서 display_order가 겹치는 블록 중 먼저 들어온 행만 남긴다.
DELETE duplicate
FROM quiz_follow_up_block duplicate
         JOIN (SELECT follow_up_question_id,
                      display_order,
                      MIN(id) AS surviving_id
               FROM quiz_follow_up_block
               GROUP BY follow_up_question_id, display_order) AS survivor
              ON duplicate.follow_up_question_id = survivor.follow_up_question_id
                  AND duplicate.display_order = survivor.display_order
WHERE duplicate.id > survivor.surviving_id;

-- 같은 꼬리질문 안에서 keyword가 겹치는 사전 항목 중 먼저 들어온 행만 남긴다.
DELETE duplicate
FROM quiz_follow_up_keyword duplicate
         JOIN (SELECT follow_up_question_id,
                      keyword,
                      MIN(id) AS surviving_id
               FROM quiz_follow_up_keyword
               GROUP BY follow_up_question_id, keyword) AS survivor
              ON duplicate.follow_up_question_id = survivor.follow_up_question_id
                  AND duplicate.keyword = survivor.keyword
WHERE duplicate.id > survivor.surviving_id;

-- 블록의 표시 순서는 꼬리질문 안에서 유일하다 — 같은 칸이 두 번 그려질 수 없다.
ALTER TABLE quiz_follow_up_block
    ADD CONSTRAINT uk_quiz_follow_up_block_order UNIQUE (follow_up_question_id, display_order);

-- 키워드 사전에 같은 용어가 두 번 실리면 툴팁 목록에 같은 항목이 두 번 나온다.
-- 서버 검증(KeywordMarkerValidator)은 Set으로 접어 보기 때문에 중복을 잡지 못한다 — DB에서 막는다.
ALTER TABLE quiz_follow_up_keyword
    ADD CONSTRAINT uk_quiz_follow_up_keyword_term UNIQUE (follow_up_question_id, keyword);

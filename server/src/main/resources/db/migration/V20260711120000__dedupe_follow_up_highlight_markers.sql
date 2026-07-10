-- #162: 꼬리질문 하나의 전용 키워드는 한 줄 답과 모든 상세 블록을 합쳐 정확히 한 번만 하이라이트한다.
--
-- 유지 우선순위는 one_line_answer > block.display_order > 같은 필드의 첫 exact marker다.
-- 우선순위 뒤의 [[keyword]]는 괄호만 벗겨 keyword 평문으로 남긴다. 마커가 전혀 없는 keyword는
-- 평문 등장 위치를 추측해 새로 마킹하지 않는다. 대소문자와 악센트까지 같은 마커만 찾도록
-- keyword와 marker, 모든 INSTR 탐색에 utf8mb4_bin을 사용한다.
--
-- 질문마다 블록 수가 가변이라, 등록 키워드와 최초 블록 위치를 migration 전용 helper table에 먼저
-- 고정한다. MySQL TEMPORARY TABLE은 한 statement에서 두 번 참조할 수 없으므로 일반 InnoDB table을
-- 쓰고 마지막에 제거한다. 실패 후 Flyway repair/retry도 가능하도록 남은 helper는 재사용하되 비운다.
-- 실제 시드의 질문당 distinct keyword 최댓값은 4개로 기본 cte_max_recursion_depth(1000) 이하다.

CREATE TABLE IF NOT EXISTS migration_20260711120000_follow_up_marker
(
    follow_up_question_id BIGINT       NOT NULL,
    marker_order          INT          NOT NULL,
    keyword_count         INT          NOT NULL,
    keyword               VARCHAR(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    marker                VARCHAR(204) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    one_line_has_marker   TINYINT      NOT NULL DEFAULT 0,
    keeper_block_id       BIGINT       NULL,
    PRIMARY KEY (follow_up_question_id, marker_order)
) ENGINE = InnoDB;

TRUNCATE TABLE migration_20260711120000_follow_up_marker;

-- exact duplicate 사전 행이 있어도 같은 marker는 한 번만 처리한다. marker 자체가 binary collation이라
-- case/accent variant는 서로 다른 사전 항목으로 유지된다.
INSERT INTO migration_20260711120000_follow_up_marker
    (follow_up_question_id, marker_order, keyword_count, keyword, marker)
SELECT follow_up_question_id,
       ROW_NUMBER() OVER (
           PARTITION BY follow_up_question_id
           ORDER BY marker
       ) AS marker_order,
       COUNT(*) OVER (
           PARTITION BY follow_up_question_id
       ) AS keyword_count,
       keyword,
       marker
FROM (SELECT DISTINCT follow_up_question_id,
                      keyword COLLATE utf8mb4_bin AS keyword,
                      CONCAT('[[', keyword, ']]') COLLATE utf8mb4_bin AS marker
      FROM quiz_follow_up_keyword) AS registered_keyword;

-- one_line_answer가 NULL인 상세 없는 질문도 0으로 취급한다. 블록 keeper는 display_order가 가장
-- 빠른 블록이며, 손상 데이터에서 order가 겹쳐도 id로 결과를 결정적으로 만든다.
UPDATE migration_20260711120000_follow_up_marker AS keyword
JOIN quiz_follow_up_question AS question
  ON question.id = keyword.follow_up_question_id
SET keyword.one_line_has_marker =
        COALESCE(
            INSTR(
                question.one_line_answer COLLATE utf8mb4_bin,
                keyword.marker
            ),
            0
        ) > 0,
    keyword.keeper_block_id = (
        SELECT block.id
        FROM quiz_follow_up_block AS block
        WHERE block.follow_up_question_id = keyword.follow_up_question_id
          AND INSTR(
                  block.content COLLATE utf8mb4_bin,
                  keyword.marker
              ) > 0
        ORDER BY block.display_order, block.id
        LIMIT 1
    );

-- 한 줄 답에 있는 각 등록 marker의 첫 등장만 유지하고 같은 필드의 후속 marker를 평문으로 바꾼다.
-- NULL answer는 재귀 단계 내내 NULL로 유지된다.
WITH RECURSIVE rewritten_answer AS (
    SELECT question.id AS follow_up_question_id,
           target.keyword_count,
           0 AS marker_order,
           CAST(
               question.one_line_answer AS CHAR(65535) CHARACTER SET utf8mb4
           ) AS content
    FROM quiz_follow_up_question AS question
    JOIN (SELECT follow_up_question_id,
                 MAX(keyword_count) AS keyword_count
          FROM migration_20260711120000_follow_up_marker
          GROUP BY follow_up_question_id) AS target
      ON target.follow_up_question_id = question.id

    UNION ALL

    SELECT rewritten.follow_up_question_id,
           rewritten.keyword_count,
           rewritten.marker_order + 1,
           IF(
               INSTR(
                   rewritten.content COLLATE utf8mb4_bin,
                   keyword.marker
               ) > 0,
               CONCAT(
                   LEFT(
                       rewritten.content,
                       INSTR(
                           rewritten.content COLLATE utf8mb4_bin,
                           keyword.marker
                       ) + CHAR_LENGTH(keyword.marker) - 1
                   ),
                   REPLACE(
                       SUBSTRING(
                           rewritten.content,
                           INSTR(
                               rewritten.content COLLATE utf8mb4_bin,
                               keyword.marker
                           ) + CHAR_LENGTH(keyword.marker)
                       ),
                       keyword.marker,
                       keyword.keyword
                   )
               ),
               rewritten.content
           ) AS content
    FROM rewritten_answer AS rewritten
    JOIN migration_20260711120000_follow_up_marker AS keyword
      ON keyword.follow_up_question_id = rewritten.follow_up_question_id
     AND keyword.marker_order = rewritten.marker_order + 1
)
UPDATE quiz_follow_up_question AS question
JOIN rewritten_answer AS rewritten
  ON rewritten.follow_up_question_id = question.id
 AND rewritten.marker_order = rewritten.keyword_count
SET question.one_line_answer = rewritten.content;

-- 한 줄 답에 marker가 있었다면 모든 블록 marker를 평문으로 바꾼다. 없었다면 가장 빠른 블록의
-- 첫 marker만 유지하고, 같은 블록의 후속 marker와 다른 모든 블록 marker의 괄호를 제거한다.
WITH RECURSIVE rewritten_block AS (
    SELECT block.id AS block_id,
           block.follow_up_question_id,
           target.keyword_count,
           0 AS marker_order,
           CAST(
               block.content AS CHAR(65535) CHARACTER SET utf8mb4
           ) AS content
    FROM quiz_follow_up_block AS block
    JOIN (SELECT follow_up_question_id,
                 MAX(keyword_count) AS keyword_count
          FROM migration_20260711120000_follow_up_marker
          GROUP BY follow_up_question_id) AS target
      ON target.follow_up_question_id = block.follow_up_question_id

    UNION ALL

    SELECT rewritten.block_id,
           rewritten.follow_up_question_id,
           rewritten.keyword_count,
           rewritten.marker_order + 1,
           CASE
               WHEN keyword.one_line_has_marker = 1
               THEN REPLACE(
                   rewritten.content,
                   keyword.marker,
                   keyword.keyword
               )
               WHEN keyword.keeper_block_id = rewritten.block_id
                    AND INSTR(
                        rewritten.content COLLATE utf8mb4_bin,
                        keyword.marker
                    ) > 0
               THEN CONCAT(
                   LEFT(
                       rewritten.content,
                       INSTR(
                           rewritten.content COLLATE utf8mb4_bin,
                           keyword.marker
                       ) + CHAR_LENGTH(keyword.marker) - 1
                   ),
                   REPLACE(
                       SUBSTRING(
                           rewritten.content,
                           INSTR(
                               rewritten.content COLLATE utf8mb4_bin,
                               keyword.marker
                           ) + CHAR_LENGTH(keyword.marker)
                       ),
                       keyword.marker,
                       keyword.keyword
                   )
               )
               ELSE REPLACE(
                   rewritten.content,
                   keyword.marker,
                   keyword.keyword
               )
           END AS content
    FROM rewritten_block AS rewritten
    JOIN migration_20260711120000_follow_up_marker AS keyword
      ON keyword.follow_up_question_id = rewritten.follow_up_question_id
     AND keyword.marker_order = rewritten.marker_order + 1
)
UPDATE quiz_follow_up_block AS block
JOIN rewritten_block AS rewritten
  ON rewritten.block_id = block.id
 AND rewritten.marker_order = rewritten.keyword_count
SET block.content = rewritten.content;

DROP TABLE migration_20260711120000_follow_up_marker;

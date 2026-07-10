-- #147: 해설 화면은 등록된 키워드당 하나의 [[마커]]만 하이라이트한다.
-- 현재 저장된 모든 quiz와 quiz_keyword를 직접 조합해 보정하므로,
-- 특정 seed의 auto-increment id나 (step_order, slot_order) 목록에 의존하지 않는다.
--
-- 마커 유지 우선순위: 핵심 정리 > 적용 예시 > 오답 해설.
-- 가장 높은 우선순위 필드의 첫 마커만 유지하고, 같은 필드의 후속 마커와
-- 낮은 우선순위 필드의 마커는 구분자만 제거해 본문을 보존한다.
-- 어느 필드에도 마커가 없는 등록 키워드는 임의로 삽입하지 않는다.
-- keyword 계약은 대소문자·악센트까지 정확히 일치하므로 탐색에는 binary collation을 쓴다.
WITH RECURSIVE registered_keyword AS (
    SELECT DISTINCT quiz_id,
                    keyword,
                    CONCAT('[[', keyword, ']]') COLLATE utf8mb4_bin AS marker
    FROM quiz_keyword
), ordered_keyword AS (
    SELECT quiz_id,
           keyword,
           marker,
           ROW_NUMBER() OVER (
               PARTITION BY quiz_id
               ORDER BY marker
           ) AS marker_order
    FROM registered_keyword
), rewritten_explanation AS (
    SELECT q.id,
           0 AS marker_order,
           CAST(q.explanation_summary AS CHAR(65535)) AS explanation_summary,
           CAST(q.explanation_example AS CHAR(65535)) AS explanation_example,
           CAST(q.wrong_answer_explanation AS CHAR(65535)) AS wrong_answer_explanation
    FROM quiz AS q
    JOIN (
        SELECT DISTINCT quiz_id
        FROM ordered_keyword
    ) AS target ON target.quiz_id = q.id

    UNION ALL

    SELECT rewritten.id,
           rewritten.marker_order + 1,
           IF(
               INSTR(
                   rewritten.explanation_summary COLLATE utf8mb4_bin,
                   keyword.marker
               ) > 0,
               CONCAT(
                   LEFT(
                       rewritten.explanation_summary,
                       INSTR(
                           rewritten.explanation_summary COLLATE utf8mb4_bin,
                           keyword.marker
                       ) + CHAR_LENGTH(keyword.marker) - 1
                   ),
                   REPLACE(
                       SUBSTRING(
                           rewritten.explanation_summary,
                           INSTR(
                               rewritten.explanation_summary COLLATE utf8mb4_bin,
                               keyword.marker
                           ) + CHAR_LENGTH(keyword.marker)
                       ),
                       keyword.marker,
                       keyword.keyword
                   )
               ),
               rewritten.explanation_summary
           ),
           IF(
               INSTR(
                   rewritten.explanation_summary COLLATE utf8mb4_bin,
                   keyword.marker
               ) > 0,
               REPLACE(
                   rewritten.explanation_example,
                   keyword.marker,
                   keyword.keyword
               ),
               IF(
                   INSTR(
                       rewritten.explanation_example COLLATE utf8mb4_bin,
                       keyword.marker
                   ) > 0,
                   CONCAT(
                       LEFT(
                           rewritten.explanation_example,
                           INSTR(
                               rewritten.explanation_example COLLATE utf8mb4_bin,
                               keyword.marker
                           ) + CHAR_LENGTH(keyword.marker) - 1
                       ),
                       REPLACE(
                           SUBSTRING(
                               rewritten.explanation_example,
                               INSTR(
                                   rewritten.explanation_example COLLATE utf8mb4_bin,
                                   keyword.marker
                               ) + CHAR_LENGTH(keyword.marker)
                           ),
                           keyword.marker,
                           keyword.keyword
                       )
                   ),
                   rewritten.explanation_example
               )
           ),
           IF(
               INSTR(
                   rewritten.explanation_summary COLLATE utf8mb4_bin,
                   keyword.marker
               ) > 0
                   OR INSTR(
                       rewritten.explanation_example COLLATE utf8mb4_bin,
                       keyword.marker
                   ) > 0,
               REPLACE(
                   rewritten.wrong_answer_explanation,
                   keyword.marker,
                   keyword.keyword
               ),
               IF(
                   INSTR(
                       rewritten.wrong_answer_explanation COLLATE utf8mb4_bin,
                       keyword.marker
                   ) > 0,
                   CONCAT(
                       LEFT(
                           rewritten.wrong_answer_explanation,
                           INSTR(
                               rewritten.wrong_answer_explanation COLLATE utf8mb4_bin,
                               keyword.marker
                           ) + CHAR_LENGTH(keyword.marker) - 1
                       ),
                       REPLACE(
                           SUBSTRING(
                               rewritten.wrong_answer_explanation,
                               INSTR(
                                   rewritten.wrong_answer_explanation COLLATE utf8mb4_bin,
                                   keyword.marker
                               ) + CHAR_LENGTH(keyword.marker)
                           ),
                           keyword.marker,
                           keyword.keyword
                       )
                   ),
                   rewritten.wrong_answer_explanation
               )
           )
    FROM rewritten_explanation AS rewritten
    JOIN ordered_keyword AS keyword
      ON keyword.quiz_id = rewritten.id
     AND keyword.marker_order = rewritten.marker_order + 1
)
UPDATE quiz AS q
JOIN rewritten_explanation AS rewritten ON rewritten.id = q.id
JOIN (
    SELECT id, MAX(marker_order) AS marker_order
    FROM rewritten_explanation
    GROUP BY id
) AS final
  ON final.id = rewritten.id
 AND final.marker_order = rewritten.marker_order
SET q.explanation_summary = rewritten.explanation_summary,
    q.explanation_example = rewritten.explanation_example,
    q.wrong_answer_explanation = rewritten.wrong_answer_explanation;

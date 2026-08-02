-- #233 지식 그래프: 배포 이전에 이미 스텝을 완료한 기존 유저들의 학습 이력을 user_concept/user_concept_step에
-- 1회성으로 채운다. 이후 신규 스텝 완료는 QuizService(advanceProgressIfStepCompleted)가 실시간으로 기록한다.
-- 이 마이그레이션 시점엔 두 테이블이 비어 있으므로(직전 마이그레이션에서 막 생성) 중복 INSERT 걱정이 없다.

INSERT INTO user_concept_step (user_id, concept_id, step_order, created_at, updated_at)
SELECT DISTINCT qp.user_id, qc.concept_id, qs.step_order, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM quiz_progress qp
         JOIN quiz_step qs ON qs.course_id = qp.course_id
         JOIN quiz q ON q.step_order = qs.step_order
         JOIN quiz_concept qc ON qc.quiz_id = q.id
WHERE qs.step_order < qp.current_step_order
  AND qs.step_order >= (SELECT MIN(qs2.step_order) FROM quiz_step qs2 WHERE qs2.course_id = qs.course_id);

-- learnedAt(=created_at)은 그 개념이 걸린 완료 스텝들 중 최초로 완료된 시각(최솟값)을 쓴다.
-- 스텝 완료 시각은 별도로 영구 저장된 값이 없어 근사한다: 문제별 "최초 시도" 시각의 최댓값
-- (= 그 스텝의 마지막 문제를 처음 푼 순간). 재제출(복습) 시도를 MAX에 섞으면 어제 복습한 스텝의
-- learnedAt이 어제로 밀리므로, 퀴즈별 MIN(created_at)으로 최초 시도만 골라낸다.
INSERT INTO user_concept (user_id, concept_id, created_at, updated_at)
SELECT e.user_id, e.concept_id, MIN(sc.completed_at), MIN(sc.completed_at)
FROM (SELECT DISTINCT qp.user_id, qs.step_order, qc.concept_id
      FROM quiz_progress qp
               JOIN quiz_step qs ON qs.course_id = qp.course_id
               JOIN quiz q ON q.step_order = qs.step_order
               JOIN quiz_concept qc ON qc.quiz_id = q.id
      WHERE qs.step_order < qp.current_step_order
        AND qs.step_order >= (SELECT MIN(qs2.step_order) FROM quiz_step qs2 WHERE qs2.course_id = qs.course_id)) e
         JOIN (SELECT f.user_id, q3.step_order, MAX(f.first_attempted_at) AS completed_at
               FROM (SELECT qa.user_id, qa.quiz_id, MIN(qa.created_at) AS first_attempted_at
                     FROM quiz_attempt qa
                     GROUP BY qa.user_id, qa.quiz_id) f
                        JOIN quiz q3 ON q3.id = f.quiz_id
               GROUP BY f.user_id, q3.step_order) sc
              ON sc.user_id = e.user_id AND sc.step_order = e.step_order
GROUP BY e.user_id, e.concept_id;
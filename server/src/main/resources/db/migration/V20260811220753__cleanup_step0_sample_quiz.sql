-- 초기 커리큘럼 이전에 만든 샘플 문제 3건(quiz id 1,2,3, V20260708171651)을 정리한다.
-- #257(PR #273)에서 코스 시작 스텝 계산 로직은 이미 이 placeholder를 제외하도록 고쳤으나
-- 데이터 자체는 남아있었다 (#287). quiz_attempt·quiz_draft 조회로 참조 없음을 확인했다.
-- id 1,2,3은 quiz 테이블에 처음 INSERT하는 마이그레이션(V20260708171651)이 만드는 값이라
-- 모든 환경(로컬/CI/운영)에서 항상 동일하다.
--
-- step_order=0 조건이 아니라 id로 정확히 지정한다: step_order=0("미배정")은 이 3건 전용이
-- 아니라 Quiz.stepOrder가 assignPosition() 호출 전 갖는 int 기본값이 공유하는 자리다.
-- QuizHintMigrationSafetyTest는 이 자리에 백필 대상이 아닌 별도 콘텐츠가 추가돼도 마이그레이션이
-- 건드리지 않아야 함을 검증하므로, step_order로 조건을 걸면 그 시나리오까지 삭제해버린다.
--
-- quiz_step.step_order=0 sentinel 행(V20260709201632, '(미배정)') 자체는 지우지 않는다:
-- QuizRepositoryTest의 다수 케이스와 QuizFixture가 assignPosition() 없이 저장하는 걸 전제하고
-- (FindByStep.finds_max_step_order_excluding_placeholder는 이 상태를 의도적으로 재현해 #257
-- 회귀를 막는다), sentinel을 지우면 fk_quiz_step_order 위반으로 이 테스트들이 깨진다. 운영 코드
-- (QuizPersister)는 항상 QuizStep 생성 + assignPosition을 함께 하므로 sentinel 유무와 무관하다.

DELETE b
FROM quiz_follow_up_block b
    JOIN quiz_follow_up_question q ON b.follow_up_question_id = q.id
WHERE q.quiz_id IN (1, 2, 3);

DELETE k
FROM quiz_follow_up_keyword k
    JOIN quiz_follow_up_question q ON k.follow_up_question_id = q.id
WHERE q.quiz_id IN (1, 2, 3);

DELETE FROM quiz_follow_up_question WHERE quiz_id IN (1, 2, 3);
DELETE FROM quiz_answer_keyword WHERE quiz_id IN (1, 2, 3);
DELETE FROM quiz_choice WHERE quiz_id IN (1, 2, 3);
DELETE FROM quiz_derived_concept WHERE quiz_id IN (1, 2, 3);
DELETE FROM quiz_keyword WHERE quiz_id IN (1, 2, 3);
DELETE FROM quiz_concept WHERE quiz_id IN (1, 2, 3);
DELETE FROM quiz WHERE id IN (1, 2, 3);

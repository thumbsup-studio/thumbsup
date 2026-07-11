-- #157: 코드가 아닌 자연어·조건 목록을 code_snippet에서 question_text로 옮긴다.
-- 운영 DB의 auto-increment id에 의존하지 않고 (step_order, slot_order) 업무 좌표와 기존 원문을 함께 검증한다.
CREATE TEMPORARY TABLE _quiz_code_snippet_patch_assertion (
    actual_count INT NOT NULL CHECK (actual_count = 1)
);

-- Step 2 / Slot 4: 타이머 인터럽트 상황은 자연어 문제 조건이다.
INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 2
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 설명에 가장 알맞은 상태 전이를 고르시오.'
  AND code_snippet = '// 단일 CPU 환경 가정\n프로세스 P가 현재 CPU에서 실행 중이다.\n타이머 인터럽트가 발생했고,\n운영체제는 P의 실행 정보를 저장한 뒤\n다른 프로세스에게 CPU를 넘긴다.';
DELETE FROM _quiz_code_snippet_patch_assertion;

UPDATE quiz
SET question_text = '단일 CPU 환경에서 CPU를 사용 중인 프로세스 P에 타이머 인터럽트가 발생했다. P는 종료되거나 입출력을 요청하지 않았으며, 운영체제는 P의 실행 정보를 저장한 뒤 다른 프로세스에 CPU를 넘겼다. 이때 P의 상태 전이로 가장 알맞은 것을 고르시오.',
    code_snippet = NULL,
    updated_at = UTC_TIMESTAMP(6)
WHERE step_order = 2
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 설명에 가장 알맞은 상태 전이를 고르시오.'
  AND code_snippet = '// 단일 CPU 환경 가정\n프로세스 P가 현재 CPU에서 실행 중이다.\n타이머 인터럽트가 발생했고,\n운영체제는 P의 실행 정보를 저장한 뒤\n다른 프로세스에게 CPU를 넘긴다.';
SET @updated_quiz_rows = ROW_COUNT();
INSERT INTO _quiz_code_snippet_patch_assertion VALUES (@updated_quiz_rows);
DELETE FROM _quiz_code_snippet_patch_assertion;

INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 2
  AND slot_order = 4
  AND question_text = '단일 CPU 환경에서 CPU를 사용 중인 프로세스 P에 타이머 인터럽트가 발생했다. P는 종료되거나 입출력을 요청하지 않았으며, 운영체제는 P의 실행 정보를 저장한 뒤 다른 프로세스에 CPU를 넘겼다. 이때 P의 상태 전이로 가장 알맞은 것을 고르시오.'
  AND code_snippet IS NULL;
DELETE FROM _quiz_code_snippet_patch_assertion;

-- Step 4 / Slot 4: 우선순위 목록과 가정은 구조화 자연어 문제 조건이다.
INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 4
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 코드 상황에 대한 설명으로 옳은 것을 고르시오.'
  AND code_snippet = '프로세스: P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)\n가정: 숫자가 작을수록 우선순위가 높고, 모두 같은 시각에 준비 상태가 된다.\n스케줄링: 비선점형 우선순위 스케줄링';
DELETE FROM _quiz_code_snippet_patch_assertion;

UPDATE quiz
SET question_text = '세 프로세스 P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)가 모두 같은 시각에 준비 상태가 된다. 숫자가 작을수록 우선순위가 높으며, 비선점형 우선순위 스케줄링을 사용한다. 이 상황에 대한 설명으로 옳은 것을 고르시오.',
    code_snippet = NULL,
    updated_at = UTC_TIMESTAMP(6)
WHERE step_order = 4
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 코드 상황에 대한 설명으로 옳은 것을 고르시오.'
  AND code_snippet = '프로세스: P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)\n가정: 숫자가 작을수록 우선순위가 높고, 모두 같은 시각에 준비 상태가 된다.\n스케줄링: 비선점형 우선순위 스케줄링';
SET @updated_quiz_rows = ROW_COUNT();
INSERT INTO _quiz_code_snippet_patch_assertion VALUES (@updated_quiz_rows);
DELETE FROM _quiz_code_snippet_patch_assertion;

INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 4
  AND slot_order = 4
  AND question_text = '세 프로세스 P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)가 모두 같은 시각에 준비 상태가 된다. 숫자가 작을수록 우선순위가 높으며, 비선점형 우선순위 스케줄링을 사용한다. 이 상황에 대한 설명으로 옳은 것을 고르시오.'
  AND code_snippet IS NULL;
DELETE FROM _quiz_code_snippet_patch_assertion;

-- Step 5 / Slot 4: 프로세스 속성 목록은 실행 흐름이 없는 문제 조건이다.
INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 5
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 상황에서 가장 먼저 CPU를 할당받는 프로세스로 알맞은 것은 무엇인가? 모든 프로세스는 시각 0에 준비 큐에 있으며, 스케줄링은 선점형 우선순위 방식이고 숫자가 작을수록 우선순위가 높다.'
  AND code_snippet = 'Process A: priority=3, burst=5\nProcess B: priority=1, burst=8\nProcess C: priority=2, burst=2\nProcess D: priority=4, burst=1';
DELETE FROM _quiz_code_snippet_patch_assertion;

UPDATE quiz
SET question_text = '프로세스 A(우선순위 3, 버스트 시간 5), B(우선순위 1, 버스트 시간 8), C(우선순위 2, 버스트 시간 2), D(우선순위 4, 버스트 시간 1)가 모두 시각 0에 준비 큐에 있다. 숫자가 작을수록 우선순위가 높은 선점형 우선순위 스케줄링을 사용할 때, 가장 먼저 CPU를 할당받는 프로세스로 알맞은 것을 고르시오.',
    code_snippet = NULL,
    updated_at = UTC_TIMESTAMP(6)
WHERE step_order = 5
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 상황에서 가장 먼저 CPU를 할당받는 프로세스로 알맞은 것은 무엇인가? 모든 프로세스는 시각 0에 준비 큐에 있으며, 스케줄링은 선점형 우선순위 방식이고 숫자가 작을수록 우선순위가 높다.'
  AND code_snippet = 'Process A: priority=3, burst=5\nProcess B: priority=1, burst=8\nProcess C: priority=2, burst=2\nProcess D: priority=4, burst=1';
SET @updated_quiz_rows = ROW_COUNT();
INSERT INTO _quiz_code_snippet_patch_assertion VALUES (@updated_quiz_rows);
DELETE FROM _quiz_code_snippet_patch_assertion;

INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 5
  AND slot_order = 4
  AND question_text = '프로세스 A(우선순위 3, 버스트 시간 5), B(우선순위 1, 버스트 시간 8), C(우선순위 2, 버스트 시간 2), D(우선순위 4, 버스트 시간 1)가 모두 시각 0에 준비 큐에 있다. 숫자가 작을수록 우선순위가 높은 선점형 우선순위 스케줄링을 사용할 때, 가장 먼저 CPU를 할당받는 프로세스로 알맞은 것을 고르시오.'
  AND code_snippet IS NULL;
DELETE FROM _quiz_code_snippet_patch_assertion;

-- Step 10 / Slot 4: 페이지 참조열과 프레임 수는 알고리즘 코드가 아니라 입력 데이터다.
INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 10
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 코드가 페이지 참조열을 순서대로 처리한다고 할 때, LRU 알고리즘의 설명으로 가장 알맞은 것은 무엇인가?'
  AND code_snippet = 'references = [1, 2, 3, 2, 4]\nframes = 3\n# 각 숫자는 페이지 번호를 의미한다.';
DELETE FROM _quiz_code_snippet_patch_assertion;

UPDATE quiz
SET question_text = '페이지 프레임이 3개이고 페이지 참조열이 [1, 2, 3, 2, 4] 순서로 주어졌을 때, LRU 알고리즘의 설명으로 가장 알맞은 것을 고르시오. 각 숫자는 페이지 번호를 의미한다.',
    code_snippet = NULL,
    updated_at = UTC_TIMESTAMP(6)
WHERE step_order = 10
  AND slot_order = 4
  AND type = 'MULTIPLE_CHOICE'
  AND difficulty = 'MEDIUM'
  AND question_text = '다음 코드가 페이지 참조열을 순서대로 처리한다고 할 때, LRU 알고리즘의 설명으로 가장 알맞은 것은 무엇인가?'
  AND code_snippet = 'references = [1, 2, 3, 2, 4]\nframes = 3\n# 각 숫자는 페이지 번호를 의미한다.';
SET @updated_quiz_rows = ROW_COUNT();
INSERT INTO _quiz_code_snippet_patch_assertion VALUES (@updated_quiz_rows);
DELETE FROM _quiz_code_snippet_patch_assertion;

INSERT INTO _quiz_code_snippet_patch_assertion
SELECT COUNT(*)
FROM quiz
WHERE step_order = 10
  AND slot_order = 4
  AND question_text = '페이지 프레임이 3개이고 페이지 참조열이 [1, 2, 3, 2, 4] 순서로 주어졌을 때, LRU 알고리즘의 설명으로 가장 알맞은 것을 고르시오. 각 숫자는 페이지 번호를 의미한다.'
  AND code_snippet IS NULL;
DELETE FROM _quiz_code_snippet_patch_assertion;

DROP TEMPORARY TABLE _quiz_code_snippet_patch_assertion;

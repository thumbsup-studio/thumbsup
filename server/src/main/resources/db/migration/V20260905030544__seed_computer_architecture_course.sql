-- #319: 사람이 승인한 컴퓨터 구조 저작 콘텐츠를 라이브 코스로 발행한다.
-- 로컬 auto-increment ID를 복사하지 않고 LAST_INSERT_ID()로 부모·자식 관계를 연결한다.
-- 저작용 outline/draft/revision/job 및 사용자 데이터는 포함하지 않는다.

CREATE TEMPORARY TABLE computer_architecture_seed_guard (
    id INT NOT NULL PRIMARY KEY
);
INSERT INTO computer_architecture_seed_guard (id) VALUES (1);

-- 같은 제목의 코스가 이미 있으면 PK 충돌로 발행을 중단한다.
INSERT INTO computer_architecture_seed_guard (id)
SELECT 1 WHERE (SELECT COUNT(*) FROM course WHERE title = '컴퓨터 구조') <> 0;

INSERT INTO course (title, category, created_at, updated_at)
VALUES ('컴퓨터 구조', 'CS', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_course_id = LAST_INSERT_ID();

-- STEP 1. 명령이 하드웨어를 지나는 전체 흐름
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (1, '명령이 하드웨어를 지나는 전체 흐름', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '프로그램 실행은 명령과 필요한 데이터를 메모리 계층에서 CPU 쪽으로 가져와 처리하고, 그 결과를 레지스터나 메모리에 남기는 흐름이다. 성능을 판단할 때는 계산 시간과 데이터 이동 대기 시간을 나누어 봐야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '명령과 데이터가 상태 변화를 만든다', '메모리에는 실행할 명령과 처리할 데이터가 놓인다. CPU는 명령을 가져와 뜻을 파악하고, 필요한 피연산자를 내부 데이터 경로로 전달해 연산한 뒤 명령이 지정한 레지스터 또는 메모리에 결과를 기록한다. 다음 명령 위치도 제어 흐름에 맞게 달라진다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '두 값을 더해 저장하는 흐름', '메모리의 두 값을 더하는 프로그램이라면 먼저 명령을 가져오고 필요한 데이터를 CPU 내부 입력까지 전달한다. 연산장치가 값을 더하면 결과가 내부 저장소에 생기며, 명령이 메모리 저장을 요구할 때 그 값을 지정한 위치로 보낸다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '계산과 이동을 구분한다', 'CPU가 빠르게 계산해도 필요한 명령이나 데이터가 늦게 도착하면 실행은 기다린다. 반대로 데이터가 준비되어도 복잡한 연산 자체가 오래 걸릴 수 있다. 관찰된 지연이 어느 구간에서 생겼는지 구분해야 개선 방향을 정할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 1 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'CPU가 명령을 처리한 결과는 언제나 메모리에 기록되므로, 레지스터에만 남는 계산 결과는 없다.', NULL, '계산 명령의 목적지가 레지스터인 경우와 별도의 저장 명령이 있는 경우를 구분해 보세요.', 'X', '계산 결과는 명령이 정한 목적지 레지스터에만 남을 수도 있다.\n메모리 기록은 저장 명령처럼 쓰기를 지시하는 동작이 있을 때 일어나는 [[실행 상태]] 변화다.\n따라서 모든 계산 결과가 언제나 메모리에 기록된다는 주장은 틀리다.', '두 레지스터를 더해 세 번째 레지스터에 넣는 명령은 별도 저장 명령이 없다면 메모리를 바꾸지 않는다.', '레지스터도 프로그램 실행 상태를 보관한다. 계산 결과를 메모리에 남기려면 그 값을 주소로 보내는 쓰기 동작이 따로 필요하다.', 1, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '저장 명령이 없는 계산도 프로그램의 상태를 바꿀 수 있을까?', 1, 1, 'EASY', '계산 결과가 [[레지스터 상태]]에 남거나 다음 명령 위치에 영향을 주면 메모리를 쓰지 않아도 상태는 변한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', 'CPU의 상태에는 메모리뿐 아니라 레지스터 값과 제어 흐름도 포함된다. 메모리 기록은 가능한 상태 변화 중 하나다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '레지스터 상태', '한 시점에 CPU 내부 레지스터들이 보관하는 값들의 모음');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 흐름', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 이동', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '상태 변화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '실행 상태', '프로그램 실행의 현재 위치와 레지스터·메모리 값처럼 이후 동작을 결정하는 정보');

-- STEP 1 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'CPU가 메모리의 값을 이용해 덧셈을 수행할 때, ALU는 메모리 셀 자체를 작업 공간으로 사용하므로 CPU 내부에 피연산자를 보관하거나 전달할 곳이 필요 없다.', NULL, '메모리에서 읽은 비트가 계산 장치의 입력까지 어떤 경로로 도착해야 하는지 살펴보세요.', 'X', 'ALU가 계산하려면 메모리의 값이 CPU 내부 데이터 경로를 통해 입력까지 와야 한다.\n읽어 온 값이나 레지스터 값은 연산에 쓰이는 [[피연산자]]가 된다.\n한 ISA 명령이 메모리 접근과 덧셈을 함께 지시해도 내부의 이동과 계산은 구분할 수 있다.', '메모리 피연산자를 허용하는 덧셈도 저장된 비트를 CPU 쪽으로 전달한 뒤 연산장치가 계산해야 한다.', 'ALU가 멀리 있는 메모리 셀을 자신의 작업 공간처럼 직접 바꾸는 것은 아니다. 값이 내부 입력으로 도착하고 결과가 데이터 경로를 통해 목적지로 전달되어야 한다.', 1, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '한 명령이 메모리 읽기와 덧셈을 함께 지시해도 두 과정의 비용을 나누어 볼 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '메모리에서 비트를 가져오는 일과 그 비트를 계산하는 일은 서로 다른 [[하드웨어 동작]]으로 진행되기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', 'ISA가 하나의 명령으로 보이게 하더라도 내부에서는 데이터를 도착시키고 연산 입력으로 선택한 뒤 계산한다. 각 구간의 지연 원인도 다를 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '하드웨어 동작', '데이터 이동이나 계산처럼 회로가 수행하는 구체적인 처리');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '연산 입력', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 읽기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 쓰기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '피연산자', '산술·논리 연산이 입력으로 사용하는 값');

-- STEP 1 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '한 명령이 메모리 주소 A의 값을 읽어 레지스터 R1에 넣고, 다음 명령이 R1과 R2를 더해 R3에 기록한다. 이때 두 번째 명령 직후의 상태를 가장 정확히 설명한 것은 무엇인가?', NULL, '읽기 단계의 목적지와 덧셈 단계의 목적지를 순서대로 추적해 보세요.', NULL, '첫 명령은 메모리 A의 값을 R1으로 옮긴다.\n다음 명령은 R1과 R2를 입력으로 삼아 R3을 바꾸는 [[데이터 경로]]를 따른다.\n별도 저장 명령이 없으므로 메모리 A의 값은 그대로다.', 'A가 4이고 R2가 3이면 두 번째 명령 뒤 R1은 4, R3은 7이며 A에는 계속 4가 남는다.', '덧셈의 입력 레지스터가 자동으로 지워지거나 메모리가 자동 갱신되지는 않는다. 각 명령이 명시한 목적지만 바뀐다고 추적해야 한다.', 1, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1에는 합이 기록되고 R3은 바뀌지 않으며, 합은 주소 A에도 자동 저장된다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1에는 A에서 읽은 값이 남고 R3에는 R1과 R2의 합이 생기며 A는 바뀌지 않는다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R3에는 합이 생기지만 같은 값이 메모리 A에도 자동으로 덮어써진다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1은 입력으로 사용된 뒤 비워지고 R3에는 합이 생기며 A는 바뀌지 않는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'R3의 결과를 메모리에 오래 남기려면 어떤 동작이 더 필요한가?', 1, 1, 'EASY', 'R3의 값을 지정한 주소로 보내는 [[메모리 쓰기]] 동작이 필요하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '레지스터 값은 CPU 내부 상태다. 프로그램이 결과를 메모리 위치에 보존하려면 저장을 지시해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '메모리 쓰기', 'CPU가 계산한 값을 지정된 메모리 위치에 기록하는 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '목적지 레지스터', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '상태 추적', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명시적 저장', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '데이터 경로', '데이터가 레지스터와 연산장치 같은 하드웨어 요소 사이를 이동하는 길');

-- STEP 1 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '같은 덧셈을 반복하는 두 프로그램을 비교했다. 첫 프로그램은 필요한 값이 CPU 가까이에 준비되어 있고, 둘째 프로그램은 매번 먼 메모리에서 값이 오기를 오래 기다린다. 둘째 프로그램의 성능을 먼저 개선할 때 살펴볼 곳은 어디인가?', NULL, '연산의 종류가 같은데 시간이 달라진 원인이 계산인지 값의 도착인지 구분해 보세요.', NULL, '두 프로그램의 덧셈 작업 자체는 같으므로 연산 종류만으로 차이를 설명하기 어렵다.\n둘째 프로그램은 값이 도착하기 전까지 CPU가 기다리는 [[메모리 지연]]이 크다.\n데이터 배치와 접근 방식처럼 이동 대기를 줄이는 지점을 먼저 살펴봐야 한다.', '연속된 데이터를 차례로 읽도록 바꾸면 가까운 저장 계층에 함께 들어올 가능성이 커져 대기가 줄 수 있다.', '덧셈기의 논리나 결과 저장 형식은 두 프로그램에서 같다. 관찰된 차이는 연산 전에 데이터를 기다리는 구간에서 발생한다.', 1, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '덧셈기의 최대 동작 속도만 높이고 메모리 접근은 그대로 둔다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '데이터의 배치와 메모리 접근 방식', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '사용 가능한 범용 레지스터 수만 늘리고 데이터 배치는 그대로 둔다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '모든 값을 더 큰 자료형으로 바꾸어 한 번에 전송할 데이터 양을 늘린다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'CPU가 메모리를 기다리는 동안 유용한 일을 하지 못한 시간은 어떻게 해석할 수 있을까?', 1, 1, 'MEDIUM', '필요한 값이 준비되지 않아 실행이 멈춘 [[대기 시간]]으로 해석할 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '명령의 계산 시간과 데이터를 기다리는 시간을 나누면 병목의 위치가 선명해진다. 이 구분은 개선 대상을 고를 때 중요하다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '대기 시간', '다음 동작에 필요한 자원이나 데이터가 준비되기를 기다리는 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '병목 진단', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 지역성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU 대기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '메모리 지연', 'CPU가 요청한 명령이나 데이터가 메모리 계층에서 도착할 때까지 걸리는 시간');

-- STEP 1 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'ALU의 계산 시간을 크게 줄였는데도 프로그램 실행 시간은 거의 줄지 않았다. 측정해 보니 CPU가 명령과 데이터가 메모리 통로를 지나오기를 대부분 기다렸다. 이때 전체 속도를 제한하는 현상을 ___이라고 한다.', NULL, '계산 장치보다 명령과 데이터가 오가는 통로가 전체 속도를 제한하는 고전적인 구조 문제를 떠올려 보세요.', NULL, '[[폰 노이만 병목]]은 CPU와 메모리 사이의 전송 한계가 실행 속도를 제한하는 현상이다.\nCPU가 계산을 빨리 끝내도 다음 명령이나 데이터가 늦으면 기다려야 한다.\n저장 계층과 접근 패턴을 개선하는 이유도 이 이동 비용을 줄이기 위해서다.', '반복 계산에 필요한 데이터가 가까운 저장 계층에 없으면 CPU는 매 반복마다 긴 메모리 대기를 겪을 수 있다.', '이 현상은 산술식의 난이도만을 가리키지 않는다. 명령과 데이터가 CPU와 메모리 사이를 이동하는 속도가 전체 처리량을 묶는 상황이다.', 1, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '폰 노이만 병목');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'von Neumann bottleneck');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '가까운 저장 계층은 이 병목을 어떻게 줄이는가?', 1, 1, 'MEDIUM', '자주 쓸 명령과 데이터를 CPU 가까이에 두어 느린 경로를 오가는 [[전송 횟수]]와 대기 시간을 줄인다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '모든 접근을 멀리 있는 메모리까지 보내지 않으면 평균 데이터 도착 시간이 짧아진다. 다만 필요한 값이 가까이에 없으면 다시 먼 경로를 이용한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '전송 횟수', '명령이나 데이터가 하드웨어 계층 사이를 오간 횟수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU-메모리 속도 차이', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 계층', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '전송 병목', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '폰 노이만 병목', '명령과 데이터가 CPU와 메모리 사이의 제한된 경로를 오가면서 생기는 성능 한계');

-- STEP 2. 명령어 집합과 기계어
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (2, '명령어 집합과 기계어', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '명령어 집합 구조는 소프트웨어가 사용할 수 있는 명령과 그 의미를 정의하는 계약이다. 기계어는 이 계약에 따라 명령 종류와 대상을 비트로 표현하므로, 실행 호환성과 소스 코드 이식성을 구분해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', 'ISA는 보이는 동작을 약속한다', 'ISA는 사용할 수 있는 명령, 레지스터, 데이터 형식, 주소 지정 방식과 각 명령의 결과를 정한다. 프로세서 내부 회로는 달라도 같은 ISA 계약을 지키면 같은 기계어 프로그램이 같은 의미로 실행될 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '비트 필드를 읽는 방법', '기계어 명령에는 수행할 연산을 나타내는 opcode와 입력·출력 대상을 나타내는 operand 정보가 들어간다. 해독 회로는 정해진 인코딩 규칙에 따라 각 비트 구간을 나누어 제어 신호를 만든다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '소스와 실행 파일의 이식성은 다르다', '고급 언어 소스는 다른 ISA용 컴파일러로 다시 번역할 수 있지만, 이미 만들어진 기계어는 대상 ISA가 다르면 그대로 실행되지 않는다. 같은 ISA라고 해도 운영체제 규약과 파일 형식 같은 조건을 추가로 확인해야 한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 2 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '한 ISA용으로 만들어진 기계어 실행 파일은 비트열이므로, 명령 인코딩이 다른 ISA의 프로세서에서도 별도 변환 없이 그대로 실행할 수 있다.', NULL, '같은 비트 구간을 서로 다른 해독 규칙으로 읽을 때 생기는 결과를 생각해 보세요.', 'X', '기계어 비트열의 의미는 특정 ISA의 [[명령 인코딩]] 규칙에 묶여 있다.\n다른 ISA는 같은 비트를 다른 명령으로 읽거나 유효한 명령으로 보지 않을 수 있다.\n따라서 대상에 맞춘 재번역이나 호환 계층이 필요하다.', '소스 코드는 다른 대상용 컴파일러로 다시 만들 수 있지만 이미 번역된 실행 파일은 대상 ISA를 확인해야 한다.', '비트로 저장된다는 사실만으로 의미가 공통이 되지는 않는다. 비트를 opcode와 operand로 나누고 해석하는 약속이 ISA마다 다를 수 있다.', 2, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '에뮬레이터는 다른 ISA의 프로그램을 어떻게 실행하게 돕는가?', 1, 1, 'HARD', '원래 명령의 동작을 읽어 현재 시스템에서 같은 효과가 나도록 [[명령 변환]]하거나 해석한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '에뮬레이터는 원래 기계어를 현재 CPU가 그대로 이해한다고 가정하지 않는다. 각 명령의 의미를 중간에서 재현한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '명령 변환', '한 명령 체계의 동작을 다른 명령 체계에서 같은 효과가 나도록 바꾸는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '바이너리 호환성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '재컴파일', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '에뮬레이션', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '명령 인코딩', '명령의 연산과 대상 정보를 정해진 비트 배치로 표현하는 규칙');

-- STEP 2 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '내부 회로가 다른 두 프로세서가 같은 ISA를 구현하고 같은 초기 아키텍처 상태에서 ISA가 정의한 같은 명령을 실행한다면, 소프트웨어가 관찰하는 결과는 그 ISA의 정의와 일치해야 한다.', NULL, '계약이 내부 제작 방법까지 정하는지, 프로그램에 보이는 동작을 정하는지 구분해 보세요.', 'O', 'ISA는 소프트웨어가 관찰하는 명령의 의미와 상태 변화를 정의한다.\n서로 다른 [[마이크로아키텍처]]도 같은 ISA 계약을 구현할 수 있다.\n내부 단계와 속도는 달라도 정의된 명령 결과는 일치해야 한다.', '한 프로세서는 명령을 순서대로 처리하고 다른 프로세서는 내부적으로 겹쳐 처리해도 덧셈 결과와 예외 동작은 ISA 정의를 따라야 한다.', 'ISA가 같다는 말은 내부 회로가 복제되었다는 뜻이 아니다. 소프트웨어에 드러나는 명령의 동작을 같은 규칙으로 제공한다는 뜻이다.', 2, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 ISA를 구현한 프로세서의 성능은 왜 다를 수 있을까?', 1, 1, 'MEDIUM', '같은 명령 의미를 지키면서도 내부 실행 방식과 저장 구조 같은 [[구현 전략]]은 다르게 선택할 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', 'ISA는 결과의 계약을 제공하지만 그 결과를 몇 단계로, 얼마나 겹쳐, 어떤 회로로 만드는지까지 하나로 고정하지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '구현 전략', '같은 외부 동작을 만들기 위해 내부 구조와 처리 방식을 선택하는 방법');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '하드웨어-소프트웨어 계약', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '동일한 명령 의미', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '구현 다양성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '마이크로아키텍처', 'ISA를 실제로 실행하기 위한 프로세서 내부 데이터 경로와 제어 구조');

-- STEP 2 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '고정 길이 기계어에서 앞쪽 비트는 수행할 연산을, 뒤쪽 비트는 입력 레지스터와 결과 레지스터를 나타낸다고 하자. 앞쪽 비트와 뒤쪽 비트의 역할을 올바르게 연결한 것은 무엇인가?', NULL, '무엇을 할지 나타내는 부분과 그 연산이 사용할 대상을 나타내는 부분을 나누어 보세요.', NULL, '명령의 연산 종류를 나타내는 필드는 opcode다.\n연산에 사용할 레지스터나 값 같은 대상 정보는 [[operand]]에 해당한다.\n해독 단계는 인코딩 규칙에 따라 두 역할을 구분한다.', 'ADD 명령의 opcode가 덧셈을 고르고, 레지스터 필드가 더할 값과 결과를 둘 위치를 가리킬 수 있다.', '연산 종류와 연산 대상을 뒤바꾸면 해독 회로가 어떤 동작을 어떤 값에 적용할지 정할 수 없다. 두 필드는 서로 보완하지만 역할이 다르다.', 2, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '앞쪽은 operand 정보, 뒤쪽은 opcode다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '앞쪽과 뒤쪽 모두 수행할 연산 종류만 중복해서 나타낸다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '앞쪽은 opcode, 뒤쪽은 operand 정보다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '앞쪽은 결과 레지스터의 현재 값, 뒤쪽은 연산이 끝난 뒤의 값을 나타낸다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '즉시값은 operand 정보에 어떻게 포함될 수 있을까?', 1, 1, 'MEDIUM', '명령 비트 일부에 계산에 바로 쓸 상수를 넣는 [[즉시값 필드]]로 표현할 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '레지스터 번호 대신 작은 상수를 명령 안에 담으면 별도의 데이터 읽기 없이 그 값을 피연산자로 사용할 수 있다. 표현 가능한 범위는 필드 길이에 제한된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '즉시값 필드', '기계어 명령 안에 직접 포함된 상수를 담는 비트 구간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 필드', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '레지스터 지정', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '해독', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'operand', '명령이 읽거나 쓰는 레지스터·메모리 위치·상수 같은 연산 대상');

-- STEP 2 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '개발팀이 동일한 C 소스 프로그램을 ISA가 다른 두 장치에서 실행하려 한다. 실행 결과의 의미를 유지하면서 준비하는 방법으로 가장 적절한 것은 무엇인가?', NULL, '사람이 작성한 소스와 특정 명령 체계로 이미 번역된 실행 파일을 구분해 보세요.', NULL, '고급 언어 소스는 대상 ISA에 맞는 도구로 다시 번역할 수 있다.\n이런 [[소스 이식성]]은 같은 기계어가 모든 CPU에서 실행된다는 뜻이 아니다.\n대상별 컴파일과 함께 운영체제 인터페이스 같은 조건도 확인해야 한다.', '한 장치용 컴파일러와 다른 장치용 컴파일러가 같은 C 소스를 각 ISA의 명령으로 번역할 수 있다.', '기존 실행 파일의 비트를 복사하거나 파일 이름만 바꾸어도 명령 해석 규칙은 달라지지 않는다. 대상 플랫폼에 맞는 번역이 필요하다.', 2, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '각 장치의 ISA와 환경을 대상으로 소스를 컴파일하고 동작을 시험한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '실행 파일 형식만 같다면 첫 장치의 기계어를 둘째 장치에 그대로 복사한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '라이브러리만 둘째 장치용으로 바꾸고 첫 ISA의 명령 비트는 그대로 둔다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '첫 ISA의 어셈블리 표기 이름만 둘째 ISA의 명령 이름으로 치환한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 ISA용 실행 파일도 운영체제가 다르면 실행되지 않을 수 있는 이유는 무엇인가?', 1, 1, 'HARD', '프로그램이 기대하는 파일 형식과 시스템 호출 같은 [[실행 환경 규약]]도 함께 맞아야 하기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', 'ISA는 CPU 명령 계약이다. 프로그램 적재 방식과 운영체제 서비스 호출 방법은 별도의 계약이므로 바이너리 호환성을 판단할 때 함께 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '실행 환경 규약', '프로그램 형식과 운영체제 서비스 호출처럼 실행 파일이 기대하는 플랫폼 약속');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '교차 컴파일', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '플랫폼 호환성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'ABI', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '소스 이식성', '같은 소스 코드를 다른 대상 환경에 맞게 번역해 사용할 수 있는 성질');

-- STEP 2 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '해독 회로가 기계어의 한 비트 구간을 읽고 덧셈을 수행할지 분기할지를 선택한다. 이처럼 명령이 수행할 연산의 종류를 지정하는 비트 필드를 ___라고 한다.', NULL, '명령의 대상이 아니라 CPU가 수행할 동작의 종류를 고르는 필드입니다.', NULL, '[[opcode]]는 명령이 수행할 연산의 종류를 나타내는 비트 필드다.\n해독 회로는 이 값을 보고 필요한 데이터 경로와 제어 동작을 선택한다.\n나머지 필드는 레지스터 번호나 상수처럼 연산에 필요한 대상을 나타낼 수 있다.', '덧셈과 분기는 서로 다른 opcode로 구분되고, 같은 덧셈 안에서도 operand 필드가 대상 레지스터를 바꿀 수 있다.', '질문은 연산에 사용할 값이나 주소가 아니라 수행할 동작 자체를 식별하는 필드를 묻는다. 대상 정보는 operand 쪽에 담긴다.', 2, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'opcode');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '연산 코드');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'operation code');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'ISA가 불법 인코딩으로 규정한 opcode를 만나면 왜 정상 명령처럼 실행할 수 없는가?', 1, 1, 'MEDIUM', 'ISA에 정해진 동작이 없으므로 프로세서는 이를 [[불법 명령]]으로 처리해야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '해독 회로가 선택할 유효한 명령 의미가 없으면 임의의 계산을 해서는 안 된다. 보통 예외를 일으켜 소프트웨어가 상황을 처리하게 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '불법 명령', '현재 ISA가 유효한 동작으로 정의하지 않은 기계어 인코딩');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 해독', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '제어 신호', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '불법 인코딩', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'opcode', '기계어에서 수행할 연산 종류를 지정하는 비트 필드');

-- STEP 3. 레지스터와 CPU의 실행 상태
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (3, '레지스터와 CPU의 실행 상태', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, 'CPU는 다음 명령 위치, 현재 명령, 계산에 쓰는 값을 서로 다른 종류의 내부 상태로 관리한다. PC와 현재 명령 저장소, 범용 레지스터의 역할을 나누어 추적하면 실행 상태의 변화를 설명할 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '내부 상태마다 역할이 다르다', 'PC는 가져올 명령의 위치를 정하는 데 쓰인다. 가져온 현재 명령은 해독하는 동안 명령 레지스터나 그에 해당하는 내부 저장소에 보관될 수 있다. 범용 레지스터는 계산할 값, 주소, 중간 결과처럼 프로그램이 자주 쓰는 데이터를 담는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '두 명령의 상태를 추적한다', '첫 명령이 값을 R1에 넣고 둘째 명령이 R1에 3을 더해 R2에 쓴다고 하자. 첫 명령의 효과 뒤에는 R1이 바뀌고, 둘째 명령의 효과 뒤에는 R2가 바뀐다. 다음 명령 위치도 순차 실행이나 제어 이동에 맞게 달라진다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '이름보다 역할을 본다', '구체적인 레지스터 이름, 명령 레지스터의 존재 형태, PC 갱신 시점은 ISA와 구현에 따라 다를 수 있다. 중요한 것은 다음 명령 위치, 현재 해독할 명령, 계산 데이터를 맡는 논리적 상태를 구분하는 것이다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 3 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '프로그램 카운터는 CPU가 다음에 가져올 명령의 메모리 위치를 정하는 데 사용되며, 순차 실행이나 분기에 따라 값이 바뀔 수 있다.', NULL, '명령 실행 순서가 이어지거나 다른 위치로 이동할 때 함께 바뀌어야 하는 위치 정보를 살펴보세요.', 'O', '프로그램 카운터는 다음에 가져올 명령의 위치를 나타낸다.\n순차 실행에서는 보통 다음 명령으로 진행하고 분기에서는 [[제어 흐름]]에 따라 다른 위치로 바뀐다.\n이 값을 추적하면 CPU가 어느 명령을 이어서 실행할지 알 수 있다.', '조건 분기를 선택하지 않으면 뒤의 명령으로 진행하고, 선택하면 분기 대상 주소가 다음 위치가 된다.', '프로그램 카운터를 일반 계산 결과나 현재 명령 비트와 혼동하면 실행 순서를 설명할 수 없다. 이 레지스터의 핵심 역할은 명령 위치를 관리하는 것이다.', 3, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '함수 호출에서도 다음 실행 위치를 별도로 보존해야 하는 이유는 무엇인가?', 1, 1, 'MEDIUM', '함수가 끝난 뒤 원래 흐름으로 돌아가려면 호출 다음 위치인 [[복귀 주소]]를 기억해야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '호출은 PC를 함수 시작 위치로 바꾼다. 원래 위치를 잃지 않도록 레지스터나 스택 등에 돌아갈 주소를 저장한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '복귀 주소', '함수 실행을 마친 뒤 이어서 실행할 호출자 쪽 명령의 위치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '순차 실행', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '분기 대상', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 위치', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '제어 흐름', '프로그램의 명령들이 실제로 선택되고 실행되는 순서');

-- STEP 3 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '명령 레지스터를 두는 단순한 CPU 모델에서도 현재 해독 중인 명령 비트는 명령 레지스터가 아니라 프로그램 카운터에 보관된다.', NULL, '위치 정보와 가져온 명령 자체가 각각 어디에 보관되는지 나누어 보세요.', 'X', '프로그램 카운터는 명령 위치를 정하는 데 쓰이며 명령 비트 자체를 담는 역할과 다르다.\n이 모델에서는 가져온 현재 명령이 [[명령 레지스터]]에 보관되어 해독에 사용된다.\n다른 구현은 같은 역할을 파이프라인 레지스터 같은 내부 저장소에 둘 수 있다.', 'PC가 100번지를 가리키면 그 위치에서 읽은 명령 비트는 별도 내부 저장소에서 해독된다. PC를 정확히 언제 갱신하는지는 구현에 따라 다를 수 있다.', '프로그램 카운터는 명령 위치를 정하는 상태이고, 이 단순 모델의 명령 레지스터가 현재 명령 비트를 맡는다. 다른 구현이 별도 명령 레지스터 대신 동등한 내부 저장소를 쓸 수는 있다.', 3, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '현재 명령을 보관하는 내부 저장소의 값은 왜 명령이 진행될 때마다 달라지는가?', 1, 1, 'EASY', '새 명령을 가져올 때마다 해독할 비트가 들어오므로 [[현재 명령]]이 교체된다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '이 단순 모델의 명령 레지스터는 프로그램 전체를 담지 않는다. 그 시점에 해독하고 실행할 한 명령을 붙잡아 두는 역할을 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '현재 명령', 'CPU가 지금 해독하거나 실행하기 위해 보관하고 있는 명령');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 위치', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '현재 명령 보관', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '범용 레지스터', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '명령 레지스터', '단순한 CPU 모델에서 가져온 현재 명령 비트를 해독하는 동안 보관하는 내부 저장소');

-- STEP 3 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'CPU 상태를 관찰했더니 PC에는 다음 명령 주소가, 현재 명령 보관 장소에는 ADD 명령이, R1과 R2에는 더할 값이 들어 있다. ADD를 실행할 때 각 값의 쓰임을 가장 정확히 설명한 것은 무엇인가?', NULL, '실행 순서를 정하는 정보, 할 일을 정하는 정보, 계산 입력을 각각 대응해 보세요.', NULL, 'PC는 다음에 가져올 명령의 위치를 정하는 실행 순서 상태다.\n현재 ADD 비트는 해독되어 수행할 동작을 고르고 R1과 R2는 [[범용 레지스터]] 피연산자를 제공한다.\n실행 결과는 명령이 지정한 목적지 레지스터에 기록된다.', 'ADD R3, R1, R2라면 R1과 R2의 값을 더해 R3에 쓰며 PC는 다음 명령 흐름을 이어 간다.', 'PC를 덧셈 입력으로 쓰거나 현재 명령 비트를 계산 결과로 보는 선택은 역할을 섞는다. 레지스터 이름마다 담은 정보가 실행의 어느 부분에 쓰이는지 구분해야 한다.', 3, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'PC와 현재 명령 비트를 더해 그 결과를 R1과 R2에 모두 쓴다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1이 다음 명령 위치를 정하고 PC는 덧셈의 첫 입력값만 제공한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '현재 명령 보관 장소는 프로그램이 끝날 때까지 같은 ADD 비트를 유지한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'PC는 다음 위치를 정하고, 현재 명령은 동작을 정하며, R1과 R2는 계산값을 제공한다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '목적지 레지스터와 입력 레지스터가 같아도 실행할 수 있을까?', 1, 1, 'MEDIUM', 'ISA가 허용하면 입력을 읽은 뒤 같은 위치에 결과를 쓰는 [[제자리 갱신]]이 가능하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '예를 들어 R1에 R2를 더해 다시 R1에 쓰는 명령은 기존 R1을 읽고 계산 결과로 덮어쓴다. 갱신 전 값이 필요하면 미리 보존해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '제자리 갱신', '입력값이 있던 저장 위치에 계산 결과를 다시 기록하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '레지스터 역할 분리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '피연산자 읽기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '결과 기록', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '범용 레지스터', '계산할 값, 주소, 중간 결과처럼 여러 용도로 사용할 수 있는 CPU 레지스터');

-- STEP 3 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '처음에 R1=5, R2=3이다. 첫 명령은 R1과 R2를 더해 R1에 쓰고, 둘째 명령은 R1을 메모리 주소 A에 저장한다. 두 명령 뒤의 상태는 무엇인가?', NULL, '첫 명령이 기존 값을 어디에 덮어쓰고 둘째 명령이 그때의 값을 어디로 복사하는지 따라가 보세요.', NULL, '첫 명령은 R1과 R2의 값을 읽어 합 8을 만든다.\n목적지가 R1이므로 기존 5는 사라지고 [[레지스터 갱신]] 뒤 R1은 8이 된다.\n둘째 명령은 갱신된 R1의 값 8을 메모리 A에 기록한다.', '입력과 목적지가 같은 명령을 추적할 때는 먼저 입력을 읽고, 계산한 뒤, 마지막에 목적지를 덮어쓴다고 보면 된다.', '저장 명령은 처음의 R1 값을 되돌려 사용하지 않는다. 명령은 순서대로 실행되므로 둘째 명령은 첫 명령이 만든 최신 상태를 읽는다.', 3, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1=5, R2=3이고 메모리 A에는 5가 저장된다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1=8, R2=8이고 메모리 A에는 3이 저장된다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1=5, R2=8이고 메모리 A에는 아무 값도 기록되지 않는다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'R1=8, R2=3이고 메모리 A에는 8이 저장된다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '덮어쓰기 전 R1의 값 5가 나중에도 필요하다면 어떻게 해야 할까?', 1, 1, 'MEDIUM', '계산 전에 다른 레지스터나 메모리에 복사해 [[이전 값]]을 보존해야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '목적지에 새 값을 쓰면 기존 비트는 더 이상 그 위치에서 읽을 수 없다. 이후 계산이 요구하는 값은 덮어쓰기 전에 따로 남겨 둔다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '이전 값', '현재 갱신이 일어나기 전에 저장 위치가 가지고 있던 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 순서', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '덮어쓰기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 저장', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '레지스터 갱신', '명령 실행 결과를 기록해 레지스터의 기존 값을 새 값으로 바꾸는 동작');

-- STEP 3 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '실행 중인 프로그램을 멈췄다가 나중에 이어가기 위해 PC와 필요한 범용 레지스터 값을 묶어 보존한 정보를 ___이라고 한다.', NULL, '작업을 다시 시작할 때 이전 실행 위치와 계산 상태를 복원하는 데 필요한 정보 묶음입니다.', NULL, '[[CPU 문맥]]은 실행을 이어가는 데 필요한 프로세서 상태의 묶음이다.\nPC를 복원하면 중단한 명령 흐름으로 돌아갈 수 있고 필요한 레지스터 값도 되살아난다.\n운영체제는 작업을 바꿀 때 이 상태를 저장하고 나중에 복원할 수 있다.', '한 작업의 PC와 범용 레지스터를 저장한 뒤 다른 작업의 값을 복원하면 CPU가 실행할 작업을 바꿀 수 있다.', '단일 명령 비트나 메모리 주소 하나만 보존해서는 이전 계산 상태를 재현할 수 없다. 실행 위치와 필요한 레지스터 상태를 함께 묶은 정보를 묻는다.', 3, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'CPU 문맥');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '프로세서 문맥');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'CPU context');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'processor context');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '문맥을 저장할 때 모든 메모리 내용을 매번 복사하지 않아도 되는 이유는 무엇인가?', 1, 1, 'HARD', '작업의 메모리는 보통 그대로 두고 CPU에서 바뀌는 [[프로세서 상태]]를 별도로 보존할 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '문맥 교환은 CPU를 다른 작업에 넘기는 데 필요한 상태를 다룬다. 실제로 어떤 항목을 저장하는지는 ISA와 운영체제의 약속에 따라 정해진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '프로세서 상태', '실행 위치와 레지스터 값처럼 CPU가 현재 작업을 이어가는 데 필요한 정보');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '문맥 교환', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '상태 저장', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '작업 재개', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'CPU 문맥', '중단한 실행을 이어가기 위해 저장하는 PC와 필요한 레지스터 상태의 묶음');

-- STEP 4. 인출·해독·실행
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (4, '인출·해독·실행', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '명령 처리는 인출, 해독, 실행이라는 논리적 역할로 나눌 수 있다. 각 단계가 어떤 입력을 받아 무엇을 결정하는지 알면 오류와 대기가 생긴 위치를 더 정확히 찾을 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '세 단계의 질문이 다르다', '인출은 다음 명령 비트를 가져오고, 해독은 그 비트가 요구하는 연산과 대상을 파악한다. 실행은 필요한 값을 사용해 계산, 메모리 접근, 분기 결정, 결과 기록 같은 실제 상태 변화를 수행한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '더하기 명령을 따라간다', 'CPU는 PC가 가리킨 더하기 명령을 메모리에서 가져온다. opcode와 레지스터 필드를 해독한 뒤 지정된 입력값을 읽고 덧셈을 수행해 목적지에 결과를 쓴다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '논리 단계와 실제 시간표는 다를 수 있다', '현대 프로세서는 여러 명령의 단계를 겹치거나 더 잘게 나눌 수 있다. 그래도 인출할 비트, 해석할 의미, 수행할 상태 변화라는 논리적 구분은 명령 흐름을 설명하고 문제를 진단하는 데 유효하다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 4 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '해독 단계는 opcode와 operand를 읽는 즉시 산술 결과까지 목적지 레지스터에 기록하므로, 실행 단계는 명령 처리에 필요하지 않다.', NULL, '무슨 동작을 할지 결정하는 역할과 그 동작으로 실제 상태를 바꾸는 역할을 나누어 보세요.', 'X', '해독은 명령 비트가 뜻하는 연산과 대상을 파악한다.\n실제 계산과 결과 기록은 [[실행 단계]]에서 이루어지는 상태 변화다.\n의미를 알아내는 일만으로 목적지 값이 자동으로 바뀌지는 않는다.', 'ADD를 해독하면 입력과 목적지 레지스터를 알 수 있고, 이후 연산장치가 입력값을 더해 결과를 기록한다.', '명령의 뜻을 정하는 것과 그 뜻대로 회로를 움직여 상태를 바꾸는 것은 구별된다. 해독만 했다면 계산 결과는 아직 만들어지지 않았다.', 4, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '해독 단계에서 operand 정보는 왜 필요한가?', 1, 1, 'EASY', '실행에 사용할 입력과 결과 위치를 고르는 [[대상 지정]]에 필요하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '같은 ADD opcode라도 레지스터 필드에 따라 더할 값과 결과를 둘 곳이 달라진다. 해독은 이 연결을 준비한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '대상 지정', '명령이 읽거나 쓸 레지스터·메모리 위치·상수를 선택하는 일');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'opcode 해독', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '제어 신호', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '상태 변경', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '실행 단계', '해독된 명령에 따라 계산, 메모리 접근, 분기, 결과 기록을 수행하는 처리 역할');

-- STEP 4 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '프로세서가 여러 명령의 처리를 겹쳐 수행하더라도 각 명령에는 명령 비트를 얻고, 의미를 파악하고, 정의된 동작을 수행하는 논리적 역할이 필요하다.', NULL, '실제 회로가 동시에 움직이는 것과 한 명령에 필요한 정보 변환의 순서를 구분해 보세요.', 'O', '실제 프로세서는 여러 명령의 작업을 시간상 겹칠 수 있다.\n그래도 각 명령은 비트를 얻고 의미를 정한 뒤 동작하는 [[논리 단계]]를 거친다.\n단계 구분은 구현의 정확한 클록 수가 아니라 역할을 설명하는 틀이다.', '한 명령이 실행되는 동안 다음 명령을 가져올 수 있지만, 다음 명령도 가져온 비트 없이는 해독할 수 없다.', '겹쳐 처리한다는 사실은 인출·해독·실행의 역할을 없애지 않는다. 서로 다른 명령의 단계가 같은 시점에 진행될 수 있다는 뜻이다.', 4, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '인출·해독·실행의 역할을 나누어 보면 오류 진단에 어떤 도움이 되는가?', 1, 1, 'MEDIUM', '각 역할이 받아야 할 입력과 내야 할 결과를 비교해 [[오류 위치]]를 좁힐 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '명령 비트가 도착하지 않았는지, 비트의 의미를 찾지 못했는지, 계산 결과가 잘못됐는지를 나누면 원인이 있는 구간을 구별하기 쉽다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '오류 위치', '처리 흐름에서 잘못된 입력이나 결과가 처음 나타난 역할 또는 구간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '처리 역할', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '단계별 입력', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '구현 독립적 설명', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '논리 단계', '구현 시간표와 별개로 입력과 책임을 기준으로 나눈 처리 역할');

-- STEP 4 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'CPU가 ''메모리 주소 A의 값을 R1로 읽기'' 명령을 처리한다. 인출·해독·실행의 연결을 가장 적절히 설명한 것은 무엇인가?', NULL, '명령 비트를 얻는 일, 그 비트에서 동작과 대상을 찾는 일, 실제 데이터를 옮기는 일을 차례로 연결해 보세요.', NULL, '인출은 PC가 가리킨 위치에서 명령 비트를 가져온다.\n해독은 읽기 연산과 주소 A, 목적지 R1을 파악하는 [[제어 정보]]를 만든다.\n실행은 A의 데이터를 읽어 R1에 기록해 실제 상태를 바꾼다.', '명령을 가져오지 못하면 읽기라는 뜻을 알 수 없고, 해독만 끝났다면 A의 값은 아직 R1에 들어오지 않았다.', '데이터 A를 읽는 것과 명령 비트를 가져오는 것을 섞으면 단계별 입력이 뒤틀린다. 먼저 명령을 얻고 뜻과 대상을 파악한 뒤 그 동작을 수행한다.', 4, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '명령 비트를 가져오고, 읽기와 대상을 파악한 뒤, A의 값을 R1에 기록한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '주소 A의 데이터를 먼저 가져온 뒤 그 값으로 opcode와 목적지 R1을 정한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '명령을 가져오고 곧바로 A의 값을 R1에 쓴 뒤 마지막에 읽기 명령인지 해독한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '명령을 가져와 읽기 연산만 확인하고 주소와 목적지는 실행 뒤에 결정한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '명령 인출과 데이터 읽기는 모두 메모리에 접근할 수 있는데 무엇이 다른가?', 1, 1, 'MEDIUM', '하나는 실행할 명령 비트를 얻고 다른 하나는 그 명령이 요구한 [[데이터 값]]을 얻는다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '접근하는 저장 장치가 같아 보여도 목적과 주소를 정하는 근거가 다르다. 인출 주소는 명령 흐름에서, 데이터 주소는 해독된 명령과 계산 결과에서 나온다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '데이터 값', '프로그램의 계산 대상이나 결과로 사용되는 비트 정보');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 인출', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 메모리 접근', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '결과 기록', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '제어 정보', '명령이 요구하는 연산과 읽기·쓰기 대상을 회로에 전달하는 선택 정보');

-- STEP 4 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'CPU가 PC가 가리킨 위치에서 명령 비트를 정상적으로 가져왔지만, opcode가 ISA에 정의되지 않아 어떤 동작을 수행할지 정할 수 없었다. 문제가 드러난 논리 단계는 어디인가?', NULL, '비트를 가져오는 데 성공한 뒤 그 비트의 의미를 찾는 역할에 주목하세요.', NULL, '명령 비트 자체는 이미 정상적으로 도착했으므로 인출은 이루어졌다.\nopcode의 의미를 찾지 못한 문제는 [[해독 오류]]에 해당한다.\n정의된 동작이 없으므로 정상 실행으로 넘어가지 않고 예외 처리가 필요하다.', '비트 패턴이 메모리에서 정확히 읽혔어도 ISA 표에 없는 opcode라면 제어 회로는 유효한 연산을 선택할 수 없다.', '데이터가 늦게 도착한 문제나 계산 결과가 잘못된 문제가 아니다. 이미 가져온 명령의 의미를 정하지 못한 지점이 핵심이다.', 4, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '명령 비트를 메모리에서 가져오는 인출 단계', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '정의된 연산으로 데이터 값을 바꾸는 실행 단계', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '명령의 의미를 파악하는 해독 단계', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '완성된 결과를 목적지에 남기는 결과 기록 단계', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '명령 주소가 유효하지 않아 비트 자체를 가져오지 못했다면 어느 단계의 문제인가?', 1, 1, 'MEDIUM', '해독할 명령 비트를 얻기 전 실패했으므로 [[인출 실패]]로 볼 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '단계를 진단할 때는 각 단계가 받을 입력이 준비되었는지 확인한다. 명령 비트가 없으면 opcode 해독도 시작할 수 없다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '인출 실패', '다음에 처리할 명령 비트를 지정된 위치에서 가져오지 못한 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '불법 opcode', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '단계별 진단', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 예외', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '해독 오류', '가져온 명령 비트에서 유효한 연산 의미나 대상을 결정하지 못한 문제');

-- STEP 4 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '프로그램 카운터가 가리키는 메모리 위치에서 다음 명령 비트를 CPU 내부로 가져오는 논리 단계를 ___이라고 한다.', NULL, '명령의 뜻을 분석하기 전에 처리할 비트 자체를 얻는 역할입니다.', NULL, '[[인출]]은 다음에 처리할 명령 비트를 메모리 계층에서 가져오는 단계다.\n가져온 명령은 CPU 내부에 보관되어 뒤의 해독에 사용된다.\n이 단계가 지연되면 뒤의 해독과 실행도 필요한 입력을 기다리게 된다.', 'PC가 200번지를 가리키면 인출은 그 위치의 명령 비트를 요청하고 현재 명령을 보관하는 곳으로 전달한다.', '질문은 가져온 명령의 의미를 푸는 단계나 계산 결과를 만드는 단계를 묻지 않는다. 그보다 앞서 명령 비트를 확보하는 역할이다.', 4, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '인출');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'fetch');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '명령어 인출');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '인출이 늦어지면 실행 장치가 놀 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '처리할 명령 비트가 준비되지 않아 뒤 단계가 기다리는 [[공급 지연]]이 생기기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '실행 장치가 비어 있어도 어떤 연산을 할지 알려 줄 명령이 도착하지 않으면 일을 시작할 수 없다. 명령 공급 속도도 전체 성능에 영향을 준다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '공급 지연', '뒤 단계가 필요로 하는 명령이나 데이터가 제때 전달되지 않아 생기는 대기');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 메모리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'PC 사용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 공급', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '인출', '다음에 처리할 명령 비트를 메모리 계층에서 CPU 내부로 가져오는 과정');

-- STEP 5. ALU, 분기와 주소 계산
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (5, 'ALU, 분기와 주소 계산', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, 'ALU는 레지스터에서 받은 값으로 산술·논리 연산과 비교에 필요한 결과를 만든다. 분기는 비교 결과로 다음 명령 위치를 고르고, 메모리 명령은 기준값과 변위로 실제 접근 주소를 계산한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', 'ALU는 값과 주소를 계산한다', 'ALU는 덧셈, 뺄셈, AND 같은 연산을 수행한다. ALU나 별도 비교 회로는 두 값의 관계를 나타내는 결과를 만들 수 있고, 주소 계산 회로는 기준 레지스터와 명령의 변위를 더해 접근할 위치를 만든다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '조건 분기와 메모리 읽기', '두 레지스터가 같은지 비교한 결과나 조건 상태는 분기 여부를 결정하는 데 쓰인다. 기준 주소가 1000이고 변위가 12인 읽기 명령은 1012를 계산한 뒤 그 메모리 위치에 접근한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '주소와 그 위치의 값을 구분한다', '주소 계산 결과는 어느 메모리 위치에 접근할지를 나타낼 뿐 그 위치에 저장된 데이터와 같지 않다. 또한 ALU가 비교 결과를 만들더라도 다음 PC를 실제로 고르는 제어 동작과 함께해야 분기가 완성된다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 5 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '기준 레지스터 값에 변위를 더해 주소 1024를 계산했다면, 메모리 1024번지에 저장된 데이터 값도 항상 1024다.', NULL, '접근할 위치를 나타내는 숫자와 그 위치에서 읽히는 내용을 서로 분리해 보세요.', 'X', '주소 계산 결과는 메모리에서 접근할 위치를 나타낸다.\n그 위치에 실제로 저장된 [[메모리 데이터]]는 주소 숫자와 독립적이다.\n주소를 계산한 뒤 별도의 읽기 동작을 해야 저장된 값을 얻을 수 있다.', '1024번지에는 7이나 문자 코드처럼 프로그램이 저장한 어떤 비트값도 들어 있을 수 있다.', '주소와 데이터를 같은 숫자로 보는 혼동이다. 건물의 번지와 그 안의 물건이 다르듯 메모리 위치 번호와 그 위치의 내용은 구별된다.', 5, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '주소를 계산한 뒤에도 메모리 읽기 시간이 필요한 이유는 무엇인가?', 1, 1, 'MEDIUM', '주소 계산 회로가 만든 위치를 메모리 계층에 요청하고 그곳의 비트를 받는 [[접근 과정]]이 별도로 필요하기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '주소 계산으로 얻은 것은 위치 정보다. 데이터는 캐시나 메모리에서 찾아 CPU 쪽으로 전달되어야 실제 피연산자로 쓸 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '접근 과정', '계산한 주소를 저장 계층에 보내고 해당 위치의 데이터를 읽거나 쓰는 절차');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '주소와 값 구분', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 읽기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '기준 주소', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '메모리 데이터', '특정 메모리 주소가 가리키는 저장 공간에 들어 있는 실제 비트값');

-- STEP 5 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'ALU는 레지스터에서 받은 값의 덧셈이나 AND 같은 연산을 수행할 수 있고, 그 결과를 목적지 레지스터에 기록하는 실행 흐름에 참여한다.', NULL, 'CPU 내부에서 입력값을 실제 계산 결과로 바꾸는 장치의 역할을 살펴보세요.', 'O', 'ALU는 레지스터에서 전달된 값을 이용해 산술과 논리 연산을 수행한다.\n연산 결과는 데이터 경로를 통해 [[목적지 레지스터]]에 기록될 수 있다.\n어떤 연산과 목적지를 쓸지는 해독된 명령의 제어 정보가 정한다.', 'R1과 R2를 더해 R3에 쓰는 명령은 두 입력을 ALU로 보내고 합을 R3에 기록한다.', 'ALU를 메모리 전체나 명령 저장소와 같은 것으로 보면 실행 흐름이 흐려진다. ALU의 중심 역할은 전달받은 비트값에 정해진 계산을 적용하는 것이다.', 5, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'AND 연산은 산술 덧셈과 달리 어떤 용도로 쓸 수 있는가?', 1, 1, 'MEDIUM', '원하는 비트만 남기거나 지우는 [[비트 마스크]] 처리에 사용할 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', 'AND는 두 입력에서 모두 1인 비트만 1로 만든다. 특정 위치만 1인 값을 함께 사용하면 그 위치의 비트만 골라낼 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '비트 마스크', '비트 연산에서 특정 위치를 선택하거나 변경하기 위해 사용하는 비트 패턴');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '산술 연산', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '논리 연산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '결과 기록', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '목적지 레지스터', '명령의 계산 결과가 기록되도록 지정된 레지스터');

-- STEP 5 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '메모리 읽기 명령이 기준 레지스터 R2의 값 1000과 변위 24를 사용한다. 단순한 기준+변위 주소 지정에서 CPU가 먼저 접근할 메모리 위치는 어디인가?', NULL, '기준이 되는 위치에서 명령에 적힌 거리만큼 이동한 값을 계산해 보세요.', NULL, '[[기준+변위]] 방식은 레지스터의 기준값과 명령 안의 변위를 더한다.\n1000과 24를 더한 1024가 이번 접근의 실제 위치가 된다.\n그 주소를 메모리 계층에 보내야 실제 데이터를 읽을 수 있다.', '배열의 시작 위치를 기준 레지스터에 두고 원소의 위치 차이를 변위로 주는 방식으로 사용할 수 있다.', '기준값이나 변위 중 하나만 주소로 쓰는 것이 아니다. 명령이 지정한 주소 계산 규칙을 적용한 결과가 실제 접근 위치가 된다.', 5, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1000번지', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '24번지', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1024번지', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '976번지', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '배열 접근에서 변위는 무엇을 나타낼 수 있는가?', 1, 1, 'MEDIUM', '배열 시작 주소에서 원하는 원소까지의 [[바이트 거리]]를 나타낼 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '원소 크기와 인덱스를 이용해 시작점에서 떨어진 거리를 계산할 수 있다. 이 거리를 기준 주소에 더하면 원소의 위치를 얻는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '바이트 거리', '한 메모리 위치에서 다른 위치까지 바이트 단위로 떨어진 양');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '기준+변위 주소 지정', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '배열 주소', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 접근', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '기준+변위', '레지스터의 기준 주소와 명령에 포함된 거리 값을 더해 접근 위치를 정하는 방식');

-- STEP 5 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'R1과 R2를 비교한 뒤 값이 같으면 주소 T로 분기하고, 다르면 순서상 다음 명령을 실행한다. 이 단순한 CPU에서 ALU가 비교 결과를 만든다고 할 때 R1=9, R2=9이면 필요한 협력은 무엇인가?', NULL, '두 값의 관계를 계산하는 일과 그 결과로 다음 명령 위치를 고르는 일을 연결해 보세요.', NULL, 'ALU는 R1과 R2의 관계를 판단할 비교 결과를 만든다.\n두 값이 같다는 [[조건 결과]]를 제어 장치가 사용해 다음 PC로 T를 선택한다.\n비교 계산과 PC 선택이 이어져 조건 분기가 완성된다.', '두 값을 빼서 결과가 0인지 확인하는 방식이라면 9-9가 0이므로 같음 조건을 만족한다.', 'ALU가 비교만 하거나 PC가 입력값을 직접 더하는 것만으로는 조건 분기가 되지 않는다. 비교 결과가 다음 위치 선택으로 이어져야 한다.', 5, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '제어 장치가 비교 결과와 관계없이 항상 T를 다음 PC로 선택한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'ALU가 두 값을 비교한 뒤 분기 주소 T를 R1의 데이터 결과로 기록한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'ALU가 비교를 위해 R1과 R2를 모두 0으로 바꾸고 PC는 순차 주소만 유지한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'ALU가 같음 조건을 만들고 제어 장치가 PC의 다음 값으로 T를 선택한다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '조건을 만족하지 않았다면 PC는 보통 어떤 위치를 선택하는가?', 1, 1, 'EASY', '분기 대상 대신 원래 실행 순서의 다음 명령인 [[순차 주소]]를 선택한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '조건 분기는 두 후보 중 다음 실행 위치를 고른다. 하나는 분기 대상이고 다른 하나는 분기하지 않을 때 이어지는 위치다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '순차 주소', '분기가 선택되지 않을 때 원래 명령 순서대로 이어지는 다음 위치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '비교 연산', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '조건 분기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'PC 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '조건 결과', '비교나 연산 뒤 특정 관계가 성립하는지를 제어 흐름에 전달하는 정보');

-- STEP 5 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '기준+변위 주소 지정에서 명령 안에 들어 있으며, 기준 레지스터의 주소에서 얼마나 떨어진 위치에 접근할지를 나타내는 값은 ___이다.', NULL, '기준 주소에 더해 최종 접근 위치를 만드는 명령 내부의 거리 값입니다.', NULL, '[[변위]]는 기준 주소에서 떨어진 거리를 나타내는 명령의 주소 요소다.\n기준값과 변위를 더해 실제 메모리 접근에 사용할 주소를 계산할 수 있다.\n변위의 비트 수와 부호 해석은 ISA의 인코딩 규칙에 따라 달라진다.', '기준값 2000에 변위 8을 더하는 방식이라면 최종 접근 위치는 2008이 된다.', '최종 접근 주소나 그 위치에 든 데이터가 아니라 기준 주소에 더하는 거리 값을 묻는다. 이 값은 명령의 주소 지정 필드에 담길 수 있다.', 5, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '변위');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'displacement');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 기준 레지스터에 서로 다른 변위를 사용하면 어떤 장점이 있는가?', 1, 1, 'HARD', '기준값을 다시 만들지 않고 주변 원소나 필드에 접근하는 [[기준 주소 재사용]]이 가능하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '배열이나 구조체처럼 가까이 놓인 데이터는 공통 시작 위치와 서로 다른 거리 값으로 표현할 수 있다. 표현 가능한 거리 범위는 명령 형식에 제한된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '기준 주소 재사용', '하나의 기준 주소에 여러 거리 값을 적용해 주변 데이터 위치를 계산하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '주소 지정 필드', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '상대 위치 계산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '유효 주소', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '변위', '기준 주소에서 접근할 위치까지 떨어진 거리를 나타내는 값');

-- STEP 6. CPU 성능을 읽는 기준
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (6, 'CPU 성능을 읽는 기준', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, 'CPU 성능은 클록 주파수 하나가 아니라 프로그램이 실행한 명령어 수, 명령어당 평균 클록 수, 한 클록의 길이가 함께 결정한다. 같은 일을 끝내는 데 걸린 실행 시간을 계산해야 공정하게 비교할 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '세 항을 곱해 실행 시간을 구한다', 'CPU 실행 시간은 명령어 수 × 평균 CPI × 클록 주기로 볼 수 있다. 명령어 수는 실제로 몇 개를 실행했는지, 평균 CPI는 명령어 하나에 평균 몇 클록이 들었는지, 클록 주기는 한 클록이 몇 초인지 나타낸다. 어느 한 항이 작아져도 다른 항이 커지면 전체 시간은 줄지 않을 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '같은 워크로드를 두 CPU에서 비교한다', 'CPU A가 100개 명령어를 평균 1클록에, 2ns 클록 주기로 실행하면 200ns가 걸린다. CPU B가 같은 일을 100개 명령어, 평균 2클록, 1ns 주기로 실행해도 200ns다. B의 클록 주파수는 더 높지만 이 워크로드의 실행 시간은 같다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '비교 대상과 측정 범위를 맞춘다', '서로 다른 프로그램이나 입력을 실행한 수치끼리는 곧바로 비교하기 어렵다. 같은 결과를 만드는 동일한 워크로드인지 먼저 확인하고, CPU 시간과 입출력 대기까지 포함한 전체 경과 시간도 구분해야 한다. 구현체별 순간 최대 주파수만으로 실제 성능을 단정하지 않는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 6 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '같은 워크로드에서 CPU A는 명령어 100개, 평균 CPI 1, 클록 주기 2ns이고 CPU B는 명령어 100개, 평균 CPI 2, 클록 주기 1ns이다. 두 CPU의 실행 시간은 모두 200ns이다.', NULL, '명령어 수와 명령어당 클록 수와 한 클록의 길이를 차례로 곱해 보세요.', 'O', '[[실행 시간]]은 명령어 수 × 평균 CPI × 클록 주기로 계산한다.\nCPU A는 100 × 1 × 2ns이고 CPU B는 100 × 2 × 1ns이다.\n두 계산 모두 200ns이므로 이 워크로드에서는 걸린 시간이 같다.', 'CPU B는 한 클록이 더 짧지만 명령어마다 평균 두 클록을 쓰므로 짧아진 주기의 이점이 상쇄된다.', '클록 주기만 비교하면 CPU B가 더 빠르다고 오해할 수 있다. 실제 완료 시간에는 평균 CPI도 함께 곱해진다.', 6, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '클록 주파수가 두 배가 되면 클록 주기는 어떻게 변할까?', 1, 1, 'EASY', '주파수와 [[클록 주기]]는 서로 역수 관계이므로 주파수가 두 배면 주기는 절반이 된다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '주파수는 1초에 반복되는 클록 수이고 주기는 클록 한 번에 걸리는 시간이다. 하나가 커지면 다른 하나는 같은 비율로 작아진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '계산 예', 'TEXT', '1GHz에서는 한 클록이 1ns이고 2GHz에서는 한 클록이 0.5ns다. 단, 실제 실행 시간은 명령어 수와 평균 CPI도 함께 봐야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '클록 주기', 'CPU 클록이 한 번 진행되는 데 걸리는 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '성능식', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '클록 주기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '동일 워크로드 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '실행 시간', 'CPU가 주어진 프로그램 또는 워크로드를 끝내는 데 실제로 사용한 시간');

-- STEP 6 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '같은 프로그램을 실행할 때 CPU X의 클록 주파수가 CPU Y보다 높다면, 실행 명령어 수와 평균 CPI가 어떻게 달라도 CPU X가 항상 더 빨리 끝난다.', NULL, '한 클록이 짧아지는 이점이 나머지 두 항의 변화로 상쇄될 수 있는지 생각해 보세요.', 'X', '[[클록 주파수]]가 높으면 한 클록의 시간은 짧아지지만 전체 성능이 자동으로 정해지지는 않는다.\n프로그램이 실행하는 명령어 수와 각 명령어에 필요한 평균 클록 수도 실행 시간에 영향을 준다.\n세 항을 같은 워크로드에서 함께 비교해야 어느 CPU가 먼저 끝나는지 판단할 수 있다.', '더 높은 주파수의 CPU가 같은 일을 더 많은 명령어나 더 큰 평균 CPI로 처리하면 전체 실행 시간이 오히려 길 수 있다.', '주파수는 성능식의 한 요소일 뿐이다. 다른 구조나 명령어 집합을 쓰는 CPU를 주파수 수치 하나로 순위를 매길 수 없다.', 6, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '평균 CPI가 프로그램마다 달라질 수 있는 이유는 무엇일까?', 1, 1, 'MEDIUM', '프로그램마다 실행하는 명령어 종류와 비율인 [[명령어 혼합]]이 다르고 각 종류의 소요 클록도 다를 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '빠르게 처리되는 명령어와 오래 걸리는 명령어가 섞이는 비율에 따라 전체 평균이 달라진다. 같은 CPU에서도 프로그램별 평균 CPI가 같다고 가정하면 안 된다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '비교 기준', 'TEXT', 'CPU를 비교할 때는 관심 있는 프로그램과 대표 입력을 실제 워크로드로 삼는 편이 좋다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '명령어 혼합', '한 프로그램에서 실행되는 여러 종류의 명령어와 각 종류가 차지하는 비율');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '클록 주파수', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '평균 CPI', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '워크로드 의존성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '클록 주파수', '1초 동안 CPU 클록이 반복되는 횟수');

-- STEP 6 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '같은 결과를 만드는 프로그램을 비교한다. CPU A는 명령어 120개, 평균 CPI 1.5, 클록 주기 1ns이고 CPU B는 명령어 100개, 평균 CPI 2, 클록 주기 0.8ns이다. 가장 정확한 판단은 무엇인가?', NULL, '각 CPU에 대해 세 수를 모두 곱한 뒤 더 작은 완료 시간을 찾으세요.', NULL, 'CPU A의 시간은 120 × 1.5 × 1ns로 180ns이다.\nCPU B의 시간은 100 × 2 × 0.8ns로 160ns이다.\nB의 [[평균 CPI]]가 더 커도 다른 두 항까지 곱한 실행 시간은 B가 더 짧다.', '두 CPU가 같은 결과를 만들므로 180ns와 160ns를 비교할 수 있고, B가 A보다 20ns 먼저 끝난다.', '평균 CPI나 클록 주기 중 하나만 골라 비교하면 다른 항의 영향을 빠뜨린다. 세 항을 모두 계산해야 한다.', 6, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU A의 평균 CPI가 더 작으므로 계산 없이 CPU A가 더 빠르다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU A가 180ns, CPU B가 160ns이므로 CPU B가 더 빨리 끝난다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU B의 실행 시간은 200ns이므로 CPU A가 20ns 더 빠르다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '클록 주기가 다르면 같은 워크로드여도 실행 시간을 비교할 수 없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'CPU 비교에서 동일한 워크로드를 사용해야 하는 이유는 무엇일까?', 1, 1, 'EASY', '같은 결과와 입력을 요구하는 [[비교 기준]]을 맞춰야 실행 시간 차이를 CPU와 실행 방식의 차이로 해석할 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '한쪽이 더 작은 입력이나 덜 완전한 작업을 수행한다면 시간이 짧아도 성능이 좋다고 말하기 어렵다. 먼저 수행한 일의 양과 결과를 맞춰야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '측정 팁', 'TEXT', '관심 있는 실제 입력을 여러 번 측정하고 준비 시간이나 입출력 포함 여부도 같게 두면 비교가 더 공정하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '비교 기준', '두 측정값을 공정하게 견주기 위해 동일하게 맞추는 작업과 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU 시간 계산', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '성능 비교', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'CPI 해석', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '평균 CPI', '실행한 명령어 하나당 평균적으로 사용한 클록 수');

-- STEP 6 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '한 프로그램은 원래 명령어 100개, 평균 CPI 2, 클록 주기 1ns로 실행된다. 새 컴파일 결과는 명령어 수가 80개로 줄지만 평균 CPI가 2.2가 되고 클록 주기는 같다. 가장 정확한 평가는 무엇인가?', NULL, '감소한 항과 증가한 항을 따로 보지 말고 변경 전후의 곱을 비교하세요.', NULL, '변경 전 실행 시간은 100 × 2 × 1ns로 200ns이다.\n변경 후 [[명령어 수]]는 80개이고 시간은 80 × 2.2 × 1ns로 176ns이다.\n평균 CPI는 늘었지만 전체 실행 시간은 24ns, 즉 12% 줄었다.', '최적화가 한 항을 나쁘게 만들더라도 다른 항을 더 크게 줄이면 최종 실행 시간은 개선될 수 있다.', '명령어 수만 보고 20% 감소라고 하거나 평균 CPI만 보고 악화라고 하면 전체 곱을 놓친다. 기준 시간 200ns에서 24ns가 줄었으므로 실행 시간 감소율은 12%다.', 6, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '변경 후 176ns이므로 실행 시간이 12% 줄어든다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '변경 후 160ns이므로 명령어 수와 같은 비율인 20%만큼 빨라진다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '평균 CPI가 늘었으므로 변경 후 220ns가 되어 느려진다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '클록 주기가 같으므로 변경 전후 모두 200ns이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '명령어 수를 줄이는 최적화가 항상 실행 시간을 줄이지는 않는 이유는 무엇일까?', 1, 1, 'MEDIUM', '명령어 수 감소와 함께 평균 CPI나 클록 주기가 불리하게 바뀌는 [[절충 관계]]가 생길 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '더 복잡한 명령어로 여러 단계를 합치면 실행 명령어는 줄어도 한 명령어에 필요한 클록이 늘 수 있다. 최종 곱으로 이득을 확인해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '검토 방법', 'TEXT', '변경 전후에 같은 입력과 결과를 사용하고 세 항을 각각 측정한 뒤 전체 실행 시간을 비교한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '절충 관계', '한 요소를 개선할 때 다른 요소가 나빠질 수 있어 함께 판단해야 하는 관계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '컴파일러 최적화', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '실행 시간 감소율', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '항 사이 절충', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '명령어 수', '한 프로그램 실행에서 CPU가 실제로 처리한 명령어의 총개수');

-- STEP 6 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '같은 일을 하는 프로그램의 실행 시간이 개선 전 240ns에서 개선 후 160ns로 줄었다. 개선 전 시간을 개선 후 시간으로 나눈 1.5 같은 배수 지표를 ___라고 한다.', NULL, '기존 완료 시간을 새 완료 시간으로 나누어 몇 배의 성능을 얻었는지 나타내는 지표를 떠올려 보세요.', NULL, '[[성능 향상비]]는 개선 전 실행 시간을 개선 후 실행 시간으로 나눈 값이다.\n240ns를 160ns로 나누면 1.5이므로 같은 일을 1.5배의 성능으로 끝낸다.\n배수와 시간 감소율은 기준이 달라 같은 숫자로 표현되지 않는다.', '실행 시간이 절반이 되면 성능 향상비는 2다. 이는 같은 시간에 같은 작업을 두 배 수행할 수 있다는 뜻이다.', '160을 240으로 나눈 0.67은 새 시간이 기존 시간의 어느 정도인지를 나타낸다. 성능 향상비는 기존 시간을 새 시간으로 나누어 계산한다.', 6, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '성능 향상비');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'speedup');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '스피드업');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '성능이 1.5배가 되었을 때 실행 시간 감소율이 50%가 아닌 이유는 무엇일까?', 1, 1, 'MEDIUM', '새 시간은 기존 시간의 1/1.5이므로 [[시간 감소율]]은 약 33.3%다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '성능 배수는 시간의 역수 관계를 사용한다. 240ns에서 160ns로 줄면 80ns가 감소했고, 80을 기준 240으로 나누면 약 0.333이다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '구분', 'TEXT', '1.5배의 성능 향상과 실행 시간 50% 감소를 같은 표현으로 보면 안 된다. 실행 시간이 50% 줄 때의 성능 향상비가 2다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '시간 감소율', '기존 실행 시간을 기준으로 줄어든 시간이 차지하는 비율');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '성능 배수', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '실행 시간 감소율', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '역수 관계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '성능 향상비', '같은 작업의 개선 전 실행 시간을 개선 후 실행 시간으로 나눈 성능 배수');

-- STEP 7. 주기억장치와 주소
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (7, '주기억장치와 주소', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '메모리 주소는 데이터 그 자체가 아니라 데이터가 놓인 위치를 가리킨다. 바이트 주소 방식에서는 여러 바이트짜리 값이 여러 주소를 차지하며, 연속 배치와 정렬 규칙을 알면 실제 접근 주소를 계산할 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '주소는 위치이고 값은 그 위치의 내용이다', '바이트 주소 방식에서는 주소 하나가 한 바이트 위치를 구분한다. 주소 100에 값 7이 저장되어 있다는 말은 위치 100의 내용이 7이라는 뜻이다. 값 7이 다음에 접근할 주소라는 뜻은 아니며, 주소를 데이터로 해석하려면 포인터처럼 별도의 규칙이 필요하다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '연속 배열의 원소 주소를 계산한다', '4바이트 원소가 주소 1000부터 빈틈없이 놓이면 인덱스 0은 1000~1003, 인덱스 1은 1004~1007을 사용한다. 인덱스 i의 시작 주소는 1000 + i × 4로 구할 수 있다. 연속 배치는 다음 원소가 일정한 거리 뒤에 있다는 뜻이다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '정렬과 바이트 순서를 섞지 않는다', '정렬은 여러 바이트짜리 값의 시작 주소를 특정 배수에 맞추는 규칙이다. 필요하면 값 사이에 사용하지 않는 바이트가 들어가므로 모든 필드가 항상 빈틈없이 이어지지는 않는다. 엔디언은 한 값의 바이트 순서를 정하지만 그 값이 차지하는 주소 범위 자체를 바꾸지는 않는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 7 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '메모리 주소 300에 숫자 900이 저장되어 있으면, CPU가 주소 300을 읽은 직후에는 별도 명령이 없어도 자동으로 주소 900을 다시 읽는다.', NULL, '읽을 위치를 나타내는 수와 그 위치에서 꺼낸 데이터가 같은 역할인지 구분해 보세요.', 'X', '[[주소]] 300은 읽을 위치를 지정하고 숫자 900은 그 위치에 저장된 값이다.\n메모리 읽기는 지정된 위치의 값을 반환할 뿐 그 값을 다음 주소로 자동 사용하지 않는다.\n900을 주소로 다시 사용하려면 포인터 역참조 같은 명시적인 접근이 필요하다.', 'load 300의 결과가 900이어도 다음 명령이 load 900을 요청하지 않으면 주소 900의 내용은 읽지 않는다.', '주소와 그 주소에 든 값을 같은 것으로 보면 접근 흐름을 잘못 추적하게 된다. 값이 주소로 쓰이는지는 명령과 자료형의 의미가 정한다.', 7, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '메모리에 저장된 숫자를 다른 위치를 가리키는 주소로 사용할 때 어떤 연산이 필요한가?', 1, 1, 'MEDIUM', '저장된 주소를 따라가 그 위치의 값을 읽는 [[역참조]] 연산이 필요하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '포인터 변수 자체도 메모리에 놓인 값이지만 그 값은 다른 메모리 위치를 나타내도록 해석된다. 역참조를 해야 가리키는 위치의 내용에 접근한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '주의', 'TEXT', '모든 정수를 임의로 주소로 사용할 수 있는 것은 아니다. 유효한 범위와 접근 권한을 만족해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '역참조', '포인터에 저장된 주소를 따라가 그 위치의 데이터에 접근하는 연산');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '주소와 값', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 읽기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '포인터', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '주소', '메모리에서 특정 저장 위치를 구분하는 번호');

-- STEP 7 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '바이트 주소를 사용하는 메모리에서 주소 200부터 4바이트 정수가 연속으로 저장되면 그 값은 주소 200, 201, 202, 203의 네 바이트 위치를 차지한다.', NULL, '주소 하나가 구분하는 저장 단위와 값 전체의 바이트 크기를 함께 보세요.', 'O', '[[바이트 주소 방식]]에서는 서로 다른 주소 하나가 한 바이트 위치를 가리킨다.\n4바이트 값이 주소 200에서 시작하면 200부터 203까지 네 위치를 사용한다.\n다음 바이트는 앞 주소에 1을 더한 위치에 연속해서 놓인다.', '이 값 바로 뒤에 빈틈없이 다른 4바이트 값이 놓인다면 두 번째 값의 시작 주소는 204가 된다.', '주소 200 하나가 4바이트 전체를 뜻한다고 생각하면 실제 바이트 범위를 놓친다. 시작 주소와 값의 크기로 마지막 주소를 계산해야 한다.', 7, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '4바이트 값이 주소 200부터 시작할 때 마지막 주소가 204가 아닌 이유는 무엇일까?', 1, 1, 'EASY', '시작 위치를 이미 한 바이트로 세므로 [[주소 범위]]는 시작 주소부터 크기에서 1을 뺀 주소까지다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '200, 201, 202, 203을 세면 네 위치다. 204까지 포함하면 다섯 바이트가 되어 값의 크기와 맞지 않는다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '계산 규칙', 'TEXT', '크기가 N바이트라면 마지막 주소는 시작 주소 + N - 1로 구한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '주소 범위', '한 데이터가 차지하는 시작 주소부터 마지막 주소까지의 위치 구간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '바이트 단위 주소', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 크기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '연속 주소 범위', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '바이트 주소 방식', '주소 하나가 메모리의 한 바이트 위치를 구분하는 방식');

-- STEP 7 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '4바이트 정수 배열의 첫 원소가 주소 1000에서 시작하고 원소 사이에 빈틈이 없다. 인덱스는 0부터 시작할 때 array[3]의 시작 주소는 어디인가?', NULL, '첫 위치에서 원소 세 칸만큼 이동하며 한 칸의 크기가 몇 바이트인지 적용하세요.', NULL, '배열의 [[연속 배치]]에서는 각 원소의 시작 주소 간격이 원소 크기와 같다.\n인덱스 3까지 이동하는 거리는 3 × 4바이트로 12바이트다.\n기준 주소 1000에 12를 더하면 시작 주소는 1012다.', 'array[0], array[1], array[2], array[3]의 시작 주소는 차례로 1000, 1004, 1008, 1012가 된다.', '인덱스를 바이트 수처럼 바로 더하거나 세 번째라는 말과 인덱스 3을 혼동하면 주소가 어긋난다. 인덱스에 원소 크기를 곱해야 한다.', 7, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1003', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1008', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1016', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1012', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 배열에서 array[i]의 시작 주소를 일반식으로 어떻게 나타낼 수 있을까?', 1, 1, 'MEDIUM', '기준 주소에 i × 원소 크기로 구한 [[바이트 오프셋]]을 더한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '인덱스는 원소 단위의 이동 횟수다. 메모리 주소는 바이트 단위이므로 원소 크기를 곱해 바이트 거리로 바꿔야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '예시', 'TEXT', '8바이트 원소의 인덱스 5라면 기준 주소에서 40바이트 떨어진 곳에서 시작한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '바이트 오프셋', '기준 주소에서 몇 바이트 떨어졌는지를 나타내는 거리');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '배열 주소 계산', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '0 기반 인덱스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '원소 크기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '연속 배치', '배열 원소가 메모리에서 일정한 간격으로 이어져 놓이는 배치 방식');

-- STEP 7 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '어떤 시스템이 4바이트 정수의 시작 주소를 4의 배수로 맞추도록 요구한다. 앞 데이터가 주소 1000과 1001을 사용했고 그 뒤에 4바이트 정수를 놓으려 한다. 요구를 만족하는 가장 이른 시작 주소와 설명은 무엇인가?', NULL, '사용 가능한 첫 위치보다 크거나 같으면서 지정된 크기의 배수가 되는 가장 작은 주소를 찾으세요.', NULL, '앞 데이터 다음의 첫 빈 주소는 1002지만 1002는 4의 배수가 아니다.\n[[정렬]] 요구를 만족하는 다음 주소는 4의 배수인 1004다.\n따라서 1002와 1003을 비워 두고 정수를 1004에서 시작할 수 있다.', '정수는 1004~1007을 차지한다. 비워 둔 두 바이트는 값의 일부가 아니라 시작 위치를 맞추기 위한 공간이다.', '1002는 바로 다음 빈 주소지만 정렬 조건을 만족하지 않는다. 1005는 마지막 주소에 크기를 더해 시작점을 잘못 구한 값이고, 1008은 가장 이른 정렬 위치가 아니다.', 7, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1002, 바로 다음 빈 주소이므로 4의 배수 조건도 만족한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1005, 사용한 마지막 주소 1001에 정수 크기 4를 더한 값이다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1004, 첫 빈 주소 이상에서 만나는 가장 작은 4의 배수다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '1008, 정렬된 주소는 언제나 앞 데이터에서 8바이트 뒤여야 한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '정렬을 맞추려고 데이터 사이에 남겨 둔 바이트를 무엇이라고 할까?', 1, 1, 'MEDIUM', '다음 데이터의 시작 주소를 맞추기 위해 넣는 빈 공간을 [[패딩]]이라고 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '패딩은 사용자가 저장하려던 필드 값이 아니지만 배치 규칙을 만족하도록 주소 간격을 채운다. 그래서 필드 크기의 합과 전체 배치 크기가 다를 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '확인 방법', 'TEXT', '각 데이터의 크기뿐 아니라 시작 주소 요구를 차례로 적용해야 실제 위치와 전체 크기를 구할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '패딩', '데이터의 시작 주소를 정렬하기 위해 사이에 추가하는 사용하지 않는 바이트');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '자연 정렬', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '패딩', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 배치', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '정렬', '데이터의 시작 주소를 정해진 바이트 경계에 맞추는 배치 규칙');

-- STEP 7 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '4바이트 정수의 시작 주소를 4의 배수로 맞추는 시스템에서 정수가 주소 1002부터 놓였다. 시작 주소가 요구된 경계에 맞지 않는 이런 메모리 접근을 ___이라고 한다.', NULL, '데이터 크기가 요구하는 주소 경계와 실제 시작 위치의 나머지를 비교해 보세요.', NULL, '[[비정렬 접근]]은 데이터의 시작 주소가 요구된 정렬 경계에 맞지 않는 접근이다.\n1002를 4로 나눈 나머지는 2이므로 4의 배수 시작 조건을 만족하지 않는다.\n이 접근의 허용 여부와 처리 비용은 ISA와 구현에 따라 다를 수 있다.', '주소 1002부터 4바이트를 읽으면 1002~1005를 사용해 1004 경계를 가로지른다. 어떤 시스템은 이를 여러 번 나누어 처리하고 다른 시스템은 예외로 막을 수 있다.', '4바이트 값이라는 이유만으로 모든 시작 주소가 자동 정렬되지는 않는다. 주어진 규칙에서는 시작 주소 자체가 4의 배수인지 확인해야 한다.', 7, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '비정렬 접근');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'misaligned access');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'unaligned access');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '주소 1002부터 4바이트를 읽을 때 두 정렬 구간에 걸치는 이유는 무엇인가?', 1, 1, 'HARD', '1002~1005가 1000~1003과 1004~1007로 나뉜 두 구간을 차지하는 [[경계 교차]]가 생기기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '4바이트 정렬 경계는 1000, 1004, 1008처럼 이어진다. 1002에서 시작한 네 바이트는 첫 구간의 끝과 다음 구간의 시작을 함께 사용한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '구현 차이', 'TEXT', '경계를 가로지른다는 사실만으로 항상 같은 페널티나 예외가 생긴다고 단정할 수 없다. 대상 ISA와 프로세서의 접근 규칙을 확인해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '경계 교차', '하나의 데이터 접근이 정해진 주소 구간의 끝을 넘어 다음 구간까지 사용하는 상황');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정렬 경계', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '경계 교차', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '구현별 비정렬 처리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '비정렬 접근', '데이터의 시작 주소가 요구된 정렬 경계에 맞지 않는 메모리 접근');

-- STEP 8. 메모리 계층과 지역성
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (8, '메모리 계층과 지역성', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '메모리 계층은 작고 빠른 저장소와 크고 느린 저장소를 함께 사용해 평균 접근 시간을 줄인다. 이 구조가 효과를 내려면 프로그램이 최근 데이터나 가까운 주소를 다시 사용할 가능성인 지역성을 보여야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '용량과 속도와 비용을 층으로 조합한다', 'CPU 가까이에는 빠르지만 작고 바이트당 비용이 큰 저장소를 두고, 멀리에는 느리지만 큰 저장소를 둔다. 자주 쓸 데이터 일부를 가까운 층에 유지하면 모든 데이터를 가장 빠른 장치에 담지 않고도 많은 접근을 빠르게 처리할 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '접근 순서에서 두 지역성을 찾는다', '루프 안에서 같은 합계 변수를 계속 읽고 쓰면 최근 항목을 곧 다시 쓰는 시간 지역성이 있다. 배열을 0, 1, 2, 3 순서로 읽으면 가까운 주소를 차례로 쓰는 공간 지역성이 있다. 두 패턴은 빠른 계층에 가져온 데이터를 다시 활용할 기회를 만든다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '자료의 크기보다 실제 접근을 본다', '큰 배열도 작은 구간만 반복하면 좋은 지역성을 가질 수 있고, 작은 배열도 매번 멀리 떨어진 위치를 무작위로 읽으면 활용이 낮을 수 있다. 자료구조 이름만 보고 판단하지 말고 시간에 따른 주소 열과 동시에 활발히 쓰는 데이터 범위를 살펴본다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 8 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '메모리 접근 기록에서 루프가 매 반복마다 같은 주소 500의 합계 값을 읽고 바로 갱신한다. 같은 위치를 짧은 간격으로 다시 사용하므로 시간 지역성이 나타난다.', NULL, '같은 저장 위치를 다시 찾기까지 걸리는 접근 간격이 짧은지 살펴보세요.', 'O', '[[시간 지역성]]은 최근에 접근한 데이터를 가까운 미래에 다시 사용할 가능성이 높은 성질이다.\n주소 500은 매 반복에서 읽고 쓰이므로 접근 기록에 짧은 간격으로 다시 등장한다.\n이런 값은 빠른 계층에 남아 있는 동안 여러 번 재사용될 수 있다.', '접근 주소 열에 500, 다른 원소, 500, 다른 원소처럼 같은 주소가 거듭 나타나면 재사용 간격이 짧다.', '서로 인접한 여러 주소를 읽는 공간 지역성과 혼동할 수 있다. 이 사례의 핵심은 같은 위치를 짧은 시간 간격으로 반복한다는 점이다.', 8, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '한 번 읽은 설정 값을 오랜 시간이 지난 뒤 다시 읽는 것도 강한 시간 지역성일까?', 1, 1, 'MEDIUM', '재접근 간격인 [[재사용 거리]]가 커질수록 그 값이 빠른 계층에 남아 있을 가능성은 낮아진다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '두 접근 사이에 다른 데이터를 많이 사용하면 앞서 가져온 값이 밀려날 수 있다. 단순히 언젠가 다시 읽는다는 사실보다 얼마나 빨리 다시 쓰는지가 중요하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '판단 방법', 'TEXT', '접근 기록에서 같은 주소 사이에 몇 개의 다른 데이터가 끼는지 살펴보면 재사용 가능성을 가늠할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '재사용 거리', '같은 데이터를 다시 접근하기 전까지 사이에 사용한 다른 데이터의 범위');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '반복 접근', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '재사용 간격', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '빠른 계층 활용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '시간 지역성', '최근 접근한 데이터를 가까운 시간 안에 다시 접근하는 경향');

-- STEP 8 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '연속 배열을 인덱스 0, 1, 2, 3 순서로 한 번씩만 읽어도 가까운 주소를 이어서 접근하므로 공간 지역성이 나타날 수 있다.', NULL, '같은 주소를 반복하는 성질과 서로 가까운 주소를 이어서 읽는 성질을 구분해 보세요.', 'O', '[[공간 지역성]]은 한 주소에 접근한 뒤 그 주변 주소도 곧 접근하는 경향이다.\n연속 배열의 0, 1, 2, 3번 원소는 메모리에서도 가까이 놓인다.\n각 원소를 한 번만 읽어도 이웃 주소를 차례로 읽으므로 공간 지역성이 나타날 수 있다.', '한 메모리 블록에 여러 배열 원소가 함께 들어오면 첫 원소 뒤의 이웃 원소 접근이 이미 가져온 데이터를 활용할 수 있다.', '같은 원소를 되풀이하는지는 시간 지역성의 단서다. 공간 지역성은 서로 다른 접근 주소들이 가까운지를 본다.', 8, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '배열을 큰 간격으로 건너뛰며 읽으면 공간 지역성 활용이 약해질 수 있는 이유는 무엇일까?', 1, 1, 'MEDIUM', '연속 접근 사이의 [[스트라이드]]가 커지면 함께 가져온 이웃 데이터를 사용하지 않고 다음 블록으로 넘어가기 쉽다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '메모리 계층은 가까운 주소를 묶어 옮기는 경우가 많다. 큰 간격으로 접근하면 묶음 안의 많은 데이터를 쓰지 않은 채 다른 묶음을 요청할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '예시', 'TEXT', '모든 원소를 차례로 읽는 패턴보다 매번 수십 개 원소를 건너뛰는 패턴이 이웃 데이터 활용 기회가 적다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '스트라이드', '연속된 두 메모리 접근 주소 사이의 일정한 간격');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '연속 순회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '인접 주소', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '블록 단위 이동', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '공간 지역성', '한 위치에 접근한 뒤 가까운 주소의 데이터도 곧 접근하는 경향');

-- STEP 8 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '4×4 행렬이 메모리에 한 행씩 연속으로 저장되어 있다. 모든 원소를 정확히 한 번 처리하면서 공간 지역성을 가장 직접적으로 활용하는 순회는 무엇인가?', NULL, '안쪽 반복에서 다음 접근 주소가 바로 이웃 주소로 이어지는 순서를 찾으세요.', NULL, '[[행 우선 배치]]에서는 같은 행의 열 원소들이 메모리에 연속으로 놓인다.\n행을 하나 고정한 채 열을 0부터 3까지 바꾸면 접근 주소가 이웃 위치로 이어진다.\n행을 먼저 바꾸며 같은 열을 읽으면 한 행의 너비만큼 건너뛰게 된다.', '접근 순서가 [0][0], [0][1], [0][2], [0][3]으로 이어지면 메모리의 연속 원소를 그대로 따라간다.', '열을 바깥 반복이 아니라 안쪽 반복에 두어야 같은 행의 연속 원소를 먼저 처리한다. 무작위 순서나 큰 간격 순회는 이웃 데이터 활용을 줄인다.', 8, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'r을 0부터 3까지 바꾸되, 각 r에서 열 c를 0부터 3까지 바꾸며 matrix[r][c]를 읽는다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '열 c를 0부터 3까지 고정하고, 각 열에서 행 r을 0부터 3까지 바꾸며 matrix[r][c]를 읽는다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '매번 아직 읽지 않은 원소 중 임의의 위치를 골라 읽는다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '짝수 행의 첫 원소를 모두 읽은 뒤 나머지 원소를 주소와 무관한 순서로 읽는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '행렬이 열 단위로 연속 저장된다면 더 유리한 순회 순서는 어떻게 바뀔까?', 1, 1, 'MEDIUM', '연속 배치된 열의 원소를 먼저 읽도록 행 인덱스를 안쪽에서 바꾸는 [[열 우선 순회]]가 유리하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '좋은 순회 순서는 수학 표기의 모양이 아니라 실제 메모리 배치에 달려 있다. 안쪽 반복이 연속 주소를 따라가도록 맞춘다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '확인 질문', 'TEXT', '사용 언어나 라이브러리가 다차원 데이터를 어떤 순서로 저장하는지 확인한 뒤 반복문 순서를 선택해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '열 우선 순회', '한 열의 원소들을 이어서 처리한 뒤 다음 열로 이동하는 접근 순서');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '다차원 배열', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '순회 순서', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '연속 주소 접근', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '행 우선 배치', '다차원 배열에서 같은 행의 원소들을 메모리에 연속으로 저장하는 방식');

-- STEP 8 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '레코드 백만 개에는 계산마다 쓰는 작은 상태 필드와 가끔만 보는 큰 설명 필드가 함께 있다. 한 작업은 모든 레코드의 상태만 차례로 여러 번 검사한다. 메모리 계층을 더 잘 활용할 가능성이 큰 변경은 무엇인가?', NULL, '자주 읽는 데이터가 적은 메모리 범위에 모이면 빠른 저장 공간에 더 오래 남을 수 있는지 생각해 보세요.', NULL, '[[메모리 계층]]은 자주 쓰는 작은 데이터가 빠른 층에 머물 때 평균 접근 시간을 줄인다.\n상태 필드를 따로 연속 배치하면 반복 작업이 건드리는 메모리 범위가 작아진다.\n가끔 쓰는 큰 설명까지 매번 함께 읽는 낭비도 줄일 수 있다.', '상태 배열과 설명 저장소를 분리하면 상태 검사 루프는 작은 상태 배열을 순서대로 반복하고 설명은 필요할 때만 찾을 수 있다.', '접근 순서를 무작위로 만들거나 자주 쓰지 않는 큰 필드를 매번 함께 복사하면 가까운 계층에 불필요한 데이터가 들어온다. 전체 데이터를 가장 빠른 장치에 둔다는 가정도 현실적인 계층 설계가 아니다.', 8, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '매 반복마다 레코드 순서를 무작위로 섞고 상태와 설명을 함께 읽는다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '상태 필드를 별도의 연속 배열에 모아 반복 검사하고 설명은 필요할 때만 접근한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '가끔 쓰는 설명 필드를 매 상태 검사 전에 새 위치로 복사한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '상태 검사 루프에서 사용하지 않는 설명 필드도 미리 읽어 캐시에 함께 올린다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '프로그램이 특정 데이터를 CPU 캐시에 직접 고정하지 않아도 접근 패턴을 고치는 일이 도움이 되는 이유는 무엇일까?', 1, 1, 'HARD', 'CPU의 [[자동 캐시 관리]]는 접근한 블록을 가까운 곳에 채우므로 작은 범위를 반복하고 연속 접근하면 재사용 기회가 커진다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '일반적인 CPU 캐시는 하드웨어가 자동으로 채우고 내보낸다. 프로그램은 주소 열을 더 예측 가능하고 재사용하기 쉽게 만들어 간접적으로 동작을 돕는다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '주의', 'TEXT', '정확한 교체 방식은 구현마다 다를 수 있으므로 특정 정책을 가정하기보다 실제 성능을 측정해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '자동 캐시 관리', '프로그램이 위치를 직접 지정하지 않아도 CPU가 접근된 메모리 블록을 캐시에 채우고 관리하는 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '뜨거운 데이터 분리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '자료 배치', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '평균 접근 시간', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '메모리 계층', '속도와 용량과 비용이 다른 저장 장치를 여러 단계로 조합한 구조');

-- STEP 8 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '한 루프가 최근에 읽은 표 항목을 다시 사용하면서 그 주변 배열 원소도 차례로 읽는다. 메모리 계층이 활용하는 이런 시간적·공간적 접근 경향을 함께 ___이라고 한다.', NULL, '최근 위치의 재사용과 가까운 주소의 연속 사용을 아우르는 성질을 떠올려 보세요.', NULL, '[[지역성]]은 프로그램의 메모리 접근이 최근 위치나 가까운 주소에 모이는 경향이다.\n같은 표 항목을 다시 쓰는 것은 시간 지역성이고 주변 배열을 읽는 것은 공간 지역성이다.\n메모리 계층은 이 경향을 이용해 가까운 저장소에 둔 데이터를 다시 활용한다.', '작은 표를 여러 번 조회한 뒤 연속 배열 구간을 순회하는 작업은 두 종류의 지역성을 모두 보일 수 있다.', '전체 데이터가 작다는 사실이나 같은 주소만 반복한다는 한 조건만을 묻는 것이 아니다. 최근 데이터와 이웃 주소에 접근이 집중되는 공통 성질을 묻는다.', 8, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '지역성');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'locality');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '캐시에서 자주 쓰는 데이터 범위를 운영체제의 working set과 같은 뜻으로 단정하면 안 되는 이유는 무엇인가?', 1, 1, 'HARD', '운영체제의 [[작업 집합 모델]]은 정한 창 안에서 참조된 가상 메모리 페이지 집합을 다루므로 캐시 라인 단위의 활성 데이터와 측정 단위가 다르다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '두 개념 모두 최근 접근에 주목하지만 운영체제 모델은 페이지와 관찰 창을 명시해 필요한 물리 메모리 양과 페이지 교체를 설명한다. CPU 캐시는 더 작은 블록과 별도의 배치·교체 규칙을 쓴다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '용어 주의', 'TEXT', '일상적으로 활성 데이터 집합이라는 넓은 표현을 쓸 수는 있지만, 엄밀한 분석에서는 어느 계층과 어떤 단위를 말하는지 밝혀야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '작업 집합 모델', '정해진 시간 또는 참조 창 안에서 프로세스가 참조한 가상 메모리 페이지 집합을 이용하는 운영체제 모델');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '시간 지역성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '공간 지역성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '계층별 분석 단위', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '지역성', '메모리 접근이 최근 사용한 위치나 그 주변 주소에 집중되는 경향');

-- STEP 9. CPU 캐시의 hit·miss와 cache line
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (9, 'CPU 캐시의 hit·miss와 cache line', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, 'CPU 캐시는 최근 사용할 가능성이 큰 메모리 데이터를 가까이 보관한다. 요청한 데이터가 캐시에 있으면 히트, 없으면 미스이며, 데이터는 보통 한 바이트가 아니라 캐시 라인이라는 묶음으로 이동한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '히트는 가까운 곳에서, 미스는 아래 계층에서 찾는다', 'CPU가 낸 주소의 데이터가 유효한 캐시 라인에 있으면 캐시 히트다. 없으면 캐시 미스가 발생해 더 느린 다음 계층에서 해당 라인을 가져와야 한다. 미스 한 번은 히트보다 큰 지연을 만들 수 있으므로 미스 횟수와 각 미스의 비용을 함께 본다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '이웃 바이트도 한 라인에 함께 온다', '라인 크기가 16바이트라면 주소 32가 속한 라인은 보통 주소 32~47을 함께 담는다. 빈 캐시에서 주소 35를 처음 읽으면 미스지만, 그 라인이 밀려나지 않았다면 이어서 주소 40을 읽을 때는 히트가 될 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '가져온 양과 실제 사용한 양을 구분한다', '라인이 크면 연속 접근에서 이웃 데이터를 재사용할 기회가 커지지만 사용하지 않는 바이트도 함께 옮길 수 있다. 무작위로 멀리 떨어진 주소만 읽으면 가져온 라인의 대부분을 쓰지 않을 수 있다. 라인 크기 하나만으로 성능을 단정하지 말고 접근 패턴과 미스 비용을 함께 본다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 9 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'CPU가 요청한 주소의 데이터가 현재 유효한 캐시 라인에 들어 있다면 캐시 히트이며, 같은 데이터를 아래 메모리 계층에서 다시 가져올 필요 없이 캐시에서 읽을 수 있다.', NULL, '요청한 데이터가 CPU 가까운 저장소에 이미 준비되어 있을 때 접근 경로가 어떻게 짧아지는지 생각해 보세요.', 'O', '[[캐시 히트]]는 요청한 데이터가 현재 캐시에 있어 가까운 곳에서 찾은 경우다.\nCPU는 해당 요청을 처리하려고 같은 라인을 아래 계층에서 다시 채울 필요가 없다.\n히트가 많아지면 느린 계층을 기다리는 평균 시간을 줄일 수 있다.', '조금 전에 읽은 변수의 라인이 캐시에 남아 있다면 같은 변수를 다시 읽을 때 그 라인에서 바로 값을 찾을 수 있다.', '캐시는 아래 계층의 데이터를 가까이 복사해 두는 저장소다. 유효한 사본이 이미 있는데도 매번 아래 계층에서 다시 읽는다면 캐시의 이점을 얻지 못한다.', 9, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '캐시에서 주소를 확인하고 데이터를 돌려주는 데 걸리는 시간을 무엇이라고 할까?', 1, 1, 'MEDIUM', '캐시 조회를 시작해 결과를 얻기까지의 시간을 [[히트 시간]]이라고 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '히트여도 태그를 비교하고 데이터를 선택하는 데 시간이 든다. 평균 접근 시간에는 히트 확률뿐 아니라 이 기본 조회 시간도 포함된다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '비교', 'TEXT', '미스가 나면 이 조회 시간 뒤에 더 느린 계층에서 라인을 가져오는 추가 지연이 붙는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '히트 시간', '캐시를 조회해 히트한 데이터를 얻는 데 필요한 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '캐시 조회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '유효한 라인', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '평균 접근 시간', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '캐시 히트', 'CPU가 요청한 데이터를 캐시에서 찾은 상태');

-- STEP 9 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '빈 캐시에서 CPU가 메모리의 한 바이트를 요청하면 캐시는 언제나 그 한 바이트만 가져오며 같은 줄의 이웃 바이트는 가져오지 않는다.', NULL, '메모리 계층 사이에서 데이터를 옮기는 최소 묶음이 요청한 자료형 크기와 항상 같은지 살펴보세요.', 'X', '캐시는 보통 데이터를 [[캐시 라인]]이라는 고정 크기 블록으로 가져온다.\n한 바이트를 요청해도 그 바이트가 속한 라인의 이웃 바이트들이 함께 채워질 수 있다.\n이 방식은 곧 인접 주소를 읽는 접근에서 공간 지역성을 활용한다.', '16바이트 라인에서 주소 35를 요청하면 그 주소가 속한 32~47 범위가 함께 캐시에 들어올 수 있다.', 'CPU의 요청 크기와 캐시가 계층 사이에서 옮기는 단위는 다를 수 있다. 캐시는 이후 이웃 접근까지 활용하려고 라인 단위로 데이터를 관리한다.', 9, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '캐시 라인이 매우 커지면 항상 성능이 좋아지지 않는 이유는 무엇일까?', 1, 1, 'HARD', '쓰지 않을 데이터까지 옮기는 [[대역폭 낭비]]와 캐시에 동시에 둘 수 있는 라인 수 감소가 생길 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '접근이 연속적이면 큰 라인이 유리할 수 있지만 무작위 접근에서는 함께 온 이웃 바이트를 사용하지 않을 수 있다. 같은 캐시 용량에서는 라인이 커질수록 라인 개수도 줄어든다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '선택 기준', 'TEXT', '라인 크기의 효과는 프로그램의 공간 지역성과 다음 계층의 전송 특성을 함께 측정해 판단해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '대역폭 낭비', '실제로 사용하지 않을 데이터 전송에 제한된 전송 능력을 소비하는 현상');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '블록 단위 전송', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '공간 지역성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '라인 크기 절충', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '캐시 라인', '캐시와 다음 메모리 계층 사이에서 함께 저장하고 옮기는 고정 크기 데이터 블록');

-- STEP 9 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '캐시는 비어 있고 라인 크기는 16바이트이며, 주소 0부터 라인 경계가 시작한다. 다른 접근이나 교체 없이 주소 35를 읽은 직후 주소 40을 읽을 때 예상되는 결과는 무엇인가?', NULL, '첫 주소가 포함된 16바이트 묶음의 시작과 끝을 구한 뒤 두 번째 주소도 그 안에 있는지 확인하세요.', NULL, '주소 35가 속한 [[라인 범위]]는 16의 배수인 32에서 시작해 47에서 끝난다.\n첫 접근은 빈 캐시이므로 미스가 나고 32~47 라인을 가져온다.\n주소 40도 같은 라인 안에 있으므로 교체가 없다면 두 번째 접근은 히트다.', '32를 16바이트 묶음의 시작으로 보면 35와 40은 모두 시작 주소에서 0~15바이트 안쪽에 있다.', '주소 차이만 보는 대신 각 주소가 어느 라인 범위에 속하는지 계산해야 한다. 주소 40은 다음 라인인 48~63으로 넘어가지 않는다.', 9, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '주소 35와 주소 40은 모두 미스다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '주소 35는 히트이고 주소 40은 미스다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '주소 35와 주소 40은 모두 히트다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '주소 35는 미스이고 주소 40은 히트다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '주소 47 다음의 주소 48이 다른 캐시 라인에 속하는 이유는 무엇일까?', 1, 1, 'MEDIUM', '16바이트씩 나눈 [[블록 경계]]가 48에서 새로 시작하므로 47과 48은 서로 다른 묶음에 속한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '32~47은 16개 주소를 포함한다. 다음 16바이트 범위는 48~63이므로 연속한 두 주소라도 경계를 사이에 두면 다른 라인이다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '계산법', 'TEXT', '주소를 라인 크기로 나눈 몫이 같으면 같은 라인이고 몫이 바뀌면 다른 라인이다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '블록 경계', '고정 크기 메모리 블록 하나가 끝나고 다음 블록이 시작되는 주소 지점');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '라인 주소 계산', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '공간 지역성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '첫 접근 미스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '라인 범위', '하나의 캐시 라인이 담는 연속된 메모리 주소 구간');

-- STEP 9 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '4바이트 정수 배열이 주소 0부터 연속 배치되고 캐시 라인은 16바이트다. 캐시는 처음 비어 있고 중간에 교체가 없을 때 array[0], array[1], array[2], array[3]을 차례로 한 번씩 읽으면 히트와 미스는 어떻게 나타나는가?', NULL, '네 원소가 차지하는 전체 주소 범위가 몇 개의 라인에 들어가는지 먼저 계산하세요.', NULL, '네 원소는 주소 0~15를 차지하므로 모두 하나의 캐시 라인에 들어간다.\narray[0]의 첫 접근에서 미스가 나며 라인 전체를 가져오는 [[미스 비용]]을 치른다.\n그 뒤 세 원소는 이미 가져온 같은 라인에 있어 차례로 히트한다.', '접근 결과는 미스, 히트, 히트, 히트다. 첫 미스가 이웃 세 원소까지 준비해 준다.', '원소마다 각각 미스가 난다고 보면 라인 단위 이동을 놓친다. 반대로 첫 접근부터 히트라고 하면 처음 비어 있다는 조건을 놓친다.', 9, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '미스, 미스, 미스, 미스', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '히트, 히트, 히트, 히트', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '히트, 미스, 히트, 미스', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '미스, 히트, 히트, 히트', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 조건에서 이어서 array[4]를 읽으면 왜 새 미스가 날 수 있을까?', 1, 1, 'MEDIUM', 'array[4]는 주소 16에서 시작해 다음 [[메모리 블록]]에 속하므로 그 라인이 아직 캐시에 없기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '첫 라인은 주소 0~15만 포함한다. array[4]는 주소 16~19를 사용하므로 주소 16~31을 담는 새 라인을 가져와야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '핵심', 'TEXT', '배열 원소 번호가 연속이어도 캐시 라인 경계를 넘는 순간에는 다른 라인이 필요하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '메모리 블록', '캐시가 한 번에 가져오는 연속된 메모리 주소 묶음');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '배열 순회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '라인 활용률', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '미스 패널티', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '미스 비용', '캐시 미스 뒤에 다음 계층에서 라인을 가져오느라 추가되는 시간과 전송 작업');

-- STEP 9 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '캐시가 충분히 비어 있어도 어떤 메모리 블록을 처음 접근할 때는 그 데이터가 아직 캐시에 없어서 미스가 난다. 이런 첫 접근의 미스를 ___라고 한다.', NULL, '용량 부족이나 주소 충돌이 아니라 해당 블록을 아직 한 번도 가져오지 않았다는 원인에 붙는 이름을 생각해 보세요.', NULL, '[[필수 미스]]는 어떤 메모리 블록을 처음 접근할 때 캐시에 사본이 없어 발생한다.\n캐시가 비어 있고 공간이 충분해도 첫 사용에서는 해당 라인을 아래 계층에서 가져와야 한다.\n한번 가져온 뒤 다시 접근하면 교체되지 않은 동안에는 히트할 수 있다.', '프로그램 시작 뒤 주소 100이 속한 라인을 처음 읽는 경우가 대표적이며 콜드 미스라고도 부른다.', '캐시 전체 용량이 작아서 생기는 용량 미스나 같은 자리를 두 주소가 다투는 충돌 미스와 원인이 다르다. 이 문제는 첫 접근이라는 조건을 강조한다.', 9, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '필수 미스');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '콜드 미스');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'compulsory miss');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'cold miss');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '필수 미스의 영향을 줄이기 위해 연속 접근이 도움이 되는 이유는 무엇일까?', 1, 1, 'HARD', '한번 가져온 라인의 여러 데이터를 쓰면 첫 미스 비용을 나누는 [[공간적 재사용]]이 가능하기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '첫 블록 접근 자체는 미스여도 함께 온 이웃 데이터를 연달아 쓰면 이후 접근은 히트가 될 수 있다. 한 번의 전송이 여러 실제 작업에 기여한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '한계', 'TEXT', '접근할 주소가 멀리 흩어져 있으면 라인마다 첫 미스를 겪고 함께 가져온 데이터도 활용하지 못할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '공간적 재사용', '가져온 메모리 블록 안의 이웃 데이터를 뒤이은 접근에서 활용하는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '첫 접근', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '콜드 캐시', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '미스 종류', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '필수 미스', '데이터 블록을 처음 접근해 캐시에 아직 사본이 없어서 발생하는 미스');

-- STEP 10. 캐시 주소 분해와 직접 매핑
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (10, '캐시 주소 분해와 직접 매핑', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '직접 매핑 캐시에서는 메모리 블록마다 들어갈 캐시 라인이 하나로 정해진다. 주소의 offset은 라인 안 위치를, index는 확인할 캐시 라인을, tag는 그 라인에 현재 어느 메모리 블록이 들어 있는지를 구분한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '라인 크기와 라인 수로 비트 수를 구한다', '바이트 주소에서 라인 크기가 2의 o제곱 바이트면 offset은 o비트다. 캐시 라인 수가 2의 i제곱이면 index는 i비트다. 전체 주소 비트에서 offset과 index를 뺀 상위 비트가 tag가 된다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '8비트 주소를 4·2·2비트로 나눈다', '라인당 4바이트이고 라인이 4개인 직접 매핑 캐시를 생각하자. offset은 2비트, index도 2비트이고 8비트 주소의 남은 상위 4비트가 tag다. 주소 0x2D인 00101101은 tag 0010, index 11, offset 01로 나뉜다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', 'index가 같아도 tag까지 확인한다', 'index는 어느 캐시 라인을 볼지만 정한다. 그 라인의 valid 비트가 켜져 있고 저장된 tag가 요청 주소의 tag와 같아야 히트다. 서로 다른 메모리 블록이 같은 index를 가지면 같은 라인을 번갈아 차지해 다른 라인이 비어 있어도 충돌 미스가 날 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 10 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '직접 매핑 캐시가 히트인지 판단하려면 index로 고른 라인이 유효한지와 저장된 tag가 요청 주소의 tag와 같은지를 함께 확인해야 한다.', NULL, '같은 캐시 자리를 여러 메모리 블록이 번갈아 쓸 때 현재 주인을 구분하는 정보를 떠올려 보세요.', 'O', 'index는 요청 주소가 확인할 캐시 라인의 위치만 선택한다.\n선택된 라인의 [[tag]]가 요청 주소의 상위 비트와 같고 라인도 유효해야 히트다.\n라인이 유효하지 않거나 tag가 다르면 index가 같아도 미스다.', '주소 0x00과 0x10은 index가 같아도 tag가 다르므로 한쪽이 들어 있는 상태에서 다른 쪽을 요청하면 미스다.', 'index만으로는 같은 자리를 사용하는 여러 메모리 블록을 구분할 수 없다. valid 비트와 tag 비교가 모두 히트 판정에 필요하다.', 10, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '캐시 라인의 valid 비트는 왜 필요한가?', 1, 1, 'MEDIUM', '[[valid 비트]]는 그 라인의 tag와 데이터가 현재 사용할 수 있는 내용인지 표시한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '캐시를 처음 켰을 때 라인의 비트 모양이 우연히 요청 tag와 같아 보여도 실제 데이터를 채운 적이 없을 수 있다. valid 비트가 꺼져 있으면 미스로 처리한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '히트 조건', 'TEXT', '직접 매핑 캐시의 기본 판정은 선택된 라인이 유효하고 저장된 tag가 요청 tag와 같은지 확인하는 것이다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, 'valid 비트', '캐시 라인에 판정에 사용할 수 있는 데이터가 들어 있는지 나타내는 상태 비트');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '히트 판정', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'valid 비트', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '태그 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'tag', '선택된 캐시 라인에 어느 메모리 블록이 들어 있는지 구분하는 주소의 상위 부분');

-- STEP 10 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '8비트 바이트 주소, 라인당 4바이트, 라인 4개인 직접 매핑 캐시에서 주소 0x00과 0x10은 같은 index 0을 사용하므로 동시에 서로 다른 캐시 라인에 머물 수 없다.', NULL, '각 주소를 4바이트 블록 번호로 바꾼 뒤 그 번호를 캐시 라인 수 4로 나눈 나머지를 비교하세요.', 'O', '[[직접 매핑]]에서는 메모리 블록 하나가 들어갈 캐시 index가 하나로 고정된다.\n0x00의 블록 번호는 0이고 0x10의 블록 번호는 4이며 둘 다 4로 나눈 나머지가 0이다.\n두 주소의 tag는 다르지만 index가 같아 같은 캐시 라인을 번갈아 사용한다.', '0x00이 index 0에 들어간 뒤 0x10을 읽으면 같은 자리에 새 tag와 데이터가 저장되어 앞 라인이 교체된다.', '주소 값이 다르다는 사실만으로 서로 다른 캐시 라인을 쓰는 것은 아니다. 직접 매핑에서는 블록 번호의 index 부분이 같은지 계산해야 한다.', 10, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '주소에서 메모리 블록 번호를 구할 때 offset 비트를 제외하는 이유는 무엇일까?', 1, 1, 'MEDIUM', 'offset은 같은 라인 안의 위치만 바꾸므로 이를 뺀 상위 부분이 [[블록 번호]]를 구분한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '라인당 4바이트라면 주소 0, 1, 2, 3은 모두 블록 0에 속한다. 주소를 4로 나눈 몫이 블록 번호가 되고 나머지가 라인 안 위치가 된다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '예시', 'TEXT', '주소 0x10은 10진수 16이고 4로 나눈 몫이 4이므로 메모리 블록 번호는 4다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '블록 번호', '메모리 주소가 속한 고정 크기 블록을 구분하는 번호');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '블록 번호', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '모듈로 매핑', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '같은 인덱스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '직접 매핑', '각 메모리 블록이 들어갈 캐시 라인을 하나로 고정하는 배치 방식');

-- STEP 10 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '8비트 바이트 주소를 쓰며 라인당 4바이트, 라인 4개인 직접 매핑 캐시가 있다. 주소 0x2D를 tag, index, offset 순서로 나눈 값은 무엇인가? 값은 각 부분을 10진수로 표시한다.', NULL, '0x2D를 00101101로 바꾸고 상위 4비트, 다음 2비트, 마지막 2비트로 끊어 보세요.', NULL, '라인 크기 4바이트이므로 offset은 2비트이고 라인 4개이므로 index도 2비트다.\n0x2D는 00101101이며 [[주소 분해]] 결과는 0010 | 11 | 01이다.\n따라서 tag는 2, index는 3, offset은 1이다.', 'offset 1은 선택된 4바이트 라인의 시작에서 한 바이트 떨어진 위치를 뜻하고 index 3은 네 번째 캐시 라인을 선택한다.', '비트 묶음의 순서는 상위에서 tag, index, offset이다. index와 offset을 바꾸거나 4바이트와 4라인에 필요한 비트 수를 4비트로 착각하면 값이 달라진다.', 10, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'tag 2, index 1, offset 3', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'tag 2, index 3, offset 1', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'tag 1, index 3, offset 2', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'tag 11, index 2, offset 1', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '라인 크기와 라인 수가 2의 거듭제곱이면 비트 경계로 나누기 쉬운 이유는 무엇일까?', 1, 1, 'MEDIUM', '2의 n제곱인 선택지 중 하나는 이진수의 [[n비트 조합]]으로 정확히 구분할 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '4개 위치는 00, 01, 10, 11의 두 비트로 구분한다. 따라서 4바이트 라인의 바이트 위치와 4개 라인의 번호는 각각 두 비트면 충분하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '일반식', 'TEXT', '선택 가능한 수가 2의 n제곱이면 그 번호를 나타내는 데 n비트가 필요하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, 'n비트 조합', 'n개의 이진 자리로 만들 수 있는 2의 n제곱 가지 비트 패턴');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '이진 주소', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '비트 수 계산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '라인 내부 위치', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '주소 분해', '메모리 주소의 비트를 캐시 판정에 필요한 tag, index, offset 부분으로 나누는 것');

-- STEP 10 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '8비트 주소, 라인당 4바이트, 라인 4개인 직접 매핑 캐시가 처음 비어 있다. 다른 접근 없이 주소 4, 5, 20, 4를 순서대로 읽을 때 히트와 미스의 흐름은 무엇인가?', NULL, '주소 4와 5는 같은 블록인지 확인하고 주소 20이 그 블록과 같은 캐시 자리를 쓰는지 추적하세요.', NULL, '주소 4의 첫 접근은 미스이고 주소 4~7의 블록이 index 1에 들어간다.\n주소 5는 같은 블록이라 히트지만 주소 20은 다른 tag로 index 1을 선택해 [[충돌 교체]]를 일으킨다.\n주소 4의 블록은 밀려났으므로 마지막 주소 4 접근도 미스다.', '흐름은 미스, 히트, 미스, 미스다. 블록 번호 1과 5는 모두 4로 나눈 나머지가 1이라 같은 index를 쓴다.', '주소 4와 5를 서로 다른 블록으로 보면 두 번째 히트를 놓친다. 주소 20 뒤에도 주소 4가 남아 있다고 보면 직접 매핑의 같은 index 교체를 놓친다.', 10, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '미스, 미스, 미스, 히트', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '미스, 히트, 히트, 히트', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '미스, 히트, 미스, 미스', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '히트, 히트, 미스, 미스', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 조건에서 주소 8을 읽으면 어느 index를 선택하며, 주소 20 뒤의 index 1 상태에는 영향을 주는가?', 1, 1, 'HARD', '주소 8의 블록 번호는 2이므로 [[index 2]]를 선택하고, index 1에 있는 주소 20의 블록은 그대로 남는다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '라인 크기가 4바이트이므로 주소 8의 블록 번호는 2다. 라인이 4개인 직접 매핑 캐시에서 2를 4로 나눈 나머지는 2이므로 index 2를 고른다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '연결', 'TEXT', '서로 다른 index에 배치되는 블록은 서로의 캐시 라인을 밀어내지 않는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, 'index 2', '주소 8의 메모리 블록이 이 직접 매핑 캐시에서 선택하는 세 번째 캐시 위치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '접근 열 추적', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '같은 라인 재사용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '태그 변경', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '충돌 교체', '서로 다른 메모리 블록이 같은 캐시 index를 요구해 기존 라인을 밀어내는 동작');

-- STEP 10 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '32바이트 캐시 라인이 주소 0x80부터 0x9F까지를 담고 있다. 주소 0x9A는 라인 시작에서 26바이트 떨어져 있으며, 주소에서 이 내부 위치를 나타내는 필드를 ___이라고 한다.', NULL, '캐시 라인을 고르는 부분이 아니라 선택된 라인 안에서 몇 번째 바이트인지 정하는 부분입니다.', NULL, '[[offset]]은 선택된 캐시 라인 안에서 요청한 바이트의 위치를 나타낸다.\n0x9A에서 라인 시작 0x80을 빼면 0x1A, 즉 26이 된다.\n32바이트 라인에는 0부터 31까지의 위치가 있어 offset에 5비트가 필요하다.', '같은 0x80~0x9F 라인에서 주소 0x80의 offset은 0이고 주소 0x9F의 offset은 31이다.', 'index는 확인할 캐시 라인을 고르고 tag는 그 라인에 든 메모리 블록을 구분한다. 질문은 이미 선택된 라인 안의 바이트 위치를 묻는다.', 10, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'offset');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '오프셋');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '블록 오프셋');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'block offset');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'tag와 index가 같고 offset만 다른 두 주소는 어떤 관계인가?', 1, 1, 'MEDIUM', '같은 메모리 블록 안의 서로 다른 바이트를 가리키는 [[라인 내부 주소]] 관계다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', 'tag와 index를 합친 상위 부분이 같으면 같은 라인을 찾는다. offset은 그 라인을 가져온 뒤 어느 바이트를 선택할지만 바꾼다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '히트 판정', 'TEXT', '라인이 유효하고 tag가 맞으면 서로 다른 offset 접근도 같은 캐시 라인에서 처리할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '라인 내부 주소', '같은 캐시 라인 범위 안에서 서로 다른 바이트 위치를 가리키는 주소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '라인 내부 위치', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'offset 비트 수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '주소 필드 역할', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'offset', '캐시 주소에서 선택된 라인 안의 바이트 위치를 나타내는 하위 비트 필드');

-- STEP 11. 연관도와 충돌 미스
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (11, '연관도와 충돌 미스', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '캐시의 연관도는 한 메모리 블록이 들어갈 수 있는 캐시 위치의 수다. 후보 위치가 많으면 충돌 미스는 줄일 수 있지만, 동시에 비교할 태그와 교체 판단이 늘어난다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '후보 위치의 수', '직접 매핑 캐시는 블록마다 후보가 한 줄뿐이다. 집합 연관 캐시는 정해진 집합 안의 여러 줄을 후보로 삼고, 완전 연관 캐시는 캐시의 모든 줄을 후보로 삼는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '공간이 남아도 생기는 미스', '서로 다른 두 블록이 직접 매핑 캐시의 같은 줄에 대응하면 번갈아 접근할 때 계속 서로를 밀어낼 수 있다. 다른 줄이 비어 있어도 생기므로 전체 용량 부족과 구분해야 한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '연관도의 비용', '연관도를 높이면 배치 선택이 넓어지지만 후보 태그를 더 많이 비교하고 교체 대상을 골라야 한다. 따라서 높은 연관도가 모든 설계에서 무조건 가장 빠르다고 단정할 수 없다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 11 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '2-way 집합 연관 캐시에서는 한 메모리 블록이 주소로 선택된 집합 안의 두 라인 중 하나에 들어갈 수 있다.', NULL, '직접 매핑의 후보 한 줄과 2-way 구조의 후보 수를 비교해 보세요.', 'O', '[[2-way 집합 연관]]은 주소가 집합을 고른 뒤 그 안의 두 라인을 후보로 둔다.\n직접 매핑보다 배치 선택지가 늘어 같은 index를 공유하는 블록의 충돌을 줄일 수 있다.\n다만 후보 태그를 더 확인하고 집합 안에서 교체 대상을 골라야 한다.', '한 집합에 라인 A와 B가 있다면 새 블록은 비어 있는 라인이나 정책이 고른 교체 대상에 들어갈 수 있다.', '2-way의 2는 캐시 전체의 후보 수가 아니라 주소가 고른 집합 안에서 사용할 수 있는 라인 수를 뜻한다.', 11, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '2-way 집합 연관 캐시가 히트를 확인할 때 한 집합에서 비교할 수 있는 태그는 최대 몇 개인가?', 1, 1, 'MEDIUM', '선택된 집합의 두 라인이 후보이므로 최대 두 태그를 확인하는 [[태그 비교]]가 필요하다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '주소의 index가 집합 하나를 고르고, 그 집합 안의 각 라인에 저장된 태그가 요청한 태그와 같은지 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '태그 비교', '요청한 메모리 블록과 캐시 라인에 저장된 블록이 같은지 태그 비트를 대조하는 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '집합 선택', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '연관도', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '충돌 완화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '2-way 집합 연관', '각 메모리 블록이 주소로 정해진 집합 안의 두 캐시 라인 중 하나에 들어갈 수 있는 배치 방식');

-- STEP 11 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '완전 연관 캐시는 원하는 블록을 찾을 때 캐시 줄 하나의 태그만 비교하면 된다.', NULL, '블록이 어느 줄에도 들어갈 수 있을 때 검색 후보가 얼마나 되는지 생각해 보세요.', 'X', '[[완전 연관]] 캐시는 한 블록을 캐시의 어느 줄에도 둘 수 있다.\n조회할 때는 요청한 태그를 모든 후보 줄의 태그와 비교해야 한다.\n배치 자유도는 크지만 비교 회로와 교체 판단 비용도 커진다.', '네 줄짜리 완전 연관 캐시라면 요청한 블록이 네 줄 중 어디에 있는지 모두 후보로 확인한다.', '태그 하나만 확인하는 설명은 후보가 한 줄인 직접 매핑에 가깝다. 완전 연관은 모든 줄이 후보다.', 11, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '완전 연관 캐시가 직접 매핑 캐시보다 충돌을 줄이기 쉬운 이유는 무엇인가?', 1, 1, 'MEDIUM', '빈 줄이 있다면 특정 인덱스에 묶이지 않고 사용할 수 있어 [[배치 자유도]]가 크기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '한 위치가 다른 블록에 사용 중이어도 남은 줄 가운데 하나를 선택할 수 있다. 그 대신 어느 줄을 내보낼지 정하는 정책이 필요하다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '배치 자유도', '메모리 블록을 둘 수 있는 캐시 위치 선택의 폭');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '병렬 태그 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '교체 정책', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '하드웨어 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '완전 연관', '메모리 블록을 캐시의 어느 줄에도 배치할 수 있는 방식');

-- STEP 11 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '총 4줄인 직접 매핑 캐시와 총 4줄인 2-way 집합 연관 캐시가 모두 비어 있다. 2-way 캐시는 2개 집합에 각 2줄이 있고 집합 번호는 블록 번호를 2로 나눈 나머지다. 블록 0과 4를 0, 4, 0, 4 순서로 읽을 때 두 캐시의 결과를 옳게 비교한 것은 무엇인가?', NULL, '직접 매핑의 한 후보와 2-way의 집합 안 두 후보에 블록 두 개가 함께 머물 수 있는지 추적하세요.', NULL, '직접 매핑에서는 블록 0과 4가 같은 한 줄만 사용해 네 접근이 모두 미스다.\n[[2-way 집합 연관]]에서는 두 블록이 같은 집합의 서로 다른 줄에 함께 머물 수 있다.\n따라서 첫 두 접근은 미스이고 뒤의 두 접근은 교체가 없다면 히트다.', '직접 매핑의 결과는 미스, 미스, 미스, 미스이고 2-way의 결과는 미스, 미스, 히트, 히트다.', '총 줄 수가 같아도 한 블록이 선택할 수 있는 후보 수는 다르다. 2-way 캐시는 이 예에서 같은 집합의 두 줄을 활용하므로 첫 접근 뒤의 충돌을 피한다.', 11, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '직접 매핑은 네 번 모두 미스이고, 2-way는 미스·미스·히트·히트다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '두 캐시 모두 네 번 전부 미스다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '직접 매핑은 미스·미스·히트·히트이고, 2-way는 네 번 모두 미스다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '두 캐시 모두 첫 접근만 미스이고 나머지는 모두 히트다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '같은 집합에 세 번째 블록이 들어오면 2-way 캐시는 무엇을 해야 하는가?', 1, 1, 'HARD', '두 줄뿐인 [[집합 용량]]이 모두 찼으므로 기존 블록 하나를 교체 대상으로 골라야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '2-way라는 말은 한 집합에 후보 줄이 두 개라는 뜻이다. 세 블록을 동시에 담을 수 없으므로 교체 정책에 따라 하나를 내보낸다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '집합 용량', '한 캐시 집합이 동시에 보관할 수 있는 캐시 줄의 수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '충돌 미스', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '웨이 수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '집합 인덱스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '2-way 집합 연관', '각 집합 안에 블록 후보 위치를 두 줄씩 두는 캐시 배치 방식');

-- STEP 11 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '같은 총 줄 수를 가진 캐시들의 조회 방식을 비교한 설명으로 가장 적절한 것은 무엇인가?', NULL, '후보 위치의 수가 늘 때 태그 비교 범위와 배치 선택이 함께 어떻게 변하는지 비교하세요.', NULL, '집합 연관 캐시는 선택된 집합 안의 여러 [[후보 태그]]를 비교한다.\n직접 매핑은 후보가 하나라 단순하고, 완전 연관은 모든 줄이 후보다.\n연관도가 커질수록 충돌 감소 가능성과 검색·교체 비용이 함께 커진다.', '4-way 캐시는 인덱스로 집합을 고른 다음 그 집합의 네 태그를 요청 태그와 비교할 수 있다.', '직접 매핑도 태그 확인이 필요하고, 완전 연관도 요청한 블록의 위치를 알아내기 위한 비교가 필요하다. 연관도는 총 용량을 자동으로 늘리는 값도 아니다.', 11, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '집합 연관은 선택된 집합의 여러 태그를 비교하고 그 안에서 배치 위치를 고른다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '직접 매핑은 태그 비교 없이 데이터가 항상 맞다고 가정한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '완전 연관은 주소마다 고정된 한 줄만 확인한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '연관도를 높이면 캐시의 전체 데이터 용량이 자동으로 두 배가 된다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '연관도를 계속 높이는 선택이 항상 성능 향상으로 이어지지 않는 이유는 무엇인가?', 1, 1, 'HARD', '충돌은 줄 수 있지만 더 많은 비교와 교체 판단이 [[접근 시간]]과 하드웨어 비용을 늘릴 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '실제 설계는 줄어드는 미스 비용과 조회 경로의 복잡도, 전력, 면적을 함께 비교해 연관도를 정한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '접근 시간', '캐시에 요청을 보낸 뒤 필요한 데이터가 준비될 때까지 걸리는 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '연관도', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '태그 배열', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '교체 대상 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '후보 태그', '요청한 메모리 블록인지 확인하기 위해 비교하는 캐시 줄의 식별 정보');

-- STEP 11 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '직접 매핑에서는 한 메모리 블록의 후보 줄이 1개이고, 4-way 집합 연관에서는 같은 집합 안의 후보 줄이 4개다. 이처럼 블록 하나가 배치될 수 있는 후보 캐시 줄의 수를 ___라고 한다.', NULL, '캐시 총용량이 아니라 한 블록이 선택할 수 있는 위치가 몇 개인지를 나타내는 설계값을 떠올려 보세요.', NULL, '[[연관도]]는 한 메모리 블록이 배치될 수 있는 후보 캐시 줄의 수다.\n직접 매핑의 연관도는 1이고 4-way 집합 연관의 연관도는 4다.\n후보가 많으면 충돌을 줄일 수 있지만 더 많은 태그 비교와 교체 판단이 필요하다.', '완전 연관 캐시는 모든 캐시 줄이 후보이므로 연관도가 전체 줄 수와 같다.', '캐시 용량은 전체 데이터 저장량이고 라인 크기는 한 번에 옮기는 블록 크기다. 빈칸은 블록 하나가 선택할 수 있는 위치의 개수를 묻는다.', 11, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '연관도');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'associativity');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '연관도를 높일수록 캐시 조회 회로가 복잡해질 수 있는 이유는 무엇인가?', 1, 1, 'HARD', '한 요청에서 확인할 [[태그 비교 범위]]가 넓어지고 여러 후보 중 교체할 줄도 골라야 하기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '후보가 하나면 태그 하나만 확인하면 되지만 후보가 여러 개면 각 후보가 요청 블록인지 확인해야 한다. 빈자리가 없을 때는 교체 선택도 추가된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '태그 비교 범위', '한 캐시 요청이 적중 여부를 판단하려고 확인해야 하는 후보 태그의 수와 영역');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '웨이 수', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '후보 위치', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '태그 비교 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '연관도', '메모리 블록 하나가 들어갈 수 있는 후보 캐시 줄의 수');

-- STEP 12. 교체·쓰기 정책과 다단계 캐시
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (12, '교체·쓰기 정책과 다단계 캐시', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '캐시 정책은 무엇을 내보낼지, 쓰기를 어느 계층에 언제 반영할지 정한다. 흔한 조합은 있지만 필연적인 조합은 아니며, L1과 L2는 속도와 용량의 차이를 나눠 맡는다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '교체와 쓰기는 다른 결정', 'LRU 계열 정책은 최근 사용 정보를 이용해 교체 대상을 고른다. write-through와 write-back은 쓰기를 아래 계층에 반영하는 시점을 정하고, write-allocate와 no-write-allocate는 쓰기 미스 때 블록을 가져올지 정한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '수정된 줄을 내보낼 때', 'write-back 캐시의 줄이 캐시 안에서만 바뀌었다면 아래 계층과 내용이 다르다. 이 줄을 교체할 때는 dirty bit를 확인하고, 최신 값을 잃지 않도록 아래 계층에 기록하거나 안전한 쓰기 버퍼로 넘긴다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '조합을 법칙으로 외우지 않기', 'write-back과 write-allocate가 함께 쓰이는 경우가 많고 write-through와 no-write-allocate도 흔하지만 반드시 그래야 하는 것은 아니다. 쓰기 패턴, 구현 복잡도, 일관성 요구를 보고 조합을 고른다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', 'L1과 L2의 협력', 'L1은 작고 빠르게 CPU 가까이에서 요청을 처리한다. L1 미스가 나도 더 크고 느린 L2에서 찾으면 주 메모리까지 가는 비용을 피할 수 있다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 12 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'write-back 캐시는 반드시 write-allocate와만 조합해야 하며 no-write-allocate와는 조합할 수 없다.', NULL, '반영 시점을 정하는 정책과 쓰기 미스의 배치 여부를 정하는 정책이 같은 질문인지 구분하세요.', 'X', '[[쓰기 정책 조합]]은 구현 목표와 접근 패턴에 따라 선택한다.\nwrite-back은 아래 계층에 반영하는 시점, write-allocate는 쓰기 미스 때 가져올지를 정한다.\n두 결정은 관련될 수 있지만 한 조합만 가능한 절대 법칙은 아니다.', 'write-back과 no-write-allocate를 조합하면 쓰기 히트는 캐시 줄을 dirty로 만들 수 있고, 쓰기 미스는 블록을 가져오지 않고 아래 계층으로 보낼 수 있다.', 'write-back과 write-allocate는 흔한 조합이지만 흔하다는 사실이 필수함을 뜻하지 않는다. 각 정책은 서로 다른 결정을 다룬다.', 12, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '쓰기 미스 뒤 같은 블록을 곧 다시 사용할 가능성이 크다면 어떤 판단이 중요한가?', 1, 1, 'HARD', '블록을 캐시에 가져오는 [[write-allocate]]가 이후 접근의 적중 가능성을 높이는지 비용과 함께 판단해야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '재사용이 크면 가져온 블록이 다음 읽기나 쓰기에 쓰일 수 있다. 재사용이 거의 없으면 블록을 가져오는 전송 비용이 이득보다 클 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, 'write-allocate', '쓰기 미스가 난 블록을 캐시에 가져온 뒤 캐시에서 쓰는 정책');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정책 독립성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '쓰기 미스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '지역성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '쓰기 정책 조합', '쓰기 반영 시점과 쓰기 미스 처리 방식을 목적에 맞게 함께 선택한 구성');

-- STEP 12 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'write-through 캐시는 캐시에 값을 쓸 때 아래 메모리 계층에도 그 쓰기를 함께 전달한다.', NULL, '캐시의 변경값과 아래 계층의 값이 언제 같아지는지를 살펴보세요.', 'O', '[[write-through]]는 캐시에 쓸 때 아래 계층에도 쓰기를 전달한다.\n아래 계층이 비교적 최신 값을 유지해 상태 관리가 단순해질 수 있다.\n대신 쓰기 트래픽과 지연을 줄이기 위한 버퍼 같은 보완이 필요할 수 있다.', 'L1에 값을 기록하면서 같은 쓰기 요청을 L2에도 보내 두 계층의 변경을 함께 진행할 수 있다.', '수정 내용을 캐시에만 두었다가 교체 시 기록하는 방식은 write-back이다. write-through는 쓰기 시점에 아래 계층으로 전달한다.', 12, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'write-through 캐시에서 쓰기 버퍼가 도움이 되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '아래 계층의 쓰기 완료를 기다리는 동안 요청을 [[쓰기 버퍼]]에 맡겨 CPU의 대기를 줄일 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '버퍼가 쓰기 요청을 흡수하면 CPU는 조건이 허용되는 범위에서 다음 작업을 진행할 수 있다. 다만 버퍼가 가득 차면 다시 기다릴 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '쓰기 버퍼', '아래 메모리 계층으로 전달할 쓰기 요청을 잠시 보관하는 공간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '쓰기 트래픽', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 일관성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '쓰기 지연', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'write-through', '캐시에 쓸 때 아래 메모리 계층에도 쓰기를 전달하는 정책');

-- STEP 12 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'write-back 캐시에서 교체 대상으로 고른 줄이 캐시 안에서 수정되었고 아래 계층에는 아직 이전 값이 있다. 그 줄을 새 블록으로 덮어쓰며 최신 값을 잃지 않기 위한 처리로 가장 적절한 것은 무엇인가?', NULL, '교체할 줄의 내용이 아래 계층과 달라졌는지 알려 주는 상태 정보를 확인하세요.', NULL, '수정된 줄의 [[dirty bit]]가 설정되어 있으면 최신 내용을 교체 과정에서 보존해야 한다.\n아래 계층에 되쓰거나 안전한 쓰기 버퍼로 넘기지 않고 덮어쓰면 최신 값이 사라진다.\n수정되지 않은 줄은 같은 이유의 되쓰기가 필요하지 않다.', 'dirty 줄을 쓰기 버퍼에 복사한 뒤 캐시 줄은 새 블록에 내주고, 버퍼가 L2나 메모리로 되쓰기를 마치는 구현도 가능하다.', '태그만 바꾸거나 줄을 즉시 덮어쓰면 최신 수정값을 잃는다. 모든 줄을 무조건 기록하는 것도 수정 여부를 추적하는 목적을 살리지 못한다.', 12, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '수정 여부와 관계없이 태그만 새 블록의 태그로 바꾼다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '아래 계층의 이전 값을 캐시에 다시 덮어쓴다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '수정된 내용을 아래 계층에 기록하거나 안전한 쓰기 버퍼에 넘긴 뒤 줄을 새 블록에 내준다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '캐시의 모든 줄을 읽기 전용으로 바꾼다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '수정되지 않은 줄을 교체할 때 아래 계층에 다시 기록하지 않아도 되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '캐시 줄과 아래 계층의 값이 같다는 [[클린 상태]]이므로 줄을 버려도 최신 데이터가 아래에 남아 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '읽어 온 뒤 수정하지 않은 복사본은 원본과 차이가 없다. 따라서 교체 시 불필요한 쓰기 트래픽을 피할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '클린 상태', '캐시 줄이 아래 계층과 같은 값을 가지고 있어 되쓰기가 필요 없는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '캐시 교체', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '되쓰기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 보존', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'dirty bit', '캐시 줄이 아래 계층에 아직 반영되지 않은 수정값을 가졌는지 나타내는 비트');

-- STEP 12 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'CPU가 읽기를 요청했는데 L1에서는 미스가 났고 L2에서는 요청한 블록을 찾았다. 이 상황을 가장 잘 설명한 것은 무엇인가?', NULL, '가까운 계층에서 찾지 못했을 때 다음 계층의 적중이 더 먼 메모리 접근을 대신할 수 있는지 보세요.', NULL, 'L1 미스 뒤 L2에서 찾으면 [[L2 적중]]으로 요청을 처리할 수 있다.\n보통 L1 적중보다는 느리지만 주 메모리까지 가는 것보다는 빠를 수 있다.\n가져온 블록을 어느 계층에 채울지는 캐시 계층의 포함·배치 정책에 달려 있다.', 'L2가 블록을 돌려주고 L1에 다시 채워 이후 가까운 접근에서 사용할 수 있는 구성이 가능하다.', 'L1 미스가 곧바로 주 메모리 접근을 뜻하지는 않는다. L2가 적중했다면 그 계층에서 데이터를 얻을 수 있으며 세부 채움 방식은 구현 정책에 따라 달라진다.', 12, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'L1 미스가 났으므로 L2 결과와 관계없이 반드시 주 메모리까지 접근한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'L2에서 블록을 얻어 주 메모리 접근 비용을 피할 수 있다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'L2 적중은 L1 적중보다 항상 더 짧은 시간이 걸린다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '다단계 캐시에서는 모든 계층의 크기와 지연이 같아야 한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '작고 빠른 L1과 더 큰 L2를 함께 두는 주된 이유는 무엇인가?', 1, 1, 'MEDIUM', '자주 쓰는 데이터에는 짧은 지연을 제공하면서 더 넓은 데이터를 [[계층적 지역성]]으로 받아들이기 위해서다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '한 계층만으로 매우 빠른 접근과 큰 용량을 동시에 얻기 어렵다. 여러 계층은 가까운 소형 캐시와 먼 대형 캐시의 장점을 조합한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '계층적 지역성', '서로 다른 크기와 속도의 캐시 계층이 접근의 가까움과 반복성을 단계적으로 활용하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '평균 메모리 접근 시간', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '캐시 계층', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '미스 처리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'L2 적중', 'L1에서 찾지 못한 요청 데이터를 두 번째 캐시 계층에서 찾은 상태');

-- STEP 12 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'write-back 캐시에서 한 캐시 줄이 아래 계층에 아직 반영되지 않은 수정값을 가지는지 표시하는 상태 비트는 ___이다.', NULL, '교체 전에 해당 줄을 아래 계층에 기록해야 하는지를 알려 주는 표식을 떠올려 보세요.', NULL, '[[dirty bit]]는 캐시 줄이 아래 계층과 달라졌는지를 표시한다.\n비트가 설정된 줄을 교체할 때는 수정값을 아래 계층에 되쓰거나 쓰기 버퍼에 보존해야 한다.\n이 정보 덕분에 수정되지 않은 줄의 불필요한 되쓰기를 피할 수 있다.', '프로세서가 캐시 줄을 수정하면 dirty bit를 설정하고, 교체 때 최신 값을 안전하게 넘긴 뒤 새 줄의 상태를 관리한다.', 'valid bit는 줄에 유효한 데이터가 있는지를 나타내고, 태그는 어떤 메모리 블록인지 구분한다. 수정값의 미반영 여부를 추적하는 역할과 다르다.', 12, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'dirty bit');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '더티 비트');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'write-through 캐시에서는 같은 목적의 상태 비트가 보통 덜 필요한 이유는 무엇인가?', 1, 1, 'HARD', '쓰기 때 아래 계층에도 값을 전달해 캐시에만 남은 [[미반영 수정값]]을 따로 추적할 필요가 줄기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '아래 계층 반영이 지연되거나 버퍼에 남는 세부 상황은 별도 관리가 필요할 수 있지만, write-back의 교체용 표시와는 목적이 다르다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '미반영 수정값', '캐시에는 존재하지만 아래 메모리 계층에는 아직 기록되지 않은 최신 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'valid bit', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'write-back', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '교체 시 쓰기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'dirty bit', '캐시 줄의 수정 내용이 아래 계층에 아직 반영되지 않았음을 나타내는 비트');

-- STEP 13. 파이프라인과 겹쳐 실행하기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (13, '파이프라인과 겹쳐 실행하기', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '파이프라인은 한 명령이 여러 단계를 지나는 동안 다른 명령이 서로 다른 단계를 사용하게 한다. 이 중첩은 일정 시간에 완료하는 명령 수를 늘리지만 한 명령의 단계 수 자체를 없애지는 않는다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '동시에 다른 단계 사용하기', '첫 명령이 실행 단계로 이동하면 다음 명령은 인출 단계를 사용할 수 있다. 같은 순간에 여러 명령이 각기 다른 단계에 있으므로 하드웨어 단계들을 겹쳐 활용한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '채우기 뒤의 완료 간격', 'N단계 파이프라인에 해저드와 지연이 없다면 첫 명령은 N번째 사이클 끝에 완료된다. 파이프라인이 찬 뒤에는 이상적으로 매 사이클 명령 하나가 완료될 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '처리량과 지연 시간 구분', '단계 중첩의 핵심 이득은 여러 명령의 전체 처리량이다. 한 명령은 여전히 모든 단계를 지나므로 단일 명령의 지연 시간이 반드시 짧아지는 것은 아니다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 13 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '각 단계가 1사이클인 이상적인 5단계 파이프라인은 첫 명령이 완료된 뒤 정상 상태에서 매 사이클 한 명령을 완료할 수 있어도 첫 명령의 완료에는 5사이클이 필요하다.', NULL, '파이프라인을 처음 채우는 구간과 이미 모든 단계가 일하는 구간을 나눠 보세요.', 'O', '첫 명령은 다섯 단계를 모두 지나야 하므로 [[채우기 시간]]이 필요하다.\n파이프라인이 찬 뒤에는 이상적으로 매 사이클 하나씩 완료할 수 있다.\n첫 결과의 지연과 이후 결과의 간격은 서로 다른 값이다.', '첫 명령은 1~5사이클에 단계를 지나고, 다음 명령들은 6, 7사이클에 차례로 완료될 수 있다.', '매 사이클 한 명령 완료라는 말은 시작하자마자 첫 결과가 나온다는 뜻이 아니다. 초기에는 단계들을 명령으로 채우는 시간이 든다.', 13, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '파이프라인의 첫 결과가 늦더라도 많은 명령을 처리할 때 이득을 얻는 이유는 무엇인가?', 1, 1, 'MEDIUM', '초기 구간 뒤에는 명령들의 단계가 겹쳐져 [[완료 간격]]이 짧아지기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '각 명령의 전체 여정은 여러 단계지만 서로 다른 명령이 동시에 진행된다. 명령 수가 많을수록 초기 채우기 비용의 비중이 작아진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '완료 간격', '연속한 두 명령의 완료 시점 사이에 걸리는 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 채우기', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정상 상태', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '첫 결과 지연', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '채우기 시간', '첫 명령이 파이프라인의 모든 단계를 지나 첫 결과가 나오기까지 필요한 초기 시간');

-- STEP 13 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '명령 처리를 더 많은 파이프라인 단계로 나누기만 하면 한 명령의 지연 시간은 항상 그 단계 수에 반비례해 줄어든다.', NULL, '단계를 나누며 생기는 단계 사이 저장과 제어의 부담도 함께 고려하세요.', 'X', '단계를 늘리는 주된 목표는 더 높은 클록과 [[처리 중첩]] 가능성이다.\n한 명령은 늘어난 모든 단계를 지나야 하고 단계 사이 레지스터 비용도 생긴다.\n따라서 단계 수 증가가 단일 명령 지연의 비례 감소를 보장하지 않는다.', '한 작업을 더 잘게 나눠 클록 주기를 줄여도 각 경계의 저장 지연이 더해져 한 명령의 총 시간이 비슷하거나 늘 수 있다.', '단계 수만 세어 단일 명령 지연을 판단하면 파이프라인 레지스터와 불균형한 단계의 비용을 놓친다. 처리량 증가와 한 명령의 지연 감소도 같은 뜻이 아니다.', 13, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '한 단계가 다른 단계보다 훨씬 오래 걸리면 클록 주기에 어떤 영향을 주는가?', 1, 1, 'HARD', '가장 느린 단계와 경계 비용이 [[임계 단계]]가 되어 클록 주기를 제한한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '모든 단계가 한 클록 안에 일을 끝내야 하므로 유난히 긴 단계가 있으면 나머지 짧은 단계가 끝나도 다음 클록을 앞당기기 어렵다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '임계 단계', '파이프라인의 클록 주기를 주로 제한하는 가장 긴 처리 단계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 레지스터', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '단계 균형', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '클록 주기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '처리 중첩', '서로 다른 명령이 같은 시간에 각기 다른 파이프라인 단계를 사용하는 방식');

-- STEP 13 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '해저드가 없는 4단계 파이프라인에 명령 3개를 첫 사이클부터 매 사이클 하나씩 넣는다. 각 단계는 1사이클이고 첫 명령은 4번째 사이클 끝에 완료된다. 세 번째 명령이 완료되는 시점은 언제인가?', NULL, '첫 완료 시점에서 뒤따르는 명령들이 한 사이클 간격으로 끝나는 모습을 그려 보세요.', NULL, '4단계에 명령 3개면 이상적인 [[파이프라인 완료 시간]]은 6사이클이다.\n첫 명령이 4번째 사이클에 끝난 뒤 둘째와 셋째가 한 사이클 간격으로 끝난다.\n각 명령의 4사이클을 단순히 더하면 단계 중첩을 반영하지 못한다.', '완료 시점은 첫째 4사이클, 둘째 5사이클, 셋째 6사이클이다.', '12사이클은 세 명령을 겹치지 않고 순서대로 처리한 계산이다. 4사이클은 첫 명령의 완료 시점일 뿐 세 번째 명령까지의 시간이 아니다.', 13, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '4번째 사이클 끝', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '6번째 사이클 끝', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '5번째 사이클 끝', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '12번째 사이클 끝', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '이상적인 N단계 파이프라인에서 M개 명령의 마지막 완료 시점을 어떻게 구하는가?', 1, 1, 'MEDIUM', '첫 명령에 N사이클이 들고 나머지 M-1개가 한 사이클씩 추가되어 [[N+M-1]]사이클이 된다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '이 식은 각 단계가 한 사이클이고 해저드나 캐시 미스가 없는 이상적인 조건에서 사용한다. 추가 정지가 있으면 그 사이클을 더해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, 'N+M-1', '이상적인 N단계 파이프라인에서 M개 명령을 완료하는 데 필요한 사이클 수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 타임라인', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '이상적 사이클 수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 완료 순서', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '파이프라인 완료 시간', '첫 명령을 넣은 때부터 주어진 모든 명령이 파이프라인을 빠져나올 때까지 걸린 시간');

-- STEP 13 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서로 독립인 명령 10개를 처리한다. 비파이프라인 설계 A는 명령 하나를 4ns에 끝낸 뒤 다음 명령을 시작한다. 4단계 파이프라인 설계 B는 단계마다 1.5ns이며 해저드 없이 매 사이클 새 명령을 시작해 첫 명령을 6ns에 끝낸다. 가장 정확한 비교는 무엇인가?', NULL, '첫 결과 시간에 뒤따르는 아홉 명령의 완료 간격을 더하고, 순차 설계의 열 번 실행 시간과 비교하세요.', NULL, 'A는 명령을 겹치지 않으므로 10 × 4ns인 40ns가 걸린다.\nB는 첫 결과 6ns 뒤 아홉 결과가 1.5ns 간격으로 나와 총 19.5ns가 걸린다.\nB는 단일 명령 지연은 더 길지만 [[처리량 이득]]으로 명령 묶음을 더 빨리 끝낸다.', 'B의 계산은 6+9×1.5=19.5ns다. 명령 하나만 실행하면 A의 4ns가 B의 6ns보다 짧다.', 'B의 6ns를 명령마다 따로 곱하면 단계 중첩을 무시한다. 반대로 첫 결과 시간만 보면 뒤의 아홉 명령이 완료되는 간격을 빠뜨린다.', 13, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'B의 단일 명령 지연이 6ns이므로 10개 처리도 A보다 항상 느리다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'B는 각 명령마다 6ns를 따로 사용하므로 총 60ns가 걸린다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'A와 B 모두 명령이 10개이므로 정확히 40ns가 걸린다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'A는 40ns, B는 19.5ns이며 B는 단일 명령 지연이 더 길어도 10개 묶음은 더 빨리 끝낸다', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '파이프라인 B의 단일 명령 지연이 A보다 길어진 원인은 무엇일 수 있는가?', 1, 1, 'HARD', '각 단계 사이 저장과 제어에 필요한 [[단계 경계 비용]]이 더해지면 모든 단계를 지나는 한 명령의 시간이 길어질 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '파이프라인은 작업을 나눠 여러 명령을 겹치지만 단계 사이 레지스터와 제어 논리는 시간을 사용한다. 처리량 개선이 단일 명령 지연 감소를 보장하지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '단계 경계 비용', '파이프라인 단계 사이에서 값을 저장하고 제어하는 데 추가되는 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '단일 명령 지연', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '묶음 처리량', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 오버헤드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '처리량 이득', '여러 작업을 겹쳐 일정 시간에 더 많은 결과를 완료하며 얻는 성능 향상');

-- STEP 13 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '파이프라인이 여러 명령의 단계를 겹쳐 일정 시간 동안 완료하는 명령 수를 늘릴 때, 주로 향상되는 성능 지표는 ___이다.', NULL, '한 명령이 끝나는 데 걸리는 시간보다 일정 구간에 몇 개가 끝나는지를 나타내는 지표를 찾으세요.', NULL, '[[처리량]]은 일정 시간 동안 완료할 수 있는 작업이나 명령의 수다.\n파이프라인은 서로 다른 명령의 단계를 겹쳐 이 값을 높인다.\n한 명령의 지연 시간은 모든 단계를 지나야 하므로 반드시 함께 줄지는 않는다.', '세탁 공정의 각 단계를 겹치면 한 벌의 총 공정 시간과 별개로 시간당 끝나는 세탁물 수가 늘어나는 것과 비슷하다.', '단일 명령 지연은 한 명령이 시작해 끝날 때까지의 시간이다. 파이프라인의 대표 이득은 여러 명령을 연속 처리할 때의 완료 빈도다.', 13, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '처리량');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'throughput');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '명령이 하나뿐이라면 파이프라인 중첩의 이득이 작아지는 이유는 무엇인가?', 1, 1, 'MEDIUM', '겹쳐 실행할 뒤 명령이 없어 [[단계 병렬성]]을 활용할 수 없기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '한 명령은 첫 단계부터 마지막 단계까지 차례로 지나간다. 여러 명령이 있어야 서로 다른 단계가 동시에 일한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '단계 병렬성', '서로 다른 명령이 파이프라인의 서로 다른 단계에서 동시에 진행되는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '지연 시간', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정상 상태 처리', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '병렬 실행', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '처리량', '단위 시간 동안 완료되는 명령이나 작업의 수');

-- STEP 14. 데이터 해저드와 포워딩
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (14, '데이터 해저드와 포워딩', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '뒤 명령이 앞 명령의 결과를 읽어야 하는 RAW 의존성은 파이프라인에서 데이터 해저드를 만들 수 있다. 이 스텝은 IF-ID-EX-MEM-WB 5단계와 명시된 포워딩 경로를 기준으로 값의 준비 시점과 정지를 추적한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '필요한 값이 준비되는 시점', 'RAW 의존성에서는 먼저 쓴 값을 뒤 명령이 읽는다. 파이프라인은 명령을 겹치므로 뒤 명령이 값을 필요로 하는 순간이 앞 명령의 레지스터 기록보다 빠를 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', 'ALU 결과 전달', '덧셈 결과가 실행 단계 끝에 나오고 바로 다음 명령이 그 값을 실행 입력으로 쓰면, 결과를 레지스터 파일을 거치지 않고 실행 입력으로 전달할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', 'load-use의 한계', '여기서 다루는 5단계 구조에서는 load 값이 MEM 단계 끝에 준비된다. 바로 다음 명령이 EX 단계 시작에 값을 요구하면 MEM-to-EX 포워딩이 있어도 한 사이클 버블로 사용 시점을 늦춰야 한다. 다른 파이프라인에서는 단계와 전달 시점이 달라질 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 14 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'IF-ID-EX-MEM-WB 순서의 5단계 파이프라인에서 load 값은 MEM 단계 끝에 준비되고, 바로 다음 명령은 EX 단계 시작에 그 값이 필요하다. MEM-to-EX 포워딩이 있어도 모든 정지를 없앨 수 있다.', NULL, '메모리에서 읽은 값이 준비되는 단계와 다음 명령이 계산 입력을 요구하는 단계를 비교하세요.', 'X', '주어진 5단계 구조에서는 load 결과가 MEM 끝에 준비되어 [[load-use 해저드]]가 남는다.\n바로 다음 명령은 그보다 이른 EX 시작에 값을 요구한다.\n한 사이클 정지한 뒤 MEM 결과를 EX 입력으로 전달하면 시점을 맞출 수 있다.', 'LW 다음의 ADD가 읽어 온 레지스터를 즉시 사용하면 ADD의 실행을 한 사이클 늦춰 값이 도착할 시간을 만든다.', '포워딩은 이미 만들어진 값을 빠르게 전달할 뿐 값을 더 일찍 생성하지는 않는다. load 값의 생성이 늦으면 시간 간격을 벌리는 정지가 필요하다.', 14, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '컴파일러가 load와 사용 명령 사이에 독립 명령을 배치하면 어떤 이점이 있는가?', 1, 1, 'HARD', '기다리는 자리에 유용한 일을 넣는 [[명령 스케줄링]]으로 정지 비용을 숨길 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '중간 명령이 load 결과와 무관하고 프로그램 의미를 바꾸지 않는다면 그 명령을 실행하는 동안 값이 준비될 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '명령 스케줄링', '의존성을 지키면서 실행 순서를 조정해 파이프라인 대기를 줄이는 기법');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '메모리 단계', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '버블', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '포워딩 한계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'load-use 해저드', 'load가 읽어 온 값을 바로 다음 명령이 너무 일찍 사용하려 할 때 생기는 데이터 해저드');

-- STEP 14 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '앞 명령이 R1에 쓴 결과를 바로 다음 명령이 R1에서 읽어 계산한다면 RAW 데이터 의존성이 있다.', NULL, '뒤 명령의 입력이 앞 명령이 아직 만들고 있는 출력과 같은 레지스터인지 확인하세요.', 'O', '[[RAW 의존성]]은 앞 명령이 쓴 값을 뒤 명령이 읽어야 할 때 생긴다.\n겹쳐 실행하면 뒤 명령의 읽기 시점에 값이 아직 준비되지 않을 수 있다.\n포워딩이나 정지 여부는 값 생성 시점과 사용 시점을 비교해 결정한다.', 'ADD가 R1을 만든 직후 SUB가 R1을 피연산자로 쓰면 SUB는 ADD의 결과를 기다린다.', '서로 다른 명령이 같은 레지스터를 사용해도 읽기와 쓰기 방향을 봐야 한다. 이 사례는 먼저 쓰고 뒤에서 읽으므로 RAW다.', 14, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'RAW 의존성이 있어도 항상 정지가 필요한 것은 아닌 이유는 무엇인가?', 1, 1, 'MEDIUM', '결과가 필요한 시점 전에 준비되면 [[전달 경로]]를 통해 뒤 명령의 입력으로 바로 보낼 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '의존성은 명령 사이의 의미 관계이고, 해저드는 현재 파이프라인 타이밍에서 그 관계가 문제를 일으키는 상황이다. 하드웨어가 시간을 맞춰 주면 정지를 피할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '전달 경로', '앞 단계의 계산 결과를 뒤 명령이 쓰는 입력으로 직접 보내는 하드웨어 연결');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '레지스터 의존성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '값 준비 시점', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 해저드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'RAW 의존성', '앞 명령이 쓴 값을 뒤 명령이 읽어야 하는 쓰기 후 읽기 의존성');

-- STEP 14 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'IF-ID-EX-MEM-WB 순서의 5단계 파이프라인에서 ADD R1, R2, R3 다음에 SUB R4, R1, R5가 이어진다. ADD 결과는 EX 끝에 준비되고 다음 사이클 SUB의 EX 입력으로 보내는 포워딩을 지원할 때 가장 적절한 처리는 무엇인가?', NULL, '덧셈 결과가 실행 단계 끝에 나온 뒤 다음 명령의 실행 입력으로 곧바로 갈 수 있는지 살펴보세요.', NULL, 'ADD의 ALU 결과를 다음 SUB의 실행 입력으로 보내는 [[EX 포워딩]]이 가능하다.\n레지스터 기록이 끝날 때까지 기다리지 않아도 필요한 값이 이미 생성되어 있다.\n따라서 이 두 ALU 명령 사이의 RAW 해저드는 보통 정지 없이 해결된다.', 'ADD의 실행 단계 출력 R1을 다음 사이클 SUB의 ALU 입력 선택기로 전달한다.', 'SUB가 이전 R1을 사용하면 프로그램 결과가 달라진다. 두 명령을 무조건 비우거나 load-use처럼 처리할 필요도 없으며, 이미 준비된 ALU 결과를 전달하면 된다.', 14, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'SUB가 레지스터에 있던 이전 R1 값을 사용하게 한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '두 명령을 모두 파이프라인에서 제거한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'ADD 결과와 무관하게 항상 메모리 읽기를 추가한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'ADD의 ALU 결과를 SUB의 실행 입력으로 전달한다', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '포워딩 선택기는 어떤 레지스터 번호를 비교해 전달 여부를 정하는가?', 1, 1, 'HARD', '앞 명령의 목적 레지스터와 뒤 명령의 원본 레지스터가 같은지 보는 [[레지스터 번호 비교]]를 사용한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '번호가 같고 앞 명령이 실제로 레지스터를 쓴다면 해당 결과를 선택한다. 상수 레지스터처럼 쓰기가 무시되는 대상은 구현 규칙에 맞게 제외한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '레지스터 번호 비교', '생산자의 목적지와 소비자의 입력이 같은 레지스터인지 확인하는 해저드 판정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'ALU 의존성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '실행 단계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '입력 선택기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'EX 포워딩', '실행 단계에서 나온 결과를 뒤 명령의 실행 입력으로 직접 전달하는 경로');

-- STEP 14 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'IF-ID-EX-MEM-WB 순서의 5단계 파이프라인에서 LW R1, 0(R2), ADD R8, R9, R10, SUB R4, R1, R5가 차례로 온다. ADD는 R1과 무관하고, load 값은 MEM 끝에 준비되며 MEM-to-EX 포워딩을 지원한다. SUB의 데이터 의존을 처리하는 설명으로 옳은 것은?', NULL, 'load와 SUB 사이의 독립 명령이 두 명령의 실행 단계 사이에 만든 간격을 살펴보세요.', NULL, 'load와 SUB 사이의 [[독립 명령]]이 한 사이클 간격을 만든다.\nload 결과가 MEM 끝에 준비된 다음 사이클에 SUB가 EX를 시작하므로 포워딩할 수 있다.\n따라서 이 조건에서는 load-use 의존 때문에 SUB를 추가로 정지하지 않아도 된다.', 'ADD가 자신의 EX 단계를 사용하는 동안 load는 MEM에서 R1 값을 준비하고, 다음 사이클 SUB의 EX 입력으로 그 값을 전달한다.', '바로 다음 명령이 R1을 쓸 때와 달리 여기에는 독립 명령 하나가 간격을 만든다. 이 간격을 무시하면 필요하지 않은 정지를 넣게 된다.', 14, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '독립 ADD가 한 사이클 간격을 만들어 SUB는 추가 정지 없이 load 값을 포워딩받는다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'SUB는 바로 다음 소비자와 같으므로 반드시 한 사이클 더 정지한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'SUB는 새 load 값이 아니라 이전 R1 값을 사용해야 한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '의존성이 있으므로 세 명령을 모두 비우고 처음부터 실행한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '가운데 ADD가 R1을 수정한다면 같은 판단을 적용할 수 없는 이유는 무엇인가?', 1, 1, 'MEDIUM', 'ADD가 R1을 바꾸면 load와 무관한 [[독립성]]이 깨지고 SUB가 사용해야 할 값의 생산자도 달라지기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '명령을 사이에 배치할 때는 단순히 한 줄을 끼우는 것이 아니라 읽고 쓰는 레지스터와 프로그램 의미를 함께 확인해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '독립성', '두 명령이 서로의 입력이나 결과에 영향을 주지 않아 순서를 조정해도 의미가 유지되는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 스케줄링', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '포워딩 시점', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '의존 거리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '독립 명령', '주변 명령이 읽거나 쓰는 값과 충돌하지 않아 그 명령의 결과를 기다리지 않고 실행할 수 있는 명령');

-- STEP 14 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '앞 명령의 계산 결과를 레지스터 파일에 기록할 때까지 기다리지 않고 뒤 명령의 실행 입력으로 직접 보내는 기법은 ___이다.', NULL, '이미 만들어진 결과가 정식 저장 경로를 모두 거치기 전에 소비자에게 도착하도록 하는 우회 연결을 떠올려 보세요.', NULL, '[[포워딩]]은 앞 명령의 결과를 뒤 명령이 필요한 입력으로 직접 보낸다.\n레지스터 쓰기와 다시 읽기를 기다리지 않아 일부 RAW 정지를 줄인다.\n하지만 아직 생성되지 않은 값은 보낼 수 없어 load-use 정지가 남을 수 있다.', 'ALU 출력에서 다음 명령의 ALU 입력으로 연결된 경로가 레지스터 기록 전 결과를 전달한다.', '분기 예측은 제어 흐름을 추측하는 기술이고 캐시 교체는 저장 공간을 고르는 정책이다. 여기서는 준비된 데이터의 전달 경로가 핵심이다.', 14, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '포워딩');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'forwarding');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '바이패싱');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'bypassing');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '포워딩이 있어도 해저드 검출 장치가 필요한 이유는 무엇인가?', 1, 1, 'HARD', '어떤 결과를 어느 입력으로 보낼지와 값이 늦어 정지해야 하는지를 [[해저드 검출]]이 판단해야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '모든 명령이 바로 앞 결과를 쓰는 것은 아니다. 레지스터 번호와 명령 종류, 값의 준비 단계를 보고 전달 선택과 정지를 제어한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '해저드 검출', '명령 사이의 의존성과 값 준비 시점을 확인해 전달이나 정지를 제어하는 기능');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '바이패스 네트워크', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'RAW 해결', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 준비 시점', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '포워딩', '앞 명령의 결과를 레지스터 기록 전에 뒤 명령의 입력으로 직접 전달하는 기법');

-- STEP 15. 제어 해저드와 구조적 해저드
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (15, '제어 해저드와 구조적 해저드', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, '제어 해저드는 다음에 실행할 주소를 아직 몰라 생기고, 구조적 해저드는 같은 하드웨어 자원을 동시에 쓰려 해 생긴다. 원인이 다르므로 분기 예측과 flush, 자원 분리와 stall을 구분해 적용해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '다음 주소의 불확실성', '조건 분기의 결과가 나오기 전에는 다음 명령 주소가 순차 경로인지 분기 목표인지 확정되지 않을 수 있다. 기다리거나 한 경로를 예측해 가져오는 방식으로 대응한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '예측이 빗나간 경우', '예측한 경로의 명령을 이미 가져오고 해독했다면 실제 경로가 확인될 때 잘못 들어온 명령을 무효화하고 올바른 주소에서 다시 채운다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '하나의 자원을 두 단계가 요구할 때', '명령 인출과 데이터 접근이 같은 단일 메모리 포트를 같은 사이클에 요구하면 둘을 모두 처리할 수 없다. 포트를 늘리거나 자원을 분리하거나 한쪽을 멈춘다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 15 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '분기 예측이 빗나가도 예측 경로의 명령이 만든 레지스터와 메모리 변경을 프로그램 상태에 그대로 반영한 뒤 실제 경로를 실행하면 된다.', NULL, '선택되지 않은 경로의 명령이 레지스터나 메모리를 바꾸면 프로그램 의미가 유지되는지 생각해 보세요.', 'X', '예측 실패 시 잘못된 경로의 명령은 [[무효화]]해야 한다.\n그 명령들이 상태를 바꾸면 원래 프로그램과 다른 결과가 생긴다.\n올바른 분기 주소에서 명령을 다시 가져와 파이프라인을 채운다.', '실제로 분기해야 하는데 순차 경로를 가져왔다면 그 경로의 레지스터 쓰기와 메모리 쓰기가 반영되지 않게 막는다.', '잘못된 경로는 실행 대상이 아니므로 완료를 허용할 수 없다. 단순히 실제 경로를 뒤에 이어 붙이면 불필요한 상태 변경이 남는다.', 15, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '예측 정확도가 높아도 분기 예측이 완전히 무료인 기법은 아닌 이유는 무엇인가?', 1, 1, 'HARD', '예측기와 목표 주소 저장소가 하드웨어를 사용하고 실패할 때 [[복구 비용]]이 발생하기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '예측 정보를 조회하고 갱신하는 회로가 필요하다. 또한 실패한 경우 잘못된 명령을 버리고 올바른 경로를 다시 채우는 시간이 든다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '복구 비용', '예측 실패 뒤 잘못된 작업을 취소하고 올바른 실행 흐름을 다시 만드는 데 드는 시간과 자원');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '분기 예측 실패', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정확한 상태', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 재채움', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '무효화', '잘못된 경로의 명령이 프로그램 상태에 영향을 주지 못하도록 취소하는 처리');

-- STEP 15 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '조건 분기는 실제 방향을 알기 전에도 다음 명령 주소가 항상 확정되므로 제어 해저드를 만들지 않는다.', NULL, '분기 조건의 결과가 나오기 전에 인출 단계가 어느 주소를 선택해야 하는지 생각해 보세요.', 'X', '[[제어 해저드]]는 분기처럼 다음 명령 주소가 아직 확정되지 않을 때 생긴다.\n파이프라인은 기다리거나 경로를 예측해 명령을 미리 가져올 수 있다.\n예측이 빗나가면 잘못 들어온 명령을 무효화해야 하므로 제시된 주장은 틀리다.', '조건 비교 결과가 실행 단계에서 나오는 동안 인출 단계는 순차 주소와 분기 목표 중 하나를 미리 선택해야 한다.', '분기 결과가 나오기 전에는 실제 다음 주소가 확정되지 않을 수 있다. 이 불확실성이 제어 해저드의 원인이다.', 15, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '분기 결과를 더 이른 단계에서 계산하면 어떤 이점이 있는가?', 1, 1, 'MEDIUM', '잘못된 경로로 들어오는 명령 수가 줄어 [[분기 패널티]]를 낮출 수 있다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '실제 경로를 빨리 알수록 기다리는 시간이나 무효화해야 할 명령의 수가 줄 수 있다. 대신 앞 단계의 논리와 지연이 늘어나는 비용도 검토한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '분기 패널티', '분기 때문에 파이프라인이 기다리거나 잘못 가져온 명령을 버리며 잃는 시간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '분기 결과', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '다음 PC', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '명령 인출', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '제어 해저드', '분기 등으로 다음에 실행할 명령 주소가 확정되지 않아 생기는 파이프라인 위험');

-- STEP 15 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '한 포트짜리 메모리를 명령 인출과 데이터 읽기가 공유한다. 같은 사이클에 인출 단계가 다음 명령을 읽으려 하고 메모리 단계의 load도 데이터를 읽으려 한다. 이 상황과 해법을 가장 잘 연결한 것은 무엇인가?', NULL, '두 파이프라인 단계가 같은 순간에 동일한 하드웨어를 요구하는지 확인하세요.', NULL, '한 메모리 포트를 동시에 요구하므로 [[구조적 해저드]]가 발생한다.\n명령과 데이터 메모리를 분리하거나 포트를 늘리면 충돌을 줄일 수 있다.\n자원을 추가하지 않으면 한 요청을 정지시켜 사용 시점을 나눠야 한다.', 'load의 데이터 접근을 우선하고 같은 사이클의 명령 인출을 한 번 멈추는 방식으로 기능적 충돌을 피할 수 있다.', '레지스터 값의 생산과 소비가 원인이 아니므로 데이터 포워딩으로 해결되지 않는다. 분기 방향의 불확실성도 없으므로 제어 해저드가 아니다.', 15, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '데이터 해저드이며 ALU 결과 포워딩만 추가한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '제어 해저드이며 분기 예측 결과만 바꾼다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '구조적 해저드이며 메모리 자원을 분리하거나 한쪽을 정지한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '캐시 용량 미스이며 캐시 줄의 태그만 제거한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '명령 캐시와 데이터 캐시를 분리하면 이 충돌을 줄일 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '인출과 데이터 접근이 서로 다른 [[메모리 경로]]를 사용해 같은 포트를 다투지 않기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '두 접근이 독립된 저장소와 포트를 쓰면 같은 사이클에도 함께 진행할 수 있다. 더 아래 계층에서는 다시 자원을 공유할 수 있어 전체 구조를 함께 봐야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '메모리 경로', '명령이나 데이터 요청이 저장 장치에 도달하는 하드웨어 접근 통로');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '단일 포트 메모리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '자원 복제', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 정지', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '구조적 해저드', '여러 파이프라인 작업이 같은 하드웨어 자원을 동시에 요구해 생기는 충돌');

-- STEP 15 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '파이프라인에서 두 사건이 관찰됐다. 사건 A는 분기 예측 실패 뒤 잘못 가져온 두 명령을 버린 것이다. 사건 B는 곱셈기가 하나뿐인데 두 명령이 같은 사이클에 사용하려 해 뒤 명령을 멈춘 것이다. 두 사건의 분류로 가장 적절한 것은 무엇인가?', NULL, '다음 주소의 불확실성과 하드웨어 사용 가능 수량 부족을 각각 연결하세요.', NULL, '사건 A는 잘못된 실행 경로에서 생긴 제어 해저드다.\n사건 B는 하나뿐인 곱셈기를 동시에 요구한 [[자원 충돌]]로 생긴 구조적 해저드다.\n원인을 구분해야 flush와 자원 분리 또는 stall 가운데 맞는 대응을 고를 수 있다.', 'A에는 올바른 PC로 복구하는 처리가 필요하고, B에는 곱셈기 추가나 사용 시점 분리가 필요하다.', 'A는 데이터 값이 늦어서가 아니라 경로 선택이 빗나간 문제다. B는 분기와 관계없이 실행 장치 수가 부족한 문제다.', 15, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'A는 제어 해저드, B는 구조적 해저드', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'A와 B 모두 데이터 해저드', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'A는 구조적 해저드, B는 제어 해저드', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'A와 B 모두 캐시 충돌 미스', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '구조적 해저드를 자원 추가로 해결할지 정지로 해결할지는 무엇을 비교해야 하는가?', 1, 1, 'HARD', '충돌 빈도로 줄일 실행 시간과 자원 추가의 면적·전력 같은 [[비용 대비 효과]]를 비교해야 한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '드문 충돌을 없애려고 비싼 장치를 복제하면 전체 이득이 작을 수 있다. 자주 쓰이는 병목 자원이라면 추가 비용이 정당화될 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '비용 대비 효과', '추가 자원이 만드는 성능 이득을 면적, 전력, 복잡도 증가와 함께 비교한 판단');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '해저드 분류', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '실행 장치 충돌', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '원인별 대응', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '자원 충돌', '둘 이상의 작업이 같은 하드웨어 자원을 같은 시점에 요구하는 상황');

-- STEP 15 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '분기 예측이 실패했을 때 잘못된 경로에서 파이프라인에 들어온 명령을 무효화하는 처리는 ___이다.', NULL, '선택되지 않은 경로의 명령이 상태를 바꾸기 전에 파이프라인에서 걷어 내는 동작을 떠올려 보세요.', NULL, '[[flush]]는 잘못된 경로의 명령을 파이프라인에서 무효화한다.\n예측 실패가 확인되면 올바른 주소에서 명령을 다시 가져온다.\n버린 명령과 재채움 시간 때문에 분기 예측 실패 비용이 생긴다.', '분기 뒤 순차 경로를 예측했지만 실제로 분기했다면 이미 들어온 순차 경로 명령을 취소한다.', 'stall은 진행을 잠시 멈추는 동작이고 forwarding은 데이터 전달이다. 예측 실패로 이미 들어온 잘못된 명령을 없애는 동작과 구분해야 한다.', 15, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'flush');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '플러시');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '분기 예측 성공 시에는 왜 같은 무효화 비용이 발생하지 않는가?', 1, 1, 'MEDIUM', '미리 가져온 명령이 실제 실행할 [[정확한 경로]]에 속하므로 그대로 진행할 수 있기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '예측한 다음 PC와 실제 다음 PC가 같으면 가져온 명령을 버릴 이유가 없다. 예측 조회 비용 자체는 남지만 실패 복구는 피한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '정확한 경로', '분기 결과에 따라 프로그램이 실제로 실행해야 하는 명령 흐름');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '잘못된 경로', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '분기 복구', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '파이프라인 재시작', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, 'flush', '파이프라인에 들어온 잘못된 경로의 명령을 무효화하는 처리');

-- STEP 16. 한 명령 흐름으로 병목 진단하기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (16, '한 명령 흐름으로 병목 진단하기', 3, @computer_architecture_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@computer_architecture_quiz_step_id, 'CPU 실행 시간은 명령어 수, 명령어당 평균 사이클 수, 클록 주기의 곱으로 볼 수 있다. 캐시 미스와 해저드 정지는 CPI를 높이므로 각 원인이 더한 사이클을 비교해 큰 병목부터 개선해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CONCEPT', '실행 시간을 이루는 세 요소', '같은 작업에서도 실행한 명령어 수가 많거나 명령 하나당 평균 사이클이 크거나 한 사이클이 길면 시간이 늘어난다. 한 요소만 보고 전체 성능을 단정하면 다른 요소의 변화를 놓친다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'EXAMPLE', '정지 사이클을 원인별로 더하기', '측정 항목을 서로 겹치지 않게 분류한 단순 모델에서는 기본 실행 사이클에 캐시 미스 대기, 데이터 해저드 정지, 분기 복구 사이클을 더해 총 사이클을 구할 수 있다. 각 항목의 크기는 개선 가능한 효과를 비교하는 출발점이 된다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@computer_architecture_briefing_id, 'CAUTION', '작은 부분만 빠르게 만들 때', '실행 시간에서 비중이 작은 부분을 크게 개선해도 전체 절감은 제한된다. 실제 프로세서는 여러 대기를 겹쳐 숨길 수 있으므로 같은 사이클을 두 원인에 중복 계산하지 말고, 이번 문제처럼 항목이 별도로 주어졌을 때만 단순 합산한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 16 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '명령어 수와 클록 주기가 같고 전체 정지 사이클의 대부분이 캐시 미스에서 생긴다면, 캐시 미스 정지를 줄이는 것은 전체 실행 시간을 줄이는 데 직접 도움이 된다.', NULL, '전체 사이클에서 가장 큰 비중을 차지하는 대기 항목이 줄 때 곱셈식이 어떻게 변하는지 보세요.', 'O', '캐시 미스 대기가 줄면 총 사이클과 [[평균 CPI]]가 함께 낮아질 수 있다.\n명령어 수와 클록 주기가 같다면 총 사이클 감소는 실행 시간 감소로 이어진다.\n특히 큰 비중의 정지를 개선할수록 전체 효과가 크다.', '기본 1000사이클에 캐시 대기 800사이클이 붙는 실행에서 대기의 절반을 줄이면 400사이클을 절약한다.', '캐시 미스는 파이프라인을 기다리게 해 실제 실행 사이클을 늘린다. 다른 조건이 같다면 이 대기를 줄여도 시간이 변하지 않는다고 볼 수 없다.', 16, 1, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '캐시 미스 횟수와 미스 한 번의 대기 시간 중 무엇을 먼저 줄일지 어떻게 판단하는가?', 1, 1, 'HARD', '각각의 변화가 줄이는 총 사이클을 계산해 [[기여도]]가 큰 개선을 우선한다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '대략적인 미스 대기 사이클은 미스 횟수와 미스당 패널티의 곱으로 볼 수 있다. 비용과 부작용이 비슷하다면 더 큰 곱을 줄이는 쪽이 효과적이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '기여도', '특정 원인이 전체 실행 시간이나 사이클에서 차지하는 몫');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '총 실행 사이클', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '캐시 미스 패널티', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '성능 병목', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '평균 CPI', '프로그램 전체에서 명령 하나를 완료하는 데 든 평균 클록 사이클 수');

-- STEP 16 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '프로그램의 클록 주기를 10퍼센트 줄이는 개선은 명령어 수와 CPI가 어떻게 변하든 항상 전체 실행 시간을 10퍼센트 줄인다.', NULL, '실행 시간 곱셈식의 다른 두 요소가 개선과 함께 바뀔 가능성도 포함하세요.', 'X', '실행 시간은 클록 주기뿐 아니라 명령어 수와 CPI에도 좌우되는 [[곱셈 관계]]다.\n주기를 줄이는 설계가 CPI를 높이거나 명령 경로를 바꾸면 효과가 상쇄될 수 있다.\n다른 요소가 고정됐을 때만 주기 변화 비율을 실행 시간에 그대로 적용할 수 있다.', '클록 주기가 짧아져도 깊어진 파이프라인의 분기 정지로 CPI가 충분히 커지면 전체 시간은 덜 줄거나 늘 수 있다.', '클록만 따로 보고 항상 같은 비율의 향상을 약속할 수 없다. 비교하려면 변경 뒤 명령어 수와 CPI까지 넣어 실행 시간을 다시 계산해야 한다.', 16, 2, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '두 CPU의 GHz 숫자만으로 같은 프로그램의 실행 속도를 비교하기 어려운 이유는 무엇인가?', 1, 1, 'MEDIUM', '클록당 진행량과 실행 명령 수가 달라질 수 있어 [[클록 속도]]만으로 총 시간을 알 수 없기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '높은 주파수는 한 사이클이 짧다는 뜻이지만 같은 일을 더 많은 사이클이나 더 많은 명령으로 수행하면 이점이 줄 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '클록 속도', '초당 발생하는 프로세서 클록 사이클의 수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '클록 주기', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '주파수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '성능 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '곱셈 관계', '실행 시간이 명령어 수, CPI, 클록 주기의 곱으로 결정되는 관계');

-- STEP 16 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '어떤 실행은 명령 1000개, 기본 CPI 1로 1000사이클이 필요하다. 여기에 캐시 미스 정지 800사이클과 분기 실패 정지 100사이클이 더해져 총 1900사이클이 된다. 다른 영향과 개선 비용이 같다면 가장 큰 사이클 절감을 만드는 선택은 무엇인가?', NULL, '각 개선이 없애는 사이클을 전체 1900사이클에서 직접 빼서 비교하세요.', NULL, '캐시 미스 정지를 절반으로 줄이면 800사이클 중 400사이클을 절감한다.\n분기 정지를 모두 없애도 절감은 100사이클이고 기본 실행의 10퍼센트도 100사이클이다.\n전체 시간에서 가장 큰 몫을 차지한 [[병목]]을 줄일 때 개선 폭이 크다.', '캐시 개선 뒤 총 사이클은 1000+400+100=1500으로 줄어 네 선택 중 가장 작다.', '분기 정지 제거와 기본 실행 10퍼센트 절감은 각각 100사이클만 줄인다. 명령 수를 1퍼센트 줄이는 효과는 기본 CPI가 같다면 약 10사이클 수준이다.', 16, 3, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '분기 실패 정지 100사이클을 모두 없앤다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '캐시 미스 정지 800사이클을 절반으로 줄인다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '기본 실행 1000사이클을 10퍼센트 줄인다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, '명령어 수 1000개를 1퍼센트 줄이고 다른 값은 유지한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '캐시 정지를 완전히 없앨 수 없고 절반만 줄일 수 있어도 우선순위가 높을 수 있는 이유는 무엇인가?', 1, 1, 'HARD', '개선 가능한 비율보다 실제로 줄어드는 [[절대 사이클 수]]가 전체 속도 향상을 결정하기 때문이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '작은 항목의 100퍼센트와 큰 항목의 50퍼센트를 비교할 때는 퍼센트만 보지 말고 각각 몇 사이클인지 계산해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '절대 사이클 수', '비율이 아니라 실제로 추가되거나 제거되는 클록 사이클의 개수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '병목 우선순위', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정지 기여도', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '개선 폭 계산', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '병목', '전체 실행 시간이나 처리량을 가장 크게 제한해 우선 개선 가치가 큰 부분');

-- STEP 16 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '같은 워크로드를 실행한다. CPU A는 명령 100개에 기본 실행 100사이클, 캐시 정지 40사이클, 분기 정지 10사이클이 들고 클록 주기는 1ns다. CPU B는 명령 120개에 기본 실행 120사이클, 캐시 정지 10사이클, 분기 정지 10사이클이 들고 클록 주기는 0.9ns다. 다른 영향이 없을 때 가장 정확한 비교는 무엇인가?', NULL, '각 CPU에서 기본 사이클과 두 정지를 더한 뒤 서로 다른 한 사이클의 길이를 곱하세요.', NULL, 'A는 100+40+10인 150사이클에 1ns를 곱해 150ns가 걸린다.\nB는 120+10+10인 140사이클에 0.9ns를 곱해 126ns가 걸린다.\nB는 명령어 수가 더 많아도 정지와 주기를 함께 반영한 [[총 CPU 실행 시간]]이 더 짧다.', '같은 결과를 만드는 워크로드이므로 150ns와 126ns를 직접 비교할 수 있고 CPU B가 24ns 먼저 끝난다.', '명령어 수, 정지 사이클, 클록 주기 중 하나만 보면 결론이 달라질 수 있다. 모든 사이클 기여도를 더한 뒤 실제 시간으로 바꿔야 한다.', 16, 4, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU A의 명령어 수가 더 적으므로 계산 없이 CPU A가 더 빠르다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU A는 150ns, CPU B는 140ns이므로 CPU B가 10ns 더 빠르다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU A는 150ns, CPU B는 126ns이므로 CPU B가 더 빠르다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU B는 명령 120개에 0.9ns를 곱한 108ns이므로 정지 사이클은 무시해도 된다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, 'CPU B의 정지를 포함한 명령당 평균 사이클 수는 얼마인가?', 1, 1, 'HARD', '총 140사이클을 명령 120개로 나눈 [[유효 CPI]]는 약 1.17이다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '기본 실행뿐 아니라 캐시와 분기 정지도 실제 완료에 든 사이클에 포함한다. 140÷120은 약 1.1667이므로 소수 둘째 자리에서 반올림하면 1.17이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '유효 CPI', '기본 처리와 실제 정지를 모두 포함해 명령 하나당 사용한 평균 사이클 수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, 'CPU 실행 시간 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정지 사이클 합산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '유효 CPI', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '총 CPU 실행 시간', '주어진 CPU에서 기본 처리와 정지에 든 사이클을 모두 합산해 계산한 실행 시간');

-- STEP 16 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '명령 100개의 기본 CPI가 1이라 기본 실행은 100사이클이다. 캐시 미스 정지 30사이클과 load-use 정지 20사이클이 더해졌다면, 추가 정지 50사이클을 명령 수로 나눈 0.5의 CPI 기여분을 ___라고 한다.', NULL, '기본 실행에 더해진 대기 사이클을 명령 수로 나누어 전체 평균에 더하는 항의 이름을 생각해 보세요.', NULL, '[[정지 CPI]]는 추가 정지 사이클을 실행 명령어 수로 나눈 평균 기여분이다.\n이 예에서는 (30+20)÷100으로 0.5이며 전체 CPI는 기본 1에 이를 더한 1.5다.\n원인별 정지 CPI를 비교하면 명령당 시간을 가장 크게 늘린 병목을 찾을 수 있다.', '캐시 정지 CPI는 30÷100인 0.3이고 load-use 정지 CPI는 20÷100인 0.2이므로 캐시 쪽 기여가 더 크다.', '0.5는 한 사이클의 길이나 총 명령 수가 아니다. 기본 처리 외에 생긴 대기를 명령 하나당 평균으로 환산한 값이다.', 16, 5, @computer_architecture_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @computer_architecture_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, '정지 CPI');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@computer_architecture_quiz_id, 1, 'stall CPI');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@computer_architecture_quiz_id, '이 실행에서 같은 비율만큼 줄일 수 있다면 어느 정지 원인을 먼저 개선하는 편이 유리한가?', 1, 1, 'HARD', '캐시 정지가 명령당 0.3으로 더 큰 [[정지 기여도]]를 가지므로 같은 비율 개선에서는 캐시 쪽 절감이 크다.');
SET @computer_architecture_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@computer_architecture_follow_up_id, '해설', 'TEXT', '두 원인을 절반씩 줄일 수 있다면 캐시는 15사이클, load-use는 10사이클을 줄인다. 개선 비용과 다른 영향이 같다는 조건에서 절대 절감량이 큰 쪽을 고른다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@computer_architecture_follow_up_id, '정지 기여도', '특정 정지 원인이 전체 평균 사이클과 실행 시간에 더하는 몫');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '원인별 CPI 분해', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '정지 사이클', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@computer_architecture_quiz_id, '병목 기여도', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@computer_architecture_quiz_id, '정지 CPI', '추가 정지 사이클을 실행 명령어 수로 나눈 명령당 평균 대기 사이클');

DROP TEMPORARY TABLE computer_architecture_seed_guard;

-- #320: 사람이 승인한 자료구조 저작 콘텐츠를 라이브 코스로 발행한다.
-- 로컬 auto-increment ID를 복사하지 않고 LAST_INSERT_ID()로 부모·자식 관계를 연결한다.
-- 저작용 outline/draft/revision/job 및 사용자 데이터는 포함하지 않는다.

CREATE TEMPORARY TABLE data_structures_seed_guard (
    id INT NOT NULL PRIMARY KEY
);
INSERT INTO data_structures_seed_guard (id) VALUES (1);

-- 같은 제목의 코스가 이미 있으면 PK 충돌로 발행을 중단한다.
INSERT INTO data_structures_seed_guard (id)
SELECT 1 WHERE (SELECT COUNT(*) FROM course WHERE title = '자료구조') <> 0;

INSERT INTO course (title, category, created_at, updated_at)
VALUES ('자료구조', 'CS', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_course_id = LAST_INSERT_ID();

-- STEP 1. 키로 찾기 — 해시 맵과 해시 셋을 고르는 기준
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (1, '키로 찾기 — 해시 맵과 해시 셋을 고르는 기준', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '해시 맵은 키로 값을 찾고, 해시 셋은 어떤 원소가 있는지만 확인한다. 반복 조회가 많은지, 순서가 필요한지, 전체를 한 번 훑는지에 따라 리스트와 해시 구조를 선택해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '값이 필요하면 맵, 존재만 보면 셋', '고객 ID로 고객 정보를 찾는 요구에는 키와 값의 연결이 필요하므로 맵이 잘 맞는다. 차단된 토큰 ID인지 확인하는 요구에는 원소의 존재만 중요하므로 셋이 의도를 더 직접 드러낸다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '반복 조회와 한 번의 순회를 구분한다', '큰 목록에서 주문 ID를 수천 번 찾는다면 매번 처음부터 비교하는 비용이 커질 수 있어 해시 맵 색인이 유용하다. 반대로 작은 목록을 저장된 순서대로 한 번 출력할 뿐이라면 리스트를 그대로 순회하는 편이 단순하다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '해시 구조에 순서를 자동 기대하지 않는다', '일반적인 해시 맵과 해시 셋의 핵심 계약은 빠른 키 조회이지 삽입 순서나 정렬 순서가 아니다. 특정 언어의 구현이 순서를 보존하더라도 이를 보편 법칙으로 단정하지 말고 필요한 순서 계약에 맞는 구조를 고른다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 1 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '일반적인 해시 맵은 키 조회를 주된 계약으로 하며, 별도의 순서 계약이 없다면 삽입 순서대로 순회된다고 보장할 수 없다.', NULL, '빠른 키 조회라는 목적과 자료를 방문하는 순서에 대한 약속을 구분해 보세요.', 'O', '일반적인 해시 맵의 핵심 계약은 키를 이용한 조회다.\n삽입한 순서에 대한 [[순서 보장]]은 별도 계약이 없으면 기대할 수 없다.\n순회 순서가 요구 사항이라면 그 순서를 명시적으로 지원하는 구현을 골라야 한다.', '접수된 로그를 입력 순서대로 다시 보여 줘야 한다면 순서를 보존한다는 계약을 따로 확인해야 한다.', '일부 해시 맵 구현은 삽입 순서를 기억하지만 모든 구현의 보편 성질은 아니다. 사용 중인 구조가 필요한 순서를 계약으로 제공하는지 확인해야 한다.', 1, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '삽입 순서를 유지하면서 키 조회도 자주 해야 한다면 어떤 선택을 할 수 있는가?', 1, 1, 'MEDIUM', '삽입 순서를 계약으로 제공하는 [[순서 유지 구현]]을 고르거나 순서용 목록을 함께 관리할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '키 조회와 삽입 순서 순회는 서로 다른 요구다. 한 구현이 둘을 모두 계약할 수도 있고, 조회용 맵과 순서용 목록을 조합할 수도 있지만 갱신 시 두 구조를 일관되게 유지해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '순서 유지 구현', '자료를 넣은 순서 같은 특정 방문 순서를 계약으로 보존하는 자료구조 구현');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '삽입 순서', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '구현 계약', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '요구 사항 확인', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '순서 보장', '자료를 순회할 때 어떤 순서로 나오는지를 자료구조가 계약으로 약속하는 성질');

-- STEP 1 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '서비스가 고객 ID를 받을 때마다 해당 고객의 현재 프로필을 찾아야 한다. ID와 프로필을 연결한 해시 맵은 이 요구를 표현하기에 알맞다.', NULL, '조회에 사용하는 식별자와 그 식별자로 얻어야 하는 정보가 각각 무엇인지 나누어 보세요.', 'O', '고객 ID는 찾을 때 사용하는 키이고 프로필은 그 키에 연결된 값이다.\n해시 맵은 이런 [[키-값 매핑]]을 표현해 ID로 프로필을 조회하게 한다.\n좋은 분포와 적절한 적재율에서는 반복 조회의 평균 비용도 작게 유지할 수 있다.', '주문 ID를 키로, 주문 상태 객체를 값으로 두면 상태 확인 요청마다 전체 주문 목록을 훑지 않아도 된다.', '키와 값의 연결이 필요한 상황을 원소 존재 여부만으로 표현하면 프로필을 따로 다시 찾아야 한다. 조회 결과로 어떤 정보가 필요한지 먼저 확인해야 한다.', 1, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '고객 이름보다 고객 ID가 키로 더 적합한 경우가 많은 이유는 무엇인가?', 1, 1, 'MEDIUM', '이름은 중복되거나 바뀔 수 있지만 [[안정된 식별자]]는 한 대상을 계속 구분하도록 설계할 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '키가 중복되면 어느 고객을 뜻하는지 모호해지고, 저장 뒤 값이 바뀌면 다시 찾기 어려울 수 있다. 고유성과 변경 가능성을 함께 살펴야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '안정된 식별자', '대상을 고유하게 구분하며 사용하는 동안 의미가 바뀌지 않도록 정한 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '식별자 선택', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 조회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '값 연결', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '키-값 매핑', '하나의 키를 그 키로 찾아야 하는 값과 연결하는 관계');

-- STEP 1 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'API 서버는 폐기된 접근 토큰 ID 목록을 보관한다. 요청마다 주어진 ID가 목록에 있는지만 확인하며 ID에 연결해 돌려줄 추가 정보는 없다. 가장 의도가 분명한 자료구조는 무엇인가?', NULL, '조회 결과로 연결된 값이 필요한지, 원소가 들어 있는지만 알면 되는지 확인하세요.', NULL, '이 요구는 토큰 ID가 존재하는지만 묻고 연결된 값을 사용하지 않는다.\n해시 셋은 원소의 포함 여부인 [[멤버십 검사]]를 직접 표현한다.\n적절한 해싱 조건에서는 요청마다 전체 목록을 선형으로 훑는 일을 피할 수 있다.', '폐기할 ID를 셋에 추가하고 요청 ID가 셋에 포함되는지 확인하면 차단 여부를 판단할 수 있다.', '불필요한 참 값을 모든 키에 붙인 맵도 구현은 가능하지만 요구를 덜 직접 표현한다. 정렬이나 위치별 접근도 이 판단에 필요하지 않다.', 1, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '모든 토큰 ID에 의미 없는 true 값을 붙인 정렬 배열', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '토큰 ID를 원소로 담는 해시 셋', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '요청할 때마다 처음부터 끝까지 읽는 연결 리스트', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '토큰 ID를 삽입 시각 순으로만 꺼내는 큐', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 토큰 ID를 셋에 여러 번 추가해도 원소가 하나로 보이는 이유는 무엇인가?', 1, 1, 'EASY', '셋은 같은 원소를 여러 자리로 세지 않는 [[중복 제거]] 의미를 가지기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '셋은 원소의 존재를 표현한다. 이미 있는 ID를 다시 추가해도 그 ID가 존재한다는 상태는 달라지지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '중복 제거', '같다고 판단한 여러 입력을 하나의 원소로 유지하는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '포함 여부', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '중복 없는 원소', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '차단 목록', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '멤버십 검사', '주어진 원소가 집합에 포함되어 있는지 확인하는 연산');

-- STEP 1 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '설정 파일에서 읽은 항목 40개를 저장된 순서대로 한 번씩 검사해 모두 출력한다. 실행 중에는 특정 키로 다시 찾지 않는다. 가장 단순하고 적절한 선택은 무엇인가?', NULL, '조회용 색인을 만드는 비용이 실제 처리에서 반복해서 회수되는지 살펴보세요.', NULL, '모든 항목을 저장된 순서대로 한 번 방문하므로 키 조회가 필요하지 않다.\n리스트의 [[전체 순회]]만으로 요구를 해결하면 추가 색인 구성 비용을 피할 수 있다.\n해시 구조는 반복 키 조회가 생길 때 다시 검토해도 늦지 않다.', '파일을 읽은 순서대로 검증 메시지를 출력하는 작업은 각 항목을 한 번 방문하면 끝난다.', '사용하지 않을 빠른 조회를 위해 맵을 만들거나 정렬하면 준비 작업만 늘어난다. 셋은 항목의 값과 중복을 원래 모습대로 보존하려는 요구에도 맞지 않을 수 있다.', 1, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '모든 항목을 해시 맵으로 옮긴 뒤 키 조회 없이 맵 전체를 순회한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '항목을 리스트에 두고 저장된 순서대로 한 번 순회한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '항목을 키 순서로 정렬한 뒤에도 원래 저장 순서라고 가정한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '중복과 연결된 값을 버리고 해시 셋의 존재 여부만 출력한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '나중에 같은 40개 항목을 키로 수천 번 조회해야 한다면 무엇을 추가할 수 있을까?', 1, 1, 'MEDIUM', '원래 순서의 리스트는 유지하면서 키에서 항목으로 가는 [[보조 인덱스]]를 만들 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '하나의 자료구조가 모든 요구를 맡을 필요는 없다. 순회용 목록과 조회용 맵을 함께 두면 갱신 시 두 구조를 일관되게 관리해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '보조 인덱스', '원본 자료를 유지하면서 특정 키 조회를 빠르게 하려고 덧붙이는 검색 구조');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '한 번의 순회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '색인 구성 비용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '자료구조 조합', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '전체 순회', '자료구조의 원소를 처음부터 끝까지 한 번씩 방문하는 처리');

-- STEP 1 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '정렬되지 않은 리스트에서 목표 키를 찾으려고 첫 원소부터 하나씩 비교하며, 목표가 없으면 n개를 모두 확인하는 탐색을 ___이라고 한다.', NULL, '별도의 색인 없이 목록의 앞에서부터 후보를 차례로 확인하는 방식입니다.', NULL, '[[선형 탐색]]은 목록의 원소를 차례로 비교해 목표를 찾는 방식이다.\n정렬되지 않은 n개 목록에서 목표가 없으면 n번의 비교가 필요하다.\n반복 조회가 많다면 해시 색인 구성 비용과 이 반복 비용을 비교해야 한다.', '고객 100명의 목록에서 존재하지 않는 ID를 찾으면 최악에는 100개 항목을 모두 확인한다.', '키로 곧바로 후보 위치를 좁히는 해시 조회나 정렬된 범위를 반씩 줄이는 탐색이 아니다. 앞에서부터 하나씩 확인하는 흐름을 묻는다.', 1, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '선형 탐색');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'linear search');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '리스트에 이진 탐색을 적용하려면 어떤 조건이 먼저 필요한가?', 1, 1, 'MEDIUM', '비교 기준에 따라 원소가 놓여 있다는 [[정렬 전제]]가 필요하다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '중간값과 목표를 비교한 뒤 한쪽 절반을 버리려면 어느 쪽에 더 작은 값과 큰 값이 있는지 보장되어야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '정렬 전제', '탐색 전에 원소가 정해진 비교 순서대로 배치되어 있어야 한다는 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최악 O(n)', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '반복 조회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '색인 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '선형 탐색', '목표를 찾을 때까지 원소를 앞에서부터 하나씩 비교하는 탐색 방식');

-- STEP 2. 해시 키의 동일성 — 동등성과 해시값 계약
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (2, '해시 키의 동일성 — 동등성과 해시값 계약', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '해시 구조는 해시값으로 후보 위치를 좁힌 뒤 동등성 비교로 실제 키를 확인한다. 같은 키는 같은 해시값을 가져야 하지만 같은 해시값의 서로 다른 키도 있을 수 있으며, 저장된 키가 바뀌면 조회가 깨질 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '동등성과 해시값의 방향을 지킨다', '프로그램이 두 키를 같다고 판단한다면 두 키의 해시값도 같아야 한다. 반대 방향은 성립하지 않는다. 해시값은 가능한 값의 수가 제한되어 서로 다른 키가 같은 값을 받을 수 있으므로 마지막에는 동등성 비교가 필요하다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '대소문자를 무시하는 사용자 이름', 'ADMIN과 admin을 같은 키로 본다면 동등성 비교뿐 아니라 해시 계산도 같은 정규화 규칙을 사용해야 한다. 한쪽만 대소문자를 무시하면 같은 키가 서로 다른 후보 위치로 가 조회에 실패할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '저장한 키의 기준 필드를 바꾸지 않는다', '해시 계산이나 동등성에 쓰는 필드를 저장 뒤 바꾸면 키의 현재 해시값과 저장된 위치가 어긋날 수 있다. 가능하면 바뀌지 않는 식별자를 키로 쓰고, 꼭 변경해야 한다면 기존 항목을 제거한 뒤 새 키로 다시 넣는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 2 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '프로그램이 두 키를 동등하다고 판단하도록 정의했다면, 해시 맵에서 두 키의 해시값도 같게 계산되어야 한다.', NULL, '같다고 보는 두 키가 서로 다른 후보 위치로 흩어질 때 조회가 어떻게 되는지 생각해 보세요.', 'O', '동등한 키는 같은 해시값을 가져야 한다는 [[해시 계약]]을 지켜야 한다.\n그래야 저장할 때와 조회할 때 같은 후보 위치를 찾을 수 있다.\n동등성 기준을 바꾸면 해시 계산도 그 기준과 함께 맞춰야 한다.', '회원 번호가 같은 두 키 객체를 같은 키로 본다면 두 객체의 해시 계산도 같은 회원 번호를 사용해야 한다.', '동등한 키가 서로 다른 해시값을 가지면 조회가 다른 위치부터 시작해 이미 저장된 항목을 찾지 못할 수 있다. 두 규칙은 따로 설계해도 되는 독립 조건이 아니다.', 2, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '계약을 어긴 키로 저장한 값을 같은 논리 키로 조회하지 못할 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '해시값이 다르면 조회가 저장된 항목과 다른 [[버킷]]부터 확인할 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '해시 구조는 모든 키를 처음부터 비교하지 않고 해시값으로 후보를 좁힌다. 동등한 키가 다른 후보로 가면 마지막 동등성 비교 기회도 얻지 못한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '버킷', '해시값을 이용해 키와 값을 배치하거나 탐색하는 후보 위치 또는 묶음');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '동등한 키', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '해시 일관성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '조회 후보', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '해시 계약', '동등한 키라면 반드시 같은 해시값을 가져야 한다는 규칙');

-- STEP 2 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '두 키의 해시값이 같다면 두 키는 반드시 동등하므로, 실제 키 내용을 다시 비교할 필요가 없다.', NULL, '많은 가능한 키를 제한된 수의 해시값으로 바꿀 때 서로 다른 입력이 만날 수 있는지 살펴보세요.', 'X', '같은 해시값을 받은 서로 다른 키가 존재할 수 있다.\n이 현상을 [[해시 충돌]]이라고 하며 해시값만으로 동등성을 확정할 수 없다.\n후보 위치를 찾은 뒤 실제 키 비교로 원하는 항목인지 확인해야 한다.', '서로 다른 주문 번호가 우연히 같은 버킷에 들어가도 두 주문을 같은 주문으로 합치면 안 된다.', '해시값은 빠르게 후보를 좁히는 요약값이지 고유 식별자라는 보장이 없다. 같은 값이 나온 뒤에도 동등성 비교가 남는다.', 2, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '모든 키에 같은 해시값을 반환해도 동등성 계약 자체는 지킬 수 있을까?', 1, 1, 'HARD', '가능하지만 모든 키가 같은 후보에 모이는 [[나쁜 분포]] 때문에 조회 성능이 크게 나빠질 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '동등한 키가 같은 해시값을 가져야 한다는 조건은 만족한다. 그러나 서로 다른 키까지 모두 같은 곳에 모여 매번 많은 키를 비교하게 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '나쁜 분포', '해시값이 일부 위치에 몰려 충돌과 비교 횟수가 커지는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '충돌 가능성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최종 키 비교', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '해시 분포', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '해시 충돌', '동등하지 않은 여러 키가 같은 해시값이나 후보 위치를 갖는 현상');

-- STEP 2 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '사용자 이름의 대소문자를 무시해 ADMIN과 admin을 같은 키로 취급하는 맵을 만든다. 동등성 비교와 해시 계산을 가장 알맞게 설계한 것은 무엇인가?', NULL, '같다고 판단할 두 입력이 저장과 조회에서 같은 대표 형태를 사용하도록 두 규칙을 맞추세요.', NULL, '동등성 비교와 해시 계산은 같은 대소문자 규칙을 사용해야 한다.\n두 문자열을 같은 대표 형태로 바꾸는 [[정규화]]를 양쪽에 적용하면 계약을 지킬 수 있다.\n원본 문자열의 대소문자만으로 해시하면 동등한 키가 다른 위치로 갈 수 있다.', '두 이름을 모두 소문자 형태로 비교하고 그 소문자 형태로 해시하면 ADMIN과 admin이 같은 결과를 얻는다.', '비교와 해시 중 한쪽에만 대소문자 무시 규칙을 적용하면 두 규칙이 어긋난다. 객체의 메모리 위치를 사용해도 요구한 논리적 키 관계를 표현하지 못한다.', 2, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '비교만 대소문자를 무시하고 해시는 원본 문자열 그대로 계산한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '해시만 소문자로 계산하고 비교는 원본 문자열이 완전히 같을 때만 통과시킨다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '비교와 해시 계산 모두 같은 방식으로 대소문자를 정규화한다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '두 규칙 모두 사용자 이름 대신 객체가 놓인 메모리 위치만 사용한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '정규화된 문자열을 키로 저장하면 어떤 장점이 있는가?', 1, 1, 'MEDIUM', '여러 입력 표현을 하나의 [[대표 표현]]으로 통일해 비교와 해시가 같은 기준을 쓰기 쉬워진다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '입력 시점에 규칙을 한 번 적용하면 이후 조회에서도 같은 변환을 재사용할 수 있다. 어떤 문자 변환 규칙을 쓸지는 요구사항에 맞춰 명시해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '대표 표현', '서로 같은 것으로 볼 여러 입력을 비교하기 위해 통일한 형태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '대소문자 무시', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '일관된 해싱', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 정규화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '정규화', '서로 같은 의미의 입력을 정해진 하나의 형태로 바꾸는 과정');

-- STEP 2 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '이메일 주소를 동등성과 해시 계산에 쓰는 User 객체를 해시 맵의 키로 넣은 뒤, 같은 객체의 이메일을 바꾸자 조회가 실패하기 시작했다. 가장 안전한 개선은 무엇인가?', NULL, '저장 위치를 정한 값이 삽입 뒤 달라졌을 때 현재 계산 결과와 기존 위치가 어긋나는지 살펴보세요.', NULL, '해시 기준 필드가 바뀌면 객체의 현재 해시값과 저장 당시 위치가 달라질 수 있다.\n이런 [[가변 키]]는 새 값과 옛 값 어느 쪽으로도 안정적으로 찾기 어렵다.\n바뀌지 않는 사용자 ID를 키로 쓰거나 제거 후 새 키로 다시 넣어야 한다.', '사용자 정보는 값으로 갱신하되 맵의 키는 생성 뒤 바뀌지 않는 사용자 번호로 두면 위치 계약을 유지할 수 있다.', '객체 안의 이메일만 바꾼다고 해시 테이블이 자동으로 새 위치로 옮겨 주지는 않는다. 조회할 때 전체 테이블을 무조건 훑게 만드는 것도 해시 맵의 목적을 해친다.', 2, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '변하지 않는 사용자 ID를 키로 쓰고 이메일은 값의 필드로 갱신한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '키 객체의 이메일만 바꾼 뒤 테이블이 자동 재배치되었다고 가정한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '조회가 실패할 때마다 모든 버킷을 선형으로 훑도록 강제한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '이메일을 바꿀 때 동등성만 수정하고 해시 계산은 이전 규칙으로 둔다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '변경한 키가 이전 이메일로도 새 이메일로도 검색되지 않을 수 있는 이유는 무엇인가?', 1, 1, 'HARD', '항목은 옛 해시 위치에 남았지만 현재 키 상태는 달라져 정상 탐색으로 [[도달 불가]]가 될 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '새 이메일은 새 해시 위치를 찾으므로 옛 위치를 보지 않을 수 있다. 옛 이메일로 옛 위치를 보더라도 바뀐 객체와 동등하지 않아 일치하지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '도달 불가', '자료는 남아 있지만 정상 조회 규칙으로 해당 항목을 찾을 수 없는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '불변 키', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '재삽입', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '안정된 식별자', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '가변 키', '해시 구조에 저장된 뒤 동등성이나 해시 계산에 쓰는 상태가 바뀔 수 있는 키');

-- STEP 2 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '서로 다른 두 CustomerKey 객체가 같은 고객 ID 42를 담고 있어 맵에서 같은 논리 키로 취급된다. 객체의 위치가 달라도 프로그램 규칙상 같은 값으로 판단하는 관계를 ___이라고 한다.', NULL, '두 참조가 같은 객체를 가리키는지가 아니라 키의 내용이 같은 의미를 나타내는지 보는 관계입니다.', NULL, '[[동등성]]은 서로 다른 객체가 프로그램의 비교 기준에서 같은 값을 나타내는 관계다.\n고객 ID를 기준으로 삼으면 별도 객체라도 ID 42가 같을 때 같은 키로 볼 수 있다.\n해시 맵은 해시값으로 후보를 찾은 뒤 이 관계로 실제 키를 확인한다.', '요청에서 새로 만든 CustomerKey(42)도 이미 저장된 CustomerKey(42)와 동등하면 같은 고객 항목을 찾을 수 있다.', '두 변수가 완전히 같은 객체를 가리키는지 묻는 것이 아니다. 별도 객체의 내용이 정한 비교 규칙에서 같은지를 묻는다.', 2, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '동등성');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'equality');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '객체 동일성과 동등성은 어떻게 다른가?', 1, 1, 'MEDIUM', '[[객체 동일성]]은 같은 객체 자체를 가리키는지 보고 동등성은 정한 값 비교 규칙을 만족하는지 본다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '내용이 같은 두 별도 객체는 동등할 수 있지만 동일한 객체는 아니다. 해시 키의 요구에 따라 어떤 필드로 동등성을 정할지 명시해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '객체 동일성', '두 참조가 메모리에서 같은 객체 하나를 가리키는 관계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '논리 키', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '객체 동일성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '값 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '동등성', '프로그램이 정한 값 비교 기준에서 두 객체를 같다고 보는 관계');

-- STEP 3. 충돌은 오류가 아니다 — 체이닝과 개방 주소법
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (3, '충돌은 오류가 아니다 — 체이닝과 개방 주소법', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '해시 충돌은 서로 다른 키가 같은 위치 후보를 얻는 정상적인 상황이다. 체이닝은 한 버킷에 여러 항목을 함께 관리하고, 개방 주소법은 테이블 안의 다른 칸을 정한 순서로 살핀다. 어느 방법이든 해시값만 믿지 않고 키의 동등성을 확인해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '두 가지 충돌 처리', '체이닝은 같은 버킷의 항목들을 별도 모음으로 관리한다. 개방 주소법은 충돌하면 테이블의 다른 칸을 차례로 탐사한다. 구체적인 모음 구조와 탐사 순서는 구현에 따라 다를 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '찾기는 키 비교까지', 'A와 B의 해시값이 같아도 서로 다른 키일 수 있다. 조회는 후보 위치에 도착한 뒤 저장된 키와 찾는 키가 같은지 비교해야 한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '삭제가 탐색을 끊지 않게', '개방 주소법에서는 중간 항목을 단순히 빈 칸으로 만들면 뒤쪽 항목을 못 찾을 수 있다. 삭제 표식은 비어 있지만 탐색은 계속해야 한다는 뜻을 남긴다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 3 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '서로 다른 두 상품 코드가 같은 해시값을 얻어도, 해시 테이블이 키 비교로 둘을 구분해 저장할 수 있다.', NULL, '해시값은 저장 위치의 후보를 좁히는 값이지 키 자체는 아닙니다.', 'O', '[[해시 충돌]]은 서로 다른 키가 같은 해시값이나 위치 후보를 얻는 상황이다.\n충돌은 가능한 정상 상황이므로 해시 테이블은 여러 후보를 다룰 방법을 둔다.\n마지막에는 키의 동등성을 비교해야 원하는 항목을 정확히 고를 수 있다.', '상품 코드 P10과 Q20이 같은 버킷 후보를 얻어도 키 비교 결과가 다르면 별도 항목으로 저장한다.', '충돌이 생겼다고 데이터가 바로 손상되거나 두 키가 같아지는 것은 아니다. 충돌 처리와 키 비교가 올바르면 둘을 구분할 수 있다.', 3, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '해시값을 고유 ID처럼 사용하면 왜 위험한가?', 1, 1, 'MEDIUM', '해시값은 여러 입력이 같게 나올 수 있는 [[요약값]]이므로 원래 키를 대신하는 고유 식별자가 아니다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '가능한 키의 수가 해시값 범위보다 많거나 매핑이 겹칠 수 있다. 따라서 해시값이 같다는 이유만으로 같은 대상을 가리킨다고 판단하면 다른 키를 합칠 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '요약값', '입력 데이터를 일정한 범위의 값으로 줄여 표현한 결과');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '버킷', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '충돌 처리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '해시 충돌', '서로 다른 키가 같은 해시값이나 같은 저장 위치 후보를 얻는 상황');

-- STEP 3 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '체이닝 방식에서는 같은 버킷 후보를 얻은 여러 항목을 함께 관리하고, 조회할 때 그 안에서 키를 비교할 수 있다.', NULL, '한 위치 후보에 항목 하나만 둘 수 있다고 가정하지 마세요.', 'O', '[[체이닝]]은 같은 버킷에 대응하는 여러 항목을 별도의 모음으로 관리하는 방식이다.\n조회는 해시값으로 버킷을 고른 뒤 그 안의 키들을 비교한다.\n모음을 연결 리스트로 만들지 다른 구조로 만들지는 구현에 따라 달라질 수 있다.', '동일한 버킷에 주문 키 세 개가 모여도 각 키를 비교하면 원하는 주문을 고를 수 있다.', '체이닝은 충돌한 뒤의 항목을 버리거나 덮어쓰는 방식이 아니다. 한 버킷에 대응하는 여러 항목을 구분해 보관한다.', 3, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '한 버킷에 항목이 많이 몰리면 조회 비용은 어떻게 달라지는가?', 1, 1, 'MEDIUM', '같은 버킷에서 비교할 항목이 늘어 [[버킷 탐색]]에 필요한 키 비교 횟수가 커질 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '해시 계산으로 버킷을 바로 골라도 버킷 안에서 여러 후보를 확인해야 한다. 항목이 고르게 퍼지지 않으면 평균 조회 비용이 커지는 이유다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '버킷 탐색', '선택한 버킷 안에서 원하는 키를 비교해 찾는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '버킷', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 동등성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '충돌 목록', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '체이닝', '같은 버킷에 대응하는 여러 항목을 별도 모음으로 관리하는 충돌 처리 방식');

-- STEP 3 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '키 A와 B의 시작 버킷이 모두 2다. A가 이미 저장된 뒤 B도 보관하려 할 때, 체이닝과 개방 주소법의 처리 비교로 가장 정확한 것은?', NULL, '충돌 뒤 새 항목을 어디에 보관하는지가 두 방식의 핵심 차이입니다.', NULL, '체이닝은 버킷 2에 대응하는 모음 안에 A와 B를 구분해 둔다.\n개방 주소법은 탐사 규칙으로 B가 들어갈 다른 테이블 칸을 찾는다.\n충돌 뒤 항목을 두는 [[충돌 배치]] 방식이 서로 다르다.', '선형 탐사를 쓰는 개방 주소법이라면 2번 칸이 찼을 때 다음 후보 칸들을 확인하지만, 체이닝은 2번 버킷의 모음에 B를 추가할 수 있다.', '두 방식 모두 A를 덮어쓰거나 B를 버리지 않는다. 체이닝은 버킷별 모음을 쓰고 개방 주소법은 테이블 배열 안의 다른 후보 칸을 찾는다.', 3, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '두 방식 모두 충돌한 B로 A를 덮어써 한 항목만 남긴다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '체이닝은 B를 다른 배열 칸에 두고, 개방 주소법은 2번 버킷 밖의 별도 모음에 둔다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '두 방식 모두 같은 시작 버킷을 얻은 서로 다른 키는 함께 저장할 수 없다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '체이닝은 2번 버킷의 모음에 둘을 보관하고, 개방 주소법은 탐사해 B의 다른 테이블 칸을 찾는다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '체이닝과 개방 주소법 중 어느 방식이 항상 더 빠르다고 단정할 수 있는가?', 1, 1, 'HARD', '데이터 분포와 적재율, 메모리 사용 방식 같은 [[선택 전제]]가 달라 어느 하나가 항상 더 빠르다고 단정할 수 없다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '체이닝은 버킷별 모음을 관리하고 개방 주소법은 테이블 안을 탐사한다. 충돌 분포, 삭제 빈도, 적재 상태와 메모리 목표에 따라 실제 비용이 달라진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '선택 전제', '자료구조의 성능을 비교할 때 먼저 정해야 하는 데이터와 사용 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '버킷별 모음', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '테이블 내부 탐사', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '충돌 처리 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '충돌 배치', '같은 시작 위치를 얻은 여러 항목을 구분해 보관하는 방법');

-- STEP 3 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '개방 주소법 테이블에서 A, B, C가 같은 시작 위치에서 차례로 탐사되어 저장되었다. B를 삭제한 뒤에도 C 조회를 안전하게 하려면 어떻게 해야 하는가?', NULL, 'C를 찾는 조회가 B가 있던 칸에서 멈추어도 되는지 생각해 보세요.', NULL, '개방 주소법의 조회는 정해진 [[탐사 경로]]를 따라 후보 칸을 확인한다.\n중간의 B 칸을 처음부터 비었던 칸처럼 만들면 조회가 거기서 끝나 C를 놓칠 수 있다.\n삭제 표식을 두면 B는 없지만 뒤쪽 후보까지 계속 확인해야 함을 나타낼 수 있다.', 'A 다음 칸의 B를 삭제 표식으로 바꾸면 C 조회는 그 칸을 지나 다음 후보 칸까지 진행한다.', '중간 칸을 완전한 빈 칸으로 바꾸거나 뒤 항목을 무시하면 탐색 연결이 끊긴다. 모든 항목을 무조건 삭제할 필요도 없다.', 3, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'B의 칸을 처음부터 비어 있던 칸으로 표시하고 조회를 즉시 끝낸다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'B의 칸에 삭제 표식을 남겨 조회가 C의 칸까지 계속되게 한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'B를 삭제할 때 같은 시작 위치를 가진 A와 C도 함께 삭제한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'C를 찾을 때는 해시값을 무시하고 테이블 전체를 항상 처음부터 읽는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '새 항목을 넣을 때 삭제 표식 칸을 재사용할 수 있는가?', 1, 1, 'MEDIUM', '삽입 규칙이 허용하면 삭제 표식 칸을 [[재사용 표식]]으로 활용할 수 있지만 조회는 그 칸만 보고 멈추면 안 된다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '삭제 표식은 현재 항목이 없다는 정보와 과거 탐사 경로가 이어졌다는 정보를 함께 담는다. 삽입은 그 자리를 후보로 기억할 수 있고 조회는 필요한 범위까지 계속 진행한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '재사용 표식', '삽입에 다시 쓸 수 있으면서 조회 경로는 이어졌음을 나타내는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '삭제 표식', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '탐사 연속성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '조회 종료', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '탐사 경로', '충돌했을 때 정한 규칙에 따라 차례로 확인하는 테이블 칸의 순서');

-- STEP 3 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '별도 버킷 모음을 두지 않고 모든 항목을 테이블 배열 안에 저장하며, 충돌하면 정한 순서로 다른 칸을 확인하는 방식을 ___이라고 한다.', NULL, '충돌한 항목이 원래 테이블 밖의 모음이 아니라 다른 빈 칸을 찾아 들어가는 방식입니다.', NULL, '[[개방 주소법]]은 충돌한 항목이 테이블 안의 다른 칸을 탐사해 저장되는 방식이다.\n조회도 삽입과 맞는 탐사 규칙을 따라 키 후보를 확인한다.\n항목이 몰리거나 삭제 표식이 많아지면 확인할 칸 수가 늘 수 있다.', '시작 칸이 차 있으면 다음 후보 칸들을 살펴 빈 칸을 찾아 항목을 저장한다.', '한 버킷에 대응하는 별도 모음에 충돌 항목을 넣는 방식은 체이닝이다. 여기서는 항목이 테이블 배열의 다른 칸으로 이동한다.', 3, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '개방 주소법');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'open addressing');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '비슷한 시작 위치의 항목이 연속된 칸에 몰리면 어떤 문제가 생길 수 있는가?', 1, 1, 'HARD', '항목이 가까이 뭉치는 [[군집화]]가 커지면 빈 칸이나 키를 찾기 위해 확인할 칸 수가 늘 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '한 번 형성된 덩어리에 새 충돌 항목이 붙으면 탐사 구간이 더 길어질 수 있다. 정도는 해시 분포와 탐사 규칙, 적재 상태에 따라 달라진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '군집화', '개방 주소 테이블에서 사용 중인 칸들이 가까운 구간에 뭉치는 현상');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '탐사', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '테이블 배열', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '군집화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '개방 주소법', '충돌하면 테이블 배열 안의 다른 칸을 탐사해 저장하는 방식');

-- STEP 4. 평균 O(1)의 조건 — 적재율, 리사이즈, 최악의 경우
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (4, '평균 O(1)의 조건 — 적재율, 리사이즈, 최악의 경우', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '해시 테이블 조회와 삽입의 평균 O(1)은 좋은 해시 분포와 관리되는 적재율을 전제로 한 기대 성능이다. 항목이 늘면 더 큰 테이블로 옮기는 리사이즈가 한 번에 비싸도, 드물게 수행하면 여러 삽입에 나눈 상각 비용은 작을 수 있다. 모든 키가 한곳에 몰리는 경우처럼 최악에는 한 번의 조회가 O(n)이 될 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '평균 성능의 전제', '기준 연산을 키 조회나 삽입 한 번으로 잡으면, 항목이 고르게 퍼지고 적재 상태가 관리될 때 확인할 후보 수가 평균적으로 작다. 그래서 기대 평균 시간을 O(1)로 설명한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '리사이즈를 나누어 보기', '테이블이 찰 때 더 큰 공간을 만들고 기존 항목을 옮기는 삽입은 비쌀 수 있다. 그러나 크기를 일정 비율로 키워 드물게 옮기면 긴 삽입 구간의 총비용을 연산 수로 나눈 상각 비용은 평균 O(1)이 될 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '보장이 아닌 기대값', '평균 O(1)은 모든 입력과 매 순간에 대한 상한이 아니다. 나쁜 분포나 높은 적재 상태에서는 비교나 탐사 횟수가 늘고, 최악에는 n개를 확인할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 4 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '키가 대체로 고르게 퍼지고 적재율이 관리된다는 전제에서, 해시 테이블의 키 조회 한 번은 기대 평균 O(1)로 볼 수 있다.', NULL, '복잡도 표현 앞에 붙은 전제와 기준 연산을 함께 확인하세요.', 'O', '[[기대 시간]]은 가능한 해시 분포나 입력 상황을 고려한 평균적인 연산 시간이다.\n키가 고르게 퍼지고 적재율이 관리되면 조회할 후보 수가 평균적으로 작다.\n따라서 키 조회 한 번을 기대 평균 O(1)로 설명할 수 있다.', '회원 ID가 여러 버킷에 고르게 분산되면 대부분의 조회는 소수의 후보만 비교한다.', '평균 O(1)은 매 조회가 항상 같은 횟수로 끝난다는 뜻이 아니다. 분포와 적재 상태라는 전제가 깨지면 비용이 커질 수 있다.', 4, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '기대 평균 O(1)을 최악 O(1) 보장으로 읽으면 왜 안 되는가?', 1, 1, 'MEDIUM', '평균 계산에는 입력과 분포에 대한 [[확률적 전제]]가 들어가지만 최악 상한은 가장 불리한 경우도 제한해야 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '대부분의 키가 잘 퍼져도 특정 입력에서는 많은 키가 같은 후보로 몰릴 수 있다. 평균값이 작다는 사실만으로 가장 긴 탐색의 상한이 상수가 되지는 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '확률적 전제', '평균 성능을 계산할 때 입력이나 해시 분포가 따를 것으로 보는 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '평균 복잡도', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 조회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '분포 전제', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '기대 시간', '가능한 입력이나 무작위 선택의 분포를 고려해 계산한 평균 실행 시간');

-- STEP 4 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '해시 테이블의 적재율이 1에 가까워질수록 빈 공간이 줄기 때문에 조회와 삽입 성능은 모든 충돌 처리 방식에서 항상 좋아진다.', NULL, '공간을 더 채우는 효과와 충돌 후보가 늘어나는 효과를 함께 생각해 보세요.', 'X', '적재율이 높아지면 충돌 후보나 [[탐사 비용]]이 커질 수 있다.\n특히 빈 칸을 찾는 방식은 여유 칸이 적을수록 더 많은 칸을 확인할 수 있다.\n적절한 기준에서 크기를 조정하는 정책은 시간과 공간의 균형을 관리한다.', '개방 주소 테이블이 거의 차면 새 항목을 넣을 빈 칸을 찾기까지 긴 구간을 살필 수 있다.', '더 많이 채우면 공간 이용률은 높아지지만 연산이 항상 빨라지는 것은 아니다. 충돌 처리 비용이 증가할 수 있으므로 진술은 틀리다.', 4, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '리사이즈를 시작하는 적재율은 모든 해시 테이블에서 같은가?', 1, 1, 'MEDIUM', '충돌 처리와 시간·공간 목표가 다르므로 [[리사이즈 기준]]은 구현과 정책에 따라 달라질 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '체이닝과 개방 주소법은 높은 적재율의 영향이 같지 않다. 사용하는 메모리와 허용할 탐색 비용을 고려해 기준을 정하므로 하나의 수치를 보편 법칙으로 볼 수 없다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '리사이즈 기준', '테이블 크기를 바꾸기로 결정하는 적재 상태나 정책 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '빈 칸', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '충돌 증가', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '시간-공간 절충', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '탐사 비용', '개방 주소법에서 원하는 키나 빈 칸을 찾기 위해 확인하는 칸 수에 따른 비용');

-- STEP 4 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '버킷 16개인 해시 테이블에 항목 12개가 있다. 정책은 적재율이 0.70을 넘으면 리사이즈한다. 현재 판단으로 옳은 것은?', NULL, '저장된 항목 수를 버킷 수로 나눈 뒤 정책 기준과 비교하세요.', NULL, '[[적재율]]은 저장된 항목 수를 버킷이나 테이블 칸 수로 나눈 비율이다.\n현재 값은 12÷16=0.75다.\n0.75는 정책 기준 0.70을 넘으므로 리사이즈 조건에 해당한다.', '버킷 수가 16으로 그대로이고 항목이 8개라면 적재율은 0.50이다.', '16÷12로 계산하거나 12와 16을 더하면 적재율 정의와 맞지 않는다. 0.75가 0.70보다 작다는 비교도 틀리다.', 4, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '적재율은 0.75이며 정책 기준을 넘으므로 리사이즈 조건에 해당한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '적재율은 약 1.33이며 정책 기준을 넘지 않으므로 그대로 둔다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '적재율은 0.25이며 빈 버킷이 있으므로 반드시 그대로 둔다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '적재율은 28이며 항목 수가 버킷 수보다 작으므로 계산할 필요가 없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 적재율이라도 체이닝과 개방 주소법의 비용이 다를 수 있는 이유는?', 1, 1, 'HARD', '충돌 항목을 두는 위치와 찾는 과정인 [[충돌 처리 구조]]가 달라 비교 횟수와 빈 칸의 영향이 다르다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '체이닝은 버킷별 모음에서 키를 비교한다. 개방 주소법은 테이블 칸을 탐사하며, 여유 칸이 줄면 긴 탐사가 생길 수 있어 같은 수치가 같은 비용을 뜻하지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '충돌 처리 구조', '같은 위치 후보를 얻은 항목들을 저장하고 조회하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '리사이즈 정책', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비율 계산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '용량 관리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '적재율', '해시 테이블의 저장 항목 수를 버킷이나 테이블 칸 수로 나눈 비율');

-- STEP 4 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '테이블이 찰 때 용량을 일정 비율로 늘리고 모든 기존 항목을 옮긴다. m번 삽입 동안 리사이즈가 드물게 일어나 전체 기대 비용이 O(m)이라면 가장 정확한 설명은?', NULL, '비싼 한 번의 비용과 긴 연산 묶음의 평균 비용을 구분하세요.', NULL, '[[상각 분석]]은 여러 연산의 총비용을 연산 수에 나누어 연산당 비용을 본다.\n리사이즈가 일어난 한 번의 삽입은 기존 항목 수에 비례해 비쌀 수 있다.\nm번 삽입의 전체 기대 비용이 O(m)이면 삽입당 상각 기대 비용은 O(1)이다.', '일부 삽입이 많은 항목을 옮겨도 그 비용을 앞뒤의 싼 삽입들과 함께 나누어 평가한다.', '상각 O(1)은 리사이즈가 공짜이거나 모든 삽입이 최악 O(1)이라는 뜻이 아니다. 전체 O(m)을 삽입 m번에 나눈 결과다.', 4, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '모든 삽입은 예외 없이 최악 O(1)이며 항목을 옮기는 비용은 없다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '전체 기대 비용이 O(m)이므로 삽입 한 번의 상각 비용은 O(m)이다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '리사이즈 한 번은 비쌀 수 있지만 삽입당 상각 기대 비용은 O(1)이다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '리사이즈가 한 번이라도 있으면 m번 삽입의 전체 비용은 반드시 O(m²)이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '리사이즈가 발생한 바로 그 삽입의 비용은 왜 클 수 있는가?', 1, 1, 'MEDIUM', '기존의 많은 항목을 새 테이블에 다시 배치하는 [[개별 최악 비용]]을 한 연산이 부담할 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '새 공간을 준비하고 기존 항목의 위치를 다시 정하면 당시 항목 수에 비례한 작업이 필요할 수 있다. 상각 분석은 이 순간의 지연을 없애지 않고 긴 구간에 나누어 평가한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '개별 최악 비용', '연산 묶음의 평균과 별개로 특정 한 연산이 부담할 수 있는 가장 큰 비용');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '리사이즈', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '총비용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '연산당 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '상각 분석', '연속된 여러 연산의 총비용을 나누어 연산당 비용을 평가하는 방법');

-- STEP 4 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '체이닝 해시 테이블의 n개 키가 모두 한 버킷에 모였다. 없는 키를 조회하며 그 버킷의 n개 키를 전부 비교한다면, 이 조회 한 번의 시간 복잡도는 ___이다.', NULL, '기준 연산을 키 비교로 두고 최악 상황에서 비교한 항목 수가 n에 따라 어떻게 늘어나는지 보세요.', NULL, 'n개 키를 모두 비교하는 조회는 [[선형 시간]]이 필요하다.\n기준 연산인 키 비교가 n번까지 늘므로 시간 복잡도는 O(n)이다.\n이 사례는 기대 평균 O(1)이 최악 성능 보장은 아님을 보여 준다.', '키 100개가 같은 버킷에 있고 목표가 없으면 최대 100개 키를 확인한다.', '버킷 위치를 한 번에 계산해도 그 안의 키 비교가 남는다. 비교 횟수가 n에 비례하므로 O(1)이나 O(log n)으로 볼 수 없다.', 4, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'O(n)');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '선형 시간');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'linear time');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '좋은 해시 분포를 사용하면 최악 O(n)이 사라진다고 단정할 수 있는가?', 1, 1, 'HARD', '좋은 분포는 몰림 가능성을 줄이는 [[분포 개선]]이지만 모든 가능한 입력의 최악 상한을 자동으로 상수로 만들지는 않는다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '실제 평균 성능은 좋아질 수 있지만 서로 다른 키들이 같은 후보로 몰리는 경우 자체가 논리적으로 없어지는 것은 아니다. 평균과 최악을 따로 보고 요구 사항에 맞는 구조를 골라야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '분포 개선', '키들이 특정 위치에 몰리지 않도록 해시 결과를 더 고르게 만드는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최악 복잡도', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 비교 횟수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '충돌 집중', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '선형 시간', '입력 크기 n에 비례해 기준 연산 수가 늘어나는 O(n) 시간');

-- STEP 5. 트리로 표현할 수 있는 관계
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (5, '트리로 표현할 수 있는 관계', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '트리는 하나의 루트에서 부모-자식 관계로 내려가는 계층을 표현한다. 한 노드와 그 아래 후손들은 부분 트리를 이룬다. 깊이와 높이는 간선 수를 기준으로 정의할 수 있지만, 다른 기준을 쓰는 자료도 있으므로 계산 전에 기준을 확인해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '위에서 아래로 보는 계층', '루트는 부모가 없는 시작 노드다. 루트가 아닌 각 노드는 부모 하나와 연결되고 자식은 여러 개일 수 있다. 파일 폴더 구조나 단일 보고 체계가 대표 사례다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '깊이와 높이의 방향', '간선 수 기준에서 노드의 깊이는 루트부터 그 노드까지의 거리다. 노드의 높이는 그 노드부터 가장 먼 잎까지의 거리다. 따라서 루트 깊이는 0이고 잎 높이는 0이다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '모든 관계가 트리는 아니다', '한 대상이 여러 부모를 가지거나 관계가 순환하면 일반적인 트리 규칙에 맞지 않는다. 이런 의존 관계는 그래프로 표현하는 편이 자연스럽다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 5 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '루트 A 아래에 자식 B가 있고 B 아래에 자식 C가 있다면, B를 시작으로 한 부분 트리에는 C만 포함되고 시작 노드 B는 포함되지 않는다.', NULL, 'B를 기준으로 위에 있는 A와 아래에 있는 C의 관계를 각각 구분해 보세요.', 'X', '[[부분 트리]]는 한 노드와 그 노드 아래의 모든 후손으로 이루어진다.\nB를 시작으로 보면 B 자신과 자식 C가 포함된다.\nB의 부모인 A는 B 아래의 후손이 아니므로 포함되지 않는다.', '프로젝트 폴더 아래 src 폴더를 고르면 src와 그 안의 모든 파일·하위 폴더가 하나의 부분 트리다.', '시작 노드 자신을 빼거나 부모까지 포함하면 범위를 잘못 잡은 것이다. 해당 노드와 아래 후손만 묶는다.', 5, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'C 아래에 자식이 없다면 C는 무엇이라고 부르는가?', 1, 1, 'EASY', '자식이 없는 C는 계층의 끝에 있는 [[잎 노드]]다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '잎 노드는 더 내려갈 자식이 없는 노드다. 루트도 자식이 하나도 없는 단일 노드 트리라면 동시에 잎이 될 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '잎 노드', '자식이 하나도 없는 트리 노드');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '후손', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '계층 범위', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '잎 노드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '부분 트리', '한 노드와 그 아래의 모든 후손으로 이루어진 트리의 일부');

-- STEP 5 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '한 문서 노드가 폴더 X와 폴더 Y의 자식으로 동시에 연결되어야 해도, 문서 하나를 복제하지 않고 일반적인 단일 부모 트리로 그 관계를 그대로 표현할 수 있다.', NULL, '루트가 아닌 한 노드가 일반적인 트리에서 가질 수 있는 부모 수를 확인하세요.', 'X', '일반적인 트리에서 루트가 아닌 각 노드는 부모 하나만 갖는다.\n문서 하나가 X와 Y에 함께 연결되는 [[공유 관계]]는 부모가 둘이어서 이 경계를 벗어난다.\n문서를 두 노드로 복제하면 같은 대상 하나라는 뜻과 변경 일관성을 잃을 수 있다.', '직원 한 명이 두 프로젝트 조직에 동시에 소속되는 관계도 단일 부모 계층 하나만으로는 그대로 나타내기 어렵다.', '일반적인 단일 부모 트리는 한 노드가 두 부모와 직접 연결되는 공유 관계를 허용하지 않는다. 복제는 서로 다른 두 문서처럼 보이게 하므로 관계를 그대로 보존한 것도 아니다.', 5, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 문서를 X와 Y 아래에 각각 복제해 저장하면 갱신할 때 어떤 위험이 생기는가?', 1, 1, 'MEDIUM', '한 복사본만 고치면 같은 대상을 나타내는 값들이 달라지는 [[중복 상태]]가 생길 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '복제된 두 노드는 자동으로 같은 대상임을 보장하지 않는다. 공유 대상을 한 번만 저장하고 여러 관계가 그 대상을 가리키게 할 수 있는 모델이 필요한지 판단해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '중복 상태', '같은 대상을 여러 곳에 복사해 서로 다른 값으로 어긋날 수 있는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다중 부모', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '모델 경계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '대상 공유', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '공유 관계', '하나의 대상을 여러 상위 대상이 함께 연결해 가리키는 관계');

-- STEP 5 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '간선 수를 기준으로 깊이를 센다. 루트 회사에서 팀, 서비스, 로그 파일 노드까지 차례로 내려간다면 로그 파일의 깊이는 얼마인가?', NULL, '노드의 개수가 아니라 루트에서 목표까지 건넌 연결의 개수를 세세요.', NULL, '노드의 [[깊이]]는 루트에서 해당 노드까지의 거리다.\n회사→팀→서비스→로그 파일 경로에는 간선이 3개 있다.\n간선 수 기준이므로 로그 파일의 깊이는 3이다.', '같은 기준에서 회사 루트의 깊이는 건넌 간선이 없으므로 0이다.', '경로의 노드 네 개를 세면 4가 되지만 문제는 간선 수 기준이다. 높이는 아래 잎까지의 거리이므로 이 계산과 방향이 다르다.', 5, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '4', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '3', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '1', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '0', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '어떤 자료가 루트 깊이를 1로 표시한다면 계산 전에 무엇을 확인해야 하는가?', 1, 1, 'MEDIUM', '간선 수인지 노드 수인지 그 자료가 정한 [[깊이 기준]]을 먼저 확인해야 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '용어는 같아도 시작값을 다르게 정하는 자료가 있다. 문제나 문서의 정의를 확인하고 같은 기준을 끝까지 적용해야 한 단계 차이 오류를 피할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '깊이 기준', '루트부터 노드까지의 거리를 간선이나 노드 중 무엇으로 세는지 정한 규칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '루트', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '간선 수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '경로 거리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '깊이', '루트에서 특정 노드까지의 경로 거리');

-- STEP 5 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '프로젝트 조직도에서 총괄 책임자가 시작점이고, 팀장 T 바로 아래에 개발자 D와 E가 연결되어 있다. 이 관계를 가장 정확하게 읽은 것은?', NULL, '바로 위에 연결된 노드와 바로 아래에 연결된 노드의 역할을 구분하세요.', NULL, '트리의 [[부모-자식 관계]]는 서로 바로 위아래로 연결된 노드 사이의 관계다.\nT 바로 아래에 D와 E가 있으므로 T는 두 노드의 부모다.\nD와 E는 같은 부모 T를 둔 자식들이며 서로의 부모는 아니다.', '폴더 docs 바로 아래에 a.txt와 b.txt가 있으면 docs는 두 파일 노드의 부모다.', '연결 방향을 뒤집으면 T와 개발자들의 역할이 바뀐다. 같은 부모 아래의 D와 E를 서로의 부모로 볼 수도 없다.', 5, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'D와 E는 T의 부모이고 T는 두 노드의 자식이다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'D는 E의 부모이고 E는 T의 부모다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'D와 E가 둘이면 T는 부모가 될 수 없다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'T는 D와 E의 부모이고 D와 E는 T의 자식이다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '총괄 책임자처럼 트리의 시작점이며 부모가 없는 노드는 무엇인가?', 1, 1, 'EASY', '부모가 없이 전체 계층의 시작점이 되는 노드를 [[루트]]라고 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '일반적인 트리는 루트 하나에서 시작해 아래로 뻗는다. 루트가 아닌 각 노드는 부모 하나를 가지지만 루트에는 부모가 없다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '루트', '트리에서 부모가 없고 전체 계층의 시작점이 되는 노드');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '부모', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '자식', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '형제 노드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '부모-자식 관계', '트리에서 서로 바로 위아래로 연결된 두 노드의 계층 관계');

-- STEP 5 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '간선 수를 기준으로 한다. 폴더 P에서 가장 먼 파일까지 내려가는 경로가 4개의 간선을 지난다면, P의 ___는 4이다.', NULL, '루트에서 P까지가 아니라 P에서 가장 먼 잎까지 아래로 내려가는 거리를 묻습니다.', NULL, '노드의 [[높이]]는 그 노드에서 가장 먼 잎까지의 최대 거리다.\nP에서 가장 먼 파일까지 간선이 4개이므로 P의 값은 4다.\n같은 간선 기준에서 자식이 없는 잎의 값은 0이다.', '폴더 P의 한 경로가 2단계이고 다른 경로가 4단계라면 더 긴 4단계가 기준이 된다.', '루트에서 P까지의 거리는 깊이다. 이 문제는 P 아래에서 가장 먼 잎까지의 최대 거리를 묻는다.', 5, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '높이');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'height');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '노드 하나만 있는 트리의 높이는 간선 수 기준에서 얼마인가?', 1, 1, 'MEDIUM', '루트이자 잎인 노드에서 자신까지 건너는 연결이 없으므로 [[간선 기준]] 높이는 0이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '가장 먼 잎이 노드 자신이고 이동한 간선이 없다. 노드 수를 쓰는 다른 정의도 있을 수 있으므로 실제 문서나 문제의 기준을 먼저 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '간선 기준', '경로의 거리를 지나간 연결의 개수로 세는 규칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최대 경로', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '잎', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '깊이와 높이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '높이', '한 노드에서 가장 먼 잎까지의 최대 경로 거리');

-- STEP 6. 이진 트리의 모양과 이진 탐색 트리의 순서
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (6, '이진 트리의 모양과 이진 탐색 트리의 순서', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '이진 트리는 각 노드의 자식이 최대 두 개라는 모양을 말한다. 이진 탐색 트리는 여기에 왼쪽과 오른쪽 부분 트리의 키 순서 규칙을 더하며, 중복키를 어디에 둘지는 설계에서 따로 정해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '자식 수와 키 순서는 다른 조건이다', '노드마다 왼쪽과 오른쪽 자식을 최대 하나씩 두면 이진 트리다. 이 조건만으로 키의 크기 관계는 정해지지 않는다. 이진 탐색 트리가 되려면 각 노드에서 왼쪽 부분 트리와 오른쪽 부분 트리의 모든 키가 정해 둔 순서 조건을 만족해야 한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '중위 순회로 순서 조건을 확인한다', '서로 다른 키를 쓰고 왼쪽은 현재 키보다 작고 오른쪽은 크다고 정한 BST를 중위 순회하면 키가 오름차순으로 나온다. 이는 왼쪽 부분 트리, 현재 노드, 오른쪽 부분 트리 순서로 방문하기 때문이다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '같은 키의 처리 규칙을 명시한다', '중복키를 금지할 수도 있고 한 노드에 개수나 값 목록을 둘 수도 있으며 한쪽 부분 트리로 보내는 규칙을 정할 수도 있다. 어느 선택도 모든 BST에 자동 적용되지 않는다. 삽입, 탐색, 삭제, 순회가 같은 정책을 따라야 결과를 예측할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 6 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '각 노드가 자식을 최대 두 개만 가지는 트리는 키의 배치 순서와 관계없이 모두 이진 탐색 트리다.', NULL, '노드의 자식 개수를 제한하는 조건과 탐색 방향을 결정하는 키 조건을 따로 살펴보세요.', 'X', '[[이진 트리]]는 각 노드가 가질 수 있는 자식 수를 최대 두 개로 제한한다.\n이 조건만으로 왼쪽 키가 작고 오른쪽 키가 크다는 순서는 생기지 않는다.\n이진 탐색 트리가 되려면 별도의 키 배치 규칙도 모든 부분 트리에서 지켜야 한다.', '루트 5의 왼쪽 자식이 9인 트리는 자식 수 조건은 만족하지만 왼쪽에 더 작은 키를 둔다는 BST 규칙은 만족하지 않는다.', '이진이라는 말은 자식 수에 관한 모양 조건이다. 빠른 방향 선택에 필요한 키 순서는 이진 탐색 트리가 추가로 요구하는 조건이다.', 6, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'BST의 키 순서 조건이 탐색에서 한쪽 부분 트리를 건너뛰게 해 주는 이유는 무엇인가?', 1, 1, 'MEDIUM', '현재 키와 찾는 키를 비교하면 답이 있을 수 없는 쪽을 제외하는 [[탐색 가지치기]]가 가능하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '찾는 키가 현재 키보다 작다면 더 큰 키만 있는 쪽은 볼 필요가 없다. 단, 이 판단은 트리 전체가 같은 순서 조건을 지킬 때만 안전하다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '탐색 가지치기', '조건상 답이 있을 수 없는 탐색 범위를 더 살펴보지 않고 제외하는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '이진 트리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '탐색 방향', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'BST 불변식', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '이진 트리', '각 노드가 왼쪽과 오른쪽 자식을 최대 하나씩 가질 수 있는 트리');

-- STEP 6 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '루트가 8이고 왼쪽 자식 3의 오른쪽 자식이 10인 트리는, 각 노드와 바로 아래 자식의 방향만 맞으므로 올바른 BST다.', NULL, '10이 바로 위의 3뿐 아니라 조상 8이 정한 왼쪽 부분 트리의 범위에도 맞는지 확인하세요.', 'X', 'BST의 [[부분 트리 범위]]는 바로 위 부모뿐 아니라 모든 조상의 조건을 함께 반영한다.\n10은 부모 3보다 커서 오른쪽에 놓였지만 루트 8의 왼쪽 부분 트리에는 들어갈 수 없다.\n따라서 가까운 부모와의 비교만 맞는다고 전체 트리가 올바른 BST가 되지는 않는다.', '루트 20의 왼쪽 부분 트리에 있는 모든 키는 그 안의 부모 관계와 별개로 20보다 작아야 한다.', '3과 10의 관계만 보면 10의 위치가 맞아 보인다. 그러나 10은 루트 8보다 크면서 8의 왼쪽에 있으므로 전체 순서 조건을 어긴다.', 6, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '재귀적으로 BST 유효성을 검사할 때 3의 오른쪽 자식에는 어떤 값 범위를 넘길 수 있는가?', 1, 1, 'HARD', '루트 8의 왼쪽이라는 [[상한 조건]]과 3의 오른쪽이라는 하한 조건을 함께 넘겨 3보다 크고 8보다 작은 값만 허용한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '루트에서 왼쪽으로 갈 때 최대 허용값은 8이 된다. 다시 3의 오른쪽으로 가면 최소 허용값은 3이 되므로 두 조상의 범위를 모두 만족해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '상한 조건', '현재 부분 트리에 들어갈 키가 넘지 않아야 하는 조상에서 내려온 최대 경계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '조상 조건', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'BST 유효성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 범위', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '부분 트리 범위', '모든 조상의 순서 조건을 반영해 한 부분 트리에 허용되는 키의 구간');

-- STEP 6 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서로 다른 키를 쓰는 BST가 있다. 루트는 8이고, 왼쪽 자식 3의 자식은 왼쪽 1과 오른쪽 6이며, 오른쪽 자식 10은 오른쪽 자식 14만 가진다. 이 트리를 중위 순회한 결과는 무엇인가?', NULL, '각 노드에서 왼쪽 부분을 모두 방문한 뒤 현재 키와 오른쪽 부분을 처리하세요.', NULL, '중위 순회는 왼쪽 부분 트리, 현재 노드, 오른쪽 부분 트리 순으로 진행한다.\n왼쪽에서는 1, 3, 6이 나오고 루트 8 뒤에 오른쪽의 10, 14가 이어진다.\n따라서 [[재귀 순회]] 결과는 1, 3, 6, 8, 10, 14다.', '루트 8을 기록하기 전에 왼쪽의 3을 같은 규칙으로 순회하므로 1과 3과 6이 먼저 나온다.', '8부터 시작하는 순서는 루트를 먼저 방문하는 전위 순회에 가깝다. 중위 순회에서는 왼쪽 부분 트리를 끝낸 뒤 루트를 기록한다.', 6, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '8, 3, 1, 6, 10, 14', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '1, 6, 3, 14, 10, 8', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '1, 3, 6, 8, 10, 14', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '8, 10, 14, 3, 6, 1', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '찾는 키 7이 이 BST에 없다면 탐색은 어디에서 끝나는가?', 1, 1, 'MEDIUM', '키 비교가 가리킨 다음 자식이 없는 [[빈 연결]]에 도달하면 해당 키가 없다고 판단한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '7은 8보다 작아 3으로 가고 3보다 커 6으로 간다. 다시 6보다 크므로 오른쪽을 보지만 자식이 없어서 탐색을 끝낸다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '빈 연결', 'BST 탐색 방향에 다음 자식 노드가 존재하지 않는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '중위 순회 추적', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '재귀 방문', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '탐색 종료', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '재귀 순회', '현재 노드의 부분 트리에도 같은 방문 규칙을 반복 적용하는 트리 탐색 방식');

-- STEP 6 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '상품 가격을 키로 쓰는 BST에 같은 가격의 상품도 모두 보관해야 한다. 같은 키를 어디에 둘지 정해지지 않은 현재 설계를 가장 안전하게 고치는 방법은 무엇인가?', NULL, '같은 키의 저장 위치와 탐색과 순회가 모두 따를 수 있는 하나의 계약을 찾으세요.', NULL, 'BST의 [[중복키 정책]]은 저장 요구에 맞게 명시적으로 정해야 한다.\n가격 노드 하나에 같은 가격의 상품 목록을 두면 키 순서와 여러 상품 보존을 함께 표현할 수 있다.\n삽입과 탐색과 삭제가 모두 같은 정책을 따라야 누락과 순회 혼란을 막는다.', '가격 10000인 노드의 값으로 상품 ID 목록을 두고 같은 가격이 들어오면 그 목록에 추가할 수 있다.', '중복을 임의로 왼쪽과 오른쪽에 섞으면 탐색 경로가 일정하지 않다. 중복을 무조건 버리면 모든 상품을 보관한다는 요구를 어긴다.', 6, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '같은 가격의 상품은 요구와 관계없이 항상 버린다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '같은 키를 삽입할 때마다 무작위로 왼쪽이나 오른쪽에 보낸다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '가격 노드에 같은 가격의 상품 목록을 두고 모든 연산이 이 규칙을 따르게 한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '이진 트리는 중복 순서를 자동으로 정하므로 별도 규칙을 두지 않는다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 가격 안에서도 등록 순서를 안정적으로 유지해야 한다면 어떤 정보를 더 둘 수 있을까?', 1, 1, 'HARD', '가격과 함께 증가하는 등록 번호를 비교하는 [[복합 키]]나 노드 내부의 순서 보존 목록을 사용할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '가격만으로는 같은 값 사이의 순서가 정해지지 않는다. 등록 번호를 두 번째 기준으로 쓰거나 같은 가격의 값들을 입력 순서대로 보관해야 안정된 결과를 만들 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '복합 키', '둘 이상의 값을 정해진 우선순위로 비교해 하나의 정렬 기준으로 사용하는 키');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '중복 값 저장', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '복합 키', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '연산 계약', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '중복키 정책', '같은 키가 들어올 때 거부하거나 묶거나 한쪽에 배치하는 방법을 정한 규칙');

-- STEP 6 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '마지막 층을 제외한 모든 층이 차 있고, 마지막 층의 노드가 왼쪽부터 빈자리 없이 채워진 이진 트리 모양을 ___라고 한다.', NULL, '키의 크기 관계가 아니라 각 층의 자리가 어떤 순서로 채워지는지를 나타내는 모양의 이름입니다.', NULL, '[[완전 이진 트리]]는 마지막 층 전까지 모두 차고 마지막 층은 왼쪽부터 채워진다.\n이 조건은 노드가 놓이는 모양을 정하며 키의 대소 순서를 정하지 않는다.\n그래서 완전한 모양이라고 해서 자동으로 이진 탐색 트리가 되는 것은 아니다.', '마지막 층에 노드가 세 개라면 가장 왼쪽 자리 세 곳이 차고 그 사이에 빈자리가 없어야 한다.', '모든 층이 반드시 가득 찬 트리만을 뜻하지 않는다. 마지막 층은 덜 찰 수 있지만 오른쪽에 노드를 두고 그보다 왼쪽을 비울 수는 없다.', 6, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '완전 이진 트리');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'complete binary tree');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '완전 이진 트리 모양이 배열 저장에 잘 맞는 이유는 무엇인가?', 1, 1, 'MEDIUM', '층별로 왼쪽부터 빈자리 없이 채워져 부모와 자식의 [[배열 위치 계산]]을 규칙으로 나타낼 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '중간 빈자리가 없으므로 노드를 층 순서대로 배열에 이어 붙일 수 있다. 포인터를 따로 저장하지 않아도 인덱스로 가까운 부모와 자식 위치를 계산할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '배열 위치 계산', '노드 인덱스에서 부모나 자식의 인덱스를 일정한 식으로 구하는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '층 채우기', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '배열 표현', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '모양과 순서 구분', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '완전 이진 트리', '마지막 층 전까지 가득 차고 마지막 층은 왼쪽부터 연속해서 채워진 이진 트리');

-- STEP 7. BST의 성능은 높이에 달려 있다
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (7, 'BST의 성능은 높이에 달려 있다', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, 'BST는 한 노드에서 한쪽 부분 트리만 따라갈 수 있지만, 실제로 몇 노드를 방문하는지는 트리 높이에 달려 있다. 균형이 좋으면 높이가 log n 정도지만 한쪽으로 길게 늘어지면 선형 탐색과 비슷해진다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '연산 비용은 높이 h를 따라간다', '여기서 n은 노드 수이고 h는 루트에서 가장 깊은 리프까지의 간선 수다. 한 경로에서 방문하는 노드는 최대 h+1개다. 탐색·삽입·삭제는 이 경로를 따라가므로 상수 하나 차이를 생략해 O(h)로 나타낸다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '같은 n이라도 모양이 시간을 바꾼다', '키 7개가 균형 있게 놓이면 높이는 2가 될 수 있어 한 경로에서 최대 3개 노드를 비교한다. 같은 7개 키가 한쪽 자식으로만 이어지면 높이는 6이 되어 최악에는 7개를 차례로 비교한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '평균 모양을 보장으로 착각하지 않는다', '일반 BST가 자동으로 균형을 유지하는 것은 아니다. 이미 정렬된 키를 차례로 넣는 입력은 삽입 규칙에 따라 편향을 만들 수 있다. 균형을 보장해야 한다면 그 성질을 유지하는 별도 구현을 선택해야 하며, 특정 입력에서 우연히 균형이 맞는 것과 구분한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 7 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '노드가 n개인 일반 BST의 탐색 시간은 트리 모양에 따라 달라지며, 한쪽으로 편향되면 최악 O(n)까지 느려질 수 있다.', NULL, '루트에서 찾는 키까지 실제로 몇 노드를 따라가야 하는지 가장 긴 경로를 기준으로 보세요.', 'O', '일반 BST의 탐색은 [[높이]] h인 경로에서 최대 h+1개 노드를 방문한다.\n균형이 좋을 때 h가 log n 규모라서 탐색도 O(log n)이 된다.\n한쪽으로 편향되어 h가 n-1이면 최악 탐색은 O(n)이다.', '노드 8개가 오른쪽 자식으로만 이어지면 가장 깊은 키를 찾을 때 8개 노드를 모두 비교할 수 있다.', 'BST의 키 순서는 탐색 방향을 줄여 주지만 높이까지 자동으로 줄여 주지는 않는다. 복잡도는 O(log n)이 아니라 먼저 O(h)로 표현해야 안전하다.', 7, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '균형 잡힌 BST에서 높이가 log n 정도가 되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '균형 규칙이 한쪽으로 긴 경로가 생기지 않게 해 트리의 [[높이 제한]]을 O(log n) 규모로 유지하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '균형 탐색 트리는 정해진 균형 규칙을 지켜 한쪽으로 지나치게 긴 경로가 생기지 않게 한다. 구현마다 구체적인 규칙은 다르지만, 그 결과 루트에서 잎까지의 높이가 O(log n) 범위에 머문다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '높이 제한', '균형 규칙으로 루트에서 가장 먼 잎까지의 경로 길이가 O(log n) 범위를 넘지 않게 하는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '트리 높이', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최악 시간', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '균형 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '높이', '이 스텝에서 루트부터 가장 깊은 리프까지 경로에 포함된 간선 수');

-- STEP 7 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '비어 있는 일반 BST에 1, 2, 3, 4, 5를 이 순서로 넣고 작은 키는 왼쪽, 큰 키는 오른쪽에 둔다면 노드들이 오른쪽으로 이어져 탐색이 선형 시간까지 느려질 수 있다.', NULL, '새 키가 지금까지 넣은 모든 키보다 클 때 삽입 경로가 어느 방향으로만 이어지는지 그려 보세요.', 'O', '오름차순 [[순차 삽입]]에서는 새 키가 매번 현재 가장 큰 노드의 오른쪽으로 들어간다.\nn개 노드가 한 줄로 이어지면 간선 수 기준 높이는 n-1이다.\n가장 깊은 키의 탐색과 삽입은 n개 노드를 확인해 O(n)까지 늘어난다.', '1이 루트가 되고 2, 3, 4, 5가 차례로 오른쪽 자식이 되면 연결 리스트처럼 한 줄의 경로가 생긴다.', '일반 BST는 삽입 뒤 모양을 자동으로 고치지 않는다. 키가 정렬되어 들어오는 입력은 순서 조건은 지키면서도 높이를 크게 만들 수 있다.', 7, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 키 1부터 7까지를 4, 2, 6, 1, 3, 5, 7 순서로 넣으면 앞 사례보다 높이가 작아지는 이유는 무엇인가?', 1, 1, 'MEDIUM', '가운데에 가까운 키가 먼저 들어가 좌우에 노드가 나뉘는 [[삽입 순서 효과]]가 생기기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '4가 루트가 되고 2와 6이 양쪽에 놓인 뒤 나머지가 다시 나뉜다. 일반 BST의 최종 모양은 같은 키 집합이라도 들어오는 순서에 따라 달라진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '삽입 순서 효과', '같은 키 집합도 삽입 순서에 따라 BST의 부모·자식 관계와 높이가 달라지는 현상');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정렬된 입력', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '오른쪽 편향', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '선형 탐색', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '순차 삽입', '키를 오름차순이나 내림차순처럼 한 방향의 순서로 계속 추가하는 입력 패턴');

-- STEP 7 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서로 다른 키 7개로 만든 균형 잡힌 BST가 있고, 높이 h는 루트부터 가장 깊은 리프까지의 간선 수다. 루트 8, 왼쪽 4와 오른쪽 12, 그 아래 리프가 2, 6, 10, 14일 때 키 14를 찾는 비교 순서와 비교 횟수는 무엇인가?', NULL, '찾는 키가 현재 키보다 큰 동안 오른쪽 한 경로만 따라가세요.', NULL, '키 14는 루트 8보다 커서 12로 가고 다시 오른쪽 14로 간다.\n[[탐색 경로]]는 8, 12, 14이며 비교는 3번이고 간선 수 기준 높이 h는 2다.\nBST 탐색은 전체 노드 7개가 아니라 선택된 한 경로만 방문한다.', '키 6을 찾는 경우에도 8, 4, 6의 세 노드를 비교하며 반대쪽 부분 트리는 방문하지 않는다.', '중위 순회처럼 모든 키를 방문할 필요는 없다. 14를 10과 비교하는 경로도 BST의 크기 비교 방향과 맞지 않는다.', 7, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '8, 4, 6, 14를 비교해 총 4번', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '2, 4, 6, 8, 10, 12, 14를 비교해 총 7번', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '8과 14만 비교해 총 2번', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '8, 12, 14를 비교해 총 3번', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'BST에서 자식이 둘인 노드를 삭제할 때 순서 조건을 유지하는 대표적인 방법은 무엇인가?', 1, 1, 'HARD', '오른쪽 부분 트리의 최솟값 같은 [[중위 후속자]]로 키를 대체한 뒤 그 노드를 정리할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '오른쪽 부분 트리의 최솟값은 삭제할 키보다 크면서 그다음으로 오는 키다. 이를 대체 위치에 쓰면 왼쪽과 오른쪽의 순서 조건을 유지할 수 있다. 왼쪽 부분 트리의 최댓값을 쓰는 대칭 방법도 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '중위 후속자', '중위 순회에서 현재 키 바로 다음에 방문되는 더 큰 키');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '경로 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'O(h)', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'BST 삭제', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '탐색 경로', '루트에서 시작해 키 비교 결과에 따라 선택한 노드들의 순서');

-- STEP 7 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '개발자가 일반 BST의 삽입과 삭제는 마지막에 연결 하나만 바꾸므로 항상 O(1)이라고 주장했다. 이 주장을 가장 정확하게 평가한 것은?', NULL, '마지막 연결 변경 전에 새 위치나 삭제 대상과 대체 노드를 어떻게 찾는지 포함해 보세요.', NULL, '삽입과 삭제에는 연결 변경 전에 대상이나 자리를 찾는 [[위치 탐색 비용]]이 든다.\n일반 BST에서는 이 과정이 루트부터 높이 h에 이르는 경로를 따라갈 수 있다.\n따라서 연결 변경 일부가 상수 시간이어도 연산 전체는 최악 O(h)로 본다.', '한쪽으로 긴 트리의 끝에 키를 삽입하려면 새 연결 하나를 만들기 전에 경로의 많은 노드를 비교한다.', '연결을 바꾸는 마지막 단계만 세면 앞선 탐색 작업을 빠뜨린다. 삭제는 대상뿐 아니라 경우에 따라 순서를 유지할 대체 위치도 찾아야 한다.', 7, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '자리와 대상을 찾는 경로까지 포함하면 삽입과 삭제 전체는 최악 O(h)다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '연결 변경만 세면 되므로 삽입과 삭제는 트리 높이와 무관하게 항상 O(1)이다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '삽입은 항상 O(n log n)이고 삭제는 항상 O(n²)이다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '삭제만 키 비교를 하며 삽입은 루트를 보지 않고 빈자리를 바로 안다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '균형을 유지하는 BST는 일반 BST와 어떤 성능 차이를 약속하는가?', 1, 1, 'HARD', '회전 같은 복구로 높이에 [[로그 상한]]을 유지해 탐색·삽입·삭제의 최악 경로가 길게 늘어지는 일을 막는다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '균형 방식마다 정확한 조건은 다르지만 높이가 노드 수에 비해 로그 규모를 넘지 않게 관리한다. 그래서 정렬된 입력처럼 불리한 순서에서도 선형 높이가 되는 것을 방지한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '로그 상한', '노드 수 n이 늘 때 높이가 O(log n) 범위를 넘지 않도록 제한하는 성능 경계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '삽입 위치', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '삭제 대상', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '연산 전체 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '위치 탐색 비용', '연결을 바꾸기 전에 트리 경로를 따라 대상 노드나 새 자리를 찾는 작업량');

-- STEP 7 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '일반 BST의 노드 n개가 모두 한쪽 자식으로만 이어져 간선 수 기준 높이 h가 n-1이 되고, 탐색이 최악 O(n)까지 느려지는 모양을 ___라고 한다.', NULL, '무게가 한쪽으로 쏠린 것처럼 루트에서 리프까지 긴 한 방향 경로가 생긴 트리 모양을 떠올려 보세요.', NULL, '[[편향 트리]]는 노드가 주로 한쪽 자식으로 이어져 높이가 크게 늘어난 트리다.\nn개가 한 줄로 연결되면 간선 수 기준 h=n-1이고 BST 연산은 최악 O(n)이 된다.\n키 순서 조건은 지켜도 균형이 없으면 로그 시간 성능을 보장하지 못한다.', '1, 2, 3, 4를 일반 BST에 순서대로 넣으면 오른쪽으로 이어진 편향 트리가 될 수 있다.', '완전 이진 트리나 균형 트리는 여러 층에 노드가 나뉘어 높이를 줄인다. 빈칸은 한쪽 경로가 길어진 모양을 가리킨다.', 7, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '편향 트리');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '편향된 트리');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'skewed tree');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '편향이 생겨도 BST의 중위 순회 결과는 왜 여전히 정렬될 수 있는가?', 1, 1, 'MEDIUM', '트리 모양과 별개로 키의 [[순서 불변식]]이 유지되면 왼쪽-현재-오른쪽 방문은 정렬 순서를 보존한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '편향은 높이와 성능의 문제다. 각 노드의 작은 키와 큰 키 배치가 올바르면 모양이 한쪽으로 길어도 중위 순회의 키 순서는 유지된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '순서 불변식', '트리 모양이 바뀌어도 모든 노드에서 계속 지켜야 하는 키의 배치 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최악 O(n)', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정렬 입력', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '균형 부재', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '편향 트리', '노드가 한쪽 방향으로 길게 이어져 높이가 노드 수에 가까워진 트리');

-- STEP 8. 균형 잡힌 순서 구조와 해시 중 고르기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (8, '균형 잡힌 순서 구조와 해시 중 고르기', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '균형 탐색 트리와 해시 테이블은 모두 키로 값을 찾는 맵이나 집합을 구현할 수 있지만 강점이 다르다. 순서가 필요한지, 정확히 일치하는 키만 빠르게 찾으면 되는지, 최악 시간 보장이 필요한지를 요구에서 먼저 찾아야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '순서 연산은 균형 탐색 트리가 맡는다', '균형 탐색 트리는 키의 대소 관계를 유지하고 높이를 log n 정도로 제한한다. 정확 키 탐색과 삽입·삭제뿐 아니라 최솟값, 최댓값, 정렬 순회, 구간 안의 키 찾기 같은 순서 연산을 자연스럽게 지원한다. 범위 결과가 k개라면 탐색 뒤 결과를 내는 비용까지 포함해야 한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '정확 조회만 많다면 해시를 검토한다', '세션 토큰으로 사용자 정보를 정확히 찾고 키 순서나 범위 조회가 필요 없다면 해시 테이블이 좋은 후보가 될 수 있다. 해시 함수가 키를 고르게 분산하고 부하율을 관리한다는 전제에서 탐색·삽입·삭제는 기대 O(1)이다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '기대 시간을 최악 보장으로 바꾸지 않는다', '충돌이 심하면 많은 키가 같은 위치에 모여 해시 연산이 최악 O(n)까지 느려질 수 있다. 또한 기본 해시 테이블은 키의 정렬 순서를 제공하지 않는다. 특정 라이브러리 이름보다 충돌 처리, 크기 조정, 순서 계약을 확인해 요구에 맞는 구현을 고른다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 8 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '일반적인 해시 테이블은 키를 항상 오름차순으로 유지하므로 시작 키와 끝 키 사이의 모든 항목을 바로 순서대로 꺼내는 데 적합하다.', NULL, '저장 위치가 키의 대소 관계로 정해지는지 해시 계산 결과로 정해지는지 구분해 보세요.', 'X', '일반적인 해시 테이블의 [[버킷 배치]]는 키의 정렬 순서가 아니라 해시값으로 정해진다.\n따라서 기본 순회 결과가 오름차순이라는 보장이 없고 구간의 시작 위치도 바로 찾기 어렵다.\n정렬 순회와 범위 조회가 핵심이면 순서를 유지하는 구조가 더 자연스럽다.', '키 10, 20, 30이 서로 다른 버킷에 흩어지면 15부터 25 사이의 키만 얻기 위해 여러 위치를 확인해야 할 수 있다.', '정확 키의 버킷을 계산하는 능력과 키들을 대소 순서로 유지하는 능력은 다르다. 별도 정렬 기능을 가진 특수 구현이 아니라면 순서 계약을 가정하면 안 된다.', 8, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '해시 테이블의 모든 키를 오름차순으로 한 번 출력해야 한다면 어떤 추가 작업이 필요할 수 있는가?', 1, 1, 'MEDIUM', '키들을 모은 뒤 비교 기준에 따라 [[별도 정렬]]해야 하며 이 비용은 정확 키 조회 비용과 다르다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '해시 버킷 순회는 키 순서를 보장하지 않는다. 출력 시점마다 정렬하거나 순서를 함께 유지하는 다른 구조를 추가해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '별도 정렬', '자료구조가 보장하지 않는 순서를 얻기 위해 원소를 모아 비교 순서대로 다시 배열하는 작업');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '해시 버킷', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정렬 순회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '범위 조회', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '버킷 배치', '해시값을 이용해 키가 들어갈 저장 위치 묶음을 정하는 방식');

-- STEP 8 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '키 조회가 어떤 입력에서도 최악 O(log n) 이내여야 하는 서비스에는, 높이를 제한하는 균형 탐색 트리가 일반 해시 테이블의 기대 O(1) 설명보다 그 요구에 더 직접 맞는다.', NULL, '평균적으로 빠르다는 설명이 가장 불리한 한 번의 조회 시간까지 제한하는지 구분하세요.', 'O', '[[최악 시간 요구]]는 가장 불리한 입력에서도 연산 시간이 정한 상한을 넘지 않아야 한다.\n일반 해시 테이블의 기대 O(1)은 충돌이 몰릴 때의 O(n) 가능성을 없애지 않는다.\n높이를 제한하는 균형 탐색 트리는 키 조회의 최악 O(log n) 요구에 더 직접 맞는다.', '평소 조회가 매우 빨라도 특정 키 묶음에서 긴 충돌 탐색이 생기면 엄격한 지연 상한을 어길 수 있다.', '기대값은 여러 상황의 평균적인 예상이고 최악 상한은 가장 긴 경우의 제한이다. 서로 다른 성능 계약이므로 기대 O(1)만으로 최악 O(log n)을 보장할 수 없다.', 8, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '평균 시간이 더 작아 보여도 최악 시간 구조를 선택할 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '마감 시간이 중요한 요청은 평균보다 한 번의 최대 지연을 제한하는 [[지연 상한]]이 더 중요한 요구일 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '실시간 처리나 응답 기한이 있는 서비스는 드문 느린 요청도 실패로 이어질 수 있다. 자료구조 선택은 평균 처리량뿐 아니라 허용 가능한 최악 지연을 함께 봐야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '지연 상한', '한 번의 연산이 넘지 않아야 하는 최대 실행 시간의 경계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '기대 시간', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최악 O(log n)', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '성능 계약', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '최악 시간 요구', '가장 불리한 입력에서도 연산 비용이 정한 상한 안에 있어야 한다는 조건');

-- STEP 8 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '예약 시스템은 시간을 키로 예약을 계속 추가·취소한다. 가장 이른 예약 찾기, 오전 10시부터 11시 사이 예약 조회, 시간순 출력이 모두 자주 필요하다. n은 저장된 예약 수이고 결과 수는 k다. 가장 적절한 구조와 이유는 무엇인가?', NULL, '정확히 같은 키 하나뿐 아니라 키의 대소 순서와 연속 구간을 이용하는 연산을 모두 지원해야 합니다.', NULL, '이 요구는 최솟값과 범위 조회와 정렬 순회라는 [[순서 연산]]을 포함한다.\n균형 탐색 트리는 높이를 O(log n)으로 유지하며 시작 위치를 찾고 순서대로 결과를 방문할 수 있다.\n범위 결과가 k개라면 조회 비용은 보통 O(log n+k)처럼 출력 비용까지 포함해 본다.', '10시의 첫 예약 위치를 찾은 뒤 키 순서로 11시 이하의 예약 k개를 이어서 방문할 수 있다.', '배열은 정렬 순회에 좋지만 중간 삽입·삭제 비용이 커질 수 있다. 일반 해시는 정확 조회에는 유리해도 시간 구간의 시작과 순서를 기본으로 제공하지 않는다.', 8, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '균형 탐색 트리, 키 순서를 유지해 최솟값과 범위와 시간순 조회를 함께 지원한다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '일반 해시 테이블, 해시 버킷이 항상 시간순으로 이어져 범위 조회가 자동으로 정렬된다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '정렬하지 않은 배열, 어떤 위치의 삽입·삭제와 범위 조회도 항상 O(1)이다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '스택, 가장 먼저 등록한 예약이 언제나 가장 이른 시간 예약과 같다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '범위 조회를 O(log n+k)로 표현할 때 k를 빼면 안 되는 이유는 무엇인가?', 1, 1, 'HARD', '조건에 맞는 k개 결과를 실제로 반환하는 [[출력 비용]]만 해도 최소 k에 비례하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '시작 키를 빠르게 찾아도 결과가 만 개라면 만 개를 읽어 전달해야 한다. 탐색 비용과 결과 열거 비용을 함께 써야 실제 작업량을 설명할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '출력 비용', '찾은 결과들을 실제로 방문하고 반환하는 데 필요한 작업량');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최솟값', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '범위 결과 k개', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'O(log n+k)', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '순서 연산', '키의 대소 관계를 이용하는 최솟값, 최댓값, 정렬 순회, 범위 조회 같은 연산');

-- STEP 8 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '인증 서버는 무작위에 가까운 세션 토큰으로 사용자 정보를 정확히 찾고 추가하거나 삭제한다. 토큰의 정렬 순서, 최솟값, 범위 조회는 필요 없고 적절한 해시 함수와 크기 조정을 사용할 수 있다. 가장 적절한 선택은 무엇인가?', NULL, '요구되는 연산이 키 하나의 정확한 일치인지 키들 사이의 순서 관계인지 구분하세요.', NULL, '이 서비스의 핵심은 순서가 없는 [[정확 일치 조회]]다.\n해시 테이블은 충돌이 잘 관리되면 조회·삽입·삭제를 기대 O(1)로 제공한다.\n균형 탐색 트리도 가능하지만 사용하지 않는 순서 기능을 위해 O(log n) 경로를 따르게 된다.', '토큰 전체가 같은지 비교해 사용자 한 명을 찾으면 되며 토큰 값이 어느 구간에 속하는지는 사용하지 않는다.', '범위와 정렬이 필요 없는데 순서 기능만을 이유로 트리를 고를 필요는 없다. 스택이나 큐는 임의 토큰으로 항목을 찾는 맵 연산을 제공하지 않는다.', 8, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '균형 탐색 트리만 가능하며 정확 조회에도 해시 구조를 사용할 수 없다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '스택, 토큰 값과 관계없이 마지막 로그인 사용자만 찾으면 된다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '큐, 임의 토큰 조회는 맨 앞 원소 확인만으로 항상 끝난다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '일반 해시 테이블, 충돌 관리 전제에서 정확 조회 중심 요구에 기대 O(1)을 제공한다', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '세션 수가 늘 때 해시 테이블의 크기 조정이 필요한 이유는 무엇인가?', 1, 1, 'MEDIUM', '한정된 버킷에 항목이 몰리는 것을 줄여 [[충돌 길이]]를 관리하기 위해서다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '항목 수만 늘고 버킷 수가 그대로면 한 버킷에서 확인할 후보가 많아질 수 있다. 크기를 늘리고 키를 다시 배치하면 기대 조회 시간을 유지하는 데 도움이 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '충돌 길이', '같은 해시 위치에 모여 한 번의 조회에서 확인해야 하는 후보들의 규모');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '세션 저장소', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '기대 시간', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '요구 기반 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '정확 일치 조회', '범위나 순서가 아니라 주어진 키와 같은 항목 하나를 찾는 연산');

-- STEP 8 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '정렬된 키 집합이 10, 20, 35, 50이다. 키 20보다 크면서 가장 작은 저장 키인 35를 20의 ___라고 한다.', NULL, '현재 키의 바로 다음에 오는 더 큰 저장 키를 가리키는 순서 용어입니다.', NULL, '정렬된 집합에서 [[후속자]]는 현재 키보다 큰 키 중 가장 작은 저장 키다.\n20보다 큰 저장 키는 35와 50이고 그중 가장 작은 값은 35다.\n이 연산은 키의 대소 순서를 유지하는 구조에서 자연스럽게 지원할 수 있다.', '같은 집합에서 35의 다음으로 큰 저장 키는 50이므로 50이 35의 후속자다.', '10은 20보다 작은 쪽에서 가장 가까운 키다. 50은 20보다 크지만 그 사이에 35가 있으므로 바로 다음 큰 키가 아니다.', 8, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '후속자');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'successor');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 집합에서 20보다 작으면서 가장 큰 저장 키 10은 무엇이라고 하는가?', 1, 1, 'MEDIUM', '현재 키보다 작은 키 중 가장 큰 저장 키를 [[선행자]]라고 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '20보다 작은 저장 키는 10 하나이므로 10이 바로 앞 키다. 후속자가 다음 큰 키를 찾는 연산이라면 선행자는 바로 앞의 작은 키를 찾는 대칭 연산이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '선행자', '정렬된 집합에서 현재 키보다 작은 키 중 가장 큰 저장 키');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정렬된 집합', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다음 키', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '선행자', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '후속자', '정렬된 집합에서 현재 키보다 큰 키 중 가장 작은 저장 키');

-- STEP 9. 우선순위 큐와 힙은 같은 말이 아니다
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (9, '우선순위 큐와 힙은 같은 말이 아니다', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '우선순위 큐는 가장 높은 또는 낮은 우선순위의 원소를 먼저 다룬다는 연산 계약이다. 이진 힙은 그 계약을 구현하는 흔한 자료구조 중 하나이며, 같은 우선순위의 입력 순서를 보존하는지는 별도 정책이다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '무엇을 할지와 어떻게 저장할지를 나눈다', '우선순위 큐 ADT는 원소 삽입, 최우선 원소 확인, 최우선 원소 제거 같은 동작의 의미를 정한다. 내부 구현은 이진 힙, 균형 탐색 트리, 정렬된 구조 등 요구에 맞게 달라질 수 있다. 호출자는 배열 모양보다 연산 계약에 의존한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '이진 힙으로 연산 계약을 구현한다', '이진 힙을 사용하면 루트의 최우선 원소 확인은 O(1), 삽입과 최우선 원소 제거는 높이를 따라 복구하므로 O(log n)으로 구현할 수 있다. 여기서 n은 저장된 원소 수이며, 최우선이 최솟값인지 최댓값인지는 큐의 우선순위 정책이 정한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '동률의 입력 순서를 자동으로 기대하지 않는다', '기본 힙은 같은 우선순위 원소 사이의 먼저 들어온 순서를 보장하지 않을 수 있다. 동률에서 FIFO가 필요하면 증가하는 순번을 함께 비교하거나 안정성을 약속하는 구현을 선택해야 한다. 우선순위 값만 같다는 이유로 순서가 저절로 정해지지 않는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 9 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '우선순위 큐와 이진 힙은 같은 개념이므로, 우선순위 큐라는 이름만으로 내부 구현이 반드시 이진 힙이라고 단정할 수 있다.', NULL, '사용자에게 약속한 연산의 의미와 내부에서 원소를 배치하는 방법을 분리해 보세요.', 'X', '[[우선순위 큐 ADT]]는 삽입과 최우선 원소 확인·제거의 의미를 정의한다.\n이진 힙은 이 계약을 효율적으로 제공하는 한 가지 구현이다.\n같은 ADT도 요구에 따라 균형 트리나 다른 구조로 구현할 수 있다.', '작업 스케줄러는 우선순위 큐 인터페이스만 사용하고 내부 구현은 이진 힙에서 다른 구조로 바꿀 수 있다.', 'ADT와 구현을 같은 말로 보면 외부 계약과 저장 방식을 결합하게 된다. 우선순위 큐라고 해서 내부가 반드시 이진 힙일 필요는 없다.', 9, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '우선순위뿐 아니라 특정 키의 빠른 삭제도 자주 필요하면 구현 선택이 달라질 수 있는 이유는 무엇인가?', 1, 1, 'HARD', '기본 힙은 임의 원소 위치를 바로 찾지 못하므로 위치표 같은 [[보조 인덱스]]나 다른 구현이 필요할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '루트 연산에는 힙이 잘 맞지만 임의 키 검색은 빠르지 않다. 실제로 필요한 모든 연산과 빈도를 보고 자료구조와 추가 정보를 함께 선택해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '보조 인덱스', '원소의 키에서 실제 저장 위치를 빠르게 찾도록 별도로 유지하는 매핑 정보');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '연산 계약', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '구현 교체', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '이진 힙', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '우선순위 큐 ADT', '원소의 입력 순서보다 정해진 우선순위에 따라 다음 원소를 선택하는 추상 자료형');

-- STEP 9 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '기본 이진 힙으로 우선순위 큐를 만들면 같은 우선순위의 작업은 별도 규칙이 없어도 항상 먼저 들어온 순서대로 제거된다.', NULL, '힙이 부모와 자식의 우선순위만 비교할 때 값이 같은 두 원소의 앞뒤까지 정해지는지 살펴보세요.', 'X', '기본 힙 불변식은 부모와 자식의 우선순위 관계만 정하고 동률의 순서는 정하지 않는다.\n같은 우선순위가 이동하고 교환되면 입력 순서가 바뀔 수 있다.\nFIFO가 필요하면 [[안정적 동률 처리]]를 별도 비교 규칙으로 넣어야 한다.', '우선순위 5인 A 뒤에 같은 우선순위의 B가 들어와도 힙 복구 과정만으로 A가 언제나 먼저 나온다고 보장할 수 없다.', '힙은 우선순위가 더 높은 원소를 루트 쪽에 두지만 같은 값끼리의 상대 순서는 자유로울 수 있다. 입력 순서 보존은 추가 요구다.', 9, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '동률 작업을 FIFO로 처리하려면 어떤 비교 키를 사용할 수 있을까?', 1, 1, 'MEDIUM', '주 우선순위가 같을 때 증가하는 [[입력 순번]]이 작은 작업을 먼저 고르는 복합 키를 사용할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '먼저 우선순위를 비교하고 값이 같을 때만 입력 순번을 비교한다. 두 기준이 모든 원소의 순서를 명확히 정하도록 우선순위 방향도 함께 정의해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '입력 순번', '원소가 들어온 순서를 구분하려고 차례로 부여하는 증가 번호');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '동일 우선순위', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'FIFO 동률', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '복합 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '안정적 동률 처리', '우선순위가 같은 원소들의 기존 입력 순서를 정해진 방식으로 보존하는 정책');

-- STEP 9 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '배포 작업 큐는 마감 시각이 이른 작업을 먼저 처리하고, 마감 시각이 같으면 실패 횟수가 큰 작업을 먼저 처리한다. 가장 알맞은 비교 규칙은 무엇인가?', NULL, '주 기준의 방향을 먼저 정하고 그 값이 같을 때만 두 번째 기준의 방향을 적용하세요.', NULL, '여러 필드를 쓰는 [[비교 규칙]]은 어느 필드를 먼저 보고 각 방향을 어떻게 정할지 명시한다.\n이 큐는 마감 시각이 작은 작업을 먼저 고르고 동률일 때 실패 횟수가 큰 작업을 고른다.\n삽입과 제거가 같은 규칙을 써야 힙의 최우선 원소와 서비스 요구가 일치한다.', '마감이 10시로 같은 A의 실패 횟수가 2이고 B가 5라면 B가 먼저이며, 마감이 9시인 C가 있으면 C가 둘보다 먼저다.', '마감 시각을 큰 값부터 고르면 늦은 작업이 먼저 나온다. 실패 횟수를 주 기준으로 삼으면 마감이 더 이른 작업을 뒤로 미룰 수 있다.', 9, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '마감 시각이 큰 작업을 먼저 고르고 같으면 실패 횟수가 작은 작업을 고른다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '마감 시각이 작은 작업을 먼저 고르고 같으면 실패 횟수가 큰 작업을 고른다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '실패 횟수가 큰 작업만 먼저 고르고 마감 시각은 비교하지 않는다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '마감 시각과 실패 횟수를 더한 값만 커지는 순서로 고른다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '비교 규칙이 A를 B보다 먼저, B를 C보다 먼저, C를 A보다 먼저라고 판단하면 왜 문제인가?', 1, 1, 'HARD', '순서가 원을 이루어 일관된 최우선 원소를 정할 수 없으므로 [[전이성]]을 만족하는 비교가 필요하다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', 'A가 B보다 앞이고 B가 C보다 앞이면 A도 C보다 앞이어야 일관된 순서가 된다. 이 성질이 없으면 힙 복구 결과가 비교 순서에 따라 흔들릴 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '전이성', 'A가 B보다 앞이고 B가 C보다 앞이면 A도 C보다 앞이어야 하는 비교의 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다중 기준', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정렬 방향', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비교 일관성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '비교 규칙', '두 원소 중 어느 것이 먼저 처리될지 필드와 방향을 정해 판단하는 기준');

-- STEP 9 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '숫자가 클수록 우선순위가 높은 큐가 비어 있다. A(2), B(5), C(3)을 차례로 삽입한 뒤 peek, remove-top, peek를 순서대로 수행한다. 각 연산이 반환하는 항목은 무엇인가?', NULL, '확인 연산은 원소를 남기고 제거 연산만 최우선 원소를 큐에서 없앤다는 차이를 적용하세요.', NULL, '처음 최우선 원소는 우선순위 5인 B이므로 [[peek]]는 B를 반환하고 큐에 남긴다.\nremove-top도 B를 반환하지만 이번에는 B를 제거한다.\n남은 A(2)와 C(3) 중 C가 최우선이므로 마지막 peek는 C다.', '반환 순서는 B, B, C이며 첫 번째 B는 확인만 하고 두 번째 B에서 실제 제거된다.', 'peek에서 B를 제거했다고 보면 두 번째 연산 결과가 달라진다. 삽입 순서만 따르면 우선순위 큐를 일반 FIFO 큐처럼 잘못 해석하게 된다.', 9, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'B, C, A', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'A, A, B', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'C, C, B', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'B, B, C', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'peek가 최우선 원소를 제거하지 않는 계약은 어떤 상황에 유용한가?', 1, 1, 'MEDIUM', '다음 작업의 우선순위를 확인한 뒤 실행 가능 여부를 판단하는 [[비파괴 조회]]에 유용하다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '자원이나 실행 시간이 아직 준비되지 않았다면 원소를 큐에 남겨 두어야 한다. 확인과 제거를 분리하면 호출자가 처리 성공 뒤에만 실제로 꺼낼 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '비파괴 조회', '자료구조의 내용을 제거하거나 바꾸지 않고 다음 원소를 확인하는 연산');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'peek', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'remove-top', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최대 우선순위', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'peek', '최우선 원소를 자료구조에서 제거하지 않고 확인하는 연산');

-- STEP 9 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'Task 객체를 우선순위 큐에 넣을 때 어떤 작업을 먼저 꺼낼지 두 객체를 비교해 순서를 정하도록 전달하는 함수나 객체를 ___라고 한다.', NULL, '자료구조가 두 작업 중 어느 쪽을 먼저 둘지 묻는 순서 판단 도구의 이름입니다.', NULL, '[[비교자]]는 두 원소를 받아 우선순위상 앞과 뒤를 판단하는 함수나 객체다.\n최소값을 먼저 둘지 최대값을 먼저 둘지와 여러 필드의 비교 순서를 여기에 담을 수 있다.\n힙은 같은 판단 기준을 일관되게 사용해 부모와 자식의 순서를 유지한다.', '마감 시각을 비교하는 도구를 전달하면 Task에 하나의 고정된 기본 순서가 없어도 이른 작업을 먼저 꺼낼 수 있다.', 'peek와 remove-top은 우선순위 큐의 연산이고 힙은 저장 구현이다. 빈칸은 원소 둘의 처리 순서를 실제로 판정하는 도구를 묻는다.', 9, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '비교자');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'comparator');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 원소 집합으로 최소 우선 큐와 최대 우선 큐를 모두 만들 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '값은 같아도 어느 방향을 우선으로 볼지 정하는 [[정렬 방향]]을 반대로 설정할 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '작은 값을 앞선다고 판단하면 최소 우선 큐가 되고 큰 값을 앞선다고 판단하면 최대 우선 큐가 된다. 힙의 부모-자식 조건도 선택한 방향에 맞춰 유지한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '정렬 방향', '두 값 중 작은 쪽과 큰 쪽 가운데 어느 쪽을 먼저 처리할지 정한 순서');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '우선순위 함수', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최소·최대 방향', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비교 일관성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '비교자', '두 원소의 순서를 판단해 어느 원소가 우선인지 알려 주는 함수나 객체');

-- STEP 10. 힙 불변식 — 루트만 확실하고 전체는 정렬되지 않는다
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (10, '힙 불변식 — 루트만 확실하고 전체는 정렬되지 않는다', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '힙은 모든 원소를 정렬하는 구조가 아니라 부모와 자식 사이의 부분 순서를 유지한다. 이 조건으로 루트의 최솟값이나 최댓값은 보장하지만 형제의 순서와 임의 값의 빠른 검색은 보장하지 않는다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '부모와 자식 사이만 비교한다', '최소 힙에서는 모든 부모 키가 각 자식 키보다 작거나 같고, 최대 힙에서는 크거나 같다. 이 관계가 루트에서 모든 아래 경로로 이어지므로 최소 힙의 루트는 전체 최솟값이고 최대 힙의 루트는 전체 최댓값이다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '배열 표현을 전체 정렬로 읽지 않는다', '최소 힙 배열 [2, 5, 3, 9, 7, 8]은 유효하다. 2는 5와 3 이하이고, 5는 9와 7 이하이며, 3은 8 이하다. 배열에서 5가 3보다 먼저 나오지만 형제 5와 3 사이의 순서는 힙 조건이 요구하지 않는다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '임의 값 검색은 힙의 주 연산이 아니다', '루트의 극값은 바로 알 수 있지만 중간 값이 어느 가지에 있는지는 대소 비교만으로 한쪽을 항상 고를 수 없다. 임의 값을 찾는 최악 시간은 O(n)이다. 힙은 임의 검색보다 최우선 원소의 반복 확인과 제거에 맞는 구현이다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 10 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '최소 힙은 루트의 전체 최솟값을 보장하지만, 배열 표현의 모든 원소가 왼쪽부터 오름차순으로 정렬될 필요는 없다.', NULL, '부모와 자식 사이의 조건이 같은 층의 형제나 배열의 이웃 원소 사이에도 적용되는지 확인하세요.', 'O', '최소 힙의 [[부분 순서]]는 부모가 각 자식보다 작거나 같다는 관계만 보장한다.\n형제끼리의 대소 관계와 서로 다른 부분 트리의 전체 순서는 정하지 않는다.\n따라서 루트는 최솟값이지만 배열 전체가 오름차순일 필요는 없다.', '[2, 5, 3, 9, 7, 8]은 최소 힙이지만 배열 위치에서 5 뒤에 더 작은 3이 나온다.', '루트 극값 보장과 전체 정렬은 다른 성질이다. 힙은 모든 원소 쌍을 비교해 순서를 정하지 않는다.', 10, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '힙이 완전 이진 트리 모양을 사용하는 것과 키가 전체 정렬되는 것은 왜 다른가?', 1, 1, 'MEDIUM', '[[완전 이진 트리]]는 노드를 채우는 위치를 정하고 힙의 키 불변식은 부모-자식 대소만 정하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '모양 조건은 마지막 층을 제외한 층이 차고 마지막 층을 왼쪽부터 채우게 한다. 어느 키가 그 위치에 놓일지는 별도의 부모-자식 비교 규칙이 제한한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '완전 이진 트리', '마지막 층을 제외한 층이 차 있고 마지막 층의 노드를 왼쪽부터 채우는 이진 트리 모양');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '부분 정렬', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '형제 순서', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '배열 표현', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '부분 순서', '모든 원소의 순서가 아니라 정해진 관계에 있는 원소 사이에서만 보장되는 대소 조건');

-- STEP 10 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '모든 부모 키가 각 자식 키보다 크거나 같은 최대 힙에서는 루트 키가 전체 원소의 최댓값이다.', NULL, '루트에서 어떤 아래 원소까지 내려가도 부모에서 자식으로 갈수록 값이 커질 수 있는지 살펴보세요.', 'O', '최대 힙에서는 루트부터 아래로 갈 때 부모가 자식보다 작아지지 않는다.\n모든 노드는 루트에서 이어진 경로 아래에 있으므로 루트보다 큰 키가 존재할 수 없다.\n따라서 [[루트 극값]]은 전체 최댓값이고 바로 확인할 수 있다.', '최대 힙 [9, 7, 8, 2, 5, 3]에서 루트 9는 모든 자식과 자손보다 크거나 같다.', '형제 사이의 순서는 자유로워도 각 노드는 부모-자식 경로로 루트와 연결된다. 경로의 대소 조건이 루트의 최댓값을 보장한다.', 10, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '최대 힙에서 최댓값 확인을 O(1)로 할 수 있는 이유는 무엇인가?', 1, 1, 'EASY', '불변식이 최댓값의 [[고정 위치]]를 루트로 정해 두어 다른 노드를 탐색할 필요가 없기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '루트 배열 위치를 한 번 읽으면 최댓값을 얻는다. 단, 루트를 제거한 뒤에는 새 루트가 조건을 만족하도록 힙을 복구해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '고정 위치', '원하는 값이나 역할을 자료구조의 정해진 한 자리에서 바로 찾을 수 있는 배치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최대 힙', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최댓값 확인', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '경로 관계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '루트 극값', '힙의 루트에 보장되는 전체 최솟값 또는 최댓값');

-- STEP 10 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '배열은 0번 인덱스부터 시작하고 노드 i의 자식은 2i+1과 2i+2에 놓인다. 다음 배열 중 모든 부모가 자식보다 작거나 같은 최소 힙은 무엇인가?', NULL, '각 후보에서 인덱스 0, 1, 2의 값을 실제 자식 위치와 비교해 위반 하나를 찾으세요.', NULL, '[[힙 배열 인덱스]] 규칙으로 [2, 5, 3, 9, 7, 8]의 부모와 자식을 비교한다.\n2는 5와 3 이하이고 5는 9와 7 이하이며 3은 8 이하다.\n다른 후보에는 부모보다 작은 자식이 하나 이상 있어 최소 힙 조건을 어긴다.', '[2, 5, 3, 4, 7, 8]에서는 인덱스 1의 부모 5가 인덱스 3의 자식 4보다 커서 유효하지 않다.', '루트 하나만 최솟값인지 보는 것으로는 부족하다. 자식을 가진 모든 인덱스에서 부모-자식 조건을 확인해야 한다.', 10, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[2, 5, 3, 9, 7, 8]', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[2, 5, 3, 4, 7, 8]', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[2, 1, 3, 9, 7, 8]', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[2, 5, 3, 9, 1, 8]', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '유효한 최소 힙에 키 1을 새 마지막 위치에 삽입하면 어떤 방향으로 복구해야 하는가?', 1, 1, 'MEDIUM', '새 키가 부모보다 작으면 부모와 바꾸며 루트 방향으로 반복하는 [[상향 이동]]을 수행한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '마지막 위치 삽입은 완전 이진 트리 모양을 유지한다. 새 노드와 조상 경로에서만 대소 조건이 깨질 수 있으므로 부모를 따라 올라가며 고친다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '상향 이동', '삽입한 힙 원소가 부모와 순서를 비교하며 루트 쪽으로 올라가는 복구 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '부모 인덱스', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최소 힙 검증', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '삽입 복구', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '힙 배열 인덱스', '완전 이진 트리를 배열에 저장할 때 부모와 자식 위치를 계산하는 번호 규칙');

-- STEP 10 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '최소 힙에 n개 원소가 있고 특정 값 37이 들어 있는지 찾으려 한다. 값의 별도 위치 인덱스는 없으며 같은 값도 허용한다. 최악 시간에 대한 설명으로 가장 정확한 것은 무엇인가?', NULL, '루트의 최솟값을 아는 것만으로 목표값이 있을 한쪽 가지를 유일하게 선택할 수 있는지 생각해 보세요.', NULL, '최소 힙은 부모보다 큰 값들이 어느 자식 가지에 있는지 서로 비교해 정하지 않는다.\n값 37이 없거나 여러 후보 가지 끝에 있을 수 있어 [[임의 값 검색]]은 최악 O(n)이다.\n루트 최솟값의 O(1) 확인과 임의 값 찾기의 비용을 구분해야 한다.', '루트가 2이고 자식이 5와 3이면 목표 37은 왼쪽이나 오른쪽 어느 쪽 아래에도 있을 수 있다.', '힙 높이가 log n이어도 BST처럼 비교 한 번으로 한쪽 부분 트리를 항상 버릴 수 없다. 배열 이진 탐색도 배열 전체가 정렬되어 있지 않아 적용할 수 없다.', 10, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '루트부터 한 경로만 따르면 되므로 최악 O(log n)이다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '배열 전체가 정렬되어 있어 이진 탐색으로 최악 O(log n)이다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '여러 가지를 확인해야 할 수 있어 최악 O(n)이다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '루트가 최솟값이므로 어떤 값도 항상 O(1)에 찾는다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '최소 힙에서 현재 노드의 값이 목표값보다 크면 그 아래를 건너뛸 수 있는 이유는 무엇인가?', 1, 1, 'HARD', '모든 자손이 현재 노드 이상이므로 더 작은 목표가 없다는 [[부분 가지치기]]가 가능하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '이 조건은 일부 가지를 줄일 수 있지만 목표보다 작거나 같은 노드가 많은 입력에서는 여전히 넓은 영역을 확인한다. 따라서 최악 O(n) 결론은 바뀌지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '부분 가지치기', '힙의 부모-자식 대소 조건으로 목표가 존재할 수 없는 일부 하위 영역을 제외하는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최악 O(n)', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'BST와 비교', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '보조 인덱스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '임의 값 검색', '루트의 최우선 값이 아닌 특정 값을 자료구조 안에서 찾는 작업');

-- STEP 10 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '최소 힙의 모든 부모 키는 각 자식 키보다 작거나 같아야 하며, 삽입과 remove-top 뒤에도 계속 유지해야 한다. 이처럼 자료구조가 유효하려면 항상 만족해야 하는 부모-자식 조건을 ___이라고 한다.', NULL, '연산 전후에도 깨지지 않게 복구해야 하는 자료구조의 핵심 조건에 붙는 이름을 떠올려 보세요.', NULL, '[[힙 불변식]]은 힙이 유효한 동안 계속 지켜야 하는 부모-자식 대소 조건이다.\n최소 힙은 부모가 자식 이하이고 최대 힙은 부모가 자식 이상이다.\n삽입과 루트 제거가 조건을 깨뜨리면 한 경로를 따라 복구해야 한다.', '최소 힙에서 루트를 제거하고 마지막 원소를 루트로 옮긴 뒤 더 작은 자식과 비교하며 아래로 내려보낼 수 있다.', '전체 배열의 오름차순 정렬이나 형제 사이의 순서를 뜻하지 않는다. 힙 연산이 보존해야 하는 부모와 자식의 부분 순서다.', 10, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '힙 불변식');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'heap invariant');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '최소 힙의 루트를 제거한 뒤 마지막 원소를 루트로 옮기면 어떤 복구가 필요한가?', 1, 1, 'MEDIUM', '옮긴 원소를 더 작은 자식과 비교하며 필요한 만큼 아래로 보내는 [[하향 이동]]을 수행한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '루트 위치의 값이 자식보다 크면 더 작은 자식과 바꾼다. 조건을 만족하거나 리프에 도달할 때까지 같은 과정을 반복한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '하향 이동', '힙의 루트 쪽 원소를 자식과 비교하며 아래로 내려보내 불변식을 복구하는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최소 힙', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최대 힙', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '불변식 복구', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '힙 불변식', '힙의 모든 부모와 자식 사이에서 유지해야 하는 우선순위 대소 조건');

-- STEP 11. 배열로 저장하는 힙과 기본 연산
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (11, '배열로 저장하는 힙과 기본 연산', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '힙은 완전 이진 트리 모양을 배열에 빈틈없이 저장해 우선순위가 가장 높은 원소를 루트에 둔다. 삽입과 루트 제거는 한 경로를 따라 복구하고, 배열 전체를 아래에서부터 힙으로 만들면 O(n)에 처리할 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '0-based 배열의 가족 위치', '인덱스 i의 부모는 i>0일 때 floor((i-1)/2), 왼쪽 자식은 2i+1, 오른쪽 자식은 2i+2다. 완전 이진 트리이므로 포인터 없이 배열 인덱스만으로 관계를 찾는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '삽입과 루트 제거', '최소 힙 삽입은 새 값을 배열 끝에 붙이고 부모보다 작으면 위로 올린다. 루트 제거는 마지막 값을 루트로 옮긴 뒤 더 작은 자식과 바꾸며 아래로 내려가 힙 순서를 복구한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', 'heapify는 O(n)', '원소를 하나씩 삽입하면 O(n log n)이 될 수 있지만, 배열의 마지막 내부 노드부터 하향 이동하는 bottom-up heapify는 O(n)이다. 대부분의 노드가 아래쪽에 있어 이동 거리가 짧기 때문이다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 11 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'n개의 값이 든 배열을 마지막 내부 노드부터 루트 방향으로 하향 이동시켜 힙으로 만드는 bottom-up heapify에는 항상 Θ(n log n) 시간이 필요하며 선형 시간에는 만들 수 없다.', NULL, '모든 노드가 트리 높이만큼 내려가는지, 아래쪽 노드들의 실제 이동 거리가 얼마나 짧은지 살펴보세요.', 'X', '[[bottom-up heapify]]는 n개 원소를 Θ(n)에 힙으로 만들 수 있다.\n아래쪽의 많은 노드는 내려갈 높이가 0이나 1이라 노드별 가능 이동 거리의 합은 O(n)이다.\n내부 노드 약 n/2개도 확인하므로 Ω(n)이며, 원소별 삽입 O(log n)을 n번 하는 방식과 다르다.', '잎은 이미 자식이 없어 하향 이동할 필요가 없고, 잎 바로 위 노드도 최대 한 층만 내려간다.', 'O(n log n)은 각 원소를 빈 힙에 하나씩 삽입하는 상한으로 볼 수 있다. 아래에서 한꺼번에 복구하는 방식은 노드별 이동 높이의 합이 O(n)이다.', 11, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'heapify를 시작할 때 잎 노드를 따로 처리하지 않아도 되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '자식이 없는 잎 하나는 이미 [[부분 힙]] 조건을 만족하므로 마지막 부모부터 확인하면 된다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '하향 이동은 자식과의 순서를 고치는 연산이다. 잎에는 비교할 자식이 없으므로 그 위치만 보면 힙 조건이 깨질 수 없다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '부분 힙', '어떤 노드를 루트로 하는 부분 트리가 힙 순서를 만족하는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '선형 시간 구성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '노드 높이 합', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '하향 이동', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'bottom-up heapify', '배열의 마지막 내부 노드부터 루트까지 하향 이동을 적용해 힙을 만드는 방법');

-- STEP 11 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '0-based 배열 힙에서 인덱스 2에 있는 노드의 왼쪽 자식은 인덱스 5이고 오른쪽 자식은 인덱스 6이다.', NULL, '인덱스를 0부터 센다는 전제로 배열 위치와 트리의 부모·자식 관계를 직접 그려 보세요.', 'O', '0-based 배열에서 왼쪽 자식은 2i+1, 오른쪽 자식은 2i+2다.\ni=2를 넣으면 두 위치는 5와 6이 되어 [[자식 인덱스]]와 일치한다.\n배열 길이를 넘는 위치라면 그 자식은 실제로 존재하지 않는다.', '배열 [1, 3, 2, 7, 8, 5, 4]에서 인덱스 2의 값 2는 인덱스 5의 값 5와 인덱스 6의 값 4를 자식으로 둔다.', '1-based 공식을 그대로 적용하면 위치가 어긋난다. 이 문제는 0부터 세므로 인덱스 2의 자식은 5와 6이다.', 11, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '0-based 배열에서 인덱스 6의 부모 위치는 어떻게 구하는가?', 1, 1, 'MEDIUM', 'floor((6-1)/2)를 계산한 인덱스 2가 [[부모 인덱스]]다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '정수 나눗셈으로 (i-1)/2의 소수점 아래를 버리면 된다. 인덱스 5와 6은 모두 인덱스 2를 부모로 가진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '부모 인덱스', '배열 힙에서 현재 노드의 바로 위 부모가 저장된 배열 위치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '완전 이진 트리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '0-based 인덱스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '배열 표현', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '자식 인덱스', '배열 힙에서 현재 노드의 왼쪽·오른쪽 자식이 저장된 위치');

-- STEP 11 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '최소 힙 배열 [2, 5, 4, 9, 7, 8]에 값 1을 삽입한다. 새 값을 끝에 붙인 뒤 부모와 비교하며 힙 순서를 복구한 최종 배열은 무엇인가?', NULL, '끝에 붙인 새 값이 현재 부모보다 작을 때마다 루트 쪽으로 비교를 이어 가세요.', NULL, '1을 인덱스 6에 붙이면 부모 인덱스 2의 값 4보다 작아 서로 바꾼다.\n이어서 부모 인덱스 0의 값 2보다 작으므로 다시 바꾸는 [[삽입 경로]]를 따른다.\n최종 최소 힙은 [1, 5, 2, 9, 7, 8, 4]다.', '변화는 [2,5,4,9,7,8,1]에서 [2,5,1,9,7,8,4], 다시 [1,5,2,9,7,8,4] 순서다.', '새 값을 끝에만 두면 부모 4보다 작아 최소 힙 조건을 어긴다. 형제인 5와 비교하는 것이 아니라 현재 위치의 부모를 따라 위로 이동해야 한다.', 11, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[2, 5, 4, 9, 7, 8, 1]', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[1, 5, 2, 9, 7, 8, 4]', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[2, 1, 4, 9, 7, 8, 5]', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[1, 2, 4, 5, 7, 8, 9]', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '삽입이 배열 전체를 정렬하지 않아도 되는 이유는 무엇인가?', 1, 1, 'HARD', '힙은 부모와 자식의 [[부분 순서]]만 요구하므로 삽입 위치에서 루트까지의 경로만 고치면 된다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '형제끼리나 서로 다른 부분 트리 사이의 전체 크기 순서는 정하지 않는다. 그래서 오름차순 배열을 만드는 작업과 다르다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '부분 순서', '전체 원소 정렬이 아니라 부모와 자식 사이에만 요구되는 우선순위 관계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최소 힙', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '삽입', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '경로 길이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '삽입 경로', '새 원소가 배열 끝에서 부모들과 비교하며 루트 방향으로 이동하는 경로');

-- STEP 11 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '최소 힙 배열 [1, 4, 3, 8, 6, 5]에서 루트 1을 제거한다. 마지막 값 5를 루트로 옮긴 뒤 더 작은 자식과 바꾸며 복구할 때 최종 배열은 무엇인가?', NULL, '마지막 값을 루트로 옮긴 뒤 두 자식 중 힙 조건을 회복할 대상을 고르고 새 위치를 다시 확인하세요.', NULL, '마지막 값 5를 루트로 옮기면 [5, 4, 3, 8, 6]이 된다.\n두 자식 중 더 작은 3과 바꾸는 [[하향 이동]]을 적용한다.\n인덱스 2에는 자식이 없으므로 최종 배열은 [3, 4, 5, 8, 6]이다.', '최소 힙에서는 두 자식이 모두 현재 값보다 작다면 더 작은 자식을 선택해야 그 자리에 가장 작은 후보가 올라온다.', '마지막 값을 루트에 놓고 끝내면 5가 자식 4와 3보다 커서 조건을 어긴다. 더 큰 자식 4를 먼저 고르면 루트 아래에 더 작은 3이 남는다.', 11, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[5, 4, 3, 8, 6]', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[4, 5, 3, 8, 6]', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[3, 5, 4, 8, 6]', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '[3, 4, 5, 8, 6]', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '루트 제거에서 마지막 배열 원소를 루트로 옮기는 이유는 무엇인가?', 1, 1, 'MEDIUM', '배열의 끝만 줄여도 [[완전 이진 트리]]의 빈틈없는 모양을 유지할 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '중간 원소를 없애 빈칸을 남기면 인덱스 공식으로 표현한 트리 모양이 깨진다. 마지막 값을 옮기면 모양을 유지한 채 순서만 복구하면 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '완전 이진 트리', '마지막 높이를 제외한 층이 차 있고 마지막 층은 왼쪽부터 채워지는 이진 트리');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '루트 제거', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '마지막 원소 이동', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '자식 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '하향 이동', '힙 조건을 어긴 원소를 알맞은 자식과 바꾸며 아래로 보내는 복구 연산');

-- STEP 11 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '최소 힙에 새 값을 배열 끝에 추가한 뒤, 그 값이 부모보다 작으면 서로 바꾸는 일을 루트 방향으로 반복한다. 이 복구 연산을 ___이라고 한다.', NULL, '새 원소가 시작한 위치에서 부모 쪽으로 한 층씩 이동하는 복구 방향에 주목하세요.', NULL, '[[sift-up]]은 새 원소를 부모와 비교하며 위로 이동시키는 힙 복구 연산이다.\n삽입 전 힙은 이미 조건을 만족하므로 새 원소에서 루트까지의 한 경로만 확인한다.\n완전 이진 트리의 높이가 O(log n)이어서 삽입도 O(log n)이다.', '최소 힙에 1을 붙였을 때 부모가 4라면 바꾸고, 새 부모가 2라면 다시 바꾸어 루트까지 갈 수 있다.', '루트에서 자식 방향으로 내려가는 복구는 루트 제거에 쓰는 sift-down이다. 이 문제는 배열 끝에 들어온 새 값이 부모 방향으로 움직인다.', 11, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'sift-up');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '상향 이동');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'up-heap');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'sift-up의 최악 시간 복잡도가 O(log n)인 이유는 무엇인가?', 1, 1, 'MEDIUM', '원소가 이동할 수 있는 최대 횟수가 힙의 [[트리 높이]]에 비례하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '완전 이진 트리는 한 층 내려갈 때 담을 수 있는 노드 수가 대략 두 배가 된다. n개 노드의 높이는 O(log n)이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '트리 높이', '루트에서 가장 깊은 노드까지 이어지는 간선 수 또는 층 수에 따른 길이');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '힙 삽입', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '부모 비교', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '로그 시간', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'sift-up', '힙에 추가된 원소를 부모와 바꾸며 위로 올려 순서를 복구하는 연산');

-- STEP 12. 힙을 선택하거나 피해야 하는 상황
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (12, '힙을 선택하거나 피해야 하는 상황', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '힙은 가장 높은 우선순위 원소를 반복해서 꺼내는 작업에 강하다. 그러나 전체 정렬 상태를 유지하지 않으므로 임의 값 탐색과 범위 질의에는 알맞지 않으며, 기존 키를 바꿀 때는 원소 위치를 찾는 방법이 필요하다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '루트에 필요한 원소를 모으기', '최소 힙은 최솟값, 최대 힙은 최댓값을 루트에 둔다. 작업 스케줄러, 반복적인 다음 항목 선택, 스트림의 top-k처럼 가장 우선인 원소를 계속 확인하고 제거할 때 적합하다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '전체 정렬 구조가 아니다', '힙은 부모와 자식의 순서만 보장한다. 특정 값이 있는지 찾거나 구간의 모든 값을 모으려면 여러 원소를 확인할 수 있어, 해시 구조나 균형 탐색 트리보다 불리할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '키 변경에는 위치 정보가 필요하다', '작업 ID만 알고 우선순위를 바꾸려면 배열에서 그 작업의 위치부터 찾아야 한다. ID에서 힙 인덱스로 가는 맵을 함께 두거나, 새 항목을 넣고 오래된 항목을 나중에 무시하는 방식 등을 요구사항에 맞게 선택한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 12 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '매번 마감 시각이 가장 이른 작업을 꺼내고 새 작업도 계속 추가하는 스케줄러에는 최소 힙이 알맞지 않다.', NULL, '다음에 처리할 항목이 항상 한쪽 극값인지와 삽입이 반복되는지를 확인하세요.', 'X', '최소 힙은 가장 이른 마감처럼 우선순위가 작은 원소를 [[루트]]에 둔다.\n루트 확인은 O(1), 삽입과 루트 제거는 O(log n)에 처리할 수 있다.\n전체 작업을 정렬할 필요 없이 다음 작업을 반복 선택하는 요구와 잘 맞는다.', '마감 시각 5, 12, 8인 작업이 있으면 루트의 5를 먼저 꺼내고 힙을 복구해 다음 마감을 준비한다.', '매번 모든 작업을 다시 정렬하거나 선형 탐색할 필요가 없다. 가장 이른 작업을 루트에 유지하는 힙의 연산이 요구사항과 직접 연결된다.', 12, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '마감 시각이 같은 두 작업의 처리 순서도 반드시 보장해야 한다면 무엇을 추가할 수 있는가?', 1, 1, 'MEDIUM', '마감 시각 뒤에 접수 순번 같은 [[보조 우선순위]]를 비교 기준으로 추가할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '힙은 비교 기준이 정한 순서만 유지한다. 같은 마감값에서 먼저 들어온 작업을 먼저 처리하려면 두 값을 묶어 비교해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '보조 우선순위', '주된 우선순위가 같을 때 순서를 결정하기 위해 추가로 비교하는 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '우선순위 큐', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '스케줄링', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '극값 제거', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '루트', '트리의 가장 위 노드이며 힙에서는 최고 우선순위 원소가 놓이는 위치');

-- STEP 12 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '예약 시작 시각을 키로 둔 최소 힙에서 10시 이상 20시 이하인 예약 k개를 자주 시작 시각순으로 조회할 때, 루트가 최솟값이므로 결과를 항상 O(k)에 바로 읽을 수 있다. 여기서 k는 결과 수다.', NULL, '루트의 최솟값 보장이 중간 값 구간의 위치와 순서까지 알려 주는지 살펴보세요.', 'X', '최소 힙은 루트의 최솟값만 보장하고 전체 원소의 정렬 순서를 제공하지 않는다.\n10시부터 20시 사이의 예약이 여러 갈래에 흩어질 수 있어 [[범위 질의]] 결과를 바로 순서대로 읽기 어렵다.\n범위 조회가 핵심이면 키 순서를 유지하는 균형 탐색 트리 같은 구조가 더 자연스럽다.', '힙 배열의 연속된 인덱스를 잘라도 10시부터 20시까지의 예약만 모이지 않으며, 결과가 시작 시각순이라는 보장도 없다.', '최솟값 하나를 O(1)에 확인하는 것과 임의 범위의 모든 원소를 정렬된 순서로 찾는 것은 다르다. 힙은 결과 수 k만큼만 읽으면 된다고 보장하지 않는다.', 12, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '범위 조회는 드물고 다음 최솟값 제거가 매우 잦다면 구조 선택은 어떻게 달라질 수 있는가?', 1, 1, 'MEDIUM', '범위 조회의 약점보다 빠른 [[극값 반복 처리]]가 중요하므로 최소 힙을 선택할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '자료구조는 드문 연산 하나보다 주요 연산의 빈도와 비용을 함께 보고 고른다. 범위 조회가 늘어나면 정렬 트리나 보조 인덱스를 다시 검토한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '극값 반복 처리', '현재 원소 중 가장 작은 값이나 가장 큰 값을 계속 확인하고 제거하는 작업');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '범위 검색', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정렬 순회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '연산 빈도', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '범위 질의', '정한 시작 키와 끝 키 사이에 있는 원소들을 찾는 조회');

-- STEP 12 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '점수가 하나씩 들어오는 큰 스트림에서 가장 큰 k개만 유지하려 한다. k는 전체 원소 수 n보다 매우 작다. 추가 요구가 없을 때 가장 적절한 방법은 무엇인가?', NULL, '현재 후보 중 가장 작은 값만 빠르게 확인해 새 값과 교체할 수 있는 크기 k의 구조를 찾으세요.', NULL, '크기 k의 최소 힙은 현재 top-k 중 가장 작은 값을 [[교체 기준]]으로 루트에 둔다.\n새 값이 루트보다 크면 루트를 바꾸고, 작거나 같으면 top-k 후보가 아니므로 넘길 수 있다.\n각 원소 처리가 O(log k)이므로 전체는 O(n log k), 추가 공간은 O(k)다.', 'k=3이고 힙이 [70,90,80]일 때 85가 오면 70을 빼고 85를 넣어 80,85,90을 유지한다.', '모든 값을 계속 정렬하면 필요 없는 하위 원소까지 보관하고 정렬한다. 크기 k 후보만 유지하면 메모리와 갱신 비용을 k에 맞출 수 있다.', 12, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '모든 원소를 배열에 저장하고 매 입력마다 전체 배열을 다시 정렬한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '크기 1의 최대 힙만 유지해 가장 큰 값 하나만 보관한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '크기 k의 최소 힙을 유지하며 새 값이 루트보다 클 때 교체한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '입력 순서를 유지하는 큐에서 앞의 k개만 남긴다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '가장 작은 k개를 유지하려면 힙의 방향을 어떻게 바꾸는가?', 1, 1, 'HARD', '크기 k의 최대 힙을 사용해 후보 중 가장 큰 값을 [[탈락 경계]]로 둔다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '새 값이 루트보다 작을 때만 루트를 교체하면 현재까지 본 값 중 작은 k개를 남길 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '탈락 경계', '현재 후보에 남을 수 있는지 결정하는 가장 낮은 우선순위의 기준값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'top-k', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '스트림 처리', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'O(n log k)', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '교체 기준', '새 원소가 현재 top-k 후보에 들어갈지를 결정하는 경계값');

-- STEP 12 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '배열 힙으로 작업 우선순위를 관리한다. 작업 ID만 주어졌을 때 그 작업의 우선순위를 자주 바꾸고, 같은 작업은 힙에 하나만 유지해야 한다. 직접 갱신을 효율적으로 지원하는 설계는 무엇인가?', NULL, '우선순위를 고치기 전에 작업이 배열의 어느 위치에 있는지 빠르게 알아내는 방법을 생각하세요.', NULL, 'ID에서 배열 위치로 가는 [[위치 맵]]을 함께 두면 갱신 대상을 빠르게 찾을 수 있다.\n키가 바뀐 뒤에는 방향에 맞게 sift-up이나 sift-down으로 힙을 복구한다.\n원소 교환 때 맵의 인덱스도 함께 바꿔 두 구조의 일관성을 지켜야 한다.', '작업 B가 인덱스 7에 있다는 맵을 조회해 값을 바꾸고, B가 위나 아래로 이동할 때 새 인덱스를 맵에 기록한다.', '루트만 보거나 배열을 매번 처음부터 찾으면 ID 기반 갱신이 느려진다. 정렬 배열로 매번 바꾸면 삽입과 이동 비용이 커지고 힙의 장점을 잃는다.', 12, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '작업 ID에서 힙 배열 인덱스로 가는 맵을 함께 유지한다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '항상 루트 작업만 갱신하고 다른 ID 요청은 무시한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '갱신할 때마다 힙 배열 전체를 정렬 배열로 다시 만든다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '작업 ID와 관계없이 임의의 인덱스를 골라 우선순위를 바꾼다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '힙에서 두 원소를 교환할 때 위치 맵을 갱신하지 않으면 어떤 오류가 생기는가?', 1, 1, 'HARD', '맵이 오래된 인덱스를 가리키는 [[불일치 상태]]가 되어 다른 작업을 잘못 수정할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '힙 배열과 맵은 같은 작업 위치를 표현한다. 한쪽만 바뀌면 다음 조회가 실제 위치와 다른 칸을 반환한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '불일치 상태', '서로 같은 정보를 나타내야 하는 두 자료구조의 값이 어긋난 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '키 갱신', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '보조 인덱스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '복합 자료구조', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '위치 맵', '원소 식별자에서 그 원소가 저장된 힙 배열 인덱스로 연결하는 매핑');

-- STEP 12 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '최소 힙에서 숫자가 작을수록 우선순위가 높다. 작업의 현재 배열 위치를 위치 맵으로 알고 있고 우선순위 값을 20에서 5로 낮춘 뒤 부모 방향으로 복구한다. 이 키 갱신 연산을 ___라고 한다.', NULL, '최소 힙의 키 값을 더 작은 값으로 바꾸는 동작에 붙는 표준 이름을 떠올려 보세요.', NULL, '[[decrease-key]]는 최소 힙의 원소 키를 더 작은 값으로 바꾸는 갱신 연산이다.\n새 값은 부모보다 작아질 수 있어 현재 위치에서 sift-up으로 순서를 복구한다.\n위치 맵이 없다면 작업 ID에서 배열 위치를 찾는 데 최악 O(n)이 먼저 들 수 있다.', '값 20을 5로 바꾼 원소가 부모 8 아래에 있다면 5와 8을 바꾸고 새 부모와 다시 비교한다.', '새 원소를 추가하는 insert와 기존 원소의 키를 낮추는 연산은 다르다. 빠른 갱신 시간에는 대상의 현재 위치를 이미 안다는 전제가 필요하다.', 12, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'decrease-key');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '키 감소');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '감소 키 연산');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '최소 힙에서 키를 5에서 20으로 늘리면 복구 방향은 어떻게 판단하는가?', 1, 1, 'MEDIUM', '새 값이 자식보다 커질 수 있으므로 필요한 경우 더 작은 자식 쪽으로 [[하향 복구]]한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '키가 커지면 부모와의 최소 힙 조건은 그대로일 수 있지만 자식과의 조건이 깨질 수 있다. 두 자식 중 더 작은 값과 비교하며 내려간다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '하향 복구', '힙 조건을 어긴 원소를 알맞은 자식과 바꾸며 아래쪽으로 이동시키는 복구');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '우선순위 갱신', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '위치 맵 전제', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'sift-up', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'decrease-key', '최소 힙에서 기존 원소의 키를 더 작은 값으로 바꾸고 힙 순서를 복구하는 연산');

-- STEP 13. 데이터가 그래프가 되는 순간
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (13, '데이터가 그래프가 되는 순간', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '그래프는 대상을 정점으로, 대상 사이 관계를 간선으로 표현한다. 한 정점이 여러 정점과 연결되고 두 대상 사이에 여러 경로가 있거나 순환이 가능할 때 트리보다 자연스럽다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '정점과 간선', 'SNS에서는 사용자가 정점, 친구나 팔로우가 간선이 될 수 있다. 도로망에서는 교차로가 정점, 교차로를 잇는 도로 구간이 간선이 될 수 있다. 무엇을 대상과 관계로 볼지는 질문에 맞춰 정한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '트리보다 넓은 관계', '루트 트리는 각 노드의 부모를 하나로 정해 계층을 표현하고, 일반적인 트리는 사이클이 없는 연결 구조다. 그래프는 여러 부모 역할의 연결이나 순환, 서로 떨어진 연결 요소도 표현할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '경로가 하나가 아닐 때', '도시 A에서 C로 갈 때 A-B-C와 A-D-C가 모두 가능하면 두 정점 사이에 여러 경로가 있다. 이런 선택지와 되돌아오는 길을 보존하려면 단일 부모 관계만으로는 부족하다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 13 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '그래프는 반드시 사이클이 없어야 하므로 출발 정점으로 돌아오는 관계는 표현할 수 없다.', NULL, '되돌아오는 연결을 허용하는 일반 관계 구조와 이를 금지하는 특정 구조를 구분하세요.', 'X', '일반 그래프는 루트가 없어도 되고 모든 정점이 연결될 필요도 없다.\n같은 정점으로 돌아오는 [[사이클]]을 허용하는 그래프도 많다.\n제시된 조건은 일반 그래프가 아니라 특정한 트리의 성질에 가깝다.', '서로 교류하지 않는 두 사용자 집단은 한 그래프 안의 서로 다른 연결 요소로 표현할 수 있다.', '그래프는 트리보다 넓은 개념이다. 관계 요구에 따라 연결되지 않은 부분이나 순환을 포함할 수 있어 루트·연결·무순환을 모두 강제하지 않는다.', 13, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'A-B-C-A 사이클이 있는 무방향 그래프가 일반적인 트리가 될 수 없는 이유는 무엇인가?', 1, 1, 'MEDIUM', '사이클이 있으면 두 정점 사이에 둘 이상의 단순 경로가 생겨 [[트리 경로 조건]]을 어긴다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '트리에서는 연결된 두 정점 사이의 단순 경로가 하나뿐이다. A와 C 사이에는 직접 간선 A-C와 A-B-C라는 두 경로가 생긴다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '트리 경로 조건', '트리에서 서로 다른 두 정점 사이의 단순 경로가 정확히 하나여야 한다는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '트리와 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비연결 그래프', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '순환 관계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '사이클', '한 정점에서 출발해 간선을 따라가고 중간 정점을 반복하지 않은 채 다시 출발점으로 돌아오는 경로');

-- STEP 13 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '한 사용자가 여러 사용자와 친구가 될 수 있고 친구들 사이에도 서로 연결될 수 있는 SNS 관계는 그래프로 표현하기 자연스럽다.', NULL, '한 대상이 하나의 부모만 가지는 계층인지 여러 방향으로 연결되는 관계인지 구분하세요.', 'O', 'SNS 사용자는 정점, 친구 관계는 두 사용자를 잇는 [[간선]]으로 표현할 수 있다.\n한 사용자가 여러 관계를 맺고 친구 사이에도 추가 연결이 생길 수 있다.\n단일 부모·자식 계층보다 일반적인 그래프 관계가 자연스럽다.', 'A가 B와 C의 친구이고 B와 C도 친구라면 세 정점과 세 연결로 삼각형 모양의 관계가 생긴다.', '사용자마다 부모를 하나만 정하는 트리는 친구 관계의 교차 연결을 잃을 수 있다. 여러 사용자 사이의 관계를 그대로 남기는 표현이 필요하다.', 13, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'SNS에서 사용자 프로필과 친구 관계 정보는 각각 어디에 둘 수 있는가?', 1, 1, 'MEDIUM', '사용자 속성은 정점에, 두 사용자 사이의 관계 속성은 [[간선 속성]]에 둘 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '가입일은 사용자 자체의 정보이고 친구가 된 시각은 두 사용자 사이 관계의 정보다. 데이터가 설명하는 대상을 기준으로 위치를 나눈다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '간선 속성', '두 정점 사이 관계에 붙는 종류, 시간, 비용 같은 추가 정보');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '소셜 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다대다 관계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '관계 모델링', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '간선', '그래프에서 두 정점 사이의 관계나 연결을 나타내는 요소');

-- STEP 13 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '작업 C는 A와 B가 모두 끝나야 시작할 수 있고, 다른 작업도 여러 선행 작업을 가질 수 있다. 선행 작업에서 다음 작업으로 화살표를 둔다면 이 관계를 가장 정확히 표현한 것은 무엇인가?', NULL, '한 작업으로 들어오는 선행 연결이 둘 이상일 때 하나의 부모만 허용하는 구조로 충분한지 살펴보세요.', NULL, '방향 그래프에서 A→C와 B→C를 함께 두면 C의 [[다중 선행조건]]을 보존할 수 있다.\n한 정점으로 들어오는 간선 수를 하나로 제한하지 않으므로 여러 선행 작업을 표현한다.\n사이클이 없어도 여러 부모 역할의 연결만으로 단일 부모 트리와 구조가 달라진다.', '배포 작업 D도 B와 C가 모두 끝나야 한다면 B→D와 C→D를 추가해 두 조건을 따로 남긴다.', 'C의 부모를 A 하나로만 정하면 B가 먼저 끝나야 한다는 조건을 잃는다. 실행 순서 배열 하나도 여러 작업 사이의 선행 관계를 일반적으로 보존하지 못한다.', 13, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'C의 부모를 A 하나로만 정하고 B와 C의 선행 관계는 버리는 트리', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'A, B, C의 이름만 정렬하고 선행 연결은 저장하지 않는 배열', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '완료 시각이 가장 빠른 작업 하나만 남기고 다른 관계는 버리는 힙', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '작업을 정점으로 두고 A→C와 B→C를 모두 저장하는 방향 그래프', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'A→C와 B→C가 있을 때 C의 진입 차수는 얼마이며 무엇을 세는가?', 1, 1, 'MEDIUM', 'C의 [[진입 차수]]는 2이며 C로 들어오는 방향 간선의 수를 센다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', 'A→C와 B→C가 각각 하나씩 들어온다. 화살표 방향을 반대로 정의했다면 무엇을 세는지도 함께 바뀌므로 방향의 의미를 먼저 정해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '진입 차수', '방향 그래프에서 한 정점으로 들어오는 간선의 수');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다중 부모 관계', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '방향 간선', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '진입 차수', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '다중 선행조건', '한 작업이 시작되기 전에 둘 이상의 다른 작업 완료를 요구하는 관계');

-- STEP 13 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '도시의 도로망에서 교차로 사이의 여러 대체 경로와 다시 출발점으로 돌아오는 길을 보존하려 한다. 대상을 정점과 간선으로 나누는 방법으로 가장 적절한 것은 무엇인가?', NULL, '이동 선택이 갈라지거나 합쳐지는 위치와 그 위치들을 직접 잇는 구간을 구분하세요.', NULL, '교차로를 정점, 두 교차로를 잇는 도로 구간을 [[도로 간선]]으로 두면 관계를 보존할 수 있다.\n여러 도로를 통해 같은 목적지에 가는 대체 경로도 각각 남는다.\n도로가 연결된 형태에 따라 출발점으로 돌아오는 사이클도 표현된다.', 'A-B-C와 A-D-C 도로가 있으면 A에서 C로 가는 두 경로를 모두 그래프에 둘 수 있다.', '교차로를 하나의 선형 목록에만 두면 어느 교차로 사이에 도로가 있는지와 대체 경로를 잃는다. 도로 자체를 정점으로만 두는 선택도 질문의 대상·관계 구분과 맞지 않는다.', 13, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '모든 교차로를 방문 시간 순서의 배열 하나로만 둔다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '교차로를 정점으로, 교차로를 잇는 도로 구간을 간선으로 둔다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '도로 구간 수만 저장하고 연결된 교차로는 저장하지 않는다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '도시 전체를 정점 하나로 만들고 모든 도로 정보를 버린다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 두 교차로 사이에 서로 다른 도로가 두 개 있다면 무엇을 확인해야 하는가?', 1, 1, 'HARD', '같은 정점 쌍 사이의 여러 간선을 허용하는 [[다중 그래프]]가 필요한지 확인해야 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '도로마다 이름이나 비용이 다르면 하나의 연결로 합칠 때 정보가 사라질 수 있다. 요구사항이 병렬 관계를 구분하는지 먼저 정한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '다중 그래프', '같은 두 정점 사이에 둘 이상의 간선을 허용하는 그래프');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '도로망 모델링', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '대체 경로', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '정점 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '도로 간선', '도로 그래프에서 두 교차로 사이의 직접 연결 구간을 나타내는 간선');

-- STEP 13 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '무방향 그래프에 A-B, B-C, X-Y 간선만 있고 두 묶음 사이의 간선은 없다. 서로 경로로 이어진 정점들의 최대 묶음 하나를 ___라고 한다.', NULL, '서로 도달할 수 있으면서 바깥의 다른 묶음과는 이어지지 않은 최대 집단의 이름을 떠올려 보세요.', NULL, '[[연결 요소]]는 무방향 그래프에서 서로 경로로 이어진 정점들의 최대 묶음이다.\nA, B, C는 한 연결 요소이고 X, Y는 다른 연결 요소다.\n그래프 전체가 하나로 연결되지 않아도 여러 연결 요소를 함께 표현할 수 있다.', '정점 Z가 아무 간선도 갖지 않아도 {Z} 하나만으로 별도의 연결 요소가 된다.', '간선 하나나 경로 하나만을 뜻하는 말이 아니다. 더 추가할 수 없을 때까지 서로 도달 가능한 정점을 모은 최대 집단을 묻는다.', 13, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '연결 요소');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '연결 성분');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'connected component');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '간선이 하나도 없는 고립 정점 Z도 연결 요소가 될 수 있는가?', 1, 1, 'HARD', 'Z는 자기 자신으로 이루어진 [[단일 정점 연결 요소]]가 될 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '길이 0인 경로로 Z는 자기 자신에 도달한다. 다른 정점과 이어지지 않았으므로 {Z}가 더 확장할 수 없는 최대 묶음이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '단일 정점 연결 요소', '다른 정점과 간선이 없는 정점 하나만으로 이루어진 연결 요소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비연결 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '고립 정점', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '도달 가능성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '연결 요소', '무방향 그래프에서 서로 경로로 연결된 정점들의 최대 묶음');

-- STEP 14. 방향·가중치·사이클을 요구사항으로 결정하기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (14, '방향·가중치·사이클을 요구사항으로 결정하기', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '그래프의 방향과 가중치는 서로 다른 요구를 표현한다. 관계가 반대로도 성립하는지, 연결마다 숫자 비용이 필요한지, 다시 출발점으로 돌아오는 순환이 어떤 의미인지 사례별로 정해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '방향은 관계의 비대칭을 나타낸다', 'A가 B를 팔로우해도 B가 A를 팔로우하지 않을 수 있으므로 방향 간선이 자연스럽다. 친구처럼 관계가 서로에게 동시에 성립한다면 무방향 간선으로 표현할 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '가중치는 연결의 수치를 담는다', '거리, 시간, 요금처럼 연결마다 비교할 숫자가 필요하면 간선에 가중치를 둔다. 단순히 연결 여부만 필요하면 가중치 없이도 충분하다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '양방향과 같은 비용은 다르다', '도로가 양쪽으로 통행 가능해도 오르막, 통행료, 시간 때문에 방향별 비용이 다를 수 있다. 이때는 서로 다른 가중치를 가진 두 방향 간선이 더 정확할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '사이클의 도메인 의미', '도로의 사이클은 돌아오는 경로로 자연스러울 수 있지만 패키지 의존성의 사이클은 빌드 순서를 정하기 어렵게 하는 문제일 수 있다. 구조만 보지 말고 업무 의미를 해석한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 14 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '사용자 A가 B를 팔로우해도 B가 A를 팔로우한다는 보장이 없다면 팔로우 관계는 방향 간선으로 표현하는 것이 자연스럽다.', NULL, '한쪽의 관계가 생겼을 때 반대쪽 관계도 자동으로 성립하는지 확인하세요.', 'O', '팔로우는 출발 사용자와 도착 사용자의 역할이 다른 [[방향 관계]]다.\nA→B가 있어도 B→A는 별도의 팔로우가 없으면 존재하지 않는다.\n방향 간선은 이 비대칭을 잃지 않고 표현한다.', 'A가 B의 글을 구독하지만 B는 A의 글을 구독하지 않는 상태를 간선 A→B 하나로 나타낼 수 있다.', '무방향 간선 하나로 저장하면 A의 팔로우가 B의 역방향 팔로우까지 뜻하게 된다. 실제 요구와 다른 관계를 만들어 낸다.', 14, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '서로 맞팔로우한 두 사용자는 방향 그래프에서 어떻게 표현하는가?', 1, 1, 'EASY', 'A→B와 B→A라는 두 [[반대 방향 간선]]을 모두 저장한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '각 간선은 한 사용자의 독립적인 팔로우 행동을 나타낸다. 한쪽이 팔로우를 끊어도 다른 방향은 남을 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '반대 방향 간선', '같은 두 정점 사이에서 출발점과 도착점이 서로 뒤바뀐 두 간선');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '팔로우 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비대칭 관계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '간선 방향', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '방향 관계', '출발 대상과 도착 대상의 역할을 구분해야 하는 관계');

-- STEP 14 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '도로가 양쪽 방향으로 통행 가능하다면 출발 방향과 관계없이 이동 시간도 항상 같으므로 같은 가중치 하나만 저장하면 된다.', NULL, '통행 가능 여부와 오르막·혼잡처럼 방향별 이동 비용이 같은지는 별도 요구인지 생각해 보세요.', 'X', '양쪽 통행 가능성만으로 방향별 [[이동 비용]]까지 같다고 결론 낼 수 없다.\n오르막, 신호, 통행료, 혼잡 때문에 A→B와 B→A의 값이 다를 수 있다.\n요구가 방향별 비용을 구분하면 두 방향 간선에 각각 가중치를 둔다.', '산길은 A에서 B로 오를 때 20분, B에서 A로 내려올 때 12분이 걸릴 수 있다.', '방향은 갈 수 있는지를, 가중치는 비용이 얼마인지를 나타낸다. 양방향 통행이 두 비용의 동일함을 보장하지 않는다.', 14, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '방향별 시간이 다를 때 두 교차로 사이를 어떻게 저장할 수 있는가?', 1, 1, 'MEDIUM', 'A→B와 B→A를 나누고 각 간선에 별도 [[방향별 가중치]]를 둔다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '두 간선은 같은 도로의 반대 통행을 나타내지만 시간 값은 독립적이다. 일방통행이면 허용된 방향만 남긴다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '방향별 가중치', '같은 두 정점 사이에서도 이동 방향에 따라 따로 저장하는 비용 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '양방향 도로', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비대칭 비용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '요구사항 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '이동 비용', '한 연결을 따라 이동할 때 드는 시간, 거리, 요금 같은 수치');

-- STEP 14 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '배포 작업에서 A→B는 A가 끝난 뒤 B를 시작할 수 있다는 뜻이다. A→B, B→C, C→A가 모두 있을 때 가장 적절한 모델과 해석은 무엇인가?', NULL, '선행 방향을 따라가 다시 출발 작업으로 돌아오면 어떤 작업을 첫 시작점으로 고를 수 있는지 살펴보세요.', NULL, '선행 조건은 출발과 도착을 보존한 [[방향 사이클]]로 모델링할 수 있다.\nA→B→C→A에서는 A 전에 C, C 전에 B, B 전에 A가 끝나야 하는 순환이 생긴다.\n이 배포 규칙에서는 첫 작업을 정할 수 없으므로 사이클을 경고로 해석한다.', 'B는 A를, C는 B를, A는 C를 기다리므로 세 작업 중 어느 것도 조건 없이 시작할 수 없다.', '방향을 버리면 어느 작업이 먼저여야 하는지 알 수 없다. 가중치를 0으로 바꿔도 간선 연결과 순환은 사라지지 않는다.', 14, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '무방향 그래프로 바꾸면 선행 순서가 자동으로 결정된다고 본다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '가중치를 모두 0으로 두면 사이클이 사라진다고 본다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '방향 그래프로 선행 조건을 저장하고 A→B→C→A 사이클을 시작 순서 경고로 해석한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '서비스 이름을 정렬하면 실제 호출 의존성도 그 순서가 된다고 본다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '도로 그래프의 사이클은 같은 구조라도 왜 반드시 오류가 아닌가?', 1, 1, 'MEDIUM', '출발점으로 돌아오는 길이 실제 이동 선택지를 나타내는 [[정상 순환]]일 수 있기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '사이클의 모양만으로 좋고 나쁨을 정할 수 없다. 의존성에서는 막힘을 뜻할 수 있고 도로에서는 왕복 경로를 뜻할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '정상 순환', '도메인 요구에서 허용되며 실제 관계를 올바르게 나타내는 사이클');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '순환 의존성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '도메인 해석', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '방향 그래프', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '방향 사이클', '간선 방향을 따라 이동해 출발 정점으로 돌아오는 경로');

-- STEP 14 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '한 회사에서 두 직원의 협업 여부만 저장한다. A가 B와 협업하면 B도 A와 협업한 것이며 시간이나 비용 수치는 필요 없다. 가장 알맞은 그래프 종류는 무엇인가?', NULL, '관계가 양쪽에 동시에 성립하는지와 연결마다 숫자를 저장할 필요가 있는지 나누어 판단하세요.', NULL, '협업 관계가 서로에게 동시에 성립하므로 [[무방향·무가중]] 그래프가 알맞다.\n간선 하나가 A와 B의 상호 협업을 나타낸다.\n비용 비교가 요구되지 않으므로 별도 가중치를 둘 필요가 없다.', '직원 A와 B 사이에 간선 {A,B} 하나를 두면 어느 쪽에서 보아도 같은 협업 관계다.', '한쪽만 성립하는 방향 관계가 아니며 이동 시간 같은 수치도 요구되지 않는다. 필요하지 않은 방향과 가중치를 추가하면 모델의 의미가 복잡해진다.', 14, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '무방향·무가중 그래프', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '방향·가중 그래프', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '방향 그래프이되 모든 간선의 반대 방향을 금지한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '간선 없이 직원 이름만 저장한 그래프', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '협업 횟수도 함께 비교해야 한다면 무엇을 바꾸면 되는가?', 1, 1, 'MEDIUM', '방향은 그대로 두고 간선에 횟수를 나타내는 [[관계 가중치]]를 추가할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '상호 관계라는 성질은 바뀌지 않는다. 새 요구는 연결마다 숫자를 저장하는 것이므로 가중치 축만 바꾸면 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '관계 가중치', '두 대상의 연결 강도나 횟수를 간선에 붙여 나타낸 수치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '상호 관계', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '무가중 그래프', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '최소 모델', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '무방향·무가중', '간선에 방향 구분과 숫자 비용을 두지 않는 그래프 성질');

-- STEP 14 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '도시 사이 연결마다 예상 이동 시간이 다르고 경로 비용 비교에 이 숫자가 필요하다. 각 간선에 이런 수치를 저장하는 그래프를 ___라고 한다.', NULL, '연결의 존재만이 아니라 시간이나 거리처럼 비교할 숫자도 간선에 붙이는 구조를 찾으세요.', NULL, '[[가중 그래프]]는 각 간선에 시간, 거리, 요금 같은 수치를 저장한다.\n같은 연결 구조라도 가중치에 따라 경로 비용의 비교 결과가 달라질 수 있다.\n방향 여부는 별도 결정이므로 가중 그래프가 반드시 방향 또는 무방향인 것은 아니다.', 'A-B는 5분, B-C는 8분처럼 도로 구간마다 이동 시간을 간선 값으로 둘 수 있다.', '무가중 그래프는 연결 여부만으로 충분할 때 사용한다. 이 사례는 간선마다 서로 다른 이동 시간을 보존해야 한다.', 14, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '가중 그래프');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'weighted graph');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '도로의 가중치로 거리와 시간을 동시에 써야 한다면 무엇을 먼저 정해야 하는가?', 1, 1, 'HARD', '질의가 비교할 비용이 무엇인지와 여러 수치를 합치는 [[비용 기준]]을 먼저 정해야 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '거리 최적과 시간 최적은 다른 결과를 낼 수 있다. 두 수치를 모두 저장할 수 있지만 어떤 값을 판단에 쓸지는 요구사항이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '비용 기준', '경로 또는 연결의 좋고 나쁨을 비교할 때 사용하는 수치와 계산 규칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '간선 가중치', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '비용 모델', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '방향과 가중치 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '가중 그래프', '각 간선에 비용이나 거리 같은 숫자 값을 붙인 그래프');

-- STEP 15. 인접 리스트·인접 행렬·간선 목록 비교
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (15, '인접 리스트·인접 행렬·간선 목록 비교', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '정점 수를 V, 간선 수를 E, 이 단계에서는 정점 v의 인접 목록 항목 수를 deg(v)라 하자. 인접 리스트는 희소 그래프와 이웃 순회에, 인접 행렬은 잦은 간선 존재 확인에, 간선 목록은 전체 간선 처리와 단순 저장에 강점이 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '인접 리스트의 전제와 비용', '각 정점의 인접 간선을 평범한 리스트로 저장하면 공간은 O(V+E), v의 목록 순회는 O(deg(v)), v에서 u로 가는 간선 확인은 최악 O(deg(v))다. 방향 그래프에서는 여기서 deg(v)를 v에서 나가는 간선 항목 수로 쓴다. 이웃을 해시 집합으로 두면 평균 조회는 달라질 수 있지만 추가 비용과 전제가 생긴다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '인접 행렬의 고정된 표', 'V×V 표의 칸에 간선 여부나 가중치를 저장하면 공간은 O(V²)다. 두 정점의 인덱스를 알면 간선 존재 확인은 O(1)이지만 한 정점의 모든 이웃을 찾으려면 행의 V개 칸을 확인한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '간선 목록의 강점과 약점', '(출발, 도착, 가중치) 레코드 E개 자체는 O(E) 공간이며 전체 간선을 차례로 읽기 쉽다. 고립 정점을 포함한 정점 정보까지 별도로 두면 전체 표현은 O(V+E)이고, 별도 인덱스가 없으면 특정 정점의 이웃을 찾을 때 E개 간선을 살펴볼 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '복잡도에는 표현 전제가 있다', '인접 리스트라는 이름만으로 간선 조회가 항상 O(1)인 것은 아니다. 내부가 배열·연결 리스트인지 해시 집합인지, 그래프가 방향인지와 무방향 간선을 두 번 저장하는지까지 밝혀야 정확히 비교할 수 있다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 15 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '각 정점의 이웃을 정렬되지 않은 평범한 리스트로 저장하고 deg(v)를 v의 목록 항목 수라 하자. 정점 v에서 u로 가는 간선이 있는지 항상 O(1)에 확인할 수 있다.', NULL, 'v의 이웃 목록에서 u를 찾을 때 몇 개의 항목을 지나갈 수 있는지 생각해 보세요.', 'X', '평범한 이웃 리스트에서는 u를 찾기 위해 최대 [[deg(v)]]개 이웃을 확인한다.\n따라서 간선 존재 확인은 최악 O(deg(v))이며 항상 O(1)이 아니다.\n해시 집합 같은 다른 컨테이너를 쓰면 평균 조회 특성이 달라질 수 있다.', 'v의 이웃이 100개이고 u가 없거나 마지막에 있다면 100개를 모두 비교할 수 있다.', '인접 리스트의 공간 복잡도와 개별 간선 조회 비용을 혼동한 설명이다. O(1) 조회를 원하면 행렬이나 별도 해시 기반 이웃 저장 같은 전제가 필요하다.', 15, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '이웃을 해시 집합으로 저장하면 무엇을 함께 고려해야 하는가?', 1, 1, 'HARD', '평균적으로 빠른 조회와 함께 해시 충돌, 추가 메모리, 순서 부재 같은 [[해시 전제]]를 고려해야 한다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '해시 집합은 보통 평균 O(1) 존재 확인을 기대하지만 최악 시간을 항상 보장하지 않는다. 반복 순서가 필요한지도 따져야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '해시 전제', '해시 함수와 충돌 처리, 적재율 같은 평균 성능 판단에 필요한 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '간선 존재 확인', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '이웃 컨테이너', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '차수', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'deg(v)', '이 문제에서 정점 v의 인접 목록에 저장된 간선 항목 수를 나타내는 표기');

-- STEP 15 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '정점 V=1000개와 간선 E=2000개인 희소 그래프를 저장할 때, 인접 리스트의 O(V+E) 공간은 인접 행렬의 O(V²) 공간보다 작을 가능성이 크다.', NULL, '1000+2000 규모와 1000×1000 칸의 규모를 비교하세요.', 'O', '인접 리스트는 정점별 목록과 실제 간선을 저장해 [[O(V+E) 공간]]을 사용한다.\n주어진 값에서는 V+E가 3000 규모이고 V²은 1,000,000 규모다.\n간선이 적은 희소 그래프에서는 인접 리스트의 공간 이점이 크다.', '무방향 간선을 양쪽 목록에 저장해 간선 항목이 약 2E가 되어도 O(V+E) 차수는 그대로다.', '인접 행렬은 실제 간선이 없는 정점 쌍의 칸도 마련한다. E가 V²보다 훨씬 작으면 빈 관계를 위한 공간 비중이 커진다.', 15, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '무방향 인접 리스트에서 간선 하나를 두 정점의 목록에 모두 넣어도 공간이 O(V+E)인 이유는 무엇인가?', 1, 1, 'MEDIUM', '간선 항목 수가 2E로 늘어도 상수 2를 제외한 [[점근적 공간]]은 O(V+E)이기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '빅오 표기는 입력이 커질 때의 증가 차수를 본다. 2E는 E와 같은 선형 차수지만 실제 메모리 사용량 차이는 구현에서 고려해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '점근적 공간', '입력 크기가 커질 때 필요한 메모리가 어떤 차수로 증가하는지 나타낸 표현');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '희소 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'V와 E', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '공간 복잡도', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'O(V+E) 공간', '정점 수와 간선 수의 합에 비례해 저장 공간이 늘어나는 복잡도');

-- STEP 15 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '방향 그래프를 평범한 인접 리스트로 저장했다. 정점 v의 나가는 간선 목록 항목 수를 deg(v)라 하며 한 사례에서는 deg(v)=4다. 모든 나가는 이웃을 한 번씩 읽는 작업의 일반적인 시간 복잡도와 이 사례의 읽기 횟수를 올바르게 연결한 것은 무엇인가?', NULL, '전체 정점 수보다 실제로 v의 목록에 저장된 이웃 항목 수를 기준으로 세어 보세요.', NULL, 'v의 목록에는 나가는 이웃 4개가 있어 순회 시간은 [[O(deg(v))]]다.\n이 사례에서 deg(v)=4이므로 이웃 네 항목을 한 번씩 읽는다.\n그래프 전체의 V개 정점이나 E개 간선을 모두 훑을 필요는 없다.', 'v의 목록이 [a,b,c,d]라면 네 원소를 차례로 방문하고 목록 끝에서 멈춘다.', 'O(V²)는 인접 행렬 전체 크기와 관련된 값이고 O(E)는 전체 간선을 모두 볼 때의 값이다. 이 작업은 v에 붙은 이웃 목록 하나만 순회한다.', 15, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'O(1), 이웃 수와 관계없이 한 번만 읽는다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'O(V²), 모든 정점 쌍을 확인한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'O(E²), 모든 간선 쌍을 비교한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, 'O(deg(v)), 이 사례에서는 이웃 4개를 읽는다', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '방향 그래프에서 들어오는 이웃도 자주 순회해야 한다면 어떤 표현을 추가할 수 있는가?', 1, 1, 'HARD', '나가는 목록과 별도로 각 정점의 [[역방향 인접 리스트]]를 함께 유지할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '간선을 추가하거나 제거할 때 두 목록을 모두 갱신해야 하지만 들어오는 이웃을 매번 전체 간선에서 찾는 비용을 줄일 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '역방향 인접 리스트', '각 정점으로 들어오는 간선의 출발 정점들을 따로 저장한 이웃 목록');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '이웃 순회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '나가는 차수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '방향 그래프 저장', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, 'O(deg(v))', '정점 v의 이웃 수에 비례하는 실행 시간');

-- STEP 15 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '정점 수 V가 크지 않고 간선이 매우 촘촘한 그래프에서 두 정점의 번호를 알고 간선 존재를 매우 자주 확인한다. O(V²) 공간을 감당할 수 있을 때 알맞은 표현은 무엇인가?', NULL, '두 정점 번호로 표의 한 칸을 바로 읽는 대신 모든 정점 쌍의 공간을 마련하는 선택을 찾으세요.', NULL, '[[인접 행렬]]은 두 정점 인덱스로 한 칸을 읽어 간선 존재를 O(1)에 확인한다.\n대신 간선이 없는 정점 쌍까지 포함해 O(V²) 공간을 사용한다.\n그래프가 촘촘하고 공간을 감당하며 존재 조회가 많다는 조건과 잘 맞는다.', 'matrix[u][v] 한 칸에 간선 여부를 두면 u와 v의 목록을 검색하지 않고 직접 확인할 수 있다.', '평범한 인접 리스트는 v의 이웃을 검색해야 하고, 간선 목록은 최악에 전체 E개를 훑을 수 있다. 이 요구는 추가 공간을 써서 개별 존재 조회를 빠르게 하려는 경우다.', 15, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '별도 인덱스가 없는 간선 목록', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '인접 행렬', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '정렬되지 않은 평범한 인접 리스트만 사용', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '정점 관계를 버리고 정점 값만 둔 배열', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '인접 행렬에서 정점 v의 모든 이웃을 찾는 데 O(V)가 드는 이유는 무엇인가?', 1, 1, 'MEDIUM', 'v에 해당하는 행의 V개 칸을 확인하는 [[행 순회]]가 필요하기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '실제 이웃이 적어도 어느 칸이 연결됐는지 알기 위해 행 전체를 본다. 행렬은 존재 확인과 이웃 열거의 비용이 다르다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '행 순회', '인접 행렬에서 한 정점에 대응하는 가로 칸들을 차례로 확인하는 작업');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '조밀 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'O(V²) 공간', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '상수 시간 조회', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '인접 행렬', '정점 쌍마다 간선 여부나 가중치를 V×V 표의 칸에 저장하는 그래프 표현');

-- STEP 15 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '그래프의 모든 연결을 출발 정점, 도착 정점, 가중치 레코드로 파일에 저장하고 전체 E개 연결을 차례로 읽는 작업이 대부분이다. 별도 이웃 인덱스 없이 이런 레코드들의 모음으로 저장하는 표현은 ___이다.', NULL, '정점별 표나 이웃 묶음 대신 연결 하나를 레코드 하나로 직접 나열하는 방식을 찾으세요.', NULL, '[[간선 목록]]의 E개 간선 레코드 자체는 O(E) 공간에 저장된다.\n고립 정점까지 별도로 기록하면 전체 그래프 표현은 O(V+E)가 될 수 있다.\n별도 인덱스가 없으면 특정 정점의 이웃을 찾을 때 O(E)가 들 수 있다.', '(A,B,5), (B,C,8)처럼 출발점, 도착점, 가중치를 행 단위로 저장할 수 있다.', '인접 행렬은 모든 정점 쌍의 칸을 만들고, 인접 리스트는 정점별 이웃 묶음을 둔다. 질문은 간선 레코드 자체를 순서대로 모은 표현을 묻는다.', 15, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '간선 목록');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'edge list');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '간선 목록에서 특정 정점의 이웃 조회가 잦아지면 무엇을 추가할 수 있는가?', 1, 1, 'HARD', '정점에서 관련 간선 위치로 가는 [[보조 인덱스]]를 만들어 전체 목록 순회를 줄일 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '인덱스는 조회를 빠르게 하지만 저장 공간과 갱신 비용을 더한다. 전체 간선 순회만 필요한지 개별 이웃 조회도 중요한지 보고 결정한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '보조 인덱스', '원본 레코드의 위치를 특정 키에서 빠르게 찾도록 추가로 유지하는 조회 구조');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '전체 간선 순회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '간선 레코드 공간', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '그래프 파일 형식', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '간선 목록', '그래프의 각 간선을 출발점과 도착점 등의 레코드로 나열한 표현');

-- STEP 16. 요구사항에서 복합 자료구조까지 — 최종 선택
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (16, '요구사항에서 복합 자료구조까지 — 최종 선택', 3, @data_structures_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@data_structures_quiz_step_id, '하나의 자료구조가 모든 연산에 가장 좋지는 않다. ID 조회, 정렬·범위, 최고 우선순위, 관계와 이웃 조회 중 무엇이 중요한지 정한 뒤 여러 구조를 조합하고 중복 상태의 일관성 비용까지 고려한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CONCEPT', '연산에서 출발한다', '정확한 키 조회가 중심이면 해시 구조, 정렬 순서와 범위가 중심이면 균형 탐색 트리, 극값 반복 처리가 중심이면 힙, 대상 사이 연결이 중심이면 그래프 표현을 우선 검토한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', 'ID 조회와 시간 순서를 함께 지원하기', '예약 시스템은 해시 맵으로 예약 ID를 찾고 시간 기준 균형 탐색 트리로 가장 이른 예약과 시간 범위를 찾을 수 있다. 예약 시간이 바뀌면 이전 시간 키를 제거하고 새 키로 넣어 두 인덱스를 함께 갱신한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'EXAMPLE', '희소 관계와 빠른 ID 조회', '사용자 ID를 해시 맵으로 정점 객체에 연결하고, 각 정점의 친구를 인접 리스트나 집합으로 둘 수 있다. 이웃 순회와 특정 친구 확인 중 어느 쪽이 중요한지에 따라 내부 컨테이너를 고른다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@data_structures_briefing_id, 'CAUTION', '조합에는 갱신 비용이 따른다', '같은 데이터를 여러 구조에 저장하면 조회는 빨라질 수 있지만 삽입·삭제 때 모두 갱신해야 한다. 연산 빈도, 데이터 규모, 메모리와 일관성 위험을 함께 비교한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 16 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '장애 대응 시스템에서 서비스 의존 관계의 이웃을 자주 보고, 미처리 장애 중 심각도가 가장 큰 항목도 반복해서 골라야 한다면 인접 리스트와 최대 힙을 함께 쓰는 설계를 고려할 수 있다.', NULL, '대상 사이 연결을 읽는 연산과 우선순위가 가장 높은 항목을 고르는 연산을 나누어 보세요.', 'O', '인접 리스트는 서비스 사이 연결을, 최대 힙은 장애의 우선순위를 맡는 [[역할 분리]]가 가능하다.\n한 서비스의 의존 대상을 읽는 작업과 가장 심각한 장애를 고르는 작업은 서로 다른 접근 패턴이다.\n각 장애가 어느 서비스에 속하는지 식별자로 연결하면 두 구조를 함께 활용할 수 있다.', '서비스 A의 이웃 목록으로 직접 의존 대상을 확인하고, 장애 힙의 루트에서 현재 가장 심각한 티켓을 선택한다.', '그래프 표현은 관계 순회에, 힙은 극값 선택에 맞는다. 한 구조에 두 의미를 억지로 넣는 것보다 각 요구를 담당하는 표현을 조합할 수 있다.', 16, 1, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '장애 항목과 서비스 정점을 안전하게 연결하려면 어떤 값을 공유할 수 있는가?', 1, 1, 'MEDIUM', '장애가 영향을 주는 서비스를 가리키는 [[공통 식별자]]를 두 구조에서 사용할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '장애 레코드에 serviceId를 두면 힙에서 고른 항목을 그래프의 서비스 정점과 연결할 수 있다. 식별자가 없는 이름 문자열만 중복 저장하면 변경 때 어긋나기 쉽다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '공통 식별자', '서로 다른 자료구조의 레코드가 같은 대상을 가리키도록 공유하는 고유 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '그래프와 힙 조합', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '장애 우선순위', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '요구 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '역할 분리', '서로 다른 연산 요구를 각 목적에 알맞은 자료구조가 맡도록 나누는 설계');

-- STEP 16 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '상품을 ID 해시 맵과 가격 기준 균형 탐색 트리에 함께 등록했다. 상품 객체의 price 값만 10,000원에서 8,000원으로 바꾸면 일반적인 트리 구현도 이를 자동 감지해 올바른 위치로 재배치한다.', NULL, '트리가 객체 필드의 변경을 지켜보는지, 저장할 때 사용한 정렬 키를 명시적으로 다시 반영해야 하는지 생각해 보세요.', 'X', '균형 탐색 트리의 [[정렬 인덱스]]는 삽입할 때 비교한 가격 키에 따라 위치가 정해진다.\n객체 필드만 바꾼다고 일반적인 트리가 변경을 자동 감지해 재배치하지는 않는다.\n이전 가격 키의 항목을 제거하고 새 가격 키로 다시 넣는 등 명시적인 갱신이 필요하다.', '10,000원 위치에 남은 객체의 값만 8,000원으로 바꾸면 8,000원 범위 조회에서 누락되거나 트리 순서 조건이 깨질 수 있다.', '같은 객체를 두 구조가 참조해도 각 자료구조의 배치 규칙이 자동으로 다시 실행되는 것은 아니다. 키 변경 연산이 두 인덱스에 반영되어야 한다.', 16, 2, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '같은 가격의 상품이 여러 개일 때 정렬 트리의 키를 어떻게 만들 수 있는가?', 1, 1, 'MEDIUM', '가격 뒤에 상품 ID를 붙인 [[복합 정렬 키]]로 같은 가격의 항목을 구분할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '(가격, 상품 ID)를 사전식으로 비교하면 가격 순서를 유지하면서 동률 상품도 잃지 않는다. 한 가격 노드에 상품 목록을 두는 정책도 가능하다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '복합 정렬 키', '첫 기준이 같을 때 다음 기준으로 항목을 구분하도록 여러 값을 묶은 정렬 키');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '가변 키 위험', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다중 인덱스 갱신', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '트리 불변식', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '정렬 인덱스', '키의 대소 순서를 유지해 범위와 순서 조회를 지원하는 보조 구조');

-- STEP 16 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '사용자 수 V가 크고 친구 관계 E가 V²보다 훨씬 적은 서비스다. 사용자 ID 조회와 한 사용자의 친구 목록 순회가 주요 연산이다. 가장 적절한 기본 설계는 무엇인가?', NULL, '희소한 연결을 실제 존재하는 만큼만 저장하면서 사용자 식별자로 정점에 접근하는 조합을 찾으세요.', NULL, '사용자 ID는 해시 맵으로 찾고 친구 관계는 [[인접 리스트]]로 저장하는 조합이 적절하다.\n희소 그래프는 O(V+E) 규모로 실제 연결 중심의 저장이 가능하다.\n한 사용자의 친구 순회는 그 사용자의 deg(v)에 비례한다.', 'users[id]로 사용자 정점을 찾고 users[id].neighbors에서 그 사용자의 친구들만 차례로 읽을 수 있다.', 'V×V 행렬은 간선이 적어도 모든 사용자 쌍의 칸을 만든다. 힙은 친구 관계보다 우선순위 극값에 맞고, 정렬 배열 하나는 다대다 연결을 자연스럽게 담지 못한다.', 16, 3, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '모든 사용자 쌍을 위한 V×V 행렬만 만들고 ID 조회 구조는 두지 않는다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '친구 수가 가장 많은 사용자만 남기는 최대 힙 하나를 사용한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '사용자 ID용 해시 맵과 친구 관계용 인접 리스트를 함께 사용한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '사용자 이름을 정렬한 배열 하나에 친구 관계를 저장하지 않는다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '특정 두 사용자가 친구인지 확인하는 요청도 매우 많다면 이웃 컨테이너를 어떻게 바꿀 수 있는가?', 1, 1, 'HARD', '각 정점의 이웃을 해시 집합으로 두어 평균적인 [[친구 존재 조회]]를 빠르게 할 수 있다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '평범한 리스트는 deg(v)개를 훑을 수 있다. 집합은 추가 메모리와 해시 전제를 감수하고 존재 확인을 개선하는 선택이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '친구 존재 조회', '두 사용자 사이에 친구 간선이 저장되어 있는지 확인하는 연산');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '희소 소셜 그래프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, 'ID 인덱스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '이웃 순회', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '인접 리스트', '각 정점마다 직접 연결된 이웃들을 모아 두는 그래프 저장 표현');

-- STEP 16 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '예약 n개를 관리하며 예약 ID로 취소하고, 시작 시각 구간의 예약 k개를 시간순으로 조회하며, 가장 이른 예약도 확인해야 한다. 해시가 고르게 분산되고 균형 트리가 높이를 O(log n)으로 유지한다고 할 때 가장 적절한 조합은 무엇인가?', NULL, '식별자 하나의 조회와 시간 키의 최솟값·구간 순회를 각각 맡을 두 인덱스를 찾아보세요.', NULL, 'ID 해시 맵은 정확 일치 조회를, 시간 기준 균형 탐색 트리는 [[시간 순서 인덱스]]를 맡는다.\n트리에서 구간 시작을 O(log n)에 찾고 결과 k개를 방문하면 범위 조회는 O(log n+k)로 볼 수 있다.\n같은 시각은 (시각, 예약 ID) 같은 키로 구분하고 변경 시 두 구조를 함께 갱신한다.', 'cancel(r7)은 ID 맵에서 찾고, 10시부터 11시까지 조회는 시간 트리의 10시 위치에서 시작해 k개 결과를 순서대로 읽는다.', '해시 맵만으로는 시간 순서와 범위를 바로 얻기 어렵고, 최소 힙은 가장 이른 하나에는 맞지만 임의 시간 구간을 정렬된 순서로 순회하는 구조가 아니다.', 16, 4, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '예약 ID용 해시 맵과 (시작 시각, 예약 ID)를 키로 한 균형 탐색 트리를 함께 사용한다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '예약 ID용 해시 맵 하나만 두고 해시 버킷 순서로 시간 범위를 읽는다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '시작 시각 최소 힙 하나만 두면 ID 취소와 모든 시간 구간 조회도 항상 O(1)이다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@data_structures_quiz_id, '예약 수만 저장하고 각 예약의 ID와 시작 시각은 저장하지 않는다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, 'ID 맵과 최소 힙만으로 시간 구간 조회를 자주 처리하기 어려운 이유는 무엇인가?', 1, 1, 'HARD', '힙은 루트 극값만 보장해 임의 시작 시각부터 이어지는 [[범위 순회]]를 직접 지원하지 않기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '최소 힙의 배열은 전체 시간순으로 정렬되어 있지 않다. 구간 결과를 자주 순서대로 읽는 요구에는 키 순서를 유지하는 인덱스가 더 자연스럽다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '범위 순회', '정한 시작 키와 끝 키 사이의 항목을 키 순서대로 방문하는 작업');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '예약 다중 인덱스', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '범위 조회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '복합 키', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '시간 순서 인덱스', '시간 키의 대소 순서를 유지해 최솟값과 구간 조회를 지원하는 구조');

-- STEP 16 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '작업을 ID 위치 맵과 최소 힙에 함께 저장한다. 취소할 때 두 구조에서 모두 제거하거나, 한쪽 제거가 실패하면 되돌려 어느 쪽에도 변경이 보이지 않게 한다. 이런 전부 성공 또는 전부 실패의 갱신 성질을 ___이라고 한다.', NULL, '여러 변경을 쪼개 보이지 않게 하나의 작업처럼 완료하거나 되돌리는 성질의 이름을 떠올려 보세요.', NULL, '[[원자적 갱신]]은 관련 변경이 모두 성공하거나 실패 시 모두 취소된 것처럼 처리하는 성질이다.\n맵에서만 사라지고 힙에 남는 부분 변경은 ID 조회와 우선순위 결과를 서로 다르게 만든다.\n구현은 잠금, 롤백 등 환경에 맞는 방법을 쓰되 두 구조의 변경 경계를 함께 잡아야 한다.', '맵에서 job-7을 제거한 뒤 힙 제거가 실패하면 맵 제거도 되돌려 이전 상태를 보존한다.', '두 연산이 각각 빠른지만으로는 중간 실패의 정확성을 보장하지 못한다. 질문은 자료구조 이름이 아니라 여러 변경을 하나로 취급하는 성질을 묻는다.', 16, 5, @data_structures_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @data_structures_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '원자적 갱신');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, '원자성');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'atomic update');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@data_structures_quiz_id, 1, 'atomicity');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@data_structures_quiz_id, '갱신이 성공한 뒤 위치 맵과 실제 힙 인덱스가 서로 맞아야 한다는 조건은 왜 필요한가?', 1, 1, 'HARD', '다음 ID 조회가 실제 작업 위치를 가리키게 하는 [[복합 구조 불변식]]이기 때문이다.');
SET @data_structures_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@data_structures_follow_up_id, '해설', 'TEXT', '힙 원소가 이동했는데 맵이 이전 칸을 가리키면 이후 취소가 다른 작업을 지울 수 있다. 성공 여부뿐 아니라 완료 상태의 대응 관계도 검사해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@data_structures_follow_up_id, '복합 구조 불변식', '여러 자료구조가 함께 같은 데이터를 표현할 때 연산 전후로 유지해야 하는 대응 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '실패 복구', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '다중 구조 일관성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@data_structures_quiz_id, '변경 경계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@data_structures_quiz_id, '원자적 갱신', '관련 변경을 모두 반영하거나 하나라도 실패하면 전체를 반영하지 않는 것처럼 처리하는 갱신');

DROP TEMPORARY TABLE data_structures_seed_guard;

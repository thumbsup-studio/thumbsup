-- 샘플 문제 세트 3건 (유형별 1개씩) — #40 스키마·저장 경로 검증용 임시 데이터.
-- 실제 콘텐츠는 #26(AI 생성 파이프라인)이 완성되면 대체된다. 수동 편집 금지(적용된 마이그레이션 규칙).

-- 1) OX (EASY)
INSERT INTO quiz (id, type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   created_at, updated_at)
VALUES (1, 'OX', 'EASY', 'TCP는 연결 지향 프로토콜이다.', NULL, 'O',
        'TCP는 3-way handshake로 연결을 맺는 연결 지향 프로토콜이다.', NULL,
        'UDP와 헷갈리기 쉽다 — UDP는 비연결형이라 handshake가 없다.',
        UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order)
VALUES (1, 'UDP와 TCP의 핵심 차이는 무엇인가요?', 1, 1);

INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (1, '3-way handshake', 1);

INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (1, '연결 지향', '통신 전에 연결을 먼저 수립하는 방식');

-- 2) 사지선다 (MEDIUM)
INSERT INTO quiz (id, type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   created_at, updated_at)
VALUES (2, 'MULTIPLE_CHOICE', 'MEDIUM', '다음 코드의 시간복잡도는?',
        'for (int i = 0; i < n; i++) { for (int j = 0; j < n; j++) { ... } }', NULL,
        '이중 반복문이 각각 n번 실행되므로 O(n^2)이다.',
        '정렬되지 않은 배열에서 버블 정렬이 이 패턴의 대표적인 예시다.',
        'O(n)으로 착각하기 쉽다 — 바깥 반복문만 보고 안쪽 반복문을 놓치지 않도록 주의.',
        UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (2, 'O(n)', 0, 1),
       (2, 'O(n log n)', 0, 2),
       (2, 'O(n^2)', 1, 3),
       (2, 'O(2^n)', 0, 4);

INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order)
VALUES (2, '이중 반복문을 O(n log n)으로 개선하려면?', 1, 1);

INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (2, '빅오 표기법', 1);

INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (2, '시간복잡도', '입력 크기에 따라 연산 횟수가 증가하는 정도');

-- 3) 키워드 빈칸 (HARD)
INSERT INTO quiz (id, type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   created_at, updated_at)
VALUES (3, 'KEYWORD_BLANK', 'HARD', '스택은 ___ 방식으로 데이터를 관리하는 자료구조다.',
        'push(1); push(2); pop(); // 결과: ?', NULL,
        '스택은 LIFO(Last In First Out) 방식으로 마지막에 넣은 데이터가 먼저 나온다.',
        '함수 호출 스택, 브라우저 뒤로가기 기능이 대표적인 활용 예시다.',
        '큐(FIFO)와 헷갈리기 쉽다 — 큐는 먼저 넣은 데이터가 먼저 나온다.',
        UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (3, 1, 'LIFO');

INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order)
VALUES (3, '큐(Queue)와 스택의 차이는 무엇인가요?', 1, 1);

INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (3, 'LIFO', 1);

INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (3, '스택', '한쪽 끝에서만 데이터를 넣고 뺄 수 있는 자료구조');

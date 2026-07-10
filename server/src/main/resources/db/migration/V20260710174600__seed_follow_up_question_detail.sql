-- 샘플 문제(quiz 1~3)의 꼬리질문에 상세 콘텐츠를 저작한다 — Swagger·FE 개발용 동작 경로 확보.
-- 정식 커리큘럼 60문제(꼬리질문 120건)의 백필은 생성 파이프라인(#26) 후속 이슈의 몫이다.
--
-- one_line_answer 와 block.content 의 [[키워드]] 마커 규칙은 해설 본문과 동일하다:
-- 마커 안 문자열은 그 꼬리질문의 quiz_follow_up_keyword.keyword 와 정확히 일치하고,
-- 조사는 마커 밖에 두며, 한 필드에서 같은 키워드는 첫 등장 1회만 마킹한다.

-- quiz 1 (TCP OX) — "UDP와 TCP의 핵심 차이는 무엇인가요?"
SET @fq_tcp = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = 1 AND is_primary = 1 ORDER BY id LIMIT 1);

UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = 'TCP는 [[연결 지향]]이라 먼저 연결을 맺고 순서와 도착을 보장하지만, UDP는 [[비연결형]]이라 연결 없이 곧바로 보냅니다.'
WHERE id = @fq_tcp;

INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq_tcp, '연결 지향', '데이터를 보내기 전에 양쪽이 연결을 먼저 수립하는 방식'),
       (@fq_tcp, '비연결형', '연결을 수립하지 않고 곧바로 데이터를 전송하는 방식'),
       (@fq_tcp, '3-way handshake', '세 단계로 패킷을 주고받아 연결을 맺는 절차');

INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq_tcp, '해설', 'TEXT',
        'TCP는 [[3-way handshake]]로 연결을 맺은 뒤 데이터를 보내고, 유실된 패킷을 재전송해 순서와 도착을 보장한다. UDP는 연결 수립 절차가 없어 헤더가 작고 지연이 짧은 대신, 순서가 뒤바뀌거나 유실돼도 복구해 주지 않는다.',
        1),
       (@fq_tcp, '실무 사용처', 'TEXT',
        '파일 전송이나 HTTP처럼 한 바이트도 틀리면 안 되는 통신은 TCP를 쓴다. 실시간 스트리밍·게임·DNS 조회처럼 조금 잃더라도 빨라야 하는 통신은 UDP를 쓴다.',
        2);

-- quiz 2 (시간복잡도 사지선다) — "이중 반복문을 O(n log n)으로 개선하려면?"
SET @fq_complexity = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = 2 AND is_primary = 1 ORDER BY id LIMIT 1);

UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '안쪽 반복문이 하는 일을 [[해시셋]] 조회로 바꾸거나, 먼저 [[정렬]]해 두고 훑으면 됩니다.'
WHERE id = @fq_complexity;

INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq_complexity, '해시셋', '값의 존재 여부를 평균 O(1)에 확인할 수 있는 자료구조'),
       (@fq_complexity, '정렬', '원소를 일정한 순서로 재배치하는 연산. 비교 정렬은 O(n log n)'),
       (@fq_complexity, '시간복잡도', '입력 크기에 따라 연산 횟수가 증가하는 정도');

INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq_complexity, '해설', 'TEXT',
        '이중 반복문의 [[시간복잡도]]는 O(n^2)다. 안쪽 반복문이 "이미 본 값 중에 있는가"를 확인하는 용도라면, 본 값을 [[해시셋]]에 넣어 두고 O(1)에 조회해 전체를 O(n)으로 낮출 수 있다. 두 값의 합처럼 순서가 필요한 문제라면 [[정렬]] 후 두 포인터로 한 번만 훑어 O(n log n)에 끝낼 수 있다.',
        1),
       (@fq_complexity, '실무 사용처', 'TEXT',
        '한 번만 조회하는 필터는 처음부터 훑어도 충분하다. 같은 컬렉션을 반복해서 조회한다면 [[해시셋]]으로 미리 인덱싱해 두는 편이 이득이다.',
        2);

-- quiz 3 (스택 빈칸) — "큐(Queue)와 스택의 차이는 무엇인가요?"
SET @fq_stack = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = 3 AND is_primary = 1 ORDER BY id LIMIT 1);

UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '스택은 [[LIFO]]라 마지막에 넣은 것이 먼저 나오고, 큐는 [[FIFO]]라 먼저 넣은 것이 먼저 나옵니다.'
WHERE id = @fq_stack;

INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq_stack, 'LIFO', 'Last In First Out — 마지막에 넣은 데이터가 먼저 나오는 순서'),
       (@fq_stack, 'FIFO', 'First In First Out — 먼저 넣은 데이터가 먼저 나오는 순서');

INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq_stack, '해설', 'TEXT',
        '스택은 한쪽 끝에서만 넣고 빼기 때문에 [[LIFO]] 순서가 된다. 큐는 넣는 쪽과 빼는 쪽이 반대라 [[FIFO]] 순서가 된다.',
        1),
       (@fq_stack, '실무 사용처', 'TEXT',
        '함수 호출 스택과 브라우저 뒤로가기는 스택으로, 작업 대기열과 너비 우선 탐색(BFS)은 큐로 구현한다.',
        2);

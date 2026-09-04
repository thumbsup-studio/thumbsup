-- #315: 승인된 컴퓨터 네트워크 저작 콘텐츠를 라이브 코스로 발행한다.
-- 로컬 auto-increment ID를 복사하지 않고 LAST_INSERT_ID()로 부모·자식 관계를 연결한다.
-- 저작용 outline/draft/revision/job 및 사용자 데이터는 포함하지 않는다.

START TRANSACTION;

INSERT INTO course (title, category, created_at, updated_at)
VALUES ('컴퓨터 네트워크', 'CS', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_course_id = LAST_INSERT_ID();

-- STEP 1. 계층 모델과 캡슐화
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (1, '계층 모델과 캡슐화', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, '계층 모델은 네트워크 통신을 역할별로 나누고, 데이터가 계층을 내려가며 감싸졌다가 수신 측에서 풀리는 과정을 설명한다. 모델마다 계층 경계가 다르며, TCP의 바이트 전달 방식은 애플리케이션의 쓰기 단위와 구별해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '계층별 전달 범위', '애플리케이션 계층은 웹 요청과 응답의 의미를 다루고, 전송 계층은 실행 중인 프로그램 사이의 전달을 맡는다. 인터넷 계층은 여러 네트워크를 지나는 호스트 간 전달을, TCP/IP 링크 계층은 한 링크에서의 전달을 담당한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '모델마다 다른 경계', '교육용 5계층 모델은 TCP/IP 링크 계층의 기능을 데이터링크 계층과 물리 계층으로 나누어 설명한다. OSI 7계층, TCP/IP 모델, 교육용 5계층 모델은 계층 수와 경계가 정확히 1:1로 대응하지 않는다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '웹 요청을 감싸는 흐름', 'TCP와 이더넷을 사용하는 경우 웹 요청 데이터는 TCP 세그먼트, IP 패킷, 이더넷 프레임 순으로 감싸진다. 라우터는 수신 프레임을 처리하고 IP 목적지를 확인한 뒤 다음 링크에 맞는 새 프레임을 만든다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '쓰기 횟수와 세그먼트 수', 'TCP는 메시지 목록이 아니라 순서 있는 연속된 바이트를 전달한다. 따라서 애플리케이션의 write 호출이나 메시지 수와 실제 TCP 세그먼트 수가 같다고 가정하면 안 된다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 1 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'OSI 7계층의 각 계층은 TCP/IP 모델의 한 계층과 정확히 1:1로 대응한다.', NULL, '두 모델이 통신 기능을 묶는 범위와 계층 수가 같은지 비교해 보라.', 'X', '이 주장은 틀리다. [[OSI 7계층 모델]]과 [[TCP/IP 모델]]은 계층 수와 기능 경계가 정확히 일치하지 않는다.\n두 모델은 통신 기능을 서로 다른 범위로 묶어 설명한다.\n장애를 분석할 때는 계층 번호보다 문제가 발생한 기능과 처리 위치를 확인해야 한다.', 'TCP/IP 모델은 OSI 상위 계층의 여러 기능을 애플리케이션 계층 범위에서 함께 다룬다.', '두 모델이 비슷한 통신 기능을 설명한다는 사실을 계층 경계까지 동일하다는 뜻으로 오해한 것이다.', 1, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '교육용 5계층 모델은 TCP/IP 링크 계층의 기능을 어떻게 나누어 설명하는가?', 1, 1, 'EASY', '[[교육용 5계층]]은 [[TCP/IP 링크 계층]]의 기능을 [[데이터링크 계층]]과 [[물리 계층]]으로 나누어 설명한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '데이터링크 계층은 한 링크에서 프레임을 전달하는 기능을, 물리 계층은 비트 신호를 전송 매체로 보내는 기능을 설명한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '확인', 'TEXT', '이 구분은 교육을 위한 모델의 경계이며 TCP/IP 모델에 별도의 두 계층이 반드시 정의되어 있다는 뜻은 아니다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '교육용 5계층', '인터넷 통신 기능을 애플리케이션, 전송, 네트워크, 데이터링크, 물리의 다섯 계층으로 설명하는 교육용 모델이다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'TCP/IP 링크 계층', '한 링크에서 데이터를 전달하는 데 필요한 기능을 묶어 설명하는 계층이다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '데이터링크 계층', '같은 링크에서 프레임을 인접한 장치로 전달하는 기능을 설명한다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '물리 계층', '비트를 전기·광학·무선 신호 등으로 전송하는 기능을 설명한다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '계층 모델의 역할', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'OSI와 TCP/IP의 관계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '교육용 5계층의 경계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'OSI 7계층 모델', '통신 기능을 일곱 계층의 역할로 나누어 설명하는 참조 모델이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TCP/IP 모델', '인터넷 통신에 필요한 기능을 애플리케이션부터 링크까지 나누어 설명하는 모델이다.');

-- STEP 1 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '웹 요청과 응답의 의미는 애플리케이션 계층이 다룬다.', NULL, '요청 메서드와 응답 상태 코드가 전달 경로 정보인지, 프로그램이 해석하는 규칙인지 생각해 보라.', 'O', '웹 요청과 응답의 의미는 [[애플리케이션 계층]]에서 다루므로 옳다.\n[[전송 계층]]은 프로세스 간 전달을, [[인터넷 계층]]은 호스트 간 전달을, [[링크 계층]]은 한 링크의 전달을 맡는다.\n백엔드에서는 요청 형식이나 응답 의미의 문제를 먼저 애플리케이션 수준에서 살펴볼 수 있다.', 'HTTP 요청 메서드와 응답 상태 코드는 웹 클라이언트와 서버가 해석하는 애플리케이션 수준의 정보다.', '웹 요청의 의미를 주소나 프레임처럼 데이터를 목적지로 옮기기 위한 하위 계층 정보와 혼동한 것이다.', 1, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '웹 요청을 여러 네트워크 너머의 목적지 호스트로 보내는 책임과 현재 링크의 다음 장치로 보내는 책임은 각각 어느 계층에 있는가?', 1, 1, 'MEDIUM', '목적지 호스트까지의 전달은 [[인터넷 계층]]이, 현재 링크에서의 전달은 [[링크 계층]]이 맡는다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '인터넷 계층은 전체 경로의 목적지 주소를 사용하고, 링크 계층은 현재 구간에서 필요한 전달 정보를 사용한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '적용', 'TEXT', '라우터를 지날 때 현재 링크의 정보는 달라질 수 있지만 목적지 호스트를 향한 전달은 계속된다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '인터넷 계층', '여러 네트워크를 거쳐 목적지 호스트 방향으로 데이터를 전달하는 계층이다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '링크 계층', '현재 링크에서 데이터를 인접한 장치로 전달하는 계층이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '애플리케이션 계층의 책임', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '계층별 전달 범위', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '기능에 따른 계층 구분', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '애플리케이션 계층', '웹 요청과 응답처럼 프로그램이 해석하는 데이터의 형식과 의미를 다루는 계층이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '전송 계층', '송신 호스트와 수신 호스트에서 실행되는 프로세스 사이의 전달을 맡는 계층이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '인터넷 계층', '여러 네트워크를 거쳐 목적지 호스트 방향으로 데이터를 전달하는 계층이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '링크 계층', '현재 링크에서 데이터를 인접한 장치로 전달하는 계층이다.');

-- STEP 1 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'TCP와 이더넷을 사용하는 웹 요청이 송신 호스트에서 감싸지는 순서로 옳은 것은?', NULL, '애플리케이션 데이터에서 시작해 아래 계층이 위 계층의 결과를 자신의 데이터 부분에 넣는 순서를 생각해 보라.', NULL, '웹 요청 데이터는 [[TCP 세그먼트]], [[IP 패킷]], [[이더넷 프레임]] 순으로 감싸진다.\n[[캡슐화]]에서 각 계층이 다루는 데이터 단위를 [[PDU]]라고 한다.\n네트워크 트래픽을 캡처한 화면에서는 바깥의 이더넷 정보부터 안쪽 TCP 정보까지 차례로 확인할 수 있다.', '웹 요청 데이터에 TCP 정보가 붙고, 그 결과에 IP 정보와 이더넷 정보가 차례로 추가된다.', '전송 계층의 결과가 인터넷 계층 안에 들어가고, 다시 그 결과가 링크 계층 안에 들어가는 중첩 순서를 뒤섞은 것이다.', 1, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'TCP 세그먼트 → IP 패킷 → 이더넷 프레임', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'TCP 세그먼트 → 이더넷 프레임 → IP 패킷', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'IP 패킷 → TCP 세그먼트 → 이더넷 프레임', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '이더넷 프레임 → IP 패킷 → TCP 세그먼트', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '라우터가 수신 프레임을 처리한 뒤 다음 링크용 프레임을 새로 만드는 이유는 무엇인가?', 1, 1, 'MEDIUM', '[[프레임]]은 각 링크의 전달 정보에 맞아야 하므로, 라우터는 [[IP 패킷]]을 전달 처리한 뒤 출력 [[링크 계층]]에 맞게 다시 감싼다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '수신 링크와 출력 링크는 사용하는 주소와 프레임 형식이 다를 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '적용', 'TEXT', '라우터는 목적지 IP 주소로 다음 경로를 고르고, 그 경로의 링크에서 사용할 바깥쪽 정보를 구성한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '프레임', '특정 링크에서 데이터를 전달하기 위한 링크 계층의 데이터 단위다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'IP 패킷', '목적지 IP 주소를 포함하며 라우터가 다음 경로로 전달하는 인터넷 계층의 데이터 단위다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '링크 계층', '각 링크의 형식과 주소 정보에 맞춰 데이터를 인접한 장치로 전달하는 계층이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캡슐화 순서', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '계층별 데이터 단위', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '링크별 재캡슐화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TCP 세그먼트', 'TCP 헤더와 애플리케이션에서 받은 바이트 일부를 담는 전송 계층의 데이터 단위다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'IP 패킷', 'IP 헤더와 전송 계층 데이터를 담아 목적지 호스트 방향으로 전달되는 데이터 단위다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '이더넷 프레임', '이더넷 헤더와 트레일러로 IP 패킷 등을 감싸 한 이더넷 링크에서 전달하는 데이터 단위다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '캡슐화', '위 계층의 데이터를 아래 계층의 데이터 부분에 넣고 필요한 제어 정보를 덧붙이는 과정이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'PDU', 'Protocol Data Unit의 약자로, 특정 계층이 처리하는 데이터 단위를 뜻한다.');

-- STEP 1 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '애플리케이션이 하나의 TCP 연결에서 write를 두 번 호출했다. 전송 중 관찰되는 TCP 세그먼트 수에 대한 설명으로 옳은 것은?', NULL, '애플리케이션 함수 호출의 구분이 전송 계층에서도 그대로 유지되는지 생각해 보라.', NULL, '두 번의 [[write 호출]]과 실제 [[TCP 세그먼트]] 수는 일치한다고 보장되지 않는다.\n[[TCP 바이트 스트림]]은 바이트의 순서를 제공하지만 애플리케이션의 [[메시지 경계]]를 보존하지 않는다.\n백엔드는 길이 정보나 구분자처럼 메시지를 나누는 규칙을 두고 수신 데이터를 처리해야 한다.', '여러 번 쓴 작은 데이터가 한 세그먼트에 담길 수도 있고, 한 번 쓴 큰 데이터가 여러 세그먼트로 나뉠 수도 있다.', 'write는 애플리케이션의 함수 호출 단위일 뿐이다. TCP 스택은 버퍼 상태와 세그먼트 크기 등의 조건에 따라 바이트를 합치거나 나누어 전송할 수 있다.', 1, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'write를 두 번 호출했으므로 TCP 세그먼트는 항상 2개다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'TCP 스택이 데이터를 합치거나 나눌 수 있어 write 횟수와 세그먼트 수가 1:1이라고 보장할 수 없다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '하나의 TCP 연결을 사용했으므로 TCP 세그먼트는 항상 1개다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTP 메서드의 종류가 TCP 세그먼트 수를 직접 결정한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '수신 프로그램이 한 번의 read 결과를 항상 하나의 완전한 메시지로 처리하면 어떤 문제가 생길 수 있는가?', 1, 1, 'MEDIUM', '한 번의 [[read 호출]]이 완전한 [[메시지 경계]]와 일치하지 않을 수 있으므로 데이터가 잘리거나 여러 메시지가 붙은 상태로 해석될 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '수신 버퍼에는 메시지 일부만 준비되어 있거나 여러 메시지의 바이트가 함께 준비되어 있을 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '적용', 'TEXT', '프로그램은 길이 정보나 구분자를 확인해 완전한 메시지가 모일 때까지 데이터를 조립해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'read 호출', '운영체제의 수신 버퍼에서 현재 읽을 수 있는 바이트를 가져오는 애플리케이션 함수 호출이다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '메시지 경계', '애플리케이션 수준에서 한 메시지가 끝나고 다음 메시지가 시작되는 지점이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'TCP 바이트 스트림', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'write와 세그먼트의 관계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '애플리케이션 메시지 구분', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'write 호출', '애플리케이션이 운영체제에 바이트 전송을 요청하는 함수 호출이며 세그먼트 하나를 뜻하지는 않는다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TCP 세그먼트', 'TCP가 바이트 스트림의 일부에 헤더를 붙여 전송하는 데이터 단위다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TCP 바이트 스트림', 'TCP가 메시지 단위가 아니라 순서가 있는 연속된 바이트로 데이터를 전달하는 방식이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '메시지 경계', '애플리케이션이 정한 한 메시지의 시작과 끝이며 TCP가 자동으로 보존하지 않는다.');

-- STEP 1 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '송신 호스트가 웹 요청을 아래 계층으로 내리며 제어 정보를 덧붙이는 과정은 ___이고, 수신 호스트가 바깥쪽 제어 정보를 처리하며 데이터를 위 계층으로 올리는 과정은 ___이다.', NULL, '보내는 쪽과 받는 쪽에서 데이터가 계층 사이를 이동하는 방향과 제어 정보의 변화를 비교해 보라.', NULL, '첫 빈칸은 [[캡슐화]], 둘째 빈칸은 [[역캡슐화]]다.\n송신 측은 아래 계층으로 내려가며 정보를 더하고, 수신 측은 바깥쪽 정보부터 처리하며 위 계층으로 올린다.\n웹 서버의 송수신 흐름을 추적할 때 데이터가 어느 방향으로 처리되는지 구분하는 기준이 된다.', '송신 측은 웹 요청에 TCP, IP, 링크 계층 정보를 차례로 더하고, 수신 측은 반대 순서로 각 정보를 처리한다.', '송신과 수신의 처리 방향을 바꾸어 생각한 것이다. 정보를 더하며 내려가는 흐름과 바깥 정보를 처리하며 올라가는 흐름을 구분해야 한다.', 1, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '캡슐화');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'encapsulation');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '역캡슐화');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '디캡슐화');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'decapsulation');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '수신 호스트가 이더넷 헤더를 먼저 처리한 뒤 IP 헤더를 처리하는 이유는 무엇인가?', 1, 1, 'HARD', '[[역캡슐화]]에서는 현재 바깥쪽 계층의 정보를 먼저 처리해야 그 안의 데이터를 알맞은 위 계층으로 넘길 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '수신된 프레임의 바깥쪽에는 이더넷 정보가 있고 그 데이터 부분 안에 IP 패킷이 들어 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '비교', 'TEXT', '송신 측의 [[캡슐화]]는 이와 반대로 위 계층의 데이터를 아래 계층 정보로 차례로 감싼다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '역캡슐화', '수신 측이 바깥쪽 계층 정보부터 처리하고 안쪽 데이터를 위 계층으로 넘기는 과정이다.');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '캡슐화', '송신 측이 위 계층 데이터를 아래 계층 정보로 차례로 감싸는 과정이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '송신과 수신 방향', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캡슐화', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '역캡슐화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '캡슐화', '송신 호스트가 위 계층의 데이터에 아래 계층의 전달 정보를 차례로 덧붙이는 과정이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '역캡슐화', '수신 호스트가 바깥쪽 계층 정보를 차례로 처리해 데이터를 위 계층으로 올리는 과정이다.');

-- STEP 2. 이더넷과 스위칭
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (2, '이더넷과 스위칭', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'Ethernet 스위치는 프레임을 보낸 장치의 위치를 학습하고, 받을 장치의 위치 정보에 따라 전달할 포트를 정한다. 충돌과 브로드캐스트가 영향을 미치는 범위는 서로 다른 기준으로 구분한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '송신 주소로 위치 학습하기', 'source MAC은 프레임을 보낸 장치를, destination MAC은 프레임을 받을 장치를 나타낸다. 스위치는 수신 프레임의 source MAC을 보고 그 주소가 들어온 포트 방향에 있다고 학습하며, 이 대응을 MAC 주소 테이블에 저장한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '목적지 위치로 전달 범위 정하기', 'destination MAC이 테이블에 있으면 해당 포트로만 전달하고, 없으면 수신 포트를 제외한 같은 VLAN의 전달 가능한 포트들로 복제한다. 복제할 때 destination MAC을 브로드캐스트 주소로 바꾸지는 않는다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', 'API 서버가 연결된 포트 찾기', 'API 서버의 프레임이 포트 1로 들어오면 스위치는 서버의 MAC 주소를 포트 1에 학습할 수 있다. 이후 그 서버를 목적지로 하는 프레임은 테이블 항목을 이용해 포트 1로 전달된다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '충돌과 브로드캐스트의 범위', '충돌 도메인은 공유 매체나 반이중 Ethernet에서 충돌이 영향을 미칠 수 있는 범위이고, 브로드캐스트 도메인은 브로드캐스트 프레임이 전달되는 LAN 또는 VLAN 범위다. 현대의 스위치 기반 전이중 Ethernet에서는 충돌이 발생하지 않으며, 라우터나 VLAN 경계는 브로드캐스트의 전달 범위를 나눈다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 2 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '서버가 같은 VLAN에 보낸 Ethernet 브로드캐스트 프레임은 라우터를 거쳐 다른 LAN까지 그대로 퍼진다.', NULL, '링크 계층에서 모든 장치를 대상으로 하는 프레임이 어느 네트워크 경계까지 유효한지 생각해 보라.', 'X', '정답은 X이며, [[브로드캐스트 도메인]]은 일반적으로 하나의 LAN 또는 VLAN 경계 안에 있다.\n스위치는 브로드캐스트 프레임을 같은 VLAN의 다른 포트로 전달하지만 라우터는 그 Ethernet 프레임을 다른 LAN으로 그대로 중계하지 않는다.\n백엔드 장애 진단에서 브로드캐스트가 다른 VLAN의 서버까지 도달한다고 가정하면 통신 범위를 잘못 판단할 수 있다.', 'VLAN 10의 서버가 보낸 브로드캐스트 프레임은 VLAN 10의 다른 포트로 전달될 수 있지만, 라우터 반대편의 VLAN 20에는 그대로 전달되지 않는다.', '스위치가 연결한 같은 VLAN의 범위와 라우터가 구분하는 서로 다른 LAN의 범위를 하나로 보면 브로드캐스트의 도달 범위를 지나치게 넓게 판단하게 된다.', 2, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '두 서버가 같은 물리적 스위치에 연결되어 있지만 서로 다른 VLAN에 속하면 한 서버의 Ethernet 브로드캐스트가 다른 서버에 그대로 도달하는가?', 1, 1, 'MEDIUM', '같은 스위치에 연결되어 있어도 서로 다른 [[VLAN]]이면 Ethernet 브로드캐스트 프레임은 한쪽에서 다른 쪽으로 그대로 넘어가지 않는다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '스위치는 논리적으로 구분된 각 네트워크 안에서만 브로드캐스트를 전달하며, 서로 다른 네트워크 사이의 통신에는 계층 3 처리가 필요하다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'VLAN', '하나의 물리적 스위치 환경을 서로 다른 논리적 LAN으로 나누는 기술');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '브로드캐스트 전달 범위', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'VLAN 경계', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '브로드캐스트 도메인', 'Ethernet 브로드캐스트 프레임이 전달될 수 있는 하나의 LAN 또는 VLAN 범위');

-- STEP 2 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '스위치는 프레임이 들어오면 destination MAC을 그 수신 포트에 학습한다.', NULL, '스위치가 프레임이 들어온 방향에서 실제 위치를 확인할 수 있는 주소가 송신 측과 수신 측 중 어느 쪽인지 생각해 보라.', 'X', '정답은 X이며, 스위치는 [[MAC 학습]]을 할 때 destination MAC이 아니라 source MAC과 수신 포트의 관계를 기록한다.\n프레임이 들어온 방향은 송신 장치가 있는 방향을 보여 주지만 목적지 장치가 있는 방향을 증명하지 않는다.\n서버를 다른 포트로 옮긴 뒤 통신이 꼬이면 서버의 MAC 주소가 새 포트로 갱신되었는지 확인할 수 있다.', 'source MAC이 A인 프레임이 포트 3으로 들어오면 스위치는 일반적으로 A가 포트 3 방향에 있다고 기록하거나 기존 항목을 갱신한다.', 'destination MAC은 프레임이 향하는 주소일 뿐이므로, 그 주소를 수신 포트에 기록하면 목적지 장치의 위치를 잘못 학습하게 된다.', 2, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '스위치가 동적으로 학습한 주소 항목을 일정 시간이 지나면 제거하는 이유는 무엇인가?', 1, 1, 'MEDIUM', '서버 이동이나 연결 변경으로 오래된 포트 정보가 남지 않도록 동적 항목에 [[에이징]]을 적용한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '오랫동안 갱신되지 않은 항목을 제거하면 스위치는 이후 프레임을 통해 장치의 현재 위치를 다시 배울 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '에이징', '일정 시간 갱신되지 않은 동적 MAC 주소 항목을 만료시키는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '송신 주소 학습', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'MAC 주소와 포트의 대응', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'MAC 학습', '스위치가 수신 프레임의 source MAC과 수신 포트의 관계를 기록하거나 갱신하는 과정');

-- STEP 2 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '스위치의 MAC 주소 테이블에서 B는 정상 상태인 포트 2에 연결되어 있다. 별도 차단 설정이 없을 때 포트 1로 들어온 destination MAC B의 프레임은 어떻게 처리되는가?', NULL, '목적지 주소 조회 결과가 하나의 사용 가능한 포트를 가리킬 때 필요한 출력 범위를 판단해 보라.', NULL, '정답은 포트 2로만 전달하는 것이며, 이는 목적지 위치가 알려진 [[known unicast]] 처리다.\n스위치는 MAC 주소 테이블에서 destination MAC과 연결된 포트를 찾아 필요한 한 포트로 프레임을 보낸다.\n서버 트래픽이 예상과 다른 포트로 향하면 해당 포트의 연결 상태와 설정, MAC 주소 테이블을 확인할 수 있다.', '포트가 네 개여도 B의 유효한 항목이 포트 2를 가리키면 스위치는 해당 프레임을 포트 2로 전달한다.', '목적지의 출력 포트를 이미 알고 있으므로 여러 포트로 복제하거나 수신 포트로 되돌려 보낼 이유가 없으며, 유니캐스트라는 이유로 폐기하지도 않는다.', 2, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '프레임을 포트 2로만 전달한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '프레임을 포트 1을 제외한 모든 포트로 전달한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '프레임을 포트 1로만 되돌려 보낸다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '프레임을 목적지 불명으로 판단해 폐기한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '장치 B를 포트 2에서 포트 4로 옮긴 뒤 B가 프레임을 보내면 스위치의 B 항목은 어떻게 되는가?', 1, 1, 'MEDIUM', 'B의 프레임이 포트 4로 들어오면 스위치는 [[MAC 주소 테이블]]의 B 항목을 포트 4 방향으로 갱신할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '스위치는 장치가 보낸 프레임을 통해 새 포트를 다시 학습한다. 항목이 예상과 다르면 해당 포트의 연결 상태와 설정, 테이블을 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'MAC 주소 테이블', '스위치가 MAC 주소와 그 주소에 도달하는 포트의 대응을 저장하는 테이블');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '선택적 전달', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '목적지 기반 포트 선택', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'known unicast', '스위치가 목적지 MAC에 해당하는 출력 포트를 알고 있는 유니캐스트 프레임');

-- STEP 2 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'MAC 주소 테이블에 D가 없는 스위치로 source MAC A, destination MAC D인 프레임이 포트 1을 통해 들어왔다. 일반적인 처리 결과는 무엇인가?', NULL, '목적지 위치를 모르는 경우에도 확인할 수 있는 송신 방향과 시도할 수 있는 출력 범위를 나누어 보라.', NULL, '정답은 A를 포트 1에 학습하고 D를 유지한 채 다른 포트로 보내는 [[unknown unicast flooding]]이다.\n스위치는 source MAC으로 들어온 방향을 배우고, 목적지 위치를 모르면 수신 포트를 제외한 같은 VLAN의 전달 가능한 포트들에 복사본을 보낸다.\n여러 포트에서 같은 유니캐스트 프레임이 관찰되면 목적지 MAC이 아직 학습되지 않았는지 확인할 수 있다.', '같은 VLAN에서 포트 2와 포트 3이 전달 가능한 상태라면 스위치는 D를 그대로 둔 프레임 복사본을 두 포트로 보낸다.', '목적지 D를 수신 포트에 학습하거나 브로드캐스트 주소로 바꾸는 것은 관찰한 정보와 맞지 않으며, 기본 동작에서는 D가 미학습 상태라는 이유만으로 프레임을 보류하지 않는다.', 2, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A를 포트 1에 학습하고, D를 유지한 채 같은 VLAN의 다른 포트들로 전달한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'D를 포트 1에 학습하고, 프레임을 포트 1로만 되돌려 보낸다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A를 포트 1에 학습하고, D가 학습될 때까지 프레임을 보류한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A를 포트 1에 학습하고, D를 브로드캐스트 주소로 바꾸어 모든 포트로 전달한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '목적지 위치를 모르는 유니캐스트와 브로드캐스트가 여러 포트로 전달되는 이유는 어떻게 다른가?', 1, 1, 'MEDIUM', '미학습 유니캐스트는 한 목적지의 위치를 몰라 복제되지만, [[브로드캐스트 MAC 주소]]는 같은 VLAN의 모든 장치를 대상으로 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '두 프레임 모두 여러 포트로 전달될 수 있지만, 하나는 위치 정보가 없기 때문이고 다른 하나는 주소 자체가 전체 대상을 지정하기 때문이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '브로드캐스트 MAC 주소', '같은 LAN 또는 VLAN의 모든 장치를 대상으로 하는 FF:FF:FF:FF:FF:FF 주소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '미학습 유니캐스트', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '수신 포트 제외', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '유니캐스트 주소 유지', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'unknown unicast flooding', '목적지 MAC의 위치를 모를 때 수신 포트를 제외한 같은 VLAN의 다른 포트들로 유니캐스트 프레임을 복제하는 동작');

-- STEP 2 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '공유 매체나 반이중 Ethernet에서 충돌 가능성을 함께 공유하는 범위를 ___이라 하고, 한 LAN 또는 VLAN 안에서 브로드캐스트가 전달되는 범위를 ___이라 한다.', NULL, '앞칸은 같은 매체에서 동시 송신의 영향을 함께 받는 범위이고, 뒤칸은 전체 수신자를 향한 프레임이 퍼지는 논리적 경계라는 점을 구분해 보라.', NULL, '첫째 빈칸은 [[충돌 도메인]], 둘째 빈칸은 [[브로드캐스트 도메인]]이다.\n공유 매체나 반이중 Ethernet에서는 같은 충돌 범위의 장치가 동시에 송신할 때 프레임 충돌이 발생할 수 있고, 브로드캐스트 프레임은 같은 브로드캐스트 범위 안으로 전달된다.\n현대의 스위치 기반 전이중 Ethernet에서는 충돌이 발생하지 않지만, VLAN 경계로 브로드캐스트 범위를 나누는 개념은 여전히 장애 범위 판단에 중요하다.', '하나의 허브에 반이중으로 연결된 장치들은 충돌 영향을 공유할 수 있고, VLAN 10의 브로드캐스트 프레임은 VLAN 10 경계 안에서 전달된다.', '두 범위는 모두 Ethernet의 전달 환경을 설명하지만, 하나는 공유 매체에서의 동시 송신 문제를 다루고 다른 하나는 전체 대상 프레임의 논리적 전달 경계를 다룬다.', 2, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '충돌 도메인');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'collision domain');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '브로드캐스트 도메인');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'broadcast domain');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '서버와 스위치가 전이중으로 정상 연결된 현대 Ethernet에서 프레임 손실을 충돌 탓으로 보기 어려운 이유는 무엇인가?', 1, 1, 'HARD', '[[전이중 Ethernet]]은 송신과 수신에 분리된 경로를 사용하므로 정상적인 링크에서는 프레임 충돌이 발생하지 않는다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '전이중 스위치 링크에서는 양쪽이 동시에 데이터를 보내고 받을 수 있으며, 공유 매체용 충돌 감지 방식도 사용하지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '전이중 Ethernet', '송신과 수신을 동시에 수행할 수 있고 정상 동작에서 프레임 충돌이 발생하지 않는 Ethernet 통신 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '충돌 영향 범위', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '브로드캐스트 전달 범위', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '충돌 도메인', '공유 매체나 반이중 Ethernet에서 여러 장치의 동시 송신으로 생기는 충돌이 영향을 미칠 수 있는 범위');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '브로드캐스트 도메인', 'Ethernet 브로드캐스트 프레임이 전달되는 하나의 LAN 또는 VLAN 범위');

-- STEP 3. IPv4 주소와 CIDR
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (3, 'IPv4 주소와 CIDR', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'IPv4 주소는 32비트이며, CIDR의 /n은 주소 왼쪽에서 공통으로 고정되는 비트 수를 나타낸다. 프리픽스가 짧을수록 하나의 주소 블록에 더 많은 주소가 포함된다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', 'CIDR로 범위 읽기', 'CIDR 프리픽스는 주소 블록의 공통 부분을 왼쪽부터 지정한다. 프리픽스 뒤에 남은 비트 수가 h라면 해당 블록에는 2의 h제곱 개 주소가 포함된다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '접근 허용 범위', '방화벽이나 보안 그룹에 172.16.8.0/28을 지정하면 프리픽스 뒤의 4비트가 달라질 수 있으므로 172.16.8.0부터 172.16.8.15까지 16개 주소가 범위에 포함된다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '주소 분류와 표기 방식', '공인 주소와 사설 주소는 주소의 용도를 구분하는 것이며, 실제 연결성은 네트워크 경로·방화벽 규칙·서비스 상태에 달려 있다. A·B·C 클래스는 역사적인 주소 분류이고, 현재 주소 범위는 /n 형태의 CIDR로 표기한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 3 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'IPv4 주소 192.168.10.34/24에서 /24는 왼쪽 24비트가 주소 블록의 공통 부분이고, 나머지 8비트가 블록 안에서 달라질 수 있다는 뜻이다.', NULL, 'IPv4 전체 비트 수에서 슬래시 뒤 숫자를 빼면 주소마다 달라질 수 있는 비트 수를 알 수 있다.', 'O', '옳으며, [[CIDR 프리픽스]] /24는 왼쪽 24비트를 주소 블록의 공통 부분으로 정한다.\nIPv4는 32비트이므로 남은 8비트의 조합으로 블록에 포함되는 주소가 구분된다.\n서버 주소와 허용 대역을 확인할 때는 점으로 구분된 숫자뿐 아니라 슬래시 길이도 함께 봐야 한다.', '192.168.10.34/24는 192.168.10.0부터 192.168.10.255까지의 주소 블록에 포함된다.', '슬래시 뒤 숫자는 호스트 비트 수나 포함되는 주소 수가 아니라 왼쪽부터 고정되는 비트 수를 나타낸다.', 3, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '192.168.10.34/24와 192.168.10.200/24는 같은 CIDR 네트워크에 속하는가?', 1, 1, 'EASY', '두 주소는 [[네트워크 부분]]인 앞 24비트가 같으므로 같은 192.168.10.0/24에 속한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '두 주소에서 앞의 세 숫자 묶음인 192.168.10이 같고, /24는 이 24비트를 공통 부분으로 사용한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '네트워크 부분', '같은 주소 블록에 속한 IPv4 주소들이 공통으로 가지는 왼쪽 비트 부분이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서브넷 마스크', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '네트워크 범위', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'CIDR 프리픽스', 'IPv4 주소의 왼쪽에서 주소 블록의 공통 부분으로 고정한 연속된 비트와 그 길이다.');

-- STEP 3 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '서로 연결되지 않은 회사 A와 회사 B가 각각 내부 서버에 10.0.0.5를 사용해도 된다.', NULL, '주소의 고유성이 공용 인터넷 전체에서 필요한지, 서로 분리된 내부 환경마다 필요한지 구분해 보라.', 'O', '옳으며, [[사설 IPv4 주소]]는 서로 분리된 조직 내부망에서 같은 값을 재사용할 수 있다.\n사설 범위는 공용 인터넷 전체에서 하나의 조직에만 배정되는 주소 공간이 아니다.\n백엔드 접속 로그에서는 같은 사설 주소가 서로 다른 환경의 호스트를 가리킬 수 있어 환경 정보도 함께 확인해야 한다.', '서로 분리된 개발 환경과 운영 환경이 각각 내부 서버 주소로 10.0.0.5를 사용할 수 있다.', '사설 주소를 전 세계에서 한 번만 사용할 수 있는 공인 주소처럼 해석하면 안 된다.', 3, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '개발 환경과 운영 환경의 접속 로그에 모두 10.0.0.5가 기록됐다면, 이 주소만으로 같은 서버라고 판단할 수 있는가?', 1, 1, 'MEDIUM', '아니며, 동일한 주소는 서로 다른 [[사설망]]에서 재사용될 수 있으므로 환경 식별 정보가 더 필요하다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '로그에 기록된 사설 주소는 그 주소를 사용한 네트워크 환경을 함께 알아야 정확히 해석할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '확인 방법', 'TEXT', '환경 이름, 서버 식별자, 요청 추적 번호와 같은 정보를 함께 확인하면 서버를 구분하는 데 도움이 된다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '사설망', '사설 IPv4 주소를 내부 통신에 사용하는 조직이나 서비스의 네트워크다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '사설 주소 예약 범위', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '로그 추적', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '사설 IPv4 주소', '조직 내부에서 재사용할 수 있도록 예약되어 공용 인터넷 전체에서 고유하지 않은 IPv4 주소다.');

-- STEP 3 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '보안 그룹에서 출발지 허용 범위를 정할 때, /24와 /26 주소 블록을 비교한 설명으로 가장 정확한 것은 무엇인가?', NULL, '슬래시 뒤 숫자가 커질 때 주소마다 달라질 수 있는 비트 수가 어떻게 변하는지 비교해 보라.', NULL, '정답은 /24가 256개 주소를 포함하고 /26이 64개 주소를 포함하므로 /24가 더 크다는 설명이다.\n[[주소 블록 크기]]는 고정되지 않은 비트의 조합 수로 정해져 프리픽스가 짧을수록 커진다.\n보안 그룹에서 범위를 크게 지정하면 의도한 서버보다 많은 출발지가 허용될 수 있다.', '192.168.10.0/24는 마지막 숫자 묶음의 0부터 255까지를 포함하지만, 192.168.10.0/26은 0부터 63까지를 포함한다.', '슬래시 뒤 숫자는 주소 개수가 아니며, 프리픽스가 길어지면 고정되는 비트가 늘어 주소 범위가 좁아진다.', 3, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/24는 24개 주소, /26은 26개 주소를 포함하므로 /26이 더 큰 범위다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/24는 256개 주소, /26은 64개 주소를 포함하므로 /24가 더 큰 범위다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/24는 64개 주소, /26은 256개 주소를 포함하므로 /26이 더 큰 범위다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/24와 /26은 모두 IPv4 주소이므로 각각 256개 주소를 포함해 범위가 같다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '192.168.10.64/26 주소 블록에 포함되는 마지막 주소는 무엇인가?', 1, 1, 'MEDIUM', '마지막 숫자 묶음의 64가 [[블록 경계]]이고 64개 주소가 포함되므로 마지막 주소는 192.168.10.127이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '/26 블록은 마지막 숫자 묶음을 0, 64, 128, 192에서 시작하는 64개 단위로 나눈다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '블록 경계', 'CIDR 주소 블록이 시작하거나 끝나는 정렬된 주소 지점이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '호스트 비트', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '접근 허용 범위', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '주소 블록 크기', '하나의 CIDR 프리픽스가 포함하는 전체 IPv4 주소의 개수다.');

-- STEP 3 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '웹 서버에 공인 IPv4 주소를 배정했다. 외부 사용자의 접속 가능 여부에 대한 판단으로 가장 정확한 것은 무엇인가?', NULL, '주소를 배정하는 일과 외부 요청이 실행 중인 서버 프로그램까지 도달하는 데 필요한 조건을 나누어 생각해 보라.', NULL, '정답은 공인 IPv4 주소만 배정했다고 외부 접속이 자동으로 보장되지는 않는다는 설명이다.\n외부 요청이 서버까지 도달할 경로와 방화벽 허용 규칙이 필요하고, 서버의 서비스도 요청을 받을 수 있어야 한다.\n장애를 확인할 때는 [[외부 접속 조건]]을 주소 배정, 네트워크 접근, 서비스 상태로 나누어 점검한다.', '공인 IP가 있어도 443번 포트가 차단됐거나 웹 서버 프로그램이 실행 중이지 않으면 HTTPS 요청은 성공하지 않는다.', '공인 주소는 외부에서 사용할 수 있는 주소이지만, 주소 배정만으로 네트워크 접근과 서버 프로그램의 동작까지 보장하지는 않는다.', 3, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '공인 주소를 배정하면 별도 설정 없이 모든 외부 요청이 서버 프로그램에 도달한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '공인 주소만 있으면 방화벽에서 허용하지 않은 포트에도 외부에서 접속할 수 있다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '공인 주소가 있어도 네트워크 경로, 방화벽 규칙, 서비스 상태가 올바르게 갖춰져야 접속할 수 있다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '공인 주소는 서버를 식별할 뿐이므로 외부 접속에는 사용할 수 없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '공인 주소와 네트워크 경로가 정상인데 웹 요청이 실패한다면, 방화벽과 서버 프로그램에서 공통으로 확인할 항목은 무엇인가?', 1, 1, 'MEDIUM', '방화벽이 서비스의 [[수신 포트]]를 허용하고 서버 프로그램이 같은 포트에서 실행 중인지 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '네트워크 경로가 있어도 방화벽이 해당 포트를 막거나 서버 프로그램이 그 포트에서 요청을 기다리지 않으면 접속할 수 없다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '점검 예', 'TEXT', 'HTTPS 서비스라면 방화벽의 443번 포트 허용 여부와 웹 서버 프로그램의 443번 포트 사용 여부를 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '수신 포트', '서버 프로그램이 클라이언트의 연결 요청을 받기 위해 사용하는 번호다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '공인 IPv4 주소', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서비스 상태', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '외부 접속 조건', '외부 요청이 서버 프로그램에 도달하려면 충족되어야 하는 주소 배정, 네트워크 경로, 접근 허용 규칙, 서비스 실행 상태다.');

-- STEP 3 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '보안 그룹의 IPv4 허용 목록에서 10.20.30.40/32는 ___을 뜻하고, 10.20.30.0/24는 ___을 뜻한다.', NULL, '각 프리픽스를 적용했을 때 고정되지 않고 달라질 수 있는 비트가 몇 개인지 계산해 포함 범위를 비교해 보라.', NULL, '첫 빈칸은 특정 IP 주소 하나이고, 둘째 빈칸은 10.20.30.0부터 10.20.30.255까지의 주소 범위다.\n[[CIDR 허용 범위]]는 프리픽스로 고정한 비트가 많을수록 좁아지고 적을수록 넓어진다.\n관리 API 허용 목록에서는 필요한 대상보다 넓은 대역을 넣지 않았는지 확인해야 한다.', '10.20.30.40/32를 등록하면 해당 주소만 범위에 포함되지만, 10.20.30.0/24를 등록하면 총 256개 주소가 범위에 포함된다.', '/32를 32개 주소로 해석하거나 /24를 특정 주소 하나로 해석하면 프리픽스 길이와 주소 개수를 혼동한 것이다.', 3, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'IP 주소 하나');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '특정 IP 주소 하나');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '단일 IP 주소');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '하나의 IP 주소');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '10.20.30.0부터 10.20.30.255까지의 주소 범위');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '10.20.30.0~10.20.30.255');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '256개 주소 범위');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '하나의 /24 네트워크 범위');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '/24 네트워크 범위');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '10.20.30.0/24 대역');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '10.20.30.0/24 범위');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '내부 관리 API를 10.20.30.64부터 10.20.30.127까지만 허용하려면 어떤 CIDR로 적어야 하는가?', 1, 1, 'HARD', '이 범위를 나타내는 [[CIDR 표기]]는 10.20.30.64/26이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '/26은 주소마다 달라질 수 있는 비트가 6개이므로 64개 주소를 포함하고, 이 블록은 마지막 숫자 묶음의 64에서 시작해 127에서 끝난다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '실무 적용', 'TEXT', '허용할 주소가 연속된 CIDR 경계에 맞는다면 하나의 프리픽스로 필요한 범위만 간결하게 지정할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'CIDR 표기', '기준 IPv4 주소와 슬래시 뒤의 프리픽스 길이를 함께 적어 주소 범위를 나타내는 방식이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '최소 권한', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '허용 목록', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'CIDR 허용 범위', '방화벽이나 보안 그룹에서 하나의 CIDR 프리픽스로 접근을 허용하는 IPv4 주소 범위다.');

-- STEP 4. 호스트 구성과 DHCP
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (4, '호스트 구성과 DHCP', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'DHCP는 호스트가 IPv4 주소와 통신에 필요한 여러 설정을 자동으로 받고, 주소를 정해진 기간 동안 사용하게 한다. 초기 할당, 임대 확인과 갱신, 원격 서버 중계 원리를 알면 호스트의 접속 장애를 구분하기 쉽다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '호스트가 받는 네트워크 설정', 'DHCP 서버는 IPv4 주소와 서브넷 마스크뿐 아니라 기본 게이트웨이와 DNS 서버 정보를 옵션으로 제공할 수 있다. 기본 게이트웨이는 다른 네트워크로 패킷을 보낼 때 사용하고, DNS 서버는 도메인 이름에 대응하는 IP 주소를 찾을 때 사용한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '주소 할당과 사용 기간', '처음 주소를 받을 때는 클라이언트의 서버 탐색, 서버의 주소 제안, 클라이언트의 요청, 서버의 승인 과정이 이어진다. 할당된 주소에는 사용 기간이 있으므로 만료 전에 갱신해야 한다. 재부팅한 클라이언트가 이전 임대 주소를 기억하더라도 현재 네트워크에서 다시 사용할 수 있는지 DHCP 서버에 요청하여 확인한 뒤 적용해야 한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '접속 증상으로 설정 구분하기', 'IP 주소로는 서비스에 접속되지만 도메인 이름으로는 접속되지 않는다면 이름 사용에 필요한 설정을 먼저 살펴볼 수 있다. 같은 네트워크의 호스트에는 접속되지만 외부 IP 주소에는 접속되지 않는다면 다른 네트워크로 보내는 데 필요한 호스트 설정을 우선 확인할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '원격 서버와 임대 주소', '초기 DHCP 요청은 일반 라우터를 거쳐 다른 네트워크로 자동 전달되지 않으므로 원격 DHCP 서버를 사용하려면 중계 기능이 필요하다. 또한 임대가 만료된 주소는 이전에 사용했다는 이유만으로 계속 사용해서는 안 된다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 4 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'DHCP로 자동 구성한 호스트는 IPv4 주소와 서브넷 마스크뿐 아니라 기본 게이트웨이와 DNS 서버도 DHCP 옵션으로 받을 수 있다.', NULL, '자동 구성 과정에서 주소 외에도 서로 다른 통신 목적에 필요한 값들을 함께 전달할 수 있는지 생각해 보라.', 'O', '[[DHCP]]는 IPv4 주소뿐 아니라 여러 호스트 구성 값을 옵션으로 제공할 수 있다.\n서브넷 마스크는 로컬 네트워크의 범위를 판단하게 하고, [[기본 게이트웨이]]와 [[DNS 서버]]는 각각 외부 통신과 이름을 이용한 접속을 지원한다.\n일부 접속만 실패한다면 주소 할당 여부뿐 아니라 호스트에 실제로 적용된 각 옵션도 확인해야 한다.', NULL, 'DHCP를 IPv4 주소 하나만 할당하는 기능으로 보면 안 된다. 서버 정책과 응답 옵션에 따라 서브넷 마스크, 기본 게이트웨이, DNS 서버 같은 설정도 함께 제공할 수 있다.', 4, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'DHCP로 설정한 서버가 같은 네트워크의 데이터베이스에는 접속하지만 외부 IP 주소에는 접속하지 못한다면 어떤 설정을 먼저 확인해야 하는가?', 1, 1, 'MEDIUM', '로컬 네트워크 밖으로 패킷을 보낼 때 사용하는 [[기본 게이트웨이]] 설정을 먼저 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '같은 네트워크의 대상에는 직접 패킷을 보낼 수 있지만, 외부 네트워크의 대상에는 다음 전달 지점이 필요하다. 따라서 호스트에 적용된 게이트웨이 주소가 누락되거나 잘못되었는지 먼저 살펴본다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '기본 게이트웨이', '호스트가 자신과 다른 네트워크의 목적지로 패킷을 보낼 때 우선 전달하는 라우터 주소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DHCP 옵션', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '호스트 네트워크 구성', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DHCP', '호스트에 IP 주소와 기타 네트워크 설정을 동적으로 제공하는 프로토콜');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '기본 게이트웨이', '호스트가 로컬 네트워크 밖의 목적지로 패킷을 보낼 때 사용하는 라우터 주소');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DNS 서버', '호스트가 도메인 이름에 대응하는 IP 주소를 질의하는 서버');

-- STEP 4 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'DHCP 주소의 임대 시간이 끝났더라도 서버가 응답하지 않으면 호스트는 그 주소를 계속 사용해도 된다.', NULL, '주소를 저장해 두었다는 사실과 서버가 허용한 사용 기간이 남아 있다는 사실을 구분하라.', 'X', '[[임대 만료]] 후에는 이전에 할당받은 주소를 그대로 계속 사용해서는 안 된다.\nDHCP 주소는 정해진 기간 동안만 사용 권한이 주어지므로 클라이언트는 만료 전에 갱신을 시도해야 한다.\n만료된 주소를 계속 쓰면 서버가 같은 주소를 다른 호스트에 할당하여 주소 충돌과 통신 장애가 발생할 수 있다.', NULL, '서버의 일시적인 무응답이 주소 사용 권한을 연장하지는 않는다. 임대가 갱신되지 않은 채 끝나면 클라이언트는 해당 주소의 사용을 중단하고 새 주소 획득을 시도해야 한다.', 4, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '클라이언트가 재부팅 뒤 이전에 임대받은 주소를 기억하고 있다면, 그 주소를 사용하기 전에 무엇을 해야 하는가?', 1, 1, 'EASY', '현재 연결된 네트워크에서 그 주소를 다시 쓸 수 있는지 [[DHCPREQUEST]] 메시지를 보내 서버에 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '기억한 주소가 있더라도 재부팅 사이에 다른 네트워크로 이동했거나 서버의 할당 정보가 달라졌을 수 있다. 클라이언트는 이전 주소를 바로 적용하지 않고 서버가 다시 사용해도 된다고 승인하는지 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'DHCPREQUEST', '클라이언트가 주소 할당, 이전 주소의 재사용 확인 또는 임대 갱신을 요청할 때 보내는 DHCP 메시지');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DHCP 임대', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '주소 사용 기간', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '임대 만료', 'DHCP 서버가 허용한 IP 주소 사용 기간이 끝난 상태');

-- STEP 4 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '새 호스트가 DHCP로 처음 주소를 할당받는 과정의 순서로 가장 정확한 것은?', NULL, '처음에는 사용할 서버와 주소가 정해지지 않았다는 점을 바탕으로, 클라이언트와 서버가 각각 언제 알림·제안·요청·승인을 하는지 생각해 보라.', NULL, '이 초기 할당 흐름은 [[DORA]]라고 하며, 클라이언트의 서버 탐색, 서버의 주소 제안, 클라이언트의 요청, 서버의 승인 순서로 진행된다.\n서버의 주소 제안만으로는 사용 권한이 확정되지 않으며 클라이언트의 요청과 서버의 승인이 이어져야 한다.\n패킷 기록에서 흐름이 멈춘 지점을 찾으면 서버, 중간 네트워크, 클라이언트 중 점검할 범위를 좁힐 수 있다.', NULL, '클라이언트가 주소를 먼저 사용하거나 서버와 클라이언트의 역할을 바꾸면 정상적인 초기 할당 절차가 되지 않는다. 서버의 제안만으로 주소 사용이 확정되지 않는다는 점도 구분해야 한다.', 4, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트가 서버를 찾고, 서버가 주소를 제안하며, 클라이언트가 그 주소를 요청한 뒤 서버가 승인한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트가 주소를 먼저 사용하고, 서버가 중복을 검사하며, 클라이언트가 주소를 제안한 뒤 서버가 승인한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버가 클라이언트를 찾고, 클라이언트가 주소를 제안하며, 서버가 그 주소를 요청한 뒤 클라이언트가 승인한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트가 서버를 찾고, 서버가 주소를 승인하며, 클라이언트가 그 주소를 요청한 뒤 서버가 제안한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'DHCP 주소 할당이 끝난 뒤 서버가 승인한 값이 클라이언트에 제대로 반영되었는지 검증하려면 무엇을 확인해야 하는가?', 1, 1, 'MEDIUM', '클라이언트의 [[적용된 네트워크 설정]]에서 IPv4 주소, 프리픽스 길이 또는 서브넷 마스크, 기본 게이트웨이, DNS 서버가 서버의 승인값과 일치하는지 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '주소 할당 절차가 완료되어도 운영체제나 네트워크 인터페이스에 기대한 값이 반영되었는지는 별도로 확인해야 한다. 클라이언트에 표시된 각 값을 서버가 승인한 설정과 비교하면 누락되거나 잘못 적용된 항목을 찾을 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '적용된 네트워크 설정', '클라이언트가 실제 통신에 사용하는 IPv4 주소, 프리픽스 길이 또는 서브넷 마스크, 기본 게이트웨이, DNS 서버 등의 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '초기 주소 할당', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DHCP 장애 구간 확인', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DORA', 'DHCP Discover, Offer, Request, Acknowledgment의 머리글자로, 발견·제안·요청·승인 순서의 초기 주소 할당 흐름');

-- STEP 4 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '클라이언트와 다른 네트워크에 DHCP 서버가 있을 때, DHCP 중계 기능의 동작으로 가장 적절한 것은?', NULL, '처음 요청이 같은 네트워크 안에 머문다면, 다른 네트워크의 서버와 클라이언트 사이에서 누가 양방향 전달을 맡아야 하는지 생각해 보라.', NULL, '[[DHCP relay]]는 클라이언트 쪽 네트워크의 요청을 원격 DHCP 서버로 중계하고 서버 응답을 클라이언트에게 전달한다.\n초기 DHCP 요청은 일반 라우터를 넘어 자동으로 퍼지지 않으므로 클라이언트 쪽 네트워크에 중계 기능이 필요하다.\n한 네트워크에서만 주소 할당이 실패한다면 해당 네트워크의 중계 설정과 원격 서버까지의 경로를 먼저 확인한다.', NULL, '스위치의 MAC 주소 학습, DNS 질의 또는 클라이언트의 임의 주소 선택은 원격 DHCP 서버와의 초기 통신을 대신하지 못한다. 일반 라우터도 링크 범위의 DHCP 요청을 모든 원격 네트워크로 자동 전달하지 않는다.', 4, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트 쪽 네트워크의 중계 장치가 요청을 원격 DHCP 서버에 전달하고, 서버 응답을 클라이언트에게 돌려보낸다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트 쪽 네트워크의 스위치가 서버의 MAC 주소를 학습한 뒤 요청을 원격 서버에 직접 전달한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트 쪽 네트워크의 DNS 서버가 요청 목적지를 해석한 뒤 원격 DHCP 서버에 질의한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트가 임시 주소를 스스로 선택해 원격 서버에 요청하고, 승인 뒤 그 주소를 계속 사용한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 원격 DHCP 서버를 쓰는 두 네트워크 중 한쪽에서만 주소를 받지 못한다면 무엇을 먼저 비교해야 하는가?', 1, 1, 'MEDIUM', '실패한 네트워크 인터페이스의 [[DHCP relay]] 설정과 원격 서버 주소를 정상 네트워크와 비교한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '원격 서버가 다른 네트워크에는 정상적으로 응답한다면 서버 전체 장애일 가능성은 낮다. 문제가 발생한 네트워크에서 중계 기능이 활성화되어 있고 올바른 서버를 가리키는지 우선 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'DHCP relay', '한 네트워크에서 받은 DHCP 메시지를 다른 네트워크의 서버로 전달하는 DHCP 중계 기능 또는 장치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '원격 DHCP 서버', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '네트워크별 DHCP 장애', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DHCP relay', '클라이언트와 다른 네트워크에 있는 DHCP 서버 사이에서 요청과 응답을 중계하는 기능 또는 장치');

-- STEP 4 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '서비스의 IP 주소로는 접속되지만 같은 서비스의 도메인 이름으로는 접속되지 않으면 먼저 ___를 확인한다.', NULL, '숫자로 된 목적지로 연결할 때와 사람이 읽는 이름으로 연결할 때 추가로 필요한 호스트 설정이 무엇인지 생각해 보라.', NULL, '빈칸에는 [[DNS 서버]] 설정이 들어간다.\nIP 주소로 직접 접속하는 시험은 도메인 이름을 IP 주소로 바꾸는 과정을 거치지 않으므로 원인 범위를 좁히는 단서가 된다.\n이 증상에서는 DHCP로 받은 서버 주소가 올바르게 적용되었는지와 해당 서버에 질의할 수 있는지를 먼저 확인한다.', NULL, 'IP 주소로는 같은 서비스에 접속되는데 도메인 이름을 사용할 때만 실패한다면, 외부 네트워크로 보내는 설정보다 이름을 주소로 바꾸는 데 사용하는 호스트 설정을 먼저 점검하는 것이 적절하다.', 4, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'DNS 서버 설정');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'DNS 설정');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'DNS 서버');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'DNS server');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'DNS');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 서비스에 IP 주소로 직접 접속하는 시험이 성공했다면 원인 범위를 어떻게 좁힐 수 있는가?', 1, 1, 'MEDIUM', '기본 통신 경로와 서비스가 동작할 가능성이 있으므로 [[이름 기반 접속]]에 필요한 설정을 우선 살필 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'IP 주소를 사용한 연결이 성공했다면 호스트에서 서비스까지의 경로와 서비스 자체는 동작할 가능성이 높다. 도메인 이름을 사용할 때만 추가되는 이름 변환 과정과 관련 호스트 설정을 먼저 점검한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '이름 기반 접속', 'IP 주소 대신 도메인 이름을 사용하며, 통신 전에 그 이름에 대응하는 주소를 찾아야 하는 접속 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DHCP 구성 장애 진단', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '접속 증상 분리', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DNS 서버', '도메인 이름에 대응하는 IP 주소를 찾기 위해 호스트가 질의하는 서버');

-- STEP 5. 서브넷·ARP·IP 전달
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (5, '서브넷·ARP·IP 전달', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, '서버는 목적지 IPv4 주소가 현재 네트워크에 속하는지 판단하고, 직접 보낼 수 없으면 라우팅 테이블이 선택한 다음 홉으로 패킷을 보낸다. 이더넷에서는 ARP로 그 다음 홉의 MAC 주소를 알아낸다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '같은 네트워크 판단', '송신 인터페이스의 IPv4 주소와 프리픽스를 목적지 주소에 적용해 네트워크 범위를 비교한다. 목적지가 같은 범위에 있으면 현재 링크에서 직접 전달할 수 있다. /31은 두 장비를 잇는 점대점 링크용 예외로, 일반적인 네트워크 주소와 브로드캐스트 주소 제외 규칙을 적용하지 않고 두 주소를 양 끝에서 모두 사용한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '다른 네트워크로 전달', '목적지가 다른 네트워크에 있고 더 구체적인 경로가 없으면 기본 게이트웨이가 다음 홉이 된다. 송신자는 원격 서버가 아니라 현재 링크의 게이트웨이에 대해 ARP를 수행한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '패킷 캡처의 두 목적지', '원격 서버로 보내는 첫 IPv4 데이터 프레임을 캡처하면 IP 목적지는 원격 서버이지만 이더넷 목적지 MAC은 게이트웨이일 수 있다. 두 헤더가 가리키는 전달 범위가 다르기 때문이다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', 'ARP에 대한 흔한 오해', 'ARP는 인터넷에 있는 원격 서버의 MAC 주소를 찾는 프로토콜이 아니다. ARP 요청은 현재 링크에서 필요한 다음 홉의 링크 계층 주소를 확인하는 데 사용된다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 5 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '서버의 IPv4 주소가 192.0.2.130/26이면 네트워크 주소는 192.0.2.128이고, 일반적인 호스트 주소 범위는 192.0.2.129부터 192.0.2.190까지이다.', NULL, '/26에서 호스트 비트의 개수를 구한 뒤 마지막 옥텟의 블록 크기와 양쪽 경계를 확인해 보세요.', 'O', '정답은 O이며, [[네트워크 주소]]는 192.0.2.128이고 [[브로드캐스트 주소]]는 192.0.2.191이므로 일반적인 호스트 주소 범위는 그 사이이다.\n/26은 호스트 비트가 6개이므로 주소가 64개씩 묶이고 192.0.2.130은 128부터 191까지의 블록에 속한다.\n범위를 잘못 계산하면 서버가 목적지를 같은 네트워크로 오인하거나 불필요하게 게이트웨이로 보내는 장애가 생길 수 있다.', NULL, '/26을 /24처럼 계산하거나 블록 시작점을 잘못 잡으면 호스트 주소 범위가 어긋난다. 마지막 옥텟에서 64씩 증가하는 경계를 먼저 찾으면 된다.', 5, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '192.0.2.0/24를 /26 네 개로 나누면 각 범위의 시작 주소는 무엇인가?', 1, 1, 'MEDIUM', '각 [[서브넷 블록]]의 시작 주소는 192.0.2.0, 192.0.2.64, 192.0.2.128, 192.0.2.192이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '/24에서 /26으로 바꾸면 서브넷을 구분하는 비트가 2개 늘어나 네 개의 범위로 나뉜다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '계산 기준', 'TEXT', '각 범위에는 주소가 64개 있으므로 마지막 옥텟을 64씩 증가시킨다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '서브넷 블록', '하나의 CIDR 프리픽스가 나타내는 연속된 IP 주소 범위');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서브넷 범위', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'CIDR 프리픽스', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '네트워크 주소', '서브넷 범위의 시작을 나타내며 일반적인 호스트 인터페이스에는 할당하지 않는 주소');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '브로드캐스트 주소', '일반적인 IPv4 서브넷에서 호스트 비트가 모두 1인 마지막 주소');

-- STEP 5 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '서버 H는 10.20.30.15/24이고 목적지는 10.20.30.200이다. 기본 게이트웨이가 설정되어 있어도 H는 목적지를 현재 링크의 직접 전달 대상으로 판단한다.', NULL, '두 주소에 같은 /24 프리픽스를 적용했을 때 얻는 네트워크 부분을 비교해 보세요.', 'O', '정답은 O이며, 10.20.30.200은 H와 같은 10.20.30.0/24에 속하는 [[on-link]] 목적지이다.\n송신자는 자신의 인터페이스 프리픽스를 목적지 주소에 적용해 현재 링크에서 직접 도달할 수 있는지 판단한다.\n이 판단을 놓치면 같은 네트워크의 서버 트래픽까지 게이트웨이 문제로 잘못 진단할 수 있다.', NULL, '기본 게이트웨이가 설정되어 있다고 해서 모든 패킷을 게이트웨이로 보내는 것은 아니다. 직접 연결된 네트워크의 경로가 목적지와 일치하면 해당 목적지로 직접 전달한다.', 5, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'H의 프리픽스가 /26으로 바뀐다면 10.20.30.200도 직접 전달 대상인가?', 1, 1, 'EASY', '아니며, [[프리픽스 경계]]를 적용하면 H는 10.20.30.0/26에 있고 목적지는 10.20.30.192/26에 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '/26은 마지막 옥텟을 0, 64, 128, 192에서 시작하는 네 개의 범위로 나눈다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '적용', 'TEXT', '두 주소가 서로 다른 범위에 있으므로 라우팅 테이블에서 다음 홉을 선택해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '프리픽스 경계', '같은 네트워크에 포함되는 연속된 IP 주소 범위의 시작점과 끝점');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '직접 전달', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '네트워크 범위 비교', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'on-link', '라우터를 다음 홉으로 거치지 않고 현재 데이터링크에서 직접 도달할 수 있는 상태');

-- STEP 5 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '두 라우터 R1과 R2만 연결된 IPv4 점대점 링크에서 R1은 203.0.113.10/31, R2는 203.0.113.11/31을 사용하려 한다. 이 주소 계획에 대한 설명으로 가장 정확한 것은?', NULL, '프리픽스가 제공하는 주소 수와 링크에 연결된 인터페이스 수를 비교한 뒤, 첫 주소와 마지막 주소의 용도를 판단해 보세요.', NULL, '두 장비만 연결하는 [[점대점 링크]]에서는 [[/31 프리픽스]]의 두 주소를 양 끝 인터페이스에 하나씩 할당할 수 있다.\n따라서 203.0.113.10과 203.0.113.11은 모두 사용할 수 있으며 어느 한쪽을 브로드캐스트 주소로 제외하지 않는다.\n이 예외를 모르면 정상적인 라우터 연결을 잘못된 주소 설정으로 오진할 수 있다.', NULL, '/31에 일반적인 서브넷의 첫 주소와 마지막 주소 제외 규칙을 그대로 적용하면 두 주소를 모두 사용할 수 없다고 잘못 판단하게 된다. 두 장비만 연결하는 링크에서는 /31의 두 주소가 각각 양 끝을 나타낸다.', 5, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '203.0.113.10은 네트워크 주소이므로 R1 인터페이스에는 할당할 수 없다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '203.0.113.11은 브로드캐스트 주소이므로 R2 인터페이스에는 할당할 수 없다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '두 주소를 각각 R1과 R2 인터페이스에 할당할 수 있다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '두 주소 모두 인터페이스에 할당할 수 없으므로 반드시 /30으로 바꿔야 한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 링크에 203.0.113.8/30을 사용한다면 양 끝 인터페이스에 일반적으로 할당할 수 있는 두 주소는 무엇인가?', 1, 1, 'MEDIUM', '[[일반 서브넷 규칙]]에 따라 203.0.113.9와 203.0.113.10을 할당할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '/30 범위는 203.0.113.8부터 203.0.113.11까지이며 첫 주소와 마지막 주소를 제외한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '주소 구분', 'TEXT', '203.0.113.8은 네트워크 주소이고 203.0.113.11은 브로드캐스트 주소이다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '일반 서브넷 규칙', 'IPv4 서브넷에서 첫 주소를 네트워크 주소로, 마지막 주소를 브로드캐스트 주소로 구분하는 통상적인 규칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '점대점 주소 할당', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv4 /31 예외', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '점대점 링크', '두 장비의 인터페이스만 서로 연결된 통신 링크');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '/31 프리픽스', 'IPv4 주소 두 개로 이루어지며 점대점 링크에서는 두 주소를 양 끝 인터페이스에 모두 할당할 수 있는 프리픽스');

-- STEP 5 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '호스트 A와 B는 같은 이더넷 네트워크에서 각각 172.16.5.10/24와 172.16.5.200/24를 사용한다. A의 ARP 캐시에 B의 정보가 없을 때 일반적인 주소 확인 흐름은?', NULL, '주소 대응 정보가 없을 때 첫 요청이 어느 범위에 전달되고 주소의 주인이 누구에게 응답하는지 구분하세요.', NULL, 'A는 B의 IPv4 주소를 묻는 [[ARP 요청]]을 [[브로드캐스트]]로 보내고, B는 자신의 MAC 주소를 담은 [[ARP 응답]]을 보통 A에게 유니캐스트로 보낸다.\n요청 시점에는 B의 MAC 주소를 모르므로 같은 링크의 모든 인터페이스가 요청을 확인할 수 있어야 한다.\n패킷 캡처에서 요청만 반복되고 응답이 없다면 같은 링크의 연결, 주소 설정 또는 필터링 문제를 의심할 수 있다.', NULL, '주소 대응 정보를 얻기 전에 B를 향한 유니캐스트 MAC을 사용할 수 없으며, 같은 네트워크의 B에 보낼 때 기본 게이트웨이를 경유할 필요도 없다. DNS는 이름을 IP 주소로 변환하지만 IP와 MAC 주소의 대응을 제공하지 않는다.', 5, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 B의 IP를 묻는 요청을 브로드캐스트하고, B는 자신의 MAC을 담아 A에게 응답한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 B의 IP를 묻는 요청을 유니캐스트하고, B는 자신의 MAC을 담아 전체에 응답한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 게이트웨이의 IP를 묻는 요청을 브로드캐스트하고, 게이트웨이는 패킷을 B에게 중계한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 DNS 서버에 B의 MAC을 질의하고, DNS 응답의 MAC을 사용해 B에게 전송한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'A의 캐시에 B의 유효한 주소 대응 정보가 있다면 다음 패킷을 보낼 때 흐름은 어떻게 달라지는가?', 1, 1, 'EASY', 'A는 [[ARP 캐시]]의 대응 정보를 재사용해 별도의 주소 확인 요청 없이 B의 MAC 주소로 프레임을 보낼 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '최근에 확인한 대응 정보를 저장하면 패킷마다 브로드캐스트 요청을 반복하지 않아도 된다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '주의', 'TEXT', '저장된 정보는 영구적이지 않으며 네트워크 변화나 유효 기간에 따라 다시 확인될 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'ARP 캐시', '최근 확인한 IPv4 주소와 MAC 주소의 대응 정보를 저장해 재사용하는 자료 구조');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '주소 대응 정보', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '링크 계층 브로드캐스트', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'ARP 요청', '현재 링크에서 특정 IPv4 주소를 사용하는 인터페이스의 MAC 주소를 묻는 메시지');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '브로드캐스트', '같은 이더넷 링크의 모든 인터페이스가 확인할 수 있도록 프레임을 보내는 방식');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'ARP 응답', '요청받은 IPv4 주소와 자신의 MAC 주소의 대응을 요청자에게 알리는 메시지');

-- STEP 5 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '서버 H가 기본 게이트웨이 192.0.2.1을 통해 198.51.100.20으로 요청을 보내며, 게이트웨이의 MAC 주소는 02:00:00:00:00:01이다. H에서 캡처한 첫 IPv4 데이터 프레임의 IP 목적지는 ___이고 이더넷 목적지 MAC은 ___이다.', NULL, 'IP 헤더와 이더넷 헤더가 각각 전체 통신 경로와 현재 링크 중 어느 범위의 수신자를 가리키는지 구분하세요.', NULL, '첫 IPv4 데이터 프레임의 [[IP 목적지]]는 198.51.100.20이고 [[다음 홉 MAC]]은 02:00:00:00:00:01이다.\nIP 헤더는 최종 서버를 가리키지만 이더넷 헤더는 현재 링크에서 프레임을 받을 게이트웨이를 가리킨다.\n패킷 캡처에서 서버 IP와 게이트웨이 MAC이 함께 보이는 것은 원격 서버로 전달할 때의 정상적인 모습이다.', NULL, '원격 서버의 IP 주소와 첫 링크에서 프레임을 받을 장치의 MAC 주소를 같은 범위의 식별자로 취급하면 안 된다. 원격 서버의 MAC 주소를 현재 링크에서 ARP로 조회하거나 IP 목적지를 게이트웨이 주소로 바꾸는 것은 일반적인 전달 동작이 아니다.', 5, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '198.51.100.20');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '02:00:00:00:00:01');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '주소 변환이 없는 상태에서 게이트웨이가 이 패킷을 다음 이더넷 링크로 보내면 두 목적지 필드는 어떻게 되는가?', 1, 1, 'MEDIUM', 'IP 목적지는 최종 서버 주소로 유지되지만 [[홉별 재캡슐화]]에 따라 이더넷 목적지 MAC은 새 다음 홉의 값으로 바뀐다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '라우터는 수신한 이더넷 프레임에서 IP 패킷을 처리한 뒤 다음 링크에 맞는 새 프레임을 만든다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '패킷 캡처', 'TEXT', '서로 다른 링크에서 캡처하면 같은 IP 목적지를 가진 패킷이라도 이더넷 주소는 다르게 보일 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '홉별 재캡슐화', '라우터가 IP 패킷을 다음 링크에 맞는 새 데이터링크 프레임에 담는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '패킷 캡처 해석', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '다음 홉 전달', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'IP 목적지', 'IP 헤더에서 패킷이 최종적으로 도달할 IPv4 인터페이스를 나타내는 주소');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '다음 홉 MAC', '현재 이더넷 링크에서 프레임을 다음으로 받을 인터페이스의 MAC 주소');

-- STEP 6. 라우팅과 ICMP 진단
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (6, '라우팅과 ICMP 진단', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, '라우터는 목적지별 경로 정보를 바탕으로 패킷을 다음 홉으로 전달한다. 경로 선택 원리와 ICMP 진단 결과가 보장하는 범위를 알면 서버 접속 장애를 더 정확하게 분석할 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '경로 정보와 실제 전달', '라우팅은 목적지별 경로 정보를 만들고 선택하는 과정이고, 포워딩은 도착한 패킷마다 그 정보를 조회해 출력 인터페이스와 다음 홉을 정하는 동작이다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '더 구체적인 경로의 우선', '목적지 주소와 여러 경로가 일치하면 프리픽스가 가장 긴 경로를 사용한다. 더 구체적으로 일치하는 경로가 없으면 모든 IPv4 주소와 일치하는 0.0.0.0/0 기본 경로를 사용할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '수명 값을 이용한 경로 관찰', 'IPv4 라우터는 패킷을 전달할 때 TTL을 줄인다. 경로 추적 도구는 작은 TTL부터 시작해 값을 늘리면서, 수명이 소진된 패킷에 대한 중간 라우터의 ICMP 응답을 관찰한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '진단 결과가 보장하는 범위', '일반적인 ping은 ICMP Echo를 사용하지만 경로 추적의 탐사 패킷은 구현과 옵션에 따라 ICMP, UDP 또는 TCP일 수 있다. 방화벽, 응답 제한, 패킷 손실 때문에 응답이 없더라도 경로 단절이나 서버 장애로 단정할 수 없다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 6 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '라우터에서 routing은 도착한 패킷을 바로 다음 홉으로 보내는 일이고, forwarding은 목적지별 경로 정보를 만드는 일이다.', NULL, '경로 정보가 준비되는 단계와 개별 패킷이 도착한 뒤 그 정보를 조회하는 단계를 구분해 보자.', 'X', '문장은 두 역할을 서로 바꾸어 설명했다.\n[[라우팅]]은 경로 정보를 만들고 선택하며, [[포워딩]]은 그 정보를 조회해 도착한 패킷을 출력 인터페이스나 다음 홉으로 보낸다.\n서버로 가는 패킷을 분석할 때도 경로가 준비되는 과정과 패킷별 전달 동작을 구분해야 한다.', '라우팅 프로토콜이나 운영자 설정으로 경로가 준비된 뒤, 라우터는 패킷이 도착할 때마다 목적지 주소를 조회해 적절한 인터페이스로 내보낸다.', '목적지별 경로 정보를 준비하는 일과 도착한 개별 패킷을 실제로 보내는 일은 수행 시점과 역할이 다르다.', 6, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '동적 라우팅 프로토콜을 사용하지 않아도 관리자가 지정한 경로를 패킷 전달에 사용할 수 있는가?', 1, 1, 'MEDIUM', '가능하다. [[정적 경로]]를 직접 설정하면 동적 라우팅 프로토콜 없이도 해당 경로를 패킷 전달에 사용할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '라우터의 경로 정보는 프로토콜로 자동 학습할 수도 있고, 운영자가 목적지와 다음 홉을 직접 지정해 만들 수도 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '정적 경로', '운영자가 목적지 네트워크와 다음 홉 등을 직접 설정한 경로이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '데이터 평면', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '제어 평면', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '전달 테이블', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '라우팅', '목적지까지의 경로 정보를 만들고 선택하는 과정으로 영어로 routing이라고 한다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '포워딩', '도착한 패킷을 전달 정보에 따라 출력 인터페이스나 다음 홉으로 보내는 동작으로 영어로 forwarding이라고 한다.');

-- STEP 6 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'IPv4 라우터가 TTL이 1인 패킷을 다음 홉으로 전달하려 할 때, 패킷을 폐기하고 일반적으로 송신자에게 ICMP Time Exceeded를 보낸다.', NULL, '라우터가 패킷을 한 홉 더 전달하기 전에 수명 값을 줄였을 때 어떤 조건에서 폐기하는지 생각해 보자.', 'O', 'TTL이 1인 패킷을 더 전달하려는 라우터는 수명 값이 소진되므로 패킷을 폐기한다.\n[[TTL]]은 라우터를 지날 때 감소하며, 라우터는 일반적으로 송신자에게 [[ICMP Time Exceeded]] 오류를 보낸다.\n경로 추적은 이 동작으로 중간 홉을 관찰하지만, 응답 부재만으로 경로 단절을 확정할 수는 없다.', 'TTL이 1인 탐사 패킷은 첫 번째 라우터를 넘어가지 못하므로, 해당 라우터가 보낸 시간 초과 응답을 통해 첫 번째 홉을 관찰할 수 있다.', '수명이 소진된 패킷을 계속 전달하면 라우팅 루프에서 패킷이 오래 순환할 수 있으므로 라우터는 해당 패킷을 폐기한다.', 6, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '경로 추적 결과에서 한 홉만 별표로 보이지만 그다음 홉과 목적지는 응답했다면 어떻게 해석해야 하는가?', 1, 1, 'MEDIUM', '해당 홉이 패킷은 전달했지만 [[응답 제한]], 필터링 또는 손실 때문에 진단 응답이 관측되지 않았을 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '중간 홉의 응답 부재와 실제 패킷 전달 실패는 같은 의미가 아니다. 이후 홉이 응답했다면 탐사 패킷이 문제의 홉을 지나갔다는 근거가 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '응답 제한', '장비가 과부하나 악용을 막기 위해 일정 시간 동안 보내는 진단 응답의 양을 제한하는 동작이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '라우팅 루프', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '홉 제한', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'ICMP 오류 메시지', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TTL', 'IPv4 패킷이 라우터를 거치며 무한히 순환하지 않도록 전달 수명을 제한하는 헤더 필드이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'ICMP Time Exceeded', '패킷의 TTL이 전달 도중 소진되었음을 알리는 ICMP 오류 메시지이다.');

-- STEP 6 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '전달 테이블에 10.0.0.0/8은 출력 A, 10.20.0.0/16은 출력 B, 10.20.30.0/24는 출력 C, 0.0.0.0/0은 출력 D로 등록되어 있다. 목적지가 10.20.30.77인 패킷은 어느 출력으로 전달되는가?', NULL, '목적지와 일치하는 주소 범위 중 목적지를 가장 구체적으로 나타내는 항목을 찾아보자.', NULL, '목적지 10.20.30.77과 일치하는 경로 중 /24가 가장 구체적이므로 출력 C가 선택된다.\n[[최장 프리픽스 일치]]는 목적지와 일치하는 경로 중 프리픽스 길이가 가장 긴 항목을 고르는 규칙이다.\n서버 트래픽이 예상과 다른 방향으로 갈 때는 [[기본 경로]]만 보지 말고 더 구체적인 경로가 있는지 확인해야 한다.', '10.20.30.77은 /8, /16, /24 경로에 모두 포함되지만, 이 중 목적지 범위를 가장 좁게 나타내는 /24 경로가 사용된다.', '표에 먼저 나온 경로나 가장 넓은 범위를 고르는 것이 아니라, 목적지와 일치하는 항목들의 프리픽스 길이를 비교해야 한다.', 6, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/8 경로가 먼저 적혀 있으므로 출력 A로 보낸다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/16 경로도 목적지와 일치하므로 출력 B로 보낸다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '/24 경로가 일치 항목 중 가장 구체적이므로 출력 C로 보낸다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '기본 경로가 모든 주소와 일치하므로 출력 D로 보낸다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 전달 테이블에서 10.20.30.0/24 경로를 제거하면 목적지가 10.20.30.77인 패킷은 어느 출력으로 전달되는가?', 1, 1, 'HARD', '남은 일치 경로 중 프리픽스가 가장 긴 10.20.0.0/16 경로가 [[최장 프리픽스 일치]]에 따라 선택되므로 출력 B로 전달된다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '10.20.30.77은 /16, /8, /0 경로와 일치한다. 제거된 /24를 제외하면 /16이 목적지를 가장 구체적으로 나타낸다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '최장 프리픽스 일치', '목적지와 일치하는 여러 경로 중 프리픽스 길이가 가장 긴 경로를 선택하는 규칙이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '경로 집약', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '구체 경로', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '프리픽스 길이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '최장 프리픽스 일치', '목적지 주소와 일치하는 경로 중 프리픽스가 가장 긴 항목을 선택하는 규칙으로 영어로 longest-prefix match라고 한다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '기본 경로', '더 구체적으로 일치하는 경로가 없을 때 사용하는 가장 포괄적인 경로로 영어로 default route라고 한다.');

-- STEP 6 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서버가 ping에는 응답하지만 HTTPS 연결은 되지 않는다. 이 상황의 해석으로 가장 정확한 것은?', NULL, 'ping 응답이 확인하는 통신 범위와 웹 서비스의 프로세스 및 포트 상태를 구분해 보자.', NULL, 'ping 성공으로 확인되는 것은 [[ICMP 왕복]]이며, HTTPS용 [[애플리케이션 포트]]의 정상 동작까지 보장하지는 않는다.\n방화벽 정책과 서버 프로세스 상태에 따라 ICMP 응답과 HTTPS 연결 결과는 다를 수 있다.\n따라서 실제 장애 진단에서는 ping 결과와 별도로 HTTPS 연결 및 응답을 확인해야 한다.', '서버가 ping에 응답하더라도 웹 서버 프로세스가 중지되었거나 서비스 포트가 차단되어 있으면 HTTPS 연결은 실패할 수 있다.', 'ping 응답과 HTTPS 연결은 서로 다른 통신 방식과 정책의 영향을 받으므로 하나의 성공이 다른 하나의 성공을 보장하지 않는다.', 6, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'ping에 사용된 ICMP의 왕복만 확인되며, HTTPS 서비스 포트의 정상 여부는 별도로 확인해야 한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'ping 응답이 왔으므로 HTTPS 서비스 포트도 정상이다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTPS 연결이 실패했으므로 서버까지의 IP 경로는 반드시 끊겨 있다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'ping과 HTTPS는 같은 종류의 요청이므로 두 결과가 달라질 수 없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '이 상황에서 HTTPS 장애 범위를 좁히기 위해 다음으로 무엇을 확인해야 하는가?', 1, 1, 'MEDIUM', '서버의 [[HTTPS 서비스 포트]]에 연결할 수 있는지와 해당 서비스 프로세스가 요청을 처리할 수 있는지를 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '클라이언트에서 해당 포트로 직접 연결을 시도하고, 서버의 수신 상태와 방화벽 정책 및 서비스 로그를 함께 점검하면 장애 범위를 좁힐 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'HTTPS 서비스 포트', 'HTTPS 요청을 받도록 서버 프로그램이 대기하는 전송 계층의 포트이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'ICMP 왕복', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서비스 포트', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '방화벽 정책', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'ICMP 왕복', 'ICMP Echo 요청이 대상에 도달하고 그 응답이 송신자에게 돌아오는 통신이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '애플리케이션 포트', '서버 프로그램이 클라이언트 연결이나 요청을 받기 위해 사용하는 포트이다.');

-- STEP 6 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '더 구체적으로 일치하는 경로가 없을 때 사용할 수 있는 0.0.0.0/0 경로를 ___라고 한다.', NULL, '모든 IPv4 목적지와 일치하며 다른 경로가 선택되지 않았을 때 사용되는 항목의 역할을 떠올려 보자.', NULL, '빈칸에는 [[기본 경로]]가 들어간다.\n0.0.0.0/0은 모든 IPv4 목적지와 일치하지만, 더 구체적으로 일치하는 경로가 없을 때 선택될 수 있다.\n서버 접속 경로를 점검할 때는 이 경로가 가리키는 다음 홉과 실제 도달 가능성을 함께 확인해야 한다.', '라우터에 사내망을 위한 구체적인 경로와 0.0.0.0/0 경로가 있다면, 구체적인 경로에 해당하지 않는 목적지는 0.0.0.0/0 경로를 사용할 수 있다.', '0.0.0.0/0은 특정한 하나의 목적지만 나타내는 경로가 아니라, 더 구체적인 일치 항목이 없을 때 사용할 수 있는 가장 포괄적인 IPv4 경로이다.', 6, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '기본 경로');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'default route');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '디폴트 라우트');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '라우터의 전달 테이블에 목적지 주소와 일치하는 구체적인 경로도 0.0.0.0/0 경로도 없다면 해당 패킷은 어떻게 처리될 수 있는가?', 1, 1, 'HARD', '패킷은 [[전달 경로 없음]]으로 폐기되며, 라우터는 송신자에게 ICMP 목적지 도달 불가 오류를 보낼 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '선택할 경로가 없으면 라우터는 출력 인터페이스나 다음 홉을 정할 수 없다. 따라서 패킷을 폐기하고 상황에 따라 오류 메시지를 보낼 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '전달 경로 없음', '목적지와 일치하는 구체 경로와 기본 경로가 없어 패킷을 전달할 항목을 선택할 수 없는 상태이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '구체 경로', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '기본 경로', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '다음 홉', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '기본 경로', '더 구체적인 경로가 없을 때 패킷 전달에 사용할 수 있는 가장 포괄적인 경로이다.');

-- STEP 7. NAT와 NAPT
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (7, 'NAT와 NAPT', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'NAT는 네트워크 경계에서 패킷의 IP 주소를 바꾸고, NAPT는 TCP·UDP 포트까지 함께 바꾸어 여러 내부 연결이 공인 IP 주소 하나를 공유하게 한다. 백엔드에서는 변환 상태의 만료, 외부에 보이는 출발지, 포트 포워딩과 방화벽의 역할, 변환 뒤 체크섬 갱신을 구분해 이해해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '주소·포트 변환과 체크섬', 'NAPT 장비는 변환 전후의 주소·포트 대응을 통신 흐름별로 기록해 응답을 원래 내부 연결로 보낸다. IPv4 주소를 바꾸면 IPv4 헤더 체크섬을 갱신하고, TCP 체크섬과 사용 중인 0이 아닌 IPv4 UDP 체크섬도 새 주소·포트에 맞게 갱신한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '외부 API에서 보이는 주소', '10.0.0.8:50000이 198.51.100.7:61000으로 변환되었다면 외부 API 서버는 198.51.100.7을 연결의 출발지로 본다. 응답은 기록된 대응 관계를 통해 10.0.0.8:50000으로 역변환된다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '유휴 상태와 UDP 체크섬 예외', '백엔드 운영체제에서 소켓이 열려 있어도 중간 NAPT 장비의 동적 매핑은 트래픽이 없으면 만료될 수 있다. IPv4 UDP 체크섬 값이 0이면 체크섬을 사용하지 않는다는 표시이므로 NAPT 장비는 이 값을 0으로 유지한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '공개 설정과 허용 정책', '포트 포워딩은 외부 주소와 포트에 도착한 연결의 내부 목적지를 정하고, 방화벽은 그 연결을 허용할지 결정한다. 내부 서버를 공개할 때는 변환 규칙과 방화벽 규칙이 모두 목적에 맞게 설정되었는지 확인해야 한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 7 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'NAT만 사용하면 별도 방화벽 규칙 없이도 출발지 IP별 접근 허용과 같은 보안 정책을 대신할 수 있다.', NULL, '패킷의 주소를 바꾸는 기능과 출발지·포트 조건에 따라 통신을 허용하거나 막는 기능이 맡는 역할을 구분해 보자.', 'X', '이 설명은 틀리며, [[NAT]]는 주소 변환을 담당할 뿐 출발지별 허용 같은 보안 정책을 대신하지 않는다.\n[[방화벽]]은 설정된 규칙에 따라 트래픽의 허용 여부를 결정한다.\n백엔드 포트를 외부에 공개할 때는 변환 규칙과 인바운드 허용 규칙을 각각 확인해야 한다.', '공유기에서 포트 포워딩을 설정해도 방화벽이 해당 TCP 포트를 막으면 외부 요청은 내부 서버에 도달하지 못할 수 있다.', '동적 변환 상태가 없는 외부 연결이 전달되지 않는 현상만으로 보안 정책이 적용되었다고 판단하면 안 된다. 주소 변환 규칙이나 장비 설정이 달라지면 노출 범위도 달라질 수 있다.', 7, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '외부 관리자 IP 한 곳만 내부 관리 API에 접속하도록 제한하려면 주소 변환 외에 무엇을 설정해야 하는가?', 1, 1, 'MEDIUM', '관리자 출발지 IP와 필요한 포트만 허용하는 [[접근 제어 규칙]]을 방화벽에 설정해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '주소 변환은 요청을 보낼 내부 목적지를 정할 수 있지만 요청자의 신뢰 여부를 판단하지 않는다. 방화벽에서 허용할 출발지와 목적지 포트를 제한해야 노출 범위를 줄일 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '접근 제어 규칙', '출발지, 목적지, 프로토콜 등의 조건에 따라 트래픽을 허용하거나 차단하는 규칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '접근 제어', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '인바운드 정책', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '최소 권한', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'NAT', '패킷이 네트워크 경계를 지날 때 IP 주소 등의 정보를 변환하는 기술');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '방화벽', '보안 규칙에 따라 네트워크 트래픽을 허용하거나 차단하는 시스템');

-- STEP 7 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'NAPT는 IP 주소와 TCP·UDP 포트를 함께 매핑하여 여러 내부 연결을 하나의 공인 IP 주소에서 서로 구분할 수 있다.', NULL, '공인 주소 하나를 여러 연결이 공유할 때 반환 패킷을 어느 내부 연결로 보낼지 구별하려면 어떤 정보가 필요한지 생각해 보자.', 'O', '이 설명은 맞으며, [[NAPT]]는 주소와 포트를 함께 매핑해 여러 연결이 하나의 공인 IP 주소를 공유하게 한다.\n[[기본 NAT]]는 주로 IP 주소끼리 대응시키지만, NAPT는 TCP·UDP 포트도 연결 구분에 사용한다.\n내부 인스턴스들이 같은 사설 출발지 포트를 사용해도 외부에서는 서로 다른 변환 결과로 구분될 수 있다.', '10.0.0.10:50000과 10.0.0.20:50000을 각각 198.51.100.5:61000과 198.51.100.5:61001로 매핑하면 공인 IP 주소 하나로 두 연결을 구분할 수 있다.', 'IP 주소만 변환하면 하나의 공인 IP 주소를 공유하는 여러 연결이 충돌할 수 있다. NAPT는 필요한 경우 서로 다른 외부 포트를 할당하고 그 대응 관계를 기록한다.', 7, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'NAPT가 IPv4 주소나 TCP·UDP 포트를 바꿀 때 관련 체크섬을 왜 갱신해야 하는가?', 1, 1, 'MEDIUM', '수신 측이 변경된 패킷을 손상으로 오인하지 않도록 NAPT 장비가 새 헤더 값에 맞춰 [[체크섬]]을 다시 계산해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '체크섬은 패킷의 일부 값을 이용해 전송 중 오류를 확인하는 값이다. IP 주소나 TCP·UDP 포트가 바뀌면 계산에 사용되는 값도 달라지므로, NAPT 장비는 변경된 값을 반영해 관련 체크섬을 갱신한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '체크섬', '패킷의 일부 값을 계산하여 전송 중 데이터나 헤더가 손상되었는지 확인하는 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '포트 다중화', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '공인 IP 공유', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '역변환', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'NAPT', 'IP 주소와 TCP·UDP 포트를 함께 매핑하여 여러 통신 흐름을 구분하는 주소 변환 방식');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '기본 NAT', '전송 계층 포트가 아니라 IP 주소 사이의 대응 관계를 중심으로 변환하는 방식');

-- STEP 7 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '백엔드가 NAPT를 거쳐 외부 API와 맺은 TCP 연결을 오랫동안 사용하지 않았다. 장비의 동적 매핑이 만료된 뒤 이전 공인 주소와 포트로 패킷이 돌아오면 어떻게 될 가능성이 가장 큰가?', NULL, '끝점이 기억하는 연결 상태와 중간 장비의 주소·포트 대응 기록이 같은 시점까지 유지되는지 생각해 보자.', NULL, '기존 변환 기록이 사라졌다면 늦게 온 패킷은 원래 내부 소켓으로 일반적으로 전달되지 않는다.\n[[매핑 만료]] 뒤에는 NAPT 장비가 이전 공인 주소·포트와 내부 주소·포트의 관계를 알 수 없다.\n연결 풀에서 오래 쉬던 연결이 실패하면 [[유휴 시간 제한]]과 연결 재사용 방식을 함께 점검해야 한다.', '외부 API의 응답이 오래 지연되는 동안 변환 기록이 제거되면, 백엔드 소켓은 열려 있어도 응답이 도착하지 않아 시간 초과가 발생할 수 있다.', 'TCP 소켓의 상태는 양 끝점이 관리하며 중간 NAPT 장비의 상태와 자동으로 동기화되지 않는다. 외부 서버의 재전송만으로 사라진 대응 관계가 복원되는 것도 아니다.', 7, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '대응 정보가 없으므로 기존 내부 소켓으로 보통 전달되지 않아 연결 오류로 이어질 수 있다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '외부 서버가 재전송하면 이전 매핑이 자동으로 복원되어 같은 연결이 계속 유지된다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '내부 소켓이 열려 있으면 장비의 매핑도 유지된 것으로 보아 같은 연결이 계속 유지된다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '공인 IP 주소가 같으면 장비가 포트 정보 없이 내부 호스트를 찾아 같은 연결을 계속 유지한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '연결 풀에서 오랫동안 사용하지 않은 연결 때문에 장애가 반복된다면 어떤 대응을 고려할 수 있는가?', 1, 1, 'MEDIUM', '오래된 연결은 [[재사용 전 상태 확인]]을 거치고, 확인이나 실제 사용에 실패하면 버린 뒤 새 연결을 만든다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '애플리케이션은 연결 풀에서 오래된 연결을 꺼낼 때 서비스에 맞는 방식으로 유효성을 확인할 수 있다. 확인이나 요청이 실패하면 해당 연결을 계속 사용하지 말고 새로 연결하도록 구성한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '재사용 전 상태 확인', '연결 풀에서 꺼낸 오래된 연결을 요청에 사용하기 전에 여전히 통신 가능한지 확인하는 절차');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '동적 매핑', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '유휴 연결', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '연결 풀', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '매핑 만료', 'NAPT가 더 이상 필요하지 않다고 판단한 주소·포트 대응 정보를 제거하는 것');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '유휴 시간 제한', '관련 트래픽이 없는 상태가 일정 시간 지속되면 동적 매핑을 제거하는 기준');

-- STEP 7 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '사설망의 두 백엔드 인스턴스가 같은 NAPT 장비를 통해 외부 API에 직접 연결했다. 외부 API가 TCP 상대 IP만 로그에 남길 때 가장 정확한 설명은 무엇인가?', NULL, '로그에는 변환 전의 내부 주소와 네트워크 경계를 지난 패킷의 출발지 주소 중 어느 값이 관측되는지 생각해 보자.', NULL, '두 연결은 모두 NAPT 장비의 [[공인 출발지 IP]]로 보일 수 있어 외부 서버는 상대 IP만으로 내부 호스트를 구분하기 어렵다.\nNAPT를 지난 패킷에는 사설 출발지 주소 대신 변환된 출발지 주소가 들어 있다.\n외부 API의 IP 기반 감사 로그나 제한 정책은 여러 백엔드를 같은 클라이언트로 묶을 수 있음을 고려해야 한다.', '10.0.0.8과 10.0.0.9가 모두 198.51.100.7을 통해 요청하면 외부 API의 상대 IP 로그에는 두 연결 모두 198.51.100.7로 기록될 수 있다.', 'NAPT는 원래 사설 IP 주소를 외부 서버에 자동으로 전달하지 않는다. 변환된 출발지 포트를 알아도 외부 서버는 장비의 매핑 정보 없이는 원래 사설 IP 주소를 복원할 수 없다.', 7, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '두 연결 모두 NAPT 장비의 공인 IP로 보일 수 있어, IP만으로 두 내부 호스트를 구분하기 어렵다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '두 연결 모두 각자의 사설 IP로 보이므로, IP만으로 두 내부 호스트를 구분할 수 있다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '첫 연결만 공인 IP로 보이고, 이후 연결은 각자의 사설 IP로 보여 서로 구분된다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '변환된 출발지 포트를 조회하면, 외부 서버가 원래 사설 IP를 자동으로 복원할 수 있다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '외부 API가 출발지 IP별 호출 한도를 적용할 때 같은 NAPT를 쓰는 여러 백엔드 인스턴스에 어떤 영향이 생길 수 있는가?', 1, 1, 'HARD', '여러 인스턴스가 하나의 [[IP 기반 호출 제한]] 한도를 함께 소비하여 한 인스턴스의 많은 요청이 다른 인스턴스의 요청까지 제한할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '외부 API가 공인 출발지 주소만 기준으로 요청 수를 세면 같은 NAPT 뒤의 인스턴스를 하나의 호출자로 취급할 수 있다. 이 경우 애플리케이션 자격 증명별 한도를 사용하거나 인스턴스 사이의 요청량을 조정하는 방안을 고려할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'IP 기반 호출 제한', '관측된 출발지 IP 주소별로 일정 기간의 요청 수를 제한하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '출발지 주소 변환', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '접근 로그', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IP 기반 호출 제한', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '공인 출발지 IP', 'NAPT를 지난 연결에서 외부 서버가 TCP 상대 주소로 관측하는 인터넷 측 IP 주소');

-- STEP 7 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '외부 사용자의 새 연결을 NAPT 뒤 특정 내부 서버의 포트로 보내려면 미리 ___을 구성한다. 내부에서 먼저 시작한 연결의 응답을 원래 백엔드로 돌려보낼 때는 장비가 ___을 조회한다.', NULL, '새 연결에 필요한 사전 설정과 기존 연결을 처리하면서 만들어진 기록을 구분해 보자.', NULL, '첫 빈칸은 [[포트 포워딩]], 둘째 빈칸은 [[매핑 상태]]다.\n새 외부 연결에는 내부 목적지를 미리 지정한 규칙이 필요하고, 기존 연결의 응답에는 변환할 때 저장한 대응 정보가 필요하다.\n외부 공개 장애를 진단할 때는 전달 규칙, 방화벽 허용 여부, 동적 상태를 서로 다른 확인 대상으로 봐야 한다.', '198.51.100.5:8443을 10.0.0.20:443으로 보내는 규칙은 미리 구성하지만, 외부 API 요청의 응답을 돌려보내는 대응 정보는 내부 연결이 시작될 때 동적으로 만들어질 수 있다.', '외부에서 시작한 새 연결에는 목적지를 정할 기존 동적 기록이 없으므로 사전 규칙이 필요하다. 반대로 내부에서 시작한 연결의 응답에는 해당 연결을 변환하면서 기록한 주소·포트 관계를 이용한다.', 7, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '포트 포워딩');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '정적 포트 매핑');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '포트 전달');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'port forwarding');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'static port mapping');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '매핑 상태');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '변환 상태');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'NAT 매핑 상태');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '매핑 테이블');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '매핑 테이블 항목');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'mapping state');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'mapping table entry');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '포트 포워딩을 설정했는데 외부 접속이 계속 시간 초과된다. 변환 규칙 외에 우선 확인할 두 항목은 무엇인가?', 1, 1, 'MEDIUM', '[[인바운드 방화벽 규칙]]이 요청을 허용하는지와 서버가 올바른 [[리스닝 주소]]와 포트에서 대기하는지를 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '변환 목적지가 올바르더라도 방화벽에서 패킷을 차단하거나 서버 프로세스가 내부 인터페이스와 대상 포트에 바인딩되지 않았다면 연결할 수 없다. 방화벽 로그와 서버의 수신 대기 상태를 나누어 확인해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '인바운드 방화벽 규칙', '외부에서 내부로 들어오는 트래픽의 허용 여부를 결정하는 방화벽 규칙');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '리스닝 주소', '서버 프로세스가 연결 요청을 받기 위해 소켓을 바인딩한 IP 주소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '정적 포트 매핑', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '동적 변환 상태', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '인바운드 허용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '포트 포워딩', '특정 외부 주소와 포트로 온 연결을 미리 지정한 내부 주소와 포트로 전달하는 설정');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '매핑 상태', 'NAPT가 응답을 원래 내부 연결로 돌려보내기 위해 저장한 변환 전후의 주소·포트 대응 정보');

-- STEP 8. IPv6와 Neighbor Discovery
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (8, 'IPv6와 Neighbor Discovery', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'IPv6는 128비트 주소와 고정 40바이트 기본 헤더를 사용하며, 같은 링크의 이웃과 라우터를 찾을 때 ICMPv6 기반 이웃 탐색을 이용한다. IPv4와 IPv6의 주소, 경로, 수신 소켓, 방화벽은 별도로 동작할 수 있으므로 장애도 두 경로로 나누어 살펴야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '주소와 기본 헤더', 'IPv6 주소는 여덟 개의 16비트 16진수 그룹으로 표현한다. 각 그룹의 선행 0을 생략할 수 있고 연속된 0 그룹은 주소에서 한 번만 ::로 줄일 수 있으며, 프리픽스 길이는 주소의 왼쪽부터 센다. IPv6 기본 헤더는 40바이트로 고정되어 있고 IPv4의 TTL 대신 Hop Limit를 사용하며, 헤더 체크섬 필드가 없다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '이웃과 라우터 찾기', 'IPv6에는 브로드캐스트 주소가 없다. 이웃 탐색은 ICMPv6 메시지를 사용하며, 이웃이나 라우터를 처음 찾을 때 멀티캐스트를 활용한다. 같은 이더넷 링크의 IPv6 주소에 대응하는 MAC 주소를 확인할 뿐 아니라 캐시된 이웃이 계속 도달 가능한지도 확인하며, 라우터 알림은 기본 라우터 후보와 프리픽스 정보를 제공할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', 'IPv4와 IPv6의 별도 경로', '서버가 IPv4와 IPv6를 모두 사용하고 DNS에 A와 AAAA 레코드를 제공해도 두 경로의 라우팅, 수신 소켓, 방화벽 상태는 서로 다를 수 있다. 이 때문에 IPv4 요청은 성공하지만 IPv6 요청만 실패할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '큰 응답만 멈추는 장애', 'IPv6 라우터는 출력 링크의 MTU보다 큰 패킷을 중간에서 단편화하지 않고 송신지에 ICMPv6 Packet Too Big 메시지를 보낸다. 송신지는 이 정보를 바탕으로 패킷 크기를 줄이거나 필요한 경우 스스로 단편화한다. 이 신호가 방화벽에서 막히면 작은 통신은 되지만 큰 API 응답이나 파일 전송이 멈추는 경로 MTU 장애가 발생할 수 있다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 8 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'IPv6 주소 2001:db8:1234:5678::1/64에서 /64는 오른쪽 64비트가 네트워크 프리픽스라는 뜻이다.', NULL, '슬래시 뒤 숫자가 주소의 어느 쪽부터 네트워크 범위에 포함되는 비트 수를 세는지 확인한다.', 'X', '이 문장은 틀렸으며, /64라는 [[프리픽스 길이]]는 주소의 왼쪽 64비트가 네트워크 프리픽스임을 뜻한다.\n슬래시 길이는 주소의 최상위 비트부터 프리픽스에 포함할 비트 수를 센다.\n이 기준을 반대로 읽으면 주소가 같은 네트워크 범위에 속하는지와 라우팅 대상을 잘못 판단할 수 있다.', '2001:db8:abcd:12::99/64에서는 앞의 네 그룹인 2001:db8:abcd:12가 64비트 네트워크 프리픽스에 해당한다.', 'IPv4와 IPv6의 CIDR 표기는 모두 주소의 왼쪽부터 프리픽스 길이를 센다. 오른쪽 64비트는 이 주소에서 프리픽스에 포함되지 않는 나머지 부분이다.', 8, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'IPv6 주소 2001:0db8:0000:0000:0000:0000:0000:0010을 짧게 쓰면 어떻게 되는가?', 1, 1, 'MEDIUM', '2001:db8::10이며, [[제로 압축]]으로 연속된 0 그룹을 줄이고 각 그룹의 선행 0을 생략한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '각 16비트 그룹의 선행 0은 생략할 수 있으며, 연속된 0 그룹은 ::로 줄일 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '주의', 'TEXT', '한 주소에서 ::를 두 번 사용하면 각각 몇 개의 0 그룹이 생략됐는지 알 수 없으므로 최대 한 번만 사용할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '제로 압축', 'IPv6 주소에서 연속된 16비트 0 그룹을 ::로 줄여 쓰는 표기 방법');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv6 주소 축약', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'CIDR 프리픽스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '네트워크 프리픽스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '프리픽스 길이', 'prefix length로도 부르며, IP 주소의 왼쪽부터 네트워크 프리픽스에 포함되는 비트 수');

-- STEP 8 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'IPv6에서는 같은 링크의 여러 호스트에게 메시지를 보낼 때 IPv4와 같은 브로드캐스트 주소를 사용한다.', NULL, 'IPv6가 일대다 전달의 수신자 집합을 어떤 종류의 주소로 표현하는지 확인한다.', 'X', '이 문장은 틀렸으며, IPv6는 브로드캐스트 주소를 정의하지 않고 필요한 수신자 집합에 [[멀티캐스트]]를 사용한다.\n멀티캐스트는 특정 그룹을 목적지로 삼아 일대다 전달이 필요한 기능을 구현한다.\n패킷 캡처나 방화벽 규칙에서 IPv4 브로드캐스트만 찾으면 IPv6 이웃 탐색과 라우터 알림 트래픽을 놓칠 수 있다.', '이웃 요청이나 라우터 알림 같은 메시지는 용도에 따라 링크 범위의 멀티캐스트 목적지로 전송될 수 있다.', 'IPv4의 ARP가 링크 계층 브로드캐스트를 이용한다는 사실을 IPv6에 그대로 적용하면 안 된다. IPv6는 브로드캐스트 주소 없이 필요한 수신 범위를 그룹 주소로 표현한다.', 8, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '멀티캐스트 패킷을 보냈다는 것은 같은 링크의 모든 IPv6 호스트가 그 패킷을 처리해야 한다는 뜻인가?', 1, 1, 'MEDIUM', '아니다. [[멀티캐스트 그룹]]을 목적지로 사용하므로 해당 그룹을 수신하는 인터페이스가 IPv6 수준의 처리 대상이 된다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '그룹마다 수신 대상이 다르므로 모든 멀티캐스트 패킷이 링크의 모든 호스트를 위한 것은 아니다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '실무', 'TEXT', '패킷을 분석할 때는 멀티캐스트라는 이유만으로 브로드캐스트와 같은 수신 범위라고 판단하지 말고 목적지 그룹을 확인해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '멀티캐스트 그룹', '같은 일대다 목적지 주소를 수신하도록 구성된 인터페이스들의 집합');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv6 멀티캐스트', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '링크 범위 통신', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'ICMPv6', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '멀티캐스트', '특정 그룹에 속한 여러 수신자를 하나의 목적지 주소로 지정하는 전달 방식');

-- STEP 8 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '호스트 A가 같은 이더넷 링크의 서버 B로 IPv6 패킷을 보내려 하지만 B의 MAC 주소를 모른다. 일반적인 처리로 가장 알맞은 것은?', NULL, '이름을 IP 주소로 바꾸는 절차와, 이미 아는 IP 주소로 이더넷 프레임을 보내기 위해 필요한 주소를 알아내는 절차를 구분한다.', NULL, '첫 번째 설명이 맞으며, [[이웃 탐색]]은 [[이웃 요청]]과 [[이웃 알림]] 메시지로 같은 이더넷 링크의 IPv6 주소에 대응하는 MAC 주소를 알아낸다.\nDNS가 이름을 IP 주소로 바꾸는 것과 달리, 이 절차는 다음 홉에 이더넷 프레임을 보낼 때 필요한 링크 계층 주소를 확인한다.\n같은 링크의 서버가 보이지 않으면 IPv6 주소와 경로뿐 아니라 이웃 캐시와 관련 ICMPv6 메시지도 확인해야 한다.', 'A의 이웃 캐시에 B가 없다면 A는 B의 IPv6 주소에 대응하는 멀티캐스트 주소로 이웃 요청을 보내고, B의 이웃 알림을 받아 MAC 주소를 캐시에 기록할 수 있다.', 'ARP는 IPv4에서 사용하는 주소 확인 방식이다. 라우터 요청과 라우터 알림은 라우터를 찾고 네트워크 정보를 얻는 데 쓰이며, DNS의 AAAA 레코드는 IPv6 주소를 제공하므로 B의 MAC 주소를 직접 확인하지 않는다.', 8, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A가 B의 IPv6 주소에 대응하는 멀티캐스트 주소로 이웃 요청을 보내고, B의 이웃 알림에서 MAC 주소를 학습한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A가 ARP 요청을 브로드캐스트로 보내고, B의 ARP 응답에서 MAC 주소를 학습한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A가 라우터 요청을 멀티캐스트로 보내고, B의 라우터 알림에서 MAC 주소를 학습한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A가 DNS에 B의 AAAA 레코드를 질의하고, 받은 IPv6 주소를 MAC 주소로 사용한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '이웃 캐시에 서버 B의 MAC 주소가 남아 있지만 최근 도달 가능성 확인이 없는 상태에서 통신을 재개했다. NDP는 무엇을 확인하는가?', 1, 1, 'EASY', '[[이웃 도달 불가 감지]]를 통해 B가 여전히 양방향 통신 가능한 이웃인지 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '캐시에 MAC 주소가 남아 있다는 사실만으로 현재도 이웃에게 도달할 수 있다고 단정할 수 없다. NDP는 상위 계층의 통신 성공 단서나 요청에 대한 알림 응답으로 도달 가능성을 확인한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '적용', 'TEXT', '오래된 캐시 항목을 곧바로 버리지는 않으며, 통신을 시도한 뒤 확인이 없으면 유니캐스트 이웃 요청을 보내 상태를 검사할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '이웃 도달 불가 감지', 'Neighbor Unreachability Detection(NUD)으로, 캐시된 이웃과의 양방향 통신 가능 여부를 확인하고 이웃 캐시 상태를 관리하는 절차');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '이웃 요청', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '이웃 알림', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv6 이웃 캐시', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '이웃 탐색', 'Neighbor Discovery Protocol(NDP)로, ICMPv6를 이용해 같은 링크의 이웃과 라우터에 필요한 정보를 찾고 이웃의 도달 가능성을 확인하는 기능');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '이웃 요청', 'Neighbor Solicitation(NS)으로, 이웃의 링크 계층 주소나 도달 가능성을 확인할 때 사용하는 ICMPv6 메시지');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '이웃 알림', 'Neighbor Advertisement(NA)로, 이웃 요청에 응답하거나 자신의 링크 계층 정보 변화를 알릴 때 사용하는 ICMPv6 메시지');

-- STEP 8 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '새 IPv6 서버가 같은 링크의 기본 라우터 후보와 프리픽스 정보를 받으려 한다. 이를 제공하는 방식으로 가장 알맞은 것은?', NULL, '이웃의 MAC 주소를 확인하는 메시지와 호스트에게 네트워크 설정 정보를 알리는 메시지의 역할을 구분한다.', NULL, '첫 번째 설명이 맞으며, 라우터는 [[라우터 알림]]으로 자신을 기본 라우터 후보로 알리고 링크의 프리픽스 정보를 제공할 수 있다.\n호스트는 알림의 라우터 수명과 프리픽스 정보 등을 바탕으로 기본 경로와 주소 설정에 필요한 정보를 구성한다.\n서버에 IPv6 주소가 있어도 기본 경로가 없으면 외부 통신이 실패할 수 있으므로 ICMPv6 알림 수신과 방화벽 정책을 확인해야 한다.', '서버가 라우터 수명이 0보다 크고 프리픽스 정보가 포함된 유효한 라우터 알림을 받으면 운영체제는 해당 정보와 플래그를 바탕으로 기본 경로와 주소 설정을 구성할 수 있다.', '이웃 알림은 이웃의 링크 계층 주소와 도달 가능성을 확인하는 데 사용되고 DNS는 이름과 IP 주소를 연결한다. DHCPv6 응답만으로 기본 라우터 정보까지 항상 얻는 것도 아니다.', 8, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '라우터는 라우터 알림을 보내 자신을 기본 라우터 후보로 알리고 프리픽스 정보를 제공할 수 있다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '다른 호스트는 이웃 알림을 보내 기본 라우터 후보와 프리픽스 정보를 제공한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'DHCPv6 서버는 DHCPv6 응답만으로 항상 기본 라우터와 프리픽스 정보를 제공한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'DNS 서버는 AAAA 레코드로 기본 라우터 후보와 프리픽스 정보를 제공한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '새로 연결된 호스트가 주기적인 라우터 알림을 기다리지 않고 네트워크 설정 확인을 앞당기려면 무엇을 할 수 있는가?', 1, 1, 'MEDIUM', '호스트는 [[라우터 요청]]을 보내 라우터가 라우터 알림을 더 빨리 보내도록 요청할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '호스트는 요청 메시지를 이용해 다음 주기까지 기다리지 않고 같은 링크의 라우터에 알림 전송을 요청할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '진단', 'TEXT', '요청을 보냈는데도 알림이 오지 않으면 링크 상태, 라우터의 IPv6 설정, ICMPv6 방화벽 규칙을 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '라우터 요청', 'Router Solicitation(RS)으로, 호스트가 같은 링크의 라우터에 라우터 알림 전송을 요청하는 ICMPv6 메시지');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv6 기본 경로', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '라우터 요청', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'ICMPv6 필터링', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '라우터 알림', 'Router Advertisement(RA)로, 라우터가 기본 라우터 후보와 프리픽스 등의 IPv6 설정 정보를 호스트에 알리는 ICMPv6 메시지');

-- STEP 8 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '운영체제가 IPv4와 IPv6를 모두 활성화하고, 서비스도 두 버전의 주소에서 연결을 받는다. 변환이나 터널링 없이 두 버전으로 직접 통신하는 구성을 ___이라 한다.', NULL, '한 장비가 두 IP 버전의 주소와 경로를 각각 사용해 직접 통신하는 구성의 이름을 떠올린다.', NULL, '빈칸에는 [[듀얼 스택]]이 들어가며, 이는 한 장비가 IPv4와 IPv6를 모두 활성화해 각 버전으로 직접 통신하는 구성이다.\n운영체제와 애플리케이션은 이름 해석 결과, 경로, 연결 정책에 따라 사용할 IP 버전을 선택한다.\n따라서 IPv4 접속이 성공해도 AAAA 주소, IPv6 경로, 수신 소켓, 방화벽 중 하나에 문제가 있으면 IPv6 접속은 별도로 실패할 수 있다.', 'api.example.com에 A와 AAAA 레코드가 있고 서버가 IPv4와 IPv6 주소에서 모두 요청을 받는다면 클라이언트는 사용 가능한 주소와 경로에 따라 한 버전으로 연결할 수 있다.', 'IPv6 패킷을 IPv4 안에 넣는 터널링이나 두 버전 사이의 패킷을 바꾸는 변환은 별도의 공존 기술이다. 여기서는 한 장비가 두 IP 버전을 각각 직접 처리한다.', 8, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'dual stack');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '듀얼 스택');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'dual-stack');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '듀얼-스택');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '이중 스택');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'DNS에 A와 AAAA 레코드가 모두 있지만 IPv4 접속만 성공한다면 어떤 항목을 두 IP 버전으로 나누어 확인해야 하는가?', 1, 1, 'MEDIUM', '[[AAAA 레코드]]가 가리키는 주소를 기준으로 IPv6 수신 소켓, 경로, 방화벽을 확인하고 IPv4 결과와 비교해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '이름 해석 결과가 올바른지 확인한 뒤 서버의 IPv6 수신 상태, 클라이언트와 서버의 경로, 중간 방화벽을 차례로 점검한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '판단', 'TEXT', 'IPv4 성공은 애플리케이션이 동작한다는 단서는 되지만 별도로 구성된 IPv6 경로까지 정상임을 보장하지 않는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'AAAA 레코드', 'DNS 이름에 대응하는 IPv6 주소를 제공하는 리소스 레코드');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv4·IPv6 공존', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'IPv6 전용 장애', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'A 레코드와 AAAA 레코드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '듀얼 스택', 'dual stack으로도 쓰며, 하나의 장비나 네트워크가 IPv4와 IPv6를 모두 활성화해 각 버전으로 직접 통신하는 구성');

-- STEP 9. 전송 계층과 TCP·UDP
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (9, '전송 계층과 TCP·UDP', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, '전송 계층은 포트와 소켓을 이용해 서버 한 대에서 실행되는 여러 프로그램의 통신을 구분하고, TCP 연결은 양쪽 IP 주소와 포트를 함께 보아 식별한다. TCP는 연결 안에서 바이트를 신뢰성 있게 순서대로 전달하도록 동작하지만 UDP는 데이터그램의 전달과 순서를 보장하지 않으며, 전송 계층의 전달 확인과 애플리케이션의 업무 완료는 구분해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '포트와 연결 구분', '서버 프로세스는 소켓을 특정 로컬 주소와 포트에 바인딩해 요청을 받는다. 운영체제는 전송 프로토콜과 주소·포트 정보를 이용해 수신 데이터를 알맞은 소켓이나 연결로 전달한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '메시지를 읽는 방식', 'UDP는 한 데이터그램을 독립된 메시지 단위로 전달한다. TCP에서는 바이트가 연속해서 보이므로 애플리케이션 프로토콜이 길이 정보나 구분 기호로 메시지를 나눠야 한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '전송 확인과 업무 완료', '프로토콜의 성능은 헤더 크기뿐 아니라 손실, 재시도, 완료 조건에 따라 달라진다. 또한 데이터가 상대 운영체제에 도착한 시점과 서버의 업무 처리가 완료된 시점은 서로 다를 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 9 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '같은 서버 IP로 들어온 두 TCP 연결 요청의 목적지 포트가 다르면, 운영체제는 각 포트에 바인딩된 소켓으로 구분해 전달할 수 있다.', NULL, '운영체제가 서버 안의 여러 프로그램 중 수신 대상을 고를 때 전송 계층 헤더의 어떤 정보를 확인하는지 생각해 보라.', 'O', '운영체제는 목적지 포트를 이용한 [[역다중화]]로 각 연결 요청을 알맞은 [[소켓]]에 전달할 수 있으므로 옳다.\n서버 프로세스는 받을 로컬 주소와 포트를 소켓에 연결하는 [[포트 바인딩]]을 한다.\n연결 거부를 진단할 때는 프로세스가 예상 주소와 포트에서 실제로 대기 중인지 확인해야 한다.', '같은 서버에서 API가 TCP 8080 포트, 관리 도구가 TCP 9090 포트를 사용하면 운영체제는 각 포트로 들어온 연결 요청을 해당 서버 소켓에 전달할 수 있다.', 'IP 주소만으로는 같은 서버에서 실행되는 여러 프로그램을 구분할 수 없다. 운영체제는 전송 프로토콜과 목적지 포트 등의 정보를 함께 사용해 수신 대상을 선택한다.', 9, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'TCP 서버가 8080 포트에서 대기하려다 ‘주소가 이미 사용 중’ 오류를 받았다면 무엇을 먼저 확인해야 하는가?', 1, 1, 'MEDIUM', '같은 전송 프로토콜에서 다른 소켓의 [[포트 점유]] 여부를 먼저 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '다른 소켓이 TCP 8080 포트에 이미 바인딩되어 있으면 새 서버가 같은 조건으로 바인딩하지 못할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '실무 확인', 'TEXT', '운영체제의 소켓 조회 도구로 해당 포트를 사용하는 프로세스와 바인딩된 로컬 주소를 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '포트 점유', '다른 소켓이 특정 로컬 주소와 포트에 이미 바인딩되어 새 바인딩과 충돌하는 상태다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '다중화와 역다중화', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '포트 바인딩', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서버 포트 충돌', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '역다중화', '수신 데이터를 전송 계층의 식별 정보에 따라 알맞은 소켓으로 나누어 전달하는 과정이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '소켓', '애플리케이션이 운영체제의 네트워크 통신 기능을 사용하는 인터페이스이자 통신 객체다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '포트 바인딩', '소켓이 받을 로컬 IP 주소와 포트 번호를 운영체제에 등록하는 동작이다.');

-- STEP 9 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'UDP는 헤더가 단순하고 자체 재전송이 없으므로, 네트워크 상태와 애플리케이션 설계에 관계없이 요청을 항상 더 빨리 완료한다.', NULL, '첫 패킷의 전송 비용이 아니라 애플리케이션이 필요한 결과를 모두 얻기까지의 시간을 기준으로 비교하라.', 'X', 'UDP를 사용한다는 이유만으로 요청의 [[종단 지연]]이 항상 더 짧다고 볼 수 없으므로 틀리다.\nTCP는 [[손실 복구]]를 통해 신뢰성 있는 순서 전달을 제공하지만, UDP는 데이터그램의 전달과 순서를 보장하지 않는다.\n헤더 크기만 보지 말고 타임아웃, 재시도, 데이터 완전성을 포함한 요청 완료 시간을 측정해야 한다.', '모든 데이터를 받아야 하는 서비스가 UDP 위에 자체 재전송을 구현하면 패킷 손실 시 복구 과정 때문에 완료 시간이 길어질 수 있다.', '작은 헤더와 단순한 기본 동작은 일부 상황에서 유리하지만 성능을 보장하지는 않는다. 실제 완료 시간은 손실, 재시도 방식과 애플리케이션의 완료 조건에 따라 달라진다.', 9, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '실시간 로그 전송에서 일부 로그가 빠져도 되는지 정하지 않은 채 UDP를 선택하면 왜 문제가 되는가?', 1, 1, 'MEDIUM', '누락 허용 범위와 완료 시간 같은 [[전송 요구사항]]이 없으면 필요한 복구 기능과 적절한 프로토콜을 판단할 수 없다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'UDP는 손실된 로그를 전송 계층에서 복구하지 않으므로 누락을 허용할 수 없다면 별도의 대책이 필요하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '설계 기준', 'TEXT', '프로토콜을 고르기 전에 데이터 누락 허용 여부, 지연 목표, 순서 요구를 먼저 정해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '전송 요구사항', '데이터 누락, 순서, 지연과 완료 조건에 관해 애플리케이션이 필요로 하는 성질이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '요청 완료 시간', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '전송 오버헤드', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '손실 복구 전략', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '종단 지연', '송신 시작부터 애플리케이션이 필요한 결과를 얻기까지 걸리는 전체 시간이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '손실 복구', '전송 중 사라진 데이터를 감지하고 필요한 데이터를 다시 전달하는 처리다.');

-- STEP 9 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'API 서버는 192.0.2.10의 TCP 443 포트에서 요청을 받고, 클라이언트는 198.51.100.7:53000을 사용한다. 이 연결을 다른 TCP 연결과 구분하는 설명으로 가장 정확한 것은?', NULL, '서버의 한 포트를 여러 클라이언트가 함께 사용할 때 각 연결을 구분하려면 양쪽의 어떤 정보를 확인해야 하는지 생각해 보라.', NULL, '이 연결은 전송 프로토콜과 양쪽 IP 주소·포트를 묶은 [[5-튜플]]로 구분한다.\n서버의 443 포트가 같아도 클라이언트의 주소나 [[임시 포트]]가 다르면 별개의 연결이 된다.\n특정 연결의 로그나 패킷을 찾을 때는 서버 정보뿐 아니라 통신 양쪽의 정보를 함께 대조해야 한다.', '한 클라이언트가 53000 포트로 연결하고 다른 클라이언트가 54000 포트로 연결하면 두 연결은 같은 서버의 443 포트를 사용하더라도 서로 구분된다.', '서버 주소와 포트만으로는 같은 서버 소켓에 연결된 여러 TCP 연결을 구분할 수 없다. 클라이언트 정보만 사용하거나 포트 정보를 제외해도 연결의 양쪽 끝을 완전하게 식별할 수 없다.', 9, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'TCP라는 전송 프로토콜과 출발지·목적지의 IP 주소 및 포트를 함께 묶어 구분한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버 IP 주소와 서버 포트만으로 모든 연결을 구분한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트 IP 주소와 클라이언트 포트만으로 구분한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '출발지와 목적지의 IP 주소만 비교하고 포트는 비교하지 않는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 서버 포트에서 처리한 요청을 TCP 연결별로 로그에서 구분하려면 무엇을 함께 기록해야 하는가?', 1, 1, 'MEDIUM', '클라이언트의 IP 주소와 포트를 [[연결 로그]]에 함께 기록해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '같은 서버 주소와 포트를 사용하더라도 클라이언트의 주소나 포트가 다르면 서로 다른 TCP 연결로 구분된다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '운영 적용', 'TEXT', '서버 로그에 클라이언트 주소와 포트를 기록하면 같은 서버 포트에서 발생한 통신을 연결별로 추적할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '연결 로그', '연결을 구분하고 추적할 수 있도록 서버와 클라이언트의 주소·포트 등의 정보를 기록한 로그다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'TCP 연결 식별', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서버 포트 공유', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '클라이언트 임시 포트', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '5-튜플', '전송 프로토콜, 출발지 IP와 포트, 목적지 IP와 포트를 묶은 연결 식별 정보다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '임시 포트', '클라이언트 연결 등에 운영체제가 일정 범위에서 동적으로 할당하는 로컬 포트다.');

-- STEP 9 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '채팅 서버가 UDP에서는 ‘ABC’와 ‘DEF’를 각각 한 데이터그램에 담고, TCP에서는 두 논리 메시지를 연달아 보낸다. 수신 애플리케이션의 처리 방식으로 가장 정확한 것은?', NULL, '수신 데이터에서 전송 단위의 경계가 유지되는지와 애플리케이션이 메시지의 시작과 끝을 따로 정해야 하는지를 비교하라.', NULL, 'UDP [[데이터그램]]은 경계를 보존하지만 TCP는 [[바이트 스트림]]만 제공하므로 별도의 메시지 구분이 필요하다.\nTCP 기반 프로토콜은 길이 정보나 구분 기호 같은 [[프레이밍]] 규칙으로 논리 메시지를 나눈다.\nTCP 데이터가 나뉘거나 합쳐져 읽혀도 완전한 메시지가 될 때까지 수신 버퍼에 모아 처리해야 한다.', '두 UDP 데이터그램이 모두 도착하면 수신자는 ‘ABC’와 ‘DEF’를 별개 단위로 읽는다. TCP 채팅 프로토콜은 각 메시지 뒤에 줄바꿈을 붙이고, 수신 버퍼에서 줄바꿈이 나타날 때마다 메시지를 꺼낼 수 있다.', 'TCP가 바이트 순서를 보장한다는 사실은 논리 메시지의 시작과 끝까지 알려 준다는 뜻이 아니다. 반대로 UDP는 각 데이터그램의 경계를 유지하므로 데이터그램 내부를 구분하기 위한 별도 규칙이 항상 필요한 것은 아니다.', 9, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'UDP는 데이터그램 경계를 보존하고, TCP에서는 길이 정보나 구분 기호로 메시지 경계를 정해야 한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'UDP는 바이트를 하나의 흐름으로 합치고, TCP는 각 논리 메시지의 경계를 자동으로 보존한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'UDP와 TCP는 모두 논리 메시지의 경계를 보존하므로 수신 측에 별도 형식이 필요 없다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'UDP와 TCP는 모두 메시지 경계를 보존하지 않으므로 두 프로토콜 모두 별도 구분 규칙이 필요하다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'TCP에서 한 번의 읽기로 받은 바이트를 메시지 하나로 바로 처리하면 안 되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '한 번의 [[읽기 결과]]는 메시지 경계와 일치하지 않아 메시지 일부만 담거나 여러 메시지를 함께 담을 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'TCP는 연속된 바이트를 제공하며, 애플리케이션이 호출한 한 번의 읽기 크기는 송신 측이 정한 메시지 단위와 무관하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '장애 예방', 'TEXT', '수신 버퍼에서 프로토콜의 길이 정보나 구분 기호를 확인한 뒤 완전한 메시지만 처리해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '읽기 결과', '애플리케이션이 한 번의 소켓 읽기 호출로 받은 바이트 묶음이며, 논리 메시지 하나와 일치한다는 보장은 없다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '애플리케이션 프레이밍', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '수신 버퍼', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '부분 읽기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '데이터그램', 'UDP가 독립된 메시지 경계를 유지해 전달하는 데이터 단위다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '바이트 스트림', '메시지 구분 없이 순서대로 이어지는 바이트의 연속으로 제공되는 데이터 모델이다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '프레이밍', '연속된 데이터에서 각 논리 메시지의 시작과 끝을 식별하도록 형식을 정하는 방법이다.');

-- STEP 9 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'TCP 소켓 쓰기(write)가 성공하고 운영체제가 원격 TCP에서 ___ 신호를 받았더라도 상대 서버의 업무 처리가 끝났다는 뜻은 아니다. 결제 처리 같은 업무 완료는 서버가 정의한 ___으로 확인해야 한다.', NULL, '운영체제가 확인하는 데이터 전달 범위와 서버의 비즈니스 로직이 보장하는 결과의 범위를 나누어 생각하라.', NULL, '소켓 쓰기 성공이나 [[TCP ACK]] 수신은 업무 완료의 증거가 아니며, 결과는 [[애플리케이션 응답]]으로 확인해야 한다.\n소켓 쓰기 성공은 바이트가 로컬 송신 계층에 받아들여졌다는 뜻이고, 전송 계층의 확인 신호는 원격 TCP가 해당 바이트를 받았다는 뜻이다.\n결제나 작업 등록의 성공 여부는 응답 내용과 요청 식별자로 확인하고 연결 상태만으로 완료 처리하지 않아야 한다.', '결제 요청의 바이트가 서버 TCP에 도착한 뒤 애플리케이션 로직이 완료되기 전에 서버가 종료될 수 있다. 이때 전송 계층의 확인만으로는 결제가 처리됐다고 판단할 수 없다.', '데이터가 원격 전송 계층에 도착한 것과 서버 애플리케이션이 요청을 읽고 데이터베이스 작업까지 마친 것은 서로 다른 사건이다. 업무 성공 여부는 애플리케이션 프로토콜이 정의한 결과로 판단해야 한다.', 9, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'TCP ACK');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'ACK');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'tcp ack');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'ack');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'acknowledgment');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'acknowledgement');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '애플리케이션 응답');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '응용 계층 응답');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'application response');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'application-level response');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '업무 응답');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '주문 생성 요청 뒤 응답을 받기 전에 연결이 끊겼다면, 클라이언트는 주문 실패로 확정해도 되는가?', 1, 1, 'HARD', '아니며, 서버의 조회 기능에서 [[요청 식별자]]로 실제 주문 상태를 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '서버가 요청을 처리하지 못했을 수도 있지만 처리를 마친 뒤 응답만 전달되지 않았을 수도 있으므로, 연결 종료만으로 결과를 구분할 수 없다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '실무 대응', 'TEXT', '서버는 클라이언트가 불확실한 결과를 조회할 수 있도록 요청과 처리 결과를 연결하는 식별 정보를 제공하는 것이 좋다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '요청 식별자', '클라이언트 요청과 서버의 처리 결과를 연결해 조회하거나 추적할 수 있게 하는 고유한 값이다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '전송 성공과 업무 성공', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서버 응답 확인', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '불확실한 요청 결과', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TCP ACK', '원격 TCP가 특정 바이트 범위를 수신했음을 알리는 전송 계층의 확인 정보다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '애플리케이션 응답', '서버 애플리케이션이 요청을 처리한 결과를 상위 프로토콜 수준에서 알려 주는 응답이다.');

-- STEP 10. TCP 연결 수립과 종료
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (10, 'TCP 연결 수립과 종료', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'TCP는 3-way handshake로 양쪽의 통신 준비와 각 송신 방향의 초기 순서 정보를 확인한 뒤 데이터를 주고받는다. 연결 종료는 송신 방향마다 독립적으로 진행되므로 누가 종료를 시작했고 로컬 애플리케이션이 정리를 마쳤는지 구분해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '연결은 세 단계로 확인한다', '일반적인 TCP 연결은 SYN, SYN+ACK, ACK 순서로 수립된다. 이 과정에서 양쪽은 연결 요청과 응답이 도달했음을 확인한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '순서 번호의 시작값을 정한다', '연결을 시작할 때 각 송신 방향은 초기 순서 번호를 정하며, 이를 ISN이라고 한다. SYN은 데이터가 없어도 순서 번호 공간 하나를 사용하므로 뒤따르는 데이터의 순서 번호는 그다음 값부터 이어진다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '종료는 방향별로 진행된다', 'FIN은 보낸 쪽이 더 이상 데이터를 보내지 않겠다는 뜻이다. 한쪽이 FIN을 보낸 뒤에도 반대쪽은 남은 데이터를 계속 보낼 수 있으며, 각 방향은 별도의 FIN으로 종료된다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '소켓 상태는 통신 흐름으로 해석한다', 'TIME_WAIT는 클라이언트에만 생기는 상태가 아니라 먼저 종료를 시작한 쪽에 남을 수 있는 정상적인 대기 상태다. CLOSE_WAIT가 계속 증가한다면 상대의 FIN을 받은 뒤 로컬 애플리케이션이 소켓 정리를 끝내지 못하는지 점검해야 한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 10 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '일반적인 TCP 연결에서 클라이언트가 SYN을 보냈다면, 서버의 응답을 확인하기 전에도 양방향 통신 준비가 끝난 것으로 볼 수 있다.', NULL, '연결 요청을 보낸 단계와 상대의 응답까지 확인한 단계를 구분해 보자.', 'X', '클라이언트가 SYN만 보낸 시점에는 연결 수립이 완료되지 않았으므로 문장은 X이다.\n[[3-way handshake]]는 양쪽이 연결 요청과 응답을 확인하고 초기 순서 정보를 맞추는 과정이다.\n접속 장애에서는 SYN 송신 여부뿐 아니라 서버 응답과 마지막 확인응답이 오가는지도 확인해야 한다.', NULL, 'SYN 송신은 연결 수립의 첫 단계일 뿐이다. 서버의 응답과 이에 대한 마지막 확인응답이 오가야 양쪽이 연결 정보를 확인할 수 있다.', 10, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '패킷 캡처에서 클라이언트의 연결 요청만 반복되고 서버 응답이 보이지 않는다. 백엔드 개발자가 우선 확인할 범위는 무엇인가?', 1, 1, 'EASY', '서버 포트가 [[리스닝]] 중인지와 요청·응답 경로의 방화벽이나 보안 그룹이 트래픽을 허용하는지 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '먼저 요청이 서버까지 도달하는지 확인하고, 서버 프로세스가 해당 포트에서 연결을 받을 준비가 되었는지와 응답 경로가 차단되지 않았는지를 차례로 점검한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '리스닝', '서버 소켓이 특정 포트에서 들어오는 연결 요청을 기다리는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '연결 수립 확인', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '접속 타임아웃 진단', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '3-way handshake', 'TCP가 SYN, SYN+ACK, ACK을 교환하여 양쪽의 연결 정보를 확인하는 절차');

-- STEP 10 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'A가 쓰기 방향을 종료해 B에 FIN을 보냈고 B의 FIN은 아직 오지 않았다. 이때 A는 B가 보내는 데이터를 계속 받을 수 있다.', NULL, '한쪽이 보내기를 끝낸 것과 반대 방향의 받기까지 끝난 것을 구분해 보자.', 'O', 'A의 수신 방향은 아직 열려 있으므로 문장은 O이다.\nTCP의 [[half-close]]에서는 한쪽 송신만 닫힌 동안 반대쪽 데이터는 계속 수신할 수 있다.\n백엔드에서는 송신 종료와 소켓 전체 종료를 구분해야 남은 응답을 잃지 않는다.', NULL, 'FIN을 연결 전체의 즉시 종료로 해석하면 반대 방향의 데이터 수신 가능성을 놓친다. 쓰기 방향만 종료했다면 읽기 방향은 별도로 유지할 수 있다.', 10, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '상대가 송신을 끝낸 상황에서 애플리케이션은 수신 버퍼의 데이터를 언제까지 읽어야 하는가?', 1, 1, 'MEDIUM', 'FIN 전에 도착해 수신 버퍼에 남아 있던 데이터까지 처리하고 [[EOF]]를 확인할 때까지 읽어야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '일반적인 스트림 읽기에서는 버퍼에 남은 데이터가 먼저 반환되고, 모두 읽은 뒤에 스트림의 끝이 알려진다. 끝을 확인하기 전에 읽기 루프를 멈추면 이미 도착한 응답 일부를 처리하지 못할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'EOF', '더 읽을 데이터가 없고 상대의 송신 스트림이 끝났음을 읽기 호출이 알리는 결과');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '단방향 스트림 종료', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '수신 버퍼 처리', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'half-close', 'TCP 연결에서 한쪽 송신 방향만 종료되고 반대쪽 송신 방향은 계속 열려 있는 상태');

-- STEP 10 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서버는 SYN+ACK을 반복해서 보내고 클라이언트는 이를 받지만, 클라이언트의 마지막 ACK은 서버에 도착하지 않는다. 연결 실패의 가장 직접적인 조사 대상은?', NULL, '서버가 확인하지 못한 패킷이 출발한 곳과 서버까지의 이동 경로를 따라가 보자.', NULL, '클라이언트의 ACK 송신 과정과 클라이언트에서 서버로 가는 네트워크 경로를 조사하는 것이 가장 적절하다.\n서버는 마지막 ACK을 받아야 [[3-way handshake]]의 서버 측 연결 수립을 마칠 수 있다.\n방화벽, 보안 그룹과 패킷 유실을 확인하면 애플리케이션 로그만으로 보이지 않는 원인을 좁힐 수 있다.', NULL, 'HTTP 응답 생성은 연결 수립 이후에 일어나고, 종료 대기 상태도 연결을 닫을 때 나타난다. DNS 조회는 이미 서버와 패킷을 교환한 뒤 발생한 마지막 ACK 유실을 직접 설명하지 못한다.', 10, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트의 ACK 송신과 클라이언트에서 서버로 가는 네트워크 경로', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버의 HTTP 응답 생성과 애플리케이션의 비즈니스 로직', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버의 정상 종료 대기와 종료된 소켓의 상태 유지 시간', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '클라이언트의 DNS 캐시와 서버 이름을 조회하는 순서', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '서버가 같은 SYN+ACK을 반복해서 보내는 이유는 무엇인가?', 1, 1, 'MEDIUM', '자신의 SYN에 대한 확인응답을 받지 못했으므로 연결 수립을 다시 시도할 기회를 만들기 위해 [[재전송]]하는 것이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '서버는 자신의 SYN이 확인되었다는 증거를 받지 못했다. SYN+ACK을 다시 보내면 클라이언트가 마지막 ACK을 다시 보내 연결 수립을 완료할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '재전송', '보낸 정보의 도착을 확인하지 못한 TCP 송신자가 같은 정보를 다시 보내는 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '패킷 캡처 해석', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '방화벽 경로 진단', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '3-way handshake', 'TCP 연결의 양쪽이 SYN, SYN+ACK, ACK을 교환하여 연결 수립을 확인하는 절차');

-- STEP 10 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '일반적인 TCP 연결에서 송신자의 초기 순서 번호가 5000이고 SYN에 데이터가 없다면, 첫 데이터 바이트의 순서 번호는 무엇인가?', NULL, '연결 시작을 알리는 제어 정보가 데이터가 없어도 다음 순서 번호에 영향을 주는지 떠올려 보자.', NULL, '첫 데이터 바이트의 순서 번호는 5001이다.\n[[ISN]]은 SYN에 기록되는 시작 순서 번호이며, SYN은 데이터가 없어도 순서 번호 공간 하나를 사용한다.\npacket capture에서 SYN 다음 순서 번호가 +1인 것을 데이터 손실로 오인하지 않는다.', NULL, '5000은 SYN 자체에 사용된 시작값이다. SYN은 순서 번호 공간 하나만 사용하므로 5002로 건너뛰지 않으며, 제시된 조건에서는 데이터 길이와 관계없이 첫 데이터 바이트의 번호를 정할 수 있다.', 10, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '5001', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '5000', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '5002', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '데이터 길이에 따라 달라져 정할 수 없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '클라이언트와 서버의 초기 순서 번호는 서로 같아야 하는가?', 1, 1, 'MEDIUM', '아니다. 각 송신 방향이 초기 순서 번호를 따로 정하므로 두 방향은 [[독립적인 순서 번호]]를 사용하며, 값이 같을 필요가 없다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'TCP 연결에는 클라이언트에서 서버로 보내는 흐름과 서버에서 클라이언트로 보내는 흐름이 있다. 양쪽은 자신이 보내는 흐름의 시작값을 각각 정하므로 서로 다른 값을 사용할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '독립적인 순서 번호', 'TCP 연결의 각 송신 방향이 상대 방향과 별개로 정하고 관리하는 순서 번호');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '초기 순서 번호', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'SYN의 순서 번호 사용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '패킷 캡처 해석', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'ISN', 'Initial Sequence Number의 약자로, TCP 연결을 시작할 때 각 송신 방향이 정해 SYN에 담는 초기 순서 번호');

-- STEP 10 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '소켓 상태 집계에서 두 종류의 상태가 많이 보인다. 상대가 먼저 닫은 뒤 로컬 애플리케이션의 정리가 끝나지 않아 쌓이는 상태는 ___이고, 로컬이 먼저 종료를 시작한 연결에서 마지막 ACK 뒤 일정 시간 남는 상태는 ___이다.', NULL, '상대의 종료를 받은 뒤 로컬 프로그램의 정리를 기다리는 경우와 로컬이 종료를 시작한 뒤 프로토콜이 기다리는 경우를 구분해 보자.', NULL, '첫 번째 빈칸은 [[CLOSE_WAIT]], 두 번째 빈칸은 [[TIME_WAIT]]이다.\n상대의 FIN을 받은 뒤에는 로컬 애플리케이션의 종료가 필요하고, 능동 종료 뒤에는 마지막 ACK 유실 등에 대비한 대기 시간이 필요하다.\n운영에서는 첫 상태의 지속 증가와 둘째 상태의 일시적 증가를 서로 다른 원인으로 해석해야 한다.', NULL, '두 상태의 순서를 바꾸면 애플리케이션이 종료를 마치지 못한 현상과 정상 종료 뒤의 프로토콜 대기를 혼동하게 된다. 누가 먼저 종료했으며 로컬 애플리케이션의 close가 끝났는지를 기준으로 구분해야 한다.', 10, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'CLOSE_WAIT');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'CLOSE-WAIT');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'CLOSE WAIT');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TIME_WAIT');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TIME-WAIT');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TIME WAIT');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '운영 서버에서 첫 번째 상태가 계속 늘어난다면 코드에서 무엇을 가장 먼저 점검해야 하는가?', 1, 1, 'MEDIUM', '정상·예외·타임아웃 경로 모두에서 소켓이나 네트워크 응답을 닫지 않아 [[자원 누수]]가 생기는지 점검한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '상대가 먼저 연결을 닫아도 로컬 프로세스는 자신이 보유한 소켓을 정리해야 한다. 예외 처리, 조기 반환과 타임아웃 처리에서 close가 빠지지 않는지 확인하는 것이 우선이다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '자원 누수', '사용을 마친 소켓 같은 자원을 해제하지 않아 프로세스와 운영체제에 계속 남기는 문제');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '소켓 상태 진단', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '연결 자원 정리', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '능동 종료', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'CLOSE_WAIT', '상대의 FIN을 받은 뒤 로컬 애플리케이션이 자신의 연결 종료를 요청하기를 기다리는 상태');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TIME_WAIT', '능동 종료자가 마지막 ACK을 보낸 뒤 종료 신뢰성과 이전 연결의 지연 세그먼트 소멸을 위해 유지하는 상태');

-- STEP 11. TCP 신뢰성과 흐름 제어
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (11, 'TCP 신뢰성과 흐름 제어', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'TCP는 바이트 위치와 누적 확인 응답으로 순서 있고 신뢰성 있는 전달을 제공하며, 수신 윈도우로 수신 측의 처리 여유를 알린다. 백엔드 애플리케이션은 TCP 바이트 스트림에서 메시지 경계를 직접 복원하고 읽기 지연이 송신 측에 미치는 영향도 이해해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '바이트 위치와 누적 확인', 'TCP 순서 번호는 세그먼트 개수가 아니라 바이트 스트림의 위치를 나타낸다. ACK 번호는 빈틈없이 받은 범위의 다음 바이트를 가리키며, 확인되지 않은 데이터는 재전송될 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '수신 버퍼가 만드는 백프레셔', '수신 애플리케이션이 데이터를 늦게 읽으면 수신 버퍼의 여유가 줄고 광고되는 수신 윈도우도 작아질 수 있다. 송신자는 이 범위를 넘는 새 데이터 전송을 제한하므로 느린 소비 처리가 연결 반대편까지 영향을 줄 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '스트림에서 요청 조립', '한 번의 읽기 호출은 요청 일부만 반환하거나 여러 요청의 데이터를 함께 반환할 수 있다. 서버는 길이 접두사나 구분자 같은 애플리케이션 규칙에 따라 버퍼의 바이트를 완전한 메시지로 조립해야 한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '도착 순서와 전달 순서', '뒤쪽 데이터가 먼저 도착하면 수신자는 이를 보관해 앞쪽 빈 구간이 채워진 뒤 재조립할 수 있다. 다만 버퍼와 구현 정책에 따라 폐기될 수도 있으며, 애플리케이션에는 연속된 데이터만 원래 순서대로 전달된다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 11 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'TCP의 순서 번호는 데이터 세그먼트마다 1씩 증가한다. 따라서 seq=1000에서 시작한 데이터 500바이트 뒤에 빈틈없이 이어지는 데이터는 seq=1001에서 시작한다.', NULL, '첫 데이터 바이트의 위치와 데이터 길이를 기준으로 다음 시작 위치를 계산해 보라.', 'X', '정답은 X이며, 500바이트 데이터 뒤의 다음 시작 [[순서 번호]]는 1500이다.\nTCP는 세그먼트 개수가 아니라 바이트 위치를 번호로 매기므로 시작 번호에 데이터 길이를 더한다.\n이 원리를 알면 패킷 캡처에서 누락 구간과 재전송 범위를 정확히 해석할 수 있다.', 'seq=4000에서 시작하는 데이터가 120바이트라면 4000부터 4119까지를 차지하므로 빈틈없이 이어지는 데이터는 seq=4120에서 시작한다.', '세그먼트 하나마다 번호를 1씩 더하면 각 세그먼트가 운반한 데이터의 실제 위치를 추적할 수 없다.', 11, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'seq=2500에서 시작하는 데이터 300바이트를 빈틈없이 받은 직후, 수신자가 보내는 ACK 번호는 무엇인가?', 1, 1, 'EASY', '2500부터 2799까지 받았으므로 [[누적 ACK]] 번호는 다음 바이트인 2800이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'ACK 번호는 연속해서 받은 마지막 바이트의 번호가 아니라 그다음에 기대하는 바이트 번호다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '누적 ACK', '빈틈없이 받은 모든 바이트를 그다음 바이트 번호 하나로 확인하는 응답 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '바이트 단위 순서 번호 공간', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '데이터 길이와 순서 번호', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '다음 데이터 위치', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '순서 번호', 'TCP 바이트 스트림에서 세그먼트에 담긴 첫 데이터 바이트의 위치를 나타내는 번호');

-- STEP 11 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'TCP 수신자는 수신 윈도우 안에서 순서가 뒤바뀐 데이터가 먼저 도착해도 재조립용으로 보관할 수 없고 항상 버린다.', NULL, '네트워크 도착 순서와 애플리케이션 전달 순서가 달라질 때 수신 버퍼가 그 차이를 흡수할 수 있는지 따져보라.', 'X', '정답은 X이며, 수신자는 먼저 도착한 뒤쪽 데이터를 [[수신 측 재조립]]을 위해 보관할 수 있다.\n앞쪽 빈 구간이 채워지면 저장한 바이트를 연결해 원래 순서대로 애플리케이션에 전달한다.\n따라서 패킷이 순서대로 보이지 않는다는 이유만으로 서버가 곧바로 데이터를 잃었다고 판단해서는 안 된다.', '수신자가 1000부터 기다리는 동안 1200부터의 데이터가 먼저 도착하면 이를 임시 저장하고, 나중에 1000부터 1199까지 도착했을 때 연결해 전달할 수 있다.', '수신자는 뒤쪽 데이터를 보관할 수 있으므로 항상 버린다는 표현은 틀리지만, 버퍼 부족이나 구현 정책에 따라 실제로 폐기하는 경우는 있을 수 있다.', 11, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '뒤쪽 데이터가 먼저 도착해 수신 버퍼에 보관되어도 앞쪽 바이트가 누락되어 있다면, 이를 애플리케이션에 즉시 전달하지 않는 이유는 무엇인가?', 1, 1, 'MEDIUM', 'TCP의 [[순서 보장]]을 유지하려면 앞쪽 빈 구간이 채워질 때까지 뒤쪽 데이터의 전달을 기다려야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '뒤쪽 바이트를 먼저 전달하면 수신 애플리케이션이 송신 애플리케이션에서 기록한 순서와 다른 순서로 데이터를 보게 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '순서 보장', '수신 애플리케이션에 바이트를 송신된 순서와 같게 전달하는 TCP의 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '수신 측 재조립', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '순서가 뒤바뀐 데이터', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '순서 있는 전달', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '수신 측 재조립', '서로 다른 순서로 도착한 TCP 데이터를 원래 바이트 순서에 맞게 연결하는 처리');

-- STEP 11 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '수신자는 다음 바이트 1000을 기다리고 있고, seq=1200인 100바이트 B를 먼저 받아 보관했지만 seq=1000인 200바이트 A는 손실되었다. 각 도착 때 ACK를 보낸다면 B 도착 뒤와 A 재전송 도착 뒤의 누적 ACK 번호는?', NULL, 'ACK 번호는 가장 나중에 본 바이트가 아니라 처음 빈 구간 바로 앞까지 연속으로 받은 범위를 기준으로 정한다.', NULL, '정답은 B 도착 뒤 ACK=1000, [[재전송]]된 A 도착 뒤 ACK=1300이다.\n[[누적 ACK]]는 가장 큰 도착 번호가 아니라 처음부터 빈틈없이 받은 범위의 다음 바이트 번호를 나타낸다.\n패킷 캡처에서 ACK가 머물다 크게 진행하는 모습은 누락 구간이 채워져 보관 데이터까지 확인되었음을 진단하는 단서가 된다.', '5000부터 기다리는 수신자가 5200부터 5299까지 먼저 보관하면 ACK는 5000에 머물며, 이후 5000부터 5199까지 도착하면 ACK는 5300으로 진행할 수 있다.', 'B의 번호를 즉시 ACK에 반영하면 연속 수신 범위와 단순히 관찰한 범위를 혼동하게 되며, A가 도착한 뒤 ACK를 1200으로만 진행하면 이미 보관한 B를 빠뜨리게 된다.', 11, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'B 뒤에는 ACK=1000, A 뒤에는 ACK=1300이다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'B 뒤에는 ACK=1200, A 뒤에는 ACK=1300이다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'B 뒤에는 ACK=1300, A 뒤에는 ACK=1300이다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'B 뒤에는 ACK=1000, A 뒤에는 ACK=1200이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 상황에서 수신자가 먼저 도착한 B를 보관하지 않고 버렸다면, A가 도착한 직후의 ACK 번호와 이후 필요한 동작은 무엇인가?', 1, 1, 'HARD', 'A만 도착하면 ACK=1200이고, B가 [[수신 버퍼]]에 없으므로 해당 100바이트가 다시 도착해야 ACK=1300이 된다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'A로 채워지는 연속 범위는 1000부터 1199까지이며, 폐기된 1200부터 1299까지의 데이터는 다시 받아야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '수신 버퍼', '도착한 TCP 데이터를 애플리케이션에 전달하거나 재조립할 때까지 임시로 저장하는 메모리 공간');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '누적 확인 응답', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '손실 데이터 재전송', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '보관 데이터의 누적 확인', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '누적 ACK', '빈틈없이 수신한 범위 전체를 다음에 기대하는 바이트 번호로 확인하는 TCP 응답');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '재전송', '손실되었거나 확인되지 않은 TCP 데이터를 다시 보내는 동작');

-- STEP 11 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '백엔드 서버가 TCP 소켓에서 데이터를 오래 읽지 않아 수신 버퍼가 거의 찼다. 흐름 제어로 나타날 가능성이 가장 큰 현상은?', NULL, '수신자가 남은 버퍼 여유를 알리는 값이 작아질 때 송신자가 사용할 수 있는 새 데이터 전송 범위가 어떻게 달라지는지 생각하라.', NULL, '정답은 수신 버퍼가 차면서 광고되는 [[수신 윈도우]]가 줄고, 송신자가 새 데이터 전송을 늦추거나 멈춘다는 설명이다.\n[[백프레셔]]는 느린 수신 측의 제한이 소켓 버퍼와 윈도우 광고를 거쳐 송신 측으로 전달되는 흐름이다.\n웹 서버의 이벤트 루프나 소비 작업이 정체되면 소켓 읽기 지연이 상류 전송 정체로 이어질 수 있어 장애 진단에 중요하다.', '서버가 요청 본문을 소비하지 않아 수신 버퍼의 빈 공간이 계속 줄면 더 작은 윈도우가 광고되며, 여유가 없어지면 송신자는 새 데이터 전송을 기다리게 된다.', 'ACK를 받고 있다는 사실만으로 새 데이터를 계속 보낼 수 있는 것은 아니며, 송신자는 수신자가 광고한 현재 수용 범위도 지켜야 한다.', 11, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '수신 윈도우가 줄어 송신자가 새 데이터 전송을 늦추거나 멈춘다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '수신 윈도우가 늘어 송신자가 새 데이터 전송을 더 빠르게 계속한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '수신 버퍼와 무관하게 송신자가 같은 양의 새 데이터를 계속 보낸다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '수신자가 읽지 않은 데이터를 비우고 큰 수신 윈도우를 계속 광고한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '서버 애플리케이션이 다시 데이터를 읽어 수신 버퍼에 충분한 여유가 생기면, 수신자는 이 변화를 송신자에게 어떻게 알릴 수 있는가?', 1, 1, 'MEDIUM', '수신자는 더 큰 여유를 담은 [[윈도우 업데이트]]를 보내고, 송신자는 넓어진 범위에서 새 데이터 전송을 재개할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '수신자는 ACK의 Window 필드로 늘어난 수신 가능 범위를 광고하여 송신자가 추가 데이터를 보내도록 허용할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '윈도우 업데이트', '수신자가 달라진 수신 버퍼 여유를 새 수신 윈도우 값으로 송신자에게 알리는 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '수신 버퍼 여유', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '광고 윈도우', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '백프레셔', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '수신 윈도우', '수신자가 현재 받아들일 수 있는 데이터 범위를 송신자에게 광고하는 값');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '백프레셔', '수신 측의 느린 처리나 부족한 버퍼가 송신 측의 전송을 제한하는 흐름');

-- STEP 11 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'TCP 서버는 한 번의 읽기 호출에서 메시지 일부만 받거나 여러 메시지를 함께 받을 수 있다. 수신 코드는 길이 접두사나 구분자를 해석하는 ___을 정의해야 하며, TCP의 전송 추상화는 메시지 단위가 아니라 ___이다.', NULL, '읽기 호출의 반환 경계와 애플리케이션 요청의 논리적 경계가 항상 일치하는지 확인하라.', NULL, '빈칸에는 차례로 [[애플리케이션 프레이밍]]과 [[바이트 스트림]]이 들어간다.\nTCP 읽기는 메시지 하나와 일치하지 않을 수 있으므로 길이 정보나 구분자를 기준으로 버퍼의 바이트를 조립해야 한다.\n이 처리가 없으면 백엔드 서버는 정상적인 부분 읽기나 합쳐 읽기를 잘못된 요청 또는 손상된 데이터로 오인할 수 있다.', '길이 접두사가 본문 길이를 100바이트로 알리면 서버는 읽기 횟수와 관계없이 본문 100바이트가 모일 때까지 버퍼에 누적한 뒤 하나의 메시지로 처리한다.', '한 번의 읽기 호출이 정확히 한 메시지를 반환한다고 가정하면 메시지가 여러 번에 나뉘거나 다음 메시지와 함께 읽힐 때 경계를 잘못 해석한다.', 11, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '애플리케이션 프레이밍');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'application framing');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '메시지 프레이밍');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '프레이밍');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'framing');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '애플리케이션 계층 프레이밍');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'application-layer framing');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'application layer framing');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '바이트 스트림');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'byte stream');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'byte-stream');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TCP 바이트 스트림');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TCP byte stream');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TCP byte-stream');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '길이 접두사에는 본문 길이가 100바이트라고 적혀 있지만 현재 읽기 호출에서 본문 40바이트만 얻었다면 서버는 어떻게 처리해야 하는가?', 1, 1, 'HARD', '[[부분 읽기]]로 받은 40바이트를 보관하고 나머지 데이터가 도착할 때까지 추가로 읽어 정확히 100바이트를 조립해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '현재 확보한 데이터만으로 메시지가 완성되었다고 판단하지 말고, 선언된 본문 길이가 충족될 때까지 버퍼에 누적해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '구현 시 주의점', 'TEXT', '본문 100바이트보다 많은 데이터가 함께 읽혔다면 처음 100바이트만 현재 메시지로 소비하고 나머지는 다음 메시지 해석을 위해 유지한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '부분 읽기', '한 번의 읽기 호출이 애플리케이션이 기다리는 전체 데이터 중 일부만 반환하는 상황');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '애플리케이션 계층 프레이밍', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '길이 기반 프로토콜', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '스트림 파서', 3);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '부분 읽기 처리', 4);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '애플리케이션 프레이밍', '바이트 스트림에서 메시지의 시작과 끝을 구분하도록 애플리케이션 프로토콜이 정한 규칙');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '바이트 스트림', '메시지 경계를 보존하지 않고 순서대로 이어지는 바이트의 흐름');

-- STEP 12. TCP 혼잡 제어와 성능
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (12, 'TCP 혼잡 제어와 성능', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'TCP의 전송 성능은 수신자의 처리 여유와 네트워크 경로의 혼잡 상태에 함께 영향을 받는다. 높은 왕복 지연과 패킷 손실은 서버 CPU와 DB가 정상이어도 재전송과 대기를 늘려 API 응답을 늦출 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '서로 다른 두 제한', '수신 윈도우(rwnd)는 수신 버퍼를 보호하는 흐름 제어 값이고, 혼잡 윈도우(cwnd)는 네트워크 경로의 과부하를 줄이기 위해 송신자가 관리하는 값이다. 송신자는 두 제한을 모두 지켜야 한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '전송량과 타이머의 변화', '슬로 스타트(slow start)는 ACK가 정상적으로 돌아오는 동안 혼잡 윈도우를 빠르게 늘린다. 전송량이 충분히 커진 뒤의 혼잡 회피(congestion avoidance)는 경로를 다시 과부하시키지 않도록 혼잡 윈도우를 더 완만하게 늘리는 과정이다. 손실이 혼잡 신호로 해석되면 전송량을 낮추며, 재전송 타이머가 반복해서 만료되면 다음 재시도까지의 간격도 늘린다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '서버 밖에서 생기는 지연', '서버 처리 시간과 DB 조회 시간이 짧아도 클라이언트까지의 RTT가 높거나 패킷 손실이 많으면 ACK 대기, 재전송, 전송량 감소가 겹쳐 전체 응답 시간이 길어질 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '구현별 차이', '혼잡 윈도우가 증가하거나 감소하는 정확한 폭은 운영체제의 혼잡 제어 알고리즘과 설정에 따라 달라질 수 있다. RTT 측정값도 재전송 타이머의 만료 기준과 같은 값은 아니다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 12 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'TCP의 흐름 제어는 주로 수신자를 보호하고, 혼잡 제어는 주로 네트워크 경로를 보호한다.', NULL, '각 제한이 수신 호스트와 네트워크 경로 중 어느 쪽의 과부하를 막기 위한 것인지 구분해 보라.', 'O', '정답은 O이며, [[흐름 제어]]와 [[혼잡 제어]]는 보호 대상이 다르다.\n전자는 수신 버퍼의 여유를 넘지 않게 하고, 후자는 네트워크에 지나치게 많은 데이터를 보내지 않게 한다.\n백엔드에서는 수신 버퍼가 충분해도 경로가 혼잡하면 API 전송 성능이 낮아질 수 있다.', '클라이언트가 데이터를 받을 여유는 충분하지만 중간 네트워크에서 손실이 발생하면, 서버는 경로 상태에 맞춰 한꺼번에 보내는 양을 줄일 수 있다.', '두 기능을 모두 수신 버퍼 관리로 보면 네트워크 경로의 과부하에 대응하는 송신자 측 제한을 놓친다. 반대로 수신자의 버퍼 여유도 네트워크 혼잡 상태와는 별도로 지켜야 한다.', 12, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '수신 버퍼에 여유가 충분해도 네트워크 손실이 계속되면 처리량이 낮아질 수 있는가?', 1, 1, 'EASY', '그렇다. 이 경우 네트워크 경로의 제약이 [[병목]]이 되어 송신량을 제한할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '수신자가 더 받을 수 있다는 사실은 경로가 더 많은 데이터를 안전하게 전달할 수 있다는 뜻이 아니다. 송신자는 경로에서 관측한 혼잡 신호에도 맞춰 전송량을 조절한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '병목', '여러 제한 가운데 전체 응답 속도나 처리량을 실질적으로 결정하는 가장 큰 제약');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '수신 윈도우', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '혼잡 윈도우', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '전송 제한', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '흐름 제어', '송신량이 수신자의 버퍼 여유를 넘지 않도록 제한하는 기능');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '혼잡 제어', '네트워크 경로가 과부하되지 않도록 송신자가 전송량을 조절하는 기능');

-- STEP 12 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'TCP의 슬로 스타트 기본 모델에서는 혼잡 윈도우가 RTT마다 대체로 선형적으로 증가한다.', NULL, '현재 전송량이 커지면 한 왕복 시간 동안 새 데이터를 확인하는 ACK의 양도 어떻게 달라지는지 생각해 보라.', 'X', '정답은 X이며, [[슬로 스타트]]의 기본 모델은 RTT마다 일정량만 더하는 선형 증가가 아니다.\n새 데이터를 확인하는 ACK가 돌아올수록 혼잡 윈도우가 빠르게 커져 이상적인 조건에서는 대체로 지수형 성장을 보인다.\n백엔드의 큰 응답도 연결 초반에는 전송 가능한 양이 단계적으로 커지면서 처리량이 달라질 수 있다.', '이상적인 모델에서는 한 RTT에 확인되는 데이터가 많아질수록 다음 RTT에 전송할 수 있는 데이터도 빠르게 늘어난다.', 'slow라는 이름은 작은 혼잡 윈도우에서 조심스럽게 시작한다는 의미이지, 윈도우를 항상 천천히 선형 증가시킨다는 의미가 아니다. 선형에 가까운 완만한 증가는 일반적인 혼잡 회피 단계의 설명에 더 가깝다.', 12, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '전송량이 충분히 커진 뒤에는 혼잡 윈도우의 증가 폭을 왜 완만하게 하는가?', 1, 1, 'EASY', '네트워크 경로를 다시 과부하시키지 않도록 전송량을 조심스럽게 늘리는 [[혼잡 회피]] 과정이기 때문이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '전송량이 이미 커진 상태에서 계속 빠르게 늘리면 경로가 감당할 수 있는 수준을 쉽게 넘을 수 있다. 따라서 전송 성공 여부를 살피며 혼잡 윈도우를 더 완만하게 늘린다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '혼잡 회피', '전송량이 충분히 커진 뒤 네트워크 경로를 다시 과부하시키지 않도록 혼잡 윈도우를 비교적 완만하게 늘리는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '지수형 증가', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '혼잡 회피', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '완만한 윈도우 증가', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '슬로 스타트', '작은 혼잡 윈도우에서 시작해 ACK가 돌아오는 동안 전송 가능량을 빠르게 늘리는 TCP 단계');

-- STEP 12 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서버 CPU와 DB 응답 시간은 정상인데, 클라이언트 구간의 RTT와 패킷 손실이 높다. API 응답이 느려진 이유로 가장 적절한 것은?', NULL, '애플리케이션 처리 시간 외에 요청과 응답이 경로를 오가며 기다리는 시간과 손실 복구 비용을 함께 살펴보라.', NULL, '서버 내부 지표가 정상이더라도 높은 [[RTT]]와 패킷 손실은 API 응답을 늦출 수 있다.\nACK가 늦으면 전송 진행이 지연되고, 손실은 재전송과 혼잡 제어에 따른 전송량 감소를 유발할 수 있다.\n장애 진단에서는 CPU와 DB뿐 아니라 구간별 왕복 시간, 손실, 재전송 지표도 함께 확인해야 한다.', '요청 본문은 작더라도 응답 본문이 크면 여러 차례 데이터와 ACK가 오가므로 높은 지연과 반복 손실의 영향이 더 두드러질 수 있다.', 'TCP가 손실된 데이터를 다시 보내 신뢰성을 제공하더라도 복구에는 시간이 필요하다. 또한 높은 왕복 지연은 연결 수립뿐 아니라 연결 후 데이터와 ACK가 오가는 과정에도 영향을 준다.', 12, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'ACK 대기와 재전송이 늘고 TCP 전송량도 줄어 네트워크 구간의 응답 시간이 길어질 수 있다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버 자원이 정상이라면 TCP가 손실을 완전히 숨기므로 전체 응답 시간은 길어질 수 없다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '높은 RTT는 연결 수립에만 영향을 주므로 연결 후의 요청과 응답 시간에는 영향을 주지 않는다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '패킷 손실이 생기면 수신 윈도우가 자동으로 커지므로 전체 응답 시간은 오히려 짧아진다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 네트워크 조건에서도 응답 본문이 클수록 높은 RTT와 손실의 영향을 더 크게 받을 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '여러 번의 데이터 전송과 ACK 진행이 필요해 대기와 재전송이 누적되고 실제 [[처리량]]이 낮아질 수 있기 때문이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '큰 응답은 전송이 완료될 때까지 네트워크를 여러 차례 이용한다. 각 구간의 대기와 손실 복구가 누적되면 서버가 응답을 빠르게 생성했어도 클라이언트의 수신 완료 시점은 늦어진다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '처리량', '일정한 시간 동안 네트워크를 통해 실제로 전달되는 데이터의 양');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '네트워크 지연', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '패킷 재전송', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '응답 처리량', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'RTT', '데이터를 보낸 뒤 그 데이터에 대한 ACK를 받기까지 관측되는 왕복 시간');

-- STEP 12 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'TCP 송신자가 혼잡 신호로 취급하는 패킷 손실을 감지했다. 일반적인 전송량 조절로 가장 적절한 것은?', NULL, '손실이 경로 과부하의 신호일 때 현재와 같은 양을 계속 보내는 행동이 상황을 완화하는지 생각해 보라.', NULL, '송신자는 보통 [[혼잡 윈도우]]를 줄여 한꺼번에 보내는 데이터 양을 낮춘다.\n손실을 경로 과부하 가능성의 신호로 보고 전송을 완화한 뒤, ACK 흐름에 따라 전송량을 다시 늘린다.\n백엔드 장애에서는 재전송뿐 아니라 이 전송량 감소도 응답 지연과 처리량 저하의 원인이 된다.', '큰 JSON 응답을 보내는 중 손실이 반복되면 손실된 데이터의 재전송뿐 아니라 이후 데이터를 보내는 속도도 낮아져 응답 완료가 늦어질 수 있다.', '손실을 만회하려고 즉시 더 많은 데이터를 보내면 혼잡한 경로에 부담을 더할 수 있다. 수신자가 알리는 버퍼 여유도 송신자의 네트워크 혼잡 대응을 대신하지 않는다.', 12, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '한꺼번에 보내는 양을 줄이고, ACK가 안정적으로 돌아오면 전송량을 다시 늘려 간다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '손실된 양을 만회하도록 한꺼번에 보내는 양을 즉시 늘리고 그대로 유지한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '수신자가 알린 버퍼 여유를 송신자가 강제로 키워 손실 구간을 빠르게 통과한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '신뢰적 재전송이 있으므로 한꺼번에 보내는 양을 바꾸지 않고 그대로 유지한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '손실 뒤 혼잡 윈도우가 줄어드는 정확한 폭을 모든 서버에서 같은 값으로 예상해도 되는가?', 1, 1, 'MEDIUM', '아니며, [[혼잡 제어 알고리즘]]과 운영체제의 구현 및 설정에 따라 감소 방식이 달라질 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '손실 뒤 전송량을 낮춘다는 큰 원리는 공통적이지만 구체적인 계산과 회복 과정은 구현마다 다를 수 있다. 장애 분석에서는 서버가 실제로 사용하는 설정과 네트워크 지표를 확인해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '혼잡 제어 알고리즘', '네트워크 신호에 따라 송신량을 늘리거나 줄이는 구체적인 규칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '손실 기반 혼잡 신호', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '전송량 감소', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '손실 복구', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '혼잡 윈도우', '송신자가 네트워크 혼잡 상태를 고려해 한꺼번에 전송할 데이터 양을 제한하는 값');

-- STEP 12 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'TCP는 측정한 RTT와 변동성을 반영해 재전송 타이머의 기준인 ___을(를) 계산한다. 타임아웃이 연속되면 대기 간격을 배수로 늘리는 ___을(를) 적용한다.', NULL, '첫째는 ACK를 얼마나 기다릴지 정하는 기준이고, 둘째는 실패가 거듭될 때 다음 시도 시점을 조절하는 정책이다.', NULL, '첫 빈칸은 [[RTO]], 둘째는 [[지수 백오프]]다.\n전자는 평활된 RTT와 그 변동성을 바탕으로 ACK 대기 한계를 정하고, 후자는 타이머가 연속으로 만료될 때 그 한계를 늘린다.\n백엔드에서는 지연 급증이 곧 서버 처리 실패를 뜻하지 않으므로 재전송과 타이머 지표를 함께 확인해야 한다.', '경로 지연이 일시적으로 커졌을 때 짧은 고정 간격으로 계속 재전송하면 불필요한 트래픽이 늘어 기존 혼잡을 악화할 수 있다.', '최근에 측정한 왕복 시간 하나를 그대로 타이머 만료 기준으로 사용하면 경로 지연의 변동성을 충분히 반영하지 못한다. 타임아웃이 반복될 때도 대기 간격을 고정하면 문제가 지속되는 경로에 재전송을 지나치게 자주 보낼 수 있다.', 12, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'RTO');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'RTO 값');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재전송 타임아웃');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재전송 타임아웃 값');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재전송 시간 초과');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'Retransmission Timeout');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'Retransmission Timeout Value');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '지수 백오프');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '지수적 백오프');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'exponential backoff');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'exponential-backoff');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'exponential back-off');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '재전송 타이머가 실제 경로 지연보다 지나치게 짧으면 서버 통신에서 어떤 현상이 생길 수 있는가?', 1, 1, 'HARD', 'ACK가 정상적으로 오는 중에도 타이머가 먼저 만료되어 [[불필요한 재전송]]이 발생하고 트래픽과 지연이 늘 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '경로 지연이 일시적으로 증가했을 뿐 데이터가 손실되지 않았는데도 송신자가 다시 데이터를 보낼 수 있다. 이런 동작이 반복되면 네트워크에 추가 부하를 만들 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '불필요한 재전송', '원래 데이터나 ACK가 정상적으로 전달되고 있는데도 타이머 판단 때문에 같은 데이터를 다시 보내는 현상');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '평활 RTT', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'RTT 변동성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '재전송 타이머', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'RTO', 'ACK가 제때 오지 않았다고 판단해 재전송을 시작하는 타이머의 만료 기준');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '지수 백오프', '연속 타임아웃이 발생할 때 다음 재전송까지의 대기 시간을 배수로 늘리는 정책');

-- STEP 13. DNS 이름 해석
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (13, 'DNS 이름 해석', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, '재귀 리졸버는 계층적으로 구성된 DNS 서버를 조회해 도메인 이름에 필요한 레코드를 찾고, 응답을 정해진 시간 동안 캐시한다. 백엔드 개발자는 주요 레코드의 역할과 부정 응답, UDP·TCP 조회 경로를 이해해야 이름 해석 장애를 구분할 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '계층적 이름 해석', 'DNS 이름 공간은 루트에서 최상위 도메인과 하위 도메인으로 이어진다. 각 영역의 권한 DNS 서버가 담당 데이터를 제공하며, 재귀 리졸버는 캐시와 상위 서버의 안내를 이용해 필요한 서버를 찾아간다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '서비스별 DNS 레코드', 'A와 AAAA는 이름을 각각 IPv4와 IPv6 주소에 연결하고, CNAME은 다른 DNS 이름을 별칭 대상으로 지정한다. MX는 메일을 받을 서버와 우선순위를 나타내며, NS는 영역을 담당하는 권한 DNS 서버를 지정한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '캐시와 전송 경로', 'NXDOMAIN처럼 이름이 없다는 응답도 권한 응답의 SOA 정보를 바탕으로 일정 시간 캐시될 수 있다. 일반적인 DNS 조회에는 UDP와 TCP가 모두 사용되며, UDP 응답에 TC라는 잘림 표시가 있으면 리졸버가 TCP로 다시 조회할 수 있다. SERVFAIL은 이름이 없다는 뜻이 아니라 해석을 완료하지 못했다는 뜻이다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 13 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '루트 DNS 서버는 모든 호스트의 IP 주소를 직접 보관하지 않고, 일반적으로 최상위 도메인을 담당하는 DNS 서버를 안내한다.', NULL, '한 서버가 모든 최종 주소를 관리하는 구조인지, 관리 범위를 여러 계층에 나누는 구조인지 생각해 보세요.', 'O', '이 설명은 맞다. [[루트 DNS 서버]]는 모든 호스트의 최종 주소를 보관하는 대신 일반적으로 최상위 도메인의 [[권한 DNS 서버]]로 가는 정보를 제공한다.\nDNS 데이터는 여러 영역에 나뉘며, 상위 영역은 하위 영역을 조회할 수 있도록 다음 서버를 안내한다.\n특정 도메인만 조회되지 않는다면 애플리케이션보다 해당 도메인의 위임 경로와 담당 서버 상태를 먼저 점검할 수 있다.', '`www.example.com`을 처음 조회하면 루트 서버에서 `.com` 담당 서버로, 이어서 `example.com` 담당 서버로 조회가 진행될 수 있다.', '루트 서버를 전 세계 호스트 주소가 모인 중앙 데이터베이스로 이해하면 안 된다. DNS 데이터는 담당 영역에 따라 여러 서버에 분산되어 있다.', 13, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '다른 도메인은 정상인데 특정 도메인만 계속 조회되지 않는다면 DNS 계층에서 무엇을 확인해야 하는가?', 1, 1, 'MEDIUM', '해당 도메인의 [[위임]] 정보가 올바른지와 지정된 [[권한 DNS 서버]]가 응답하는지를 확인한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '상위 영역이 잘못된 서버를 안내하거나 담당 서버가 응답하지 않으면 다른 도메인이 정상이어도 해당 도메인만 조회에 실패할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '위임', '상위 DNS 영역이 하위 영역을 담당할 서버를 지정하는 구성');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '권한 DNS 서버', '특정 DNS 영역의 데이터에 근거해 권한 있는 응답을 제공하는 서버');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '루트 영역', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '최상위 도메인', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DNS 위임', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '루트 DNS 서버', 'DNS 계층의 시작점인 루트 영역에 대해 권한 있는 응답을 제공하는 서버');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '권한 DNS 서버', '담당 DNS 영역의 데이터에 근거해 권한 있는 응답을 제공하는 서버');

-- STEP 13 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'DNS 이름 해석은 항상 UDP만 사용하므로, 방화벽에서 TCP 53번 포트를 막아도 조회 결과에는 영향이 없다.', NULL, '응답이 한 번에 전달되지 못하는 경우 다른 전송 경로로 다시 조회할 수 있는지 생각해 보세요.', 'X', '이 설명은 틀리다. DNS는 [[UDP]]뿐 아니라 [[TCP]]도 사용할 수 있다.\n일반적인 조회는 UDP로 시작하는 경우가 많지만, 응답이 잘렸다는 표시가 오면 TCP로 다시 조회할 수 있다.\n따라서 TCP 53번 포트가 차단되면 간단한 조회는 성공해도 일부 조회는 실패할 수 있다.', '같은 DNS 서버에서 짧은 응답은 정상적으로 오지만 일부 응답만 시간 초과된다면 UDP와 TCP의 53번 포트 경로를 각각 확인할 수 있다.', 'DNS를 UDP 전용 프로토콜로 이해하면 TCP 전환이 필요한 조회만 실패하는 현상을 애플리케이션 오류로 오인할 수 있다.', 13, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'DNS 진단 결과에서 UDP 응답에 TC라는 잘림 표시가 확인되었다. 리졸버가 다음에 취할 수 있는 동작은 무엇인가?', 1, 1, 'MEDIUM', '[[잘림 표시]]를 확인한 리졸버는 전체 응답을 받기 위해 같은 질문을 [[TCP 재조회]]로 보낼 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'UDP 응답에 TC 비트가 설정되면 응답의 일부가 생략되었을 수 있으므로, TCP 연결을 사용해 완전한 응답을 다시 요청할 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '잘림 표시', 'DNS 응답 헤더의 TC 비트로, 응답이 전송 과정에서 잘렸음을 나타내는 표시');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'TCP 재조회', '잘린 UDP 응답 대신 전체 응답을 받기 위해 TCP로 같은 DNS 질문을 다시 보내는 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DNS의 TCP 사용', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '응답 잘림', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '부분적 조회 실패', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'UDP', '연결 설정 없이 데이터그램을 보내며 일반적인 DNS 조회에 널리 사용되는 전송 프로토콜');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TCP', '연결 기반의 바이트 스트림을 제공하며 DNS 조회에도 사용되는 전송 프로토콜');

-- STEP 13 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '`api.example.com`의 접속 주소를 확인할 때 A·AAAA·CNAME 레코드의 역할을 올바르게 설명한 것은 무엇인가?', NULL, '각 레코드의 값이 숫자 주소인지 다른 도메인 이름인지 구분하고, 숫자 주소라면 주소 체계의 버전을 살펴보세요.', NULL, '[[A 레코드]]는 IPv4 주소, [[AAAA 레코드]]는 IPv6 주소를 저장하며, [[CNAME 레코드]]는 다른 DNS 이름을 별칭 대상으로 지정한다.\n이와 별도로 [[MX 레코드]]는 메일을 받을 서버와 우선순위를, [[NS 레코드]]는 영역을 담당하는 권한 DNS 서버를 나타낸다.\nAPI 연결 문제를 진단할 때는 주소 레코드와 별칭 대상이 의도한 서비스로 이어지는지 확인해야 한다.', '`api.example.com`이 다른 서비스 이름의 별칭이라면 그 대상 이름을 따라간 뒤 대상의 A 또는 AAAA 레코드에서 접속 주소를 얻을 수 있다.', 'A와 AAAA의 주소 체계를 바꾸거나 CNAME이 IP 주소를 직접 저장한다고 이해하면 API 도메인의 조회 결과를 올바르게 해석할 수 없다.', 13, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 IPv4 주소, AAAA는 IPv6 주소를 저장하고, CNAME은 다른 DNS 이름을 별칭 대상으로 지정한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 IPv6 주소, AAAA는 IPv4 주소를 저장하고, CNAME은 다른 DNS 이름을 별칭 대상으로 지정한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 IPv4 주소, AAAA는 IPv6 주소를 저장하고, CNAME은 IPv4 주소를 직접 저장한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A는 IPv4 주소를 저장하고, AAAA는 다른 DNS 이름을 별칭 대상으로 지정하며, CNAME은 IPv6 주소를 저장한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '`api.example.com`의 CNAME이 다른 이름을 가리킬 때 최종 IP 주소는 어떻게 찾는가?', 1, 1, 'MEDIUM', '리졸버는 [[CNAME 연쇄]]를 따라가고, 필요한 경우 [[별칭 대상]]의 A 또는 AAAA 레코드를 조회한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '대상 이름의 주소가 캐시에 있거나 같은 응답에 포함되어 있다면 추가 네트워크 질의 없이 최종 주소를 얻을 수도 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'CNAME 연쇄', 'CNAME의 대상이 다시 다른 CNAME을 가리켜 별칭 관계가 이어지는 구조');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '별칭 대상', 'CNAME 레코드가 가리키는 실제 DNS 이름');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '정식 이름', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '메일 서버 우선순위', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DNS 자원 레코드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'A 레코드', 'DNS 이름을 IPv4 주소에 연결하는 레코드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'AAAA 레코드', 'DNS 이름을 IPv6 주소에 연결하는 레코드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'CNAME 레코드', '한 DNS 이름이 다른 DNS 이름의 별칭임을 나타내는 레코드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'MX 레코드', '도메인의 이메일을 받을 메일 서버와 우선순위를 지정하는 레코드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'NS 레코드', 'DNS 영역을 담당하는 권한 DNS 서버를 지정하는 레코드');

-- STEP 13 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '재귀 DNS 리졸버가 성공한 A 응답과 NXDOMAIN 응답을 캐시에 저장했다. 이후 동작을 올바르게 설명한 것은 무엇인가?', NULL, '권한 서버의 데이터가 변경된 시점과 리졸버가 기존 응답을 재사용할 수 있는 시간이 다를 수 있음을 생각해 보세요.', NULL, '[[성공 응답 캐시]]와 [[부정 응답 캐시]]는 각각 정해진 유효 시간 동안 재사용될 수 있다.\n[[NXDOMAIN]]도 캐시될 수 있으며, 권한 서버의 변경이 기존 캐시를 즉시 지우지는 않으므로 [[TTL]]과 부정 응답의 남은 캐시 시간을 확인해야 한다.\n따라서 새 레코드를 추가한 뒤에도 일부 백엔드 서버에서는 이전의 이름 해석 실패가 잠시 이어질 수 있다.', '존재하지 않던 `api.example.com`을 새로 등록해도 이전 NXDOMAIN 응답이 남은 리졸버에서는 일정 시간 같은 실패가 반복될 수 있다.', '성공 응답만 캐시되는 것은 아니며, 권한 서버의 레코드 변경이 여러 리졸버에 저장된 기존 부정 응답을 즉시 삭제하지도 않는다.', 13, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A 응답은 TTL 동안 재사용되지만 NXDOMAIN은 캐시되지 않으므로, 레코드를 추가하면 다음 조회부터 바로 성공한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A 응답과 NXDOMAIN은 캐시될 수 있지만, 권한 서버에 레코드를 추가하면 모든 리졸버의 기존 캐시가 즉시 삭제된다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A 응답은 레코드의 TTL 동안, NXDOMAIN은 부정 응답에 정해진 캐시 시간 동안 재사용될 수 있으므로 레코드를 추가해도 일부 조회가 계속 실패할 수 있다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'A 응답과 NXDOMAIN은 브라우저에만 저장되므로, 백엔드가 사용하는 리졸버의 캐시는 조회 결과에 영향을 주지 않는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'DNS 조회 로그에서 NXDOMAIN과 SERVFAIL을 구분해야 하는 이유는 무엇인가?', 1, 1, 'MEDIUM', '[[NXDOMAIN]]은 조회한 이름이 없다는 결과이고, [[SERVFAIL]]은 서버가 이름 해석을 완료하지 못한 결과이므로 점검 대상과 재시도 판단이 달라진다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '이름이 없다는 결과라면 철자와 레코드 등록 상태 및 부정 캐시를 확인하고, 해석 실패라면 리졸버와 권한 서버의 응답 경로 및 구성을 점검한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'NXDOMAIN', '조회한 DNS 이름 자체가 존재하지 않음을 나타내는 결과');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'SERVFAIL', 'DNS 서버가 오류 때문에 요청한 이름 해석을 완료하지 못했음을 나타내는 결과');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캐시 유효 시간', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DNS 변경 반영', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캐시 차이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '성공 응답 캐시', '존재하는 DNS 데이터에 대한 성공 응답을 저장한 캐시로, positive cache라고도 한다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '부정 응답 캐시', '이름이나 요청한 레코드가 없다는 응답을 저장한 캐시로, negative cache라고도 한다.');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'NXDOMAIN', '조회한 DNS 이름 자체가 존재하지 않음을 나타내는 결과');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TTL', 'DNS 레코드를 캐시에서 유효한 것으로 재사용할 수 있는 시간을 나타내는 값');

-- STEP 13 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '호스트는 로컬 DNS 리졸버에 `www.example.com`의 최종 답을 요청한다. 캐시가 없을 때 로컬 리졸버가 루트, 최상위 도메인, 권한 서버의 안내를 따라 직접 질의한다면, 첫 요청 방식은 ___이고 로컬 리졸버의 조회 방식은 ___이다.', NULL, '최종 결과를 만들어 달라고 맡기는 요청과 다음 서버를 직접 선택하며 조회를 이어 가는 절차를 구분하세요.', NULL, '첫 빈칸은 [[재귀 질의]], 둘째 빈칸은 [[반복 질의]]이다.\n호스트는 로컬 리졸버에 완성된 결과를 요청하고, 로컬 리졸버는 캐시가 없으면 상위 서버의 안내를 따라 다음 서버를 찾아간다.\n백엔드에서는 애플리케이션이 어느 리졸버를 사용하는지 알아야 캐시 차이와 조회 실패 지점을 올바르게 진단할 수 있다.', '애플리케이션은 사내 리졸버에 최종 주소를 요청하고, 사내 리졸버는 필요한 경우 여러 DNS 서버에 차례로 질의해 결과를 만든다.', '두 용어는 DNS 서버의 계층을 구분하는 이름이 아니다. 최종 결과를 만들 책임을 맡기는 요청과 안내받은 다음 서버를 직접 찾아가는 절차를 구분해야 한다.', 13, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀 질의');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀적 질의');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'recursive query');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀적');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'recursive');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'recursion');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀 해석');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀적 해석');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'recursive resolution');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '재귀 조회');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복 질의');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복적 질의');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'iterative query');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복적');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'iterative');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'iteration');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복 해석');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복적 해석');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'iterative resolution');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '반복 조회');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '개발 PC와 운영 서버에서 같은 도메인의 조회 결과가 다르다면 먼저 무엇을 비교해야 하는가?', 1, 1, 'MEDIUM', '각 환경이 사용하는 [[재귀 리졸버]]의 주소와 응답의 [[캐시 상태]]를 비교한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '운영체제나 컨테이너의 DNS 설정을 확인하고, 같은 리졸버에 직접 질의한 결과와 남은 유효 시간을 비교하면 차이가 생긴 지점을 좁힐 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '재귀 리졸버', '클라이언트를 대신해 캐시와 DNS 계층을 이용하여 최종 응답을 구하는 서버');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '캐시 상태', '리졸버가 이전 응답을 보유하고 있는지와 그 응답의 유효 시간이 남았는지를 나타내는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '클라이언트 DNS 기능', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캐시에 답이 없는 상태', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서버 안내 응답', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '재귀 질의', '질의를 받은 DNS 서버에 최종 응답이나 오류를 만들어 달라고 요청하는 방식');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '반복 질의', '질의자가 서버의 안내를 바탕으로 다음 DNS 서버를 선택해 조회를 이어 가는 방식');

-- STEP 14. HTTP 의미와 캐시
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (14, 'HTTP 의미와 캐시', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'HTTP는 요청 메서드로 의도를 나타내고, 상태 코드와 헤더로 처리 결과와 표현의 조건을 전달한다. 백엔드에서는 재시도의 효과, 응답 형식, 연결 재사용, 캐시 재사용 조건을 구분해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '요청 의미와 재시도', '안전성은 클라이언트가 상태 변경을 요청하는지에 관한 성질이고, 멱등성은 동일한 요청을 반복했을 때 의도된 서버 효과가 누적되는지에 관한 성질이다. 재시도 가능성을 판단할 때는 응답의 모양보다 서버에 남는 의도된 효과를 살펴본다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', '처리 결과와 응답 표현', '서버는 상태 코드로 요청 처리 결과의 범주를 알리고, 헤더로 응답을 해석하거나 후속 요청을 만드는 데 필요한 메타데이터를 전달한다. 같은 리소스도 요청 조건에 따라 HTML이나 JSON처럼 서로 다른 형식으로 표현될 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '저장 응답의 재사용 흐름', '캐시는 저장된 응답의 현재 경과 시간이 신선도 수명보다 짧을 때 서버에 묻지 않고 재사용할 수 있다. 더는 신선하지 않으면 저장한 검증 값을 조건부 요청에 보내 변경 여부를 확인할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '전송과 저장을 함께 보지 않기', '장애를 진단할 때는 연결 상태와 응답별 캐시 메타데이터를 각각 확인한다. Cache-Control의 no-cache는 보통 저장을 금지하는 뜻이 아니라 재사용 전 검증을 요구하며, no-store는 저장을 막는 지시다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 14 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '같은 DELETE 요청을 여러 번 보내면 응답 코드는 달라질 수 있지만, 의도된 서버 효과는 한 번 보냈을 때와 같으므로 DELETE는 멱등하다.', NULL, '응답의 모양이 아니라 요청을 반복한 뒤 서버에 남는 의도된 효과가 첫 요청 뒤와 달라지는지 살펴보세요.', 'O', '[[DELETE]]는 같은 요청을 여러 번 적용해도 URI와 대상 리소스의 연결을 제거한다는 의도된 효과가 한 번 적용한 것과 같아 멱등하다.\n[[안전성]]은 상태 변경을 요청하는지 보고, [[멱등성]]은 동일 요청을 반복했을 때 의도된 서버 효과가 누적되는지 본다.\n따라서 재시도 가능성을 판단할 때는 응답 코드가 같은지보다 서버에 남는 의도된 효과를 확인해야 한다.', '첫 삭제에서는 204를 받고 같은 URI에 다시 요청했을 때는 404를 받을 수 있지만, 두 요청 모두 URI와 대상 리소스의 연결이 제거된 상태를 목표로 한다.', '응답 코드가 달라질 수 있다는 이유만으로 멱등하지 않다고 판단하면 안 된다. 멱등성은 매번 같은 응답을 받는지가 아니라 동일 요청을 반복했을 때 의도된 서버 효과가 달라지는지를 따진다.', 14, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'PUT으로 같은 내용을 여러 번 보내도 일반적으로 멱등하다고 보는 이유는 무엇인가?', 1, 1, 'MEDIUM', '[[PUT]]은 같은 내용을 [[대상 리소스]]에 반복 적용해도 의도된 최종 상태가 같기 때문이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'PUT은 지정한 리소스의 상태를 요청 내용으로 생성하거나 대체한다. 동일한 내용을 반복해서 적용해도 의도된 최종 상태는 한 번 적용했을 때와 같다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '흔한 오해', 'TEXT', '첫 요청에서 리소스가 생성되고 다음 요청에서 기존 리소스가 대체되면 상태 코드는 서로 다를 수 있지만, 이것만으로 멱등성이 깨지지는 않는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'PUT', '요청 내용을 사용해 지정한 리소스의 상태를 생성하거나 대체하는 HTTP 메서드');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '대상 리소스', '요청 URI가 가리키며 HTTP 메서드의 동작이 적용되는 리소스');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'HTTP 메서드의 성질', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '장애 후 재시도', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'PUT과 DELETE의 멱등성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DELETE', '대상 URI와 리소스의 현재 연결을 제거하도록 요청하는 HTTP 메서드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '안전성', '클라이언트가 서버 상태 변경을 요청하거나 기대하지 않는 메서드의 성질');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '멱등성', '동일한 요청을 여러 번 적용해도 의도된 효과가 한 번 적용한 것과 같은 성질');

-- STEP 14 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'HTTP 지속 연결은 여러 요청과 응답에 같은 네트워크 연결을 재사용하는 기능이다. 이 기능만으로 응답이 캐시에 저장되거나 계속 신선하다고 볼 수는 없다.', NULL, '네트워크 연결을 다시 쓰는 조건과 저장된 응답을 다시 쓰는 조건이 같은 규칙으로 결정되는지 구분하세요.', 'O', '[[지속 연결]]은 연결을 재사용할 뿐, 응답의 저장 가능 여부나 신선도를 결정하지 않는다.\n연결 재사용 여부와 캐시 재사용 여부는 서로 다른 규칙으로 관리된다.\n백엔드 장애를 분석할 때 연결 문제와 오래된 응답 문제를 분리하면 원인을 좁히기 쉽다.', '한 연결로 문서와 이미지 요청을 연이어 보내더라도 문서 응답은 저장하지 않고 이미지 응답은 일정 시간 저장하도록 각각 설정할 수 있다.', '연결이 유지된다는 사실을 응답도 계속 유효하다는 뜻으로 해석하면 전송과 캐시를 혼동하게 된다. 연결은 메시지를 운반하고, 캐시는 응답별 메타데이터를 바탕으로 저장과 재사용을 판단한다.', 14, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 지속 연결로 받은 /profile과 /logo.png 응답에 서로 다른 캐시 정책을 적용할 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '캐시 정책은 연결이 아니라 각 응답의 [[Cache-Control]] 같은 메타데이터를 기준으로 판단하기 때문이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '서버는 응답마다 저장 가능 여부와 재사용 조건을 다르게 지정할 수 있다. 같은 연결을 통해 전달되었다는 사실은 이러한 응답별 정책을 하나로 묶지 않는다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '실무 사용처', 'TEXT', '개인화된 프로필과 자주 바뀌지 않는 정적 이미지는 같은 서버에서 전달되더라도 서로 다른 캐시 정책이 필요할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'Cache-Control', '캐시가 HTTP 응답을 저장하거나 재사용할 조건을 전달하는 헤더');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '연결 재사용', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '응답별 캐시 정책', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캐시 장애 진단', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '지속 연결', '하나의 네트워크 연결을 여러 HTTP 요청과 응답에 재사용하는 방식');

-- STEP 14 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '클라이언트가 POST /articles로 게시물 생성을 요청했고, 서버가 즉시 /articles/123을 만들었다. 가장 적절한 응답은 무엇인가?', NULL, '생성 작업의 완료 여부와 새 리소스의 주소를 상태 코드와 응답 헤더가 각각 어떻게 전달하는지 확인하세요.', NULL, '생성이 끝났다면 [[POST]] 응답으로 [[201 Created]]를 보내고, [[Location]] 헤더에 새 리소스의 URI를 알리는 것이 적절하다.\n상태 코드는 처리 결과를 나타내고 응답 헤더는 그 결과를 설명하는 메타데이터를 전달한다.\n클라이언트는 생성 응답의 위치 정보를 사용해 새 리소스를 조회하거나 후속 요청을 만들 수 있다.', '게시물 생성에 성공한 서버는 201 상태와 Location: /articles/123을 함께 보내 새 게시물의 위치를 알릴 수 있다.', 'POST가 항상 200을 반환해야 하는 것은 아니며, 202는 요청을 수락했지만 처리가 완료되지 않았을 수 있음을 나타낸다. 또한 204 응답에는 생성된 리소스의 표현을 본문으로 넣을 수 없다.', 14, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '201 Created를 반환하고 Location 헤더에 /articles/123을 넣는다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '200 OK를 반환하고 성공한 POST에는 Location 헤더를 쓰지 않는다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '202 Accepted를 반환하고 게시물 생성이 완료되었다고 본다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '204 No Content를 반환하고 생성된 게시물 표현을 본문에 넣는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '기존 리소스를 PUT으로 수정한 뒤, 결과를 본문으로 보내는 경우와 보내지 않는 경우 상태 코드를 어떻게 선택할 수 있는가?', 1, 1, 'MEDIUM', '[[응답 콘텐츠]]가 있으면 200 OK를, 없으면 [[204 No Content]]를 사용할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '기존 리소스의 수정을 성공적으로 마쳤다면 서버는 처리 결과를 본문으로 보낼 때 200을 사용할 수 있다. 보낼 본문이 없다면 204로 성공을 알릴 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '주의할 점', 'TEXT', 'PUT으로 대상 리소스를 새로 생성했다면 기존 리소스를 수정한 상황과 달리 201을 사용해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '응답 콘텐츠', 'HTTP 응답 본문으로 클라이언트에 전달되는 표현이나 처리 결과');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '204 No Content', '요청 처리는 성공했지만 응답에 전달할 콘텐츠가 없음을 나타내는 상태 코드');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '리소스 생성 응답', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '생성된 리소스의 위치', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '성공 상태 코드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'POST', '대상 리소스가 정한 방식으로 요청 콘텐츠를 처리하도록 요구하는 HTTP 메서드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '201 Created', '요청이 성공하여 하나 이상의 새 리소스가 생성되었음을 나타내는 상태 코드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'Location', '응답과 관련된 리소스의 URI 참조를 전달하는 헤더');

-- STEP 14 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서버가 같은 /report URI에서 요청의 Accept 헤더에 따라 HTML 또는 JSON을 보낸다. 공유 캐시까지 고려할 때 가장 정확한 설명은 무엇인가?', NULL, '클라이언트가 원하는 형식, 서버가 실제로 보낸 형식, 캐시가 저장 응답을 구분하는 기준의 역할을 나누어 보세요.', NULL, '서버가 JSON을 선택했다면 [[Content-Type]]으로 실제 형식을 알리고, 선택이 [[Accept]]에 따라 달라지면 [[Vary]]에 그 요청 헤더를 지정한다.\n[[콘텐츠 협상]]은 같은 리소스의 여러 [[표현]] 중 요청 조건에 맞는 형식을 고르는 과정이다.\n공유 캐시가 형식 선택 조건을 구분하지 않으면 기대와 다른 형식이 전달될 수 있다.', 'Accept: text/html 요청에는 HTML을, Accept: application/json 요청에는 JSON을 보내고 각 응답에 실제 미디어 유형과 Vary: Accept를 표시할 수 있다.', 'Accept와 Content-Type의 역할을 바꾸거나 같은 URI에는 한 형식만 있다고 가정하면 콘텐츠 협상을 올바르게 처리할 수 없다. 응답의 실제 형식만 표시해서는 공유 캐시가 형식 선택에 사용된 요청 조건을 자동으로 구분하지 못한다.', 14, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'JSON 응답에는 Content-Type: application/json을 쓰고, 선택이 Accept에 따라 달라지면 Vary: Accept를 함께 보낸다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'JSON 응답에는 Accept: application/json을 쓰고, 클라이언트의 선호 형식은 Content-Type으로 받는다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'URI가 같으면 표현도 하나라고 보고, 캐시는 Accept와 무관하게 저장된 응답을 재사용한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '응답에 Content-Type만 있으면 공유 캐시는 Accept가 다른 요청을 자동으로 구분하므로 Vary는 필요 없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'JSON을 요청했는데 HTML 응답을 받았다면 요청 Accept, 응답 Content-Type, Vary를 어떻게 대조해 원인을 좁힐 수 있는가?', 1, 1, 'HARD', '요청의 [[Accept]], 응답의 [[Content-Type]], 캐시 변형 기준을 알리는 [[Vary]]를 대조해 서버의 형식 선택 문제인지 캐시의 변형 재사용 문제인지 좁힌다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '먼저 요청이 JSON을 요구했는지와 응답이 실제로 HTML이라고 표시했는지 확인한다. 그다음 서버가 형식 선택에 사용한 요청 헤더를 응답에 알렸는지 살펴본다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '장애 진단', 'TEXT', '원본 서버의 응답부터 형식이 다르면 서버의 콘텐츠 협상 설정을 확인한다. 원본 응답은 올바르지만 공유 캐시를 거친 응답만 다르면 캐시 로그와 변형 구분 설정을 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'Accept', '클라이언트가 응답으로 받을 수 있거나 선호하는 미디어 유형을 전달하는 요청 헤더');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'Content-Type', 'HTTP 메시지에 실제로 담긴 콘텐츠의 미디어 유형을 나타내는 헤더');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'Vary', '저장된 응답을 다시 선택할 때 대조해야 할 요청 헤더를 캐시에 알려 주는 응답 헤더');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '응답 미디어 유형', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'Accept와 Content-Type', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '공유 캐시의 응답 변형', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'Content-Type', 'HTTP 메시지에 실제로 담긴 콘텐츠의 미디어 유형을 나타내는 헤더');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'Accept', '클라이언트가 응답으로 받을 수 있거나 선호하는 미디어 유형을 전달하는 요청 헤더');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'Vary', '응답 선택에 영향을 준 요청 헤더를 캐시에 알려 주는 응답 헤더');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '콘텐츠 협상', '요청 조건과 서버 능력을 바탕으로 보낼 응답 형식을 선택하는 과정');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '표현', '리소스의 상태를 HTML이나 JSON 같은 특정 형식의 데이터로 나타낸 것');

-- STEP 14 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '공유 캐시에 저장된 GET 응답은 현재 경과 시간이 신선도 수명보다 짧으면 ___ 상태이다. 경과 시간이 신선도 수명 이상이 된 뒤 저장된 ETag로 재검증할 때 요청 헤더는 ___이고, 표현이 바뀌지 않았다면 서버는 ___을 반환할 수 있다.', NULL, '저장된 응답을 바로 쓰는 단계와 서버에 변경 여부를 확인하는 단계를 시간 순서대로 연결하세요.', NULL, '빈칸은 차례대로 신선한, [[If-None-Match]], [[304 Not Modified]]이다.\n저장 응답의 현재 경과 시간이 [[신선도 수명]] 이상이면 더는 신선하지 않으며, 캐시는 [[ETag]]를 사용한 [[조건부 검증]]으로 변경 여부를 확인할 수 있다.\n304 응답에는 전체 표현 본문이 없으며, 캐시는 저장된 본문과 응답에서 갱신한 메타데이터를 사용한다.', '캐시가 ETag 값 "v7"을 저장했다면 If-None-Match: "v7"을 보내고, 서버의 현재 값이 같을 때 304 응답을 받은 뒤 저장된 본문을 계속 사용할 수 있다.', '저장된 응답이 더는 신선하지 않다고 항상 전체 본문을 다시 받아야 하는 것은 아니다. 캐시는 저장한 검증 값을 조건부 요청에 사용하고, 서버는 표현이 바뀌지 않았다면 본문을 다시 보내지 않을 수 있다.', 14, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '신선한');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '신선');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'fresh');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'If-None-Match');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'If-None-Match 헤더');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 3, '304 Not Modified');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 3, '304');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 3, '304 상태 코드');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 3, 'HTTP 304');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 3, 'HTTP 304 Not Modified');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '조건부 GET에서 저장된 ETag와 현재 표현의 ETag가 달라 서버 표현이 변경된 경우, 서버의 응답과 캐시 처리는 어떻게 이어지는가?', 1, 1, 'MEDIUM', '서버는 새 ETag와 본문을 포함한 [[200 OK]] 응답을 보내고, 캐시는 응답 정책에 따라 [[캐시 갱신]]을 수행한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '검증 값이 일치하지 않으면 서버는 변경된 표현의 전체 본문과 새 ETag를 200 상태 응답으로 보낸다. 캐시는 이 응답을 저장할 수 있는 경우 기존 항목을 새 응답으로 갱신한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '주의할 점', 'TEXT', '200 상태 응답을 받았다고 항상 저장되는 것은 아니다. 저장하거나 기존 항목을 바꿀 수 있는지는 새 응답의 캐시 정책에 따라 결정된다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '200 OK', '조건부 GET에서 저장된 ETag와 현재 ETag가 달라 변경된 표현의 본문을 반환할 때 사용할 수 있는 성공 상태 코드');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '캐시 갱신', '새 응답을 저장할 수 있을 때 기존 캐시 항목의 본문과 메타데이터를 새 값으로 바꾸는 처리');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '캐시 신선도', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '응답 버전 검증', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '조건부 GET', 3);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '304 응답', 4);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '신선도 수명', '저장된 응답을 서버 확인 없이 신선하다고 볼 수 있는 기간');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'ETag', '선택된 표현을 구분하기 위해 서버가 제공하며 캐시 재검증에 사용할 수 있는 값');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '조건부 검증', '저장된 검증 값을 요청 조건으로 보내 현재 표현의 변경 여부를 확인하는 절차');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'If-None-Match', '저장한 ETag 값을 보내 현재 표현과 일치하지 않을 때만 일반 응답을 요청하는 헤더');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '304 Not Modified', '조건부 GET 또는 HEAD에서 선택된 표현이 변경되지 않았음을 알리는 상태 코드');

-- STEP 15. TLS와 HTTP 전송 버전
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (15, 'TLS와 HTTP 전송 버전', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'HTTPS는 HTTP 통신 전에 TLS로 서버를 확인하고 데이터를 보호한다. HTTP 버전에 따라 TCP와 TLS를 사용하는 방식 또는 QUIC에 보안 기능이 통합되는 방식으로 전송 구조가 달라진다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', 'HTTPS 연결의 보호', 'TLS는 서버 인증서 검증을 통해 접속 상대를 확인하고, 전송 데이터의 기밀성과 무결성을 보호한다. 일반적인 웹 서비스의 사용자 로그인은 TLS의 서버 인증과 별도로 처리된다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '인증서 오류의 위치', '인증서가 만료되었거나 접속한 호스트 이름과 맞지 않거나 신뢰할 수 있는 발급 경로가 없으면 TLS 연결 단계에서 실패할 수 있다. 이때 HTTP 요청은 컨트롤러 같은 서버 애플리케이션 코드까지 도달하지 않는다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', 'HTTP 버전별 전송 구조', 'HTTPS의 HTTP/1.1과 HTTP/2는 일반적으로 TCP 위에서 TLS를 사용한다. HTTP/3는 UDP 위의 QUIC을 사용하며, TLS 1.3 핸드셰이크가 QUIC 안에 통합되어 있다. 따라서 TCP 위의 HTTPS처럼 별도의 TLS 레코드 계층을 사용하지 않는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', 'UDP와 보안의 구분', 'HTTP/3가 UDP를 사용한다고 해서 암호화나 신뢰성 있는 스트림이 없는 것은 아니다. QUIC이 데이터 보호와 스트림 전송을 담당하므로 장애 진단에서는 TCP 연결만 확인해서는 충분하지 않다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 15 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '일반적인 HTTPS는 서버의 신원을 확인하고 통신을 보호하지만, 클라이언트 인증서까지 항상 요구하지는 않는다.', NULL, '웹 서버의 신원을 확인하는 절차와 서비스 사용자의 계정을 확인하는 절차가 같은지 구분해 보세요.', 'O', '이 문장은 맞다.\n일반적인 HTTPS는 [[인증된 암호화]]로 데이터를 보호하고 서버 인증서를 검증하지만, 클라이언트 인증서는 보통 필수가 아니다.\n따라서 백엔드는 로그인·세션·토큰 같은 사용자 인증을 별도로 구현하며, 양쪽의 인증서가 필요할 때 [[상호 TLS 인증]]을 구성한다.', '브라우저는 API 서버의 인증서를 확인한 뒤 연결하지만, 사용자는 그 연결 안에서 비밀번호나 토큰을 보내 별도로 로그인할 수 있다.', 'TLS가 클라이언트 인증서를 지원한다는 사실이 모든 HTTPS 연결에서 이를 요구한다는 뜻은 아니다. 일반적인 웹 환경에서는 서버 인증이 기본이고 사용자 인증은 애플리케이션에서 별도로 수행된다.', 15, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '클라이언트 인증서를 사용하지 않는 웹 API는 요청한 사용자를 어떻게 확인할 수 있는가?', 1, 1, 'EASY', '로그인 정보, 세션 쿠키, 접근 토큰을 검증하는 [[애플리케이션 인증]]으로 사용자를 확인할 수 있다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'TLS 연결이 보호된 통신 경로를 만들면, 서버는 그 경로로 받은 자격 증명이나 토큰을 검사해 사용자 계정을 식별한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '애플리케이션 인증', '웹 애플리케이션이 로그인 정보나 토큰을 검사해 사용자를 확인하는 절차');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서버 인증', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '상호 TLS 인증', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '사용자 인증', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '인증된 암호화', '데이터를 숨기면서 전송 중 변조 여부도 확인할 수 있게 하는 암호화 방식');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '상호 TLS 인증', '서버와 클라이언트가 TLS 인증서를 사용해 서로의 신원을 확인하는 구성');

-- STEP 15 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'HTTP/3는 UDP를 사용하므로 서버 인증이나 전송 데이터 암호화를 제공하지 않는다.', NULL, '기반 전송 프로토콜의 종류와 그 위에서 제공되는 보안 기능의 유무를 따로 확인해 보세요.', 'X', '이 문장은 틀리며, HTTP/3도 서버를 인증하고 전송 데이터를 보호한다.\nHTTP/3는 UDP 위의 [[QUIC]]에 [[TLS 1.3]] 절차를 통합해 보호에 필요한 키를 설정한다.\n따라서 장애 진단에서는 UDP 사용만 보고 보안이 없다고 판단하지 말고 QUIC 연결과 인증서 상태를 함께 확인해야 한다.', '브라우저가 HTTP/3로 API를 호출하면 HTTP 데이터는 암호학적으로 보호된 QUIC 패킷으로 전송된다.', 'UDP 자체가 연결이나 암호화를 제공하지 않는 것과 HTTP/3 전체에 보안이 없는 것은 다른 주장이다. HTTP/3에서는 QUIC이 TLS의 인증 및 키 설정 기능을 이용해 데이터를 보호한다.', 15, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '같은 서버에서 HTTP/2는 연결되지만 HTTP/3만 실패한다면 네트워크 경로에서 무엇을 확인해야 하는가?', 1, 1, 'MEDIUM', '방화벽이나 네트워크 장비가 서버의 [[QUIC용 UDP 포트]]를 허용하는지 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'HTTP/2의 TCP 연결이 성공해도 HTTP/3가 사용하는 UDP 경로는 별도로 차단될 수 있으므로 두 경로를 나누어 점검해야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'QUIC용 UDP 포트', 'HTTP/3 연결을 받기 위해 서버가 UDP 통신을 허용해야 하는 포트다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'QUIC 패킷 보호', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'UDP 경로 점검', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'HTTP/3 연결', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'QUIC', 'UDP 위에서 스트림 전송, 연결 관리, 혼잡 제어와 보안 기능을 제공하는 전송 프로토콜');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TLS 1.3', 'HTTP/3의 QUIC 연결에서 상대 인증과 보호용 키 설정에 사용되는 TLS 버전');

-- STEP 15 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '브라우저가 HTTPS API의 인증서에서 만료, 호스트 이름 불일치 또는 신뢰 경로 문제를 발견했다. 일반적으로 어떤 일이 일어나는가?', NULL, '이 오류가 HTTP 메시지를 처리하는 단계보다 앞에서 발견되는지 확인해 보세요.', NULL, '첫 번째 선택지가 맞으며, TLS 연결이 중단되어 HTTP 요청은 서버 애플리케이션에 도달하지 않는다.\n브라우저의 [[인증서 검증]]은 유효 기간과 호스트 이름을 확인하고, 인증서가 신뢰할 수 있는 [[신뢰 경로]]로 이어지는지 검사한다.\n따라서 컨트롤러 로그가 없다면 애플리케이션 코드뿐 아니라 로드 밸런서나 프록시의 인증서와 TLS 로그도 확인해야 한다.', 'api.example.com에 접속했는데 다른 이름으로 발급된 인증서가 제시되면, 브라우저는 API 요청을 보내기 전에 연결을 중단할 수 있다.', '인증서 검증은 HTTP 상태 코드를 만드는 애플리케이션 처리보다 먼저 수행된다. 검증에 실패한 요청을 컨트롤러가 받아 401이나 500 응답으로 바꾸는 것이 아니다.', 15, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'TLS 연결이 중단되어 HTTP 요청은 서버 애플리케이션에 도달하지 않는다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTP 요청이 컨트롤러에 도달한 뒤 애플리케이션이 401 응답을 만든다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '브라우저가 인증서 검증을 생략하고 같은 요청을 평문 HTTP로 다시 보낸다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '운영체제가 인증서를 자동으로 교체한 뒤 같은 요청을 애플리케이션에 전달한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '외부 HTTPS 접속은 인증서 오류로 실패하지만 서버 내부의 애플리케이션 호출은 성공한다면 어디를 먼저 점검해야 하는가?', 1, 1, 'MEDIUM', '외부 연결의 [[TLS 종료 지점]]인 로드 밸런서나 리버스 프록시의 인증서 설정을 먼저 점검한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '외부 연결에서 제시되는 인증서는 애플리케이션 서버가 아니라 앞단 장비가 관리할 수 있으므로 실제로 인증서를 제공하는 구성 요소를 찾아야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'TLS 종료 지점', 'TLS 연결을 받아 인증서를 제시하고 암호화된 통신을 해제하는 서버나 네트워크 구성 요소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '인증서 만료', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '호스트 이름 검증', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'TLS 장애 진단', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '인증서 검증', '인증서의 유효 기간, 접속 이름, 서명과 신뢰 관계를 확인하는 절차');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '신뢰 경로', '서버 인증서에서 클라이언트가 신뢰하는 인증 기관까지 이어지는 검증 가능한 인증서 관계');

-- STEP 15 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '웹 브라우저와 HTTPS 서버 사이에서 HTTP/1.1, HTTP/2, HTTP/3의 일반적인 전송 구조를 올바르게 비교한 것은 무엇인가?', NULL, '각 버전 아래에서 연결, 신뢰성 있는 전송과 보안을 맡는 프로토콜 조합을 비교해 보세요.', NULL, '첫 번째 선택지가 맞으며, HTTP/1.1과 HTTP/2는 보통 TCP 위에서 TLS를 사용하고 HTTP/3는 UDP 위의 QUIC을 사용한다.\nHTTP/3에서는 [[QUIC]]이 신뢰성 있는 스트림과 보호된 전송을 제공한다.\n프록시가 있으면 클라이언트 쪽과 백엔드 쪽은 별도의 [[연결 구간]]이므로 서로 다른 HTTP 버전을 사용할 수 있다.', '예를 들어 브라우저와 프록시는 HTTP/3를 사용하고, 프록시와 백엔드는 양쪽이 지원하는 HTTP/2를 사용할 수 있다.', 'HTTP/3는 UDP를 기반으로 하지만 보안과 신뢰성 있는 스트림을 제공한다. 또한 프록시 앞뒤의 연결이 같은 HTTP 버전을 사용해야 하는 것은 아니다.', 15, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTP/1.1과 HTTP/2는 보통 TCP 위에 TLS를 사용하고, HTTP/3는 UDP 위에 QUIC을 사용한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTP/1.1과 HTTP/2는 UDP 위에 QUIC을 사용하고, HTTP/3는 TCP 위에 TLS를 사용한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTP/1.1부터 HTTP/3까지 모두 TCP 위에 같은 방식으로 TLS를 사용한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'HTTP/1.1부터 HTTP/3까지 모두 UDP를 직접 사용하며 보안은 애플리케이션이 처리한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '클라이언트와 리버스 프록시 사이의 HTTP 버전이 프록시와 백엔드 사이의 버전과 달라도 되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '두 구간은 서로 다른 연결이며, 각 연결에서 양쪽이 함께 지원하는 [[HTTP 버전 선택]]이 따로 이루어질 수 있기 때문이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '리버스 프록시는 클라이언트와의 연결을 끝낸 뒤 백엔드와 별도의 연결을 만들므로, 두 연결이 같은 HTTP 버전을 사용할 필요는 없다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'HTTP 버전 선택', '연결 양쪽이 모두 지원하는 버전 중 실제 통신에 사용할 HTTP 버전을 정하는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'HTTP 버전 선택', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '프록시 연결 구간', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'QUIC 전송', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'QUIC', 'HTTP/3가 UDP 위에서 신뢰성 있는 스트림과 통합 보안을 제공하기 위해 사용하는 전송 프로토콜');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '연결 구간', '클라이언트와 프록시 또는 프록시와 백엔드처럼 두 통신 지점 사이에 따로 만들어지는 연결');

-- STEP 15 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '서버 이름과 공개키의 관계를 검증하는 데 쓰이는 전자 문서는 ___이고, 연결을 시작할 때 상대를 확인하고 보호용 키를 정하는 메시지 교환은 ___이다.', NULL, '접속 전에 준비해 두는 신원 자료와 접속할 때마다 수행되는 초기 절차가 맡는 역할을 비교해 보세요.', NULL, '첫 번째 빈칸은 [[인증서]], 두 번째 빈칸은 [[TLS 핸드셰이크]]이다.\n앞의 자료는 서버 이름과 공개키의 관계를 검증하게 하고, 뒤의 절차는 연결을 시작하며 상대 확인과 키 설정을 수행한다.\n따라서 인증서 오류는 연결 초기에 진단하고, 일반적인 최초 HTTPS 연결에서는 초기 절차가 성공한 뒤 HTTP 통신을 정상적으로 진행해야 한다.', '브라우저는 서버가 제시한 신원 자료를 확인하고 연결 초기의 메시지 교환을 마친 뒤 보호된 채널로 API 요청을 전송한다.', '서버의 신원 정보를 담은 자료와 연결할 때마다 실행되는 메시지 교환은 역할이 다르다. 전자가 연결 절차를 직접 수행하거나 후자가 서버의 비밀키를 클라이언트에 전달하는 것은 아니다.', 15, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '인증서');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'certificate');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '서버 인증서');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'TLS 인증서');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'TLS certificate');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'server certificate');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'X.509 인증서');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'X.509 certificate');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '디지털 인증서');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'digital certificate');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '공개키 인증서');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '핸드셰이크');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'handshake');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS 핸드셰이크');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS handshake');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS 1.3 핸드셰이크');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS 1.3 handshake');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '보호된 연결은 성공했지만 API가 HTTP 500 응답을 반환한다면 어느 부분을 먼저 조사해야 하는가?', 1, 1, 'HARD', '[[HTTP 5xx]] 응답은 HTTP 처리가 시작된 뒤 발생한 오류이므로 애플리케이션 로그와 서버 코드를 먼저 조사해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'HTTP 상태 응답을 받았다는 것은 연결 초기 단계가 완료되어 요청이 HTTP 처리 영역에 들어갔음을 뜻하므로, 우선 애플리케이션의 예외와 의존 서비스 상태를 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, 'HTTP 5xx', '요청을 받은 서버가 처리 과정에서 실패했음을 나타내는 HTTP 상태 코드 범위다.');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '서버 인증서', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'TLS 연결 설정', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '애플리케이션 오류 구분', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '인증서', '서버의 신원 정보와 공개키의 관계를 검증할 수 있도록 서명된 전자 문서');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TLS 핸드셰이크', 'TLS 연결을 시작하면서 상대를 확인하고 데이터 보호에 사용할 키를 설정하는 메시지 교환');

-- STEP 16. URL 입력부터 응답까지
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (16, 'URL 입력부터 응답까지', 3, @network_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@network_quiz_step_id, 'URL을 입력하면 기존 네트워크 설정을 바탕으로 DNS 해석, 경로와 다음 전달 대상 결정, 연결 수립, HTTP 요청·응답이 이어진다. 각 단계는 독립적으로 실패하거나 기존 상태를 재사용해 생략될 수 있으므로 장애가 발생한 위치를 구분하는 것이 중요하다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CONCEPT', 'URL에서 HTTP 응답까지', '브라우저는 URL의 호스트 이름을 DNS로 해석한 뒤 서버 IP가 같은 네트워크에 있는지, 게이트웨이를 거쳐야 하는지 판단한다. 필요한 링크 계층 주소를 확인하고 TCP와 TLS 또는 QUIC 연결을 준비한 다음 HTTP 요청을 보내 응답을 받는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'EXAMPLE', '오류로 구분하는 실패 위치', '이름을 해석하지 못하면 DNS 단계를 확인하고, 연결 시간 초과나 거부가 발생하면 서버 경로와 포트를 확인한다. 인증서 오류는 TLS 검증 단계의 문제이며, HTTP 5xx는 서버나 중간 프록시가 HTTP 오류 응답을 보낸 상황이다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@network_briefing_id, 'CAUTION', '생략될 수 있는 준비 단계', '유효한 DHCP 구성은 URL마다 다시 받을 필요가 없다. DNS 결과나 열린 연결을 재사용할 수 있으며, 열린 연결이 없다면 이전 TLS 상태를 이용해 새 보안 연결의 수립 비용을 줄일 수도 있다. 또한 저장된 HTTP 응답이 아직 유효하고 요청 조건이 맞으면 원본 서버와 새로 통신하지 않고 그 응답을 쓸 수 있으며, 이는 DNS 결과·열린 연결·이전 TLS 상태를 재사용하는 것과 다르다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 16 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '브라우저는 유효한 DNS 결과와 재사용 가능한 연결이 있어도 HTTPS URL을 열 때마다 DNS 조회와 새 연결 수립을 반드시 다시 수행한다.', NULL, '이전 요청에서 얻은 이름 해석 결과와 아직 사용할 수 있는 연결의 수명을 확인하세요.', 'X', '이 문장은 틀렸으며, 유효한 [[DNS 캐시]]와 [[연결 재사용]] 조건이 충족되면 두 절차를 생략할 수 있다.\n브라우저는 단계별 상태를 독립적으로 확인해 아직 쓸 수 있는 결과나 연결만 다시 사용한다.\n백엔드 지연을 분석할 때는 DNS 시간과 연결 시간을 분리해야 실제 병목을 좁힐 수 있다.', NULL, 'URL을 입력할 때마다 모든 준비 절차가 반복된다고 보면 캐시와 열린 연결이 지연 시간을 줄이는 실제 동작을 설명할 수 없다.', 16, 1, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, 'DNS 조회 시간은 거의 0인데 첫 응답이 느리다면, 다음으로 어떤 구간을 나누어 확인해야 하는가?', 1, 1, 'MEDIUM', 'TCP·TLS 연결 시간과 요청을 보낸 뒤의 [[첫 바이트 도착 시간]]을 나누어 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '이름 해석이 빨라도 새 연결 수립, 서버의 요청 처리, 응답 전송에서 지연될 수 있다. 구간별 시간 측정은 연결 문제와 백엔드 처리 지연을 구분하는 데 도움이 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '첫 바이트 도착 시간', '요청 후 응답의 첫 바이트를 받을 때까지의 시간으로, 서버 처리와 네트워크 지연이 함께 반영될 수 있는 지표');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '단계별 상태 재사용', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'DNS 시간과 연결 시간 분리', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DNS 캐시', '이전에 얻은 이름 해석 결과를 유효 기간 동안 저장해 다시 사용하는 기능');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '연결 재사용', '이미 수립되어 사용할 수 있는 연결에 새로운 요청을 보내는 방식');

-- STEP 16 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '호스트에 유효한 DHCP 임대가 남아 있다면, URL을 입력할 때마다 DHCP 절차를 다시 수행하지 않고 기존 IP 주소와 게이트웨이 설정을 사용할 수 있다.', NULL, '호스트의 네트워크 설정이 유지되는 기간과 개별 웹 요청의 처리 기간을 비교하세요.', 'O', '이 문장은 맞으며, 유효한 [[DHCP 임대]]가 있다면 URL마다 네트워크 설정을 다시 받을 필요가 없다.\nDHCP로 받은 IP 주소, prefix, 게이트웨이, DNS 서버 주소는 임대 조건 안에서 여러 통신에 계속 사용된다.\n접속 장애를 진단할 때는 웹 요청보다 먼저 임대 만료 여부와 호스트의 기본 네트워크 설정을 확인해야 한다.', NULL, 'DHCP는 브라우저 요청마다 실행되는 절차가 아니라 호스트가 네트워크에서 사용할 주소와 관련 설정을 일정 기간 제공받는 절차다.', 16, 2, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '유효한 임대가 있는데 도메인 접속이 안 된다면, 호스트에서 먼저 어떤 설정을 확인해야 하는가?', 1, 1, 'EASY', 'IP 주소와 prefix, [[기본 게이트웨이]], DNS 서버 주소가 의도한 네트워크의 값인지 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '임대가 유효하다는 사실만으로 설정값이 현재 네트워크에 적합하거나 DNS 서버와 게이트웨이가 정상이라고 보장되지는 않는다. 이름 해석과 서버 연결을 진단하기 전에 기본 구성을 확인한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '기본 게이트웨이', '호스트가 다른 네트워크로 패킷을 보낼 때 일반적으로 사용하는 첫 번째 라우터');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '네트워크 구성의 수명', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '웹 요청과 호스트 구성의 구분', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'DHCP 임대', 'DHCP 서버가 클라이언트에 네트워크 설정을 일정 기간 사용하도록 허용한 상태');

-- STEP 16 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'DNS 해석은 끝났고 서버는 다른 네트워크에 있으며, 게이트웨이의 MAC 주소 정보와 기존 연결은 없다. TCP와 TLS를 사용하는 HTTPS 요청의 일반적인 순서로 가장 적절한 것은?', NULL, '원격 서버로 가는 첫 프레임의 수신 대상과 상위 프로토콜이 의존하는 순서를 확인하세요.', NULL, '서버 IP로 경로와 [[다음 홉]]을 정하고 게이트웨이의 MAC 주소를 확인한 뒤 TCP, TLS, HTTP 순으로 진행하는 것이 적절하다.\n서버가 다른 네트워크에 있으면 첫 Ethernet 프레임은 원격 서버가 아니라 게이트웨이로 전달된다.\n백엔드 연결 장애에서는 게이트웨이 도달 여부, TCP 포트, TLS를 순서대로 확인하면 실패 구간을 빠르게 좁힐 수 있다.', NULL, '다른 네트워크에 있는 서버의 MAC 주소를 호스트가 직접 확인하지는 않는다. TCP 기반 HTTPS에서는 TCP 연결 후 TLS를 수립하며, 그 연결이 준비된 뒤 HTTP를 교환한다.', 16, 3, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버 IP로 경로를 정한다 → 원격 서버의 MAC 주소를 확인한다 → TCP 연결을 맺는다 → TLS를 수립한다 → HTTP를 교환한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버 IP로 경로를 정한다 → 게이트웨이의 MAC 주소를 확인한다 → TCP 연결을 맺는다 → TLS를 수립한다 → HTTP를 교환한다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버 IP로 경로를 정한다 → 게이트웨이의 MAC 주소를 확인한다 → TLS를 수립한다 → TCP 연결을 맺는다 → HTTP를 교환한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, '서버 IP로 경로를 정한다 → 게이트웨이의 MAC 주소를 확인한다 → HTTP를 교환한다 → TCP 연결을 맺는다 → TLS를 수립한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '게이트웨이의 MAC 주소를 확인하지 못하면 TCP 연결 시도가 시작되지 못하거나 지연되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '호스트가 TCP 연결 시작 패킷을 담은 프레임을 [[기본 게이트웨이]]에 전달할 수 없어 첫 패킷을 로컬 링크 밖으로 보내지 못하기 때문이다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '서버가 다른 네트워크에 있으면 호스트가 보내는 첫 프레임의 링크 계층 수신 대상은 게이트웨이다. 이 프레임을 전달하지 못하면 서버와의 TCP 연결 수립도 진행되지 않는다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '기본 게이트웨이', '로컬 네트워크 밖의 목적지로 패킷을 전달할 때 호스트가 먼저 보내는 라우터');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'URL 요청의 선행 순서', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '원격 서버 연결 경로', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '다음 홉', '목적지로 가는 경로에서 현재 호스트가 패킷을 직접 전달할 다음 네트워크 장치');

-- STEP 16 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'HTTPS 호출에서 DNS 이름 해석 실패, TCP 연결 시간 초과·거부, TLS 인증서 오류, HTTP 5xx가 발생했다. 각 증상과 실패 단계를 올바르게 연결한 것은?', NULL, '클라이언트가 이름 확인, 소켓 연결, 보안 검증, 애플리케이션 응답 중 어디까지 진행했는지 확인하세요.', NULL, 'DNS 실패는 이름 해석, [[연결 시간 초과]]와 [[연결 거부]]는 TCP 연결, 인증서 오류는 TLS 검증, HTTP 5xx는 HTTP 응답 단계에 해당한다.\n앞 단계가 실패하면 뒤 단계까지 진행할 수 없으며, 5xx는 서버나 프록시가 HTTP 오류 응답을 보냈다는 뜻이다.\n백엔드 장애 진단에서는 오류 메시지와 상태 코드를 바탕으로 DNS 설정, 네트워크·포트, 인증서, 서버 로그 순으로 조사 범위를 좁힌다.', NULL, '모든 접속 실패를 서버 애플리케이션 문제로 취급하면 DNS, 네트워크 경로, 포트, 인증서 문제를 놓칠 수 있다. 반대로 HTTP 5xx를 TCP 연결 실패로 분류하면 이미 HTTP 응답을 받았다는 사실과 맞지 않는다.', 16, 4, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'DNS 실패—이름 해석 단계, TCP 시간 초과·거부—TCP 연결 단계, 인증서 오류—TLS 검증 단계, HTTP 5xx—HTTP 응답 단계', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'DNS 실패—HTTP 응답 단계, TCP 시간 초과·거부—HTTP 응답 단계, 인증서 오류—HTTP 응답 단계, HTTP 5xx—HTTP 응답 단계', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'DNS 실패—이름 해석 단계, TCP 시간 초과·거부—HTTP 응답 단계, 인증서 오류—TLS 검증 단계, HTTP 5xx—TCP 연결 단계', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@network_quiz_id, 'DNS 실패—이름 해석 단계, TCP 시간 초과·거부—TCP 연결 단계, 인증서 오류—TLS 검증 단계, HTTP 5xx—TCP 연결 단계', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '클라이언트가 HTTP 500을 받았다면, 백엔드에서 원인을 좁히기 위해 어떤 기록을 먼저 연결해 봐야 하는가?', 1, 1, 'HARD', '발생 시각과 [[요청 ID]]를 기준으로 해당 요청의 애플리케이션 로그, 예외, 외부 서비스 호출 기록을 연결해 본다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', 'HTTP 500은 해당 시도에서 요청과 응답이 HTTP 단계까지 진행되었음을 보여 준다. 실제 원인을 찾으려면 클라이언트의 실패 시각을 서버와 프록시의 관련 로그에 대응시켜야 한다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '요청 ID', '하나의 요청이 여러 서버나 로그를 지날 때 관련 기록을 서로 연결하는 식별값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '단계별 장애 분류', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '오류 증상 기반 진단', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '연결 시간 초과', 'TCP 연결 수립이 정해진 시간 안에 완료되지 않은 상태');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '연결 거부', '대상 호스트나 중간 장비가 TCP 연결 시도를 즉시 받아들이지 않은 상태');

-- STEP 16 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '이미 열려 있고 사용할 수 있는 연결에 새 요청을 보내 새 연결 수립을 생략하는 것은 ___이다. 이전 보안 상태를 활용해 새 TLS 연결의 핸드셰이크 비용을 줄이는 것은 ___이다.', NULL, '열려 있는 통신 경로를 계속 쓰는 경우와 새 경로에서 과거 보안 상태를 활용하는 경우를 구분하세요.', NULL, '첫 번째 빈칸은 [[연결 재사용]]이고 두 번째 빈칸은 [[TLS 세션 재개]]이다.\n앞의 방식은 열린 연결을 그대로 사용하고, 뒤의 방식은 새 연결에서 이전의 보안 상태를 활용한다.\n백엔드에서는 기존 연결의 유지 여부와 보안 연결의 재개 여부를 구분해야 지연과 연결 수 증가의 원인을 정확히 찾을 수 있다.', NULL, '두 방식은 모두 연결 준비 비용을 줄일 수 있지만 같은 동작은 아니다. 이전 연결이 닫혔다면 그 연결을 그대로 쓸 수 없으며, 저장된 TLS 상태가 있을 때도 새 전송 연결은 필요할 수 있다.', 16, 5, @network_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @network_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '연결 재사용');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'connection reuse');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, 'connection re-use');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '기존 연결 재사용');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 1, '커넥션 재사용');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS 세션 재개');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS session resumption');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, '세션 재개');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'session resumption');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS 재개');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@network_quiz_id, 2, 'TLS resumption');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@network_quiz_id, '새 연결 수가 급증했다면 연결 재사용이 제대로 되는지 확인하기 위해 무엇을 살펴봐야 하는가?', 1, 1, 'MEDIUM', '애플리케이션의 [[연결 풀]] 재사용률과 연결 만료·유휴 시간 설정을 확인해야 한다.');
SET @network_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@network_follow_up_id, '해설', 'TEXT', '풀에서 사용할 수 있는 연결이 없거나 연결이 너무 빨리 닫히면 요청마다 새 연결이 만들어질 수 있다. 대상별 연결 수와 생성률도 함께 보면 설정 문제와 실제 트래픽 증가를 구분하는 데 도움이 된다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@network_follow_up_id, '연결 풀', '외부 서버나 데이터베이스에 수립한 연결을 보관하고 여러 요청에서 다시 쓰도록 관리하는 구성 요소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, '연결 생명주기', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@network_quiz_id, 'TLS 핸드셰이크 최적화', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, '연결 재사용', '열려 있는 전송 연결을 닫지 않고 후속 요청에 다시 사용하는 방식');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@network_quiz_id, 'TLS 세션 재개', '이전에 합의한 TLS 상태를 활용해 새 보안 연결의 핸드셰이크 비용을 줄이는 방식');

COMMIT;

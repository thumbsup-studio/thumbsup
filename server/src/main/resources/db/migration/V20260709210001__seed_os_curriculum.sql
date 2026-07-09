-- 운영체제 커리큘럼 12스텝(60문제) — #26 생성 파이프라인으로 만들고 사람이 검수한 콘텐츠.
-- 로컬에서 생성 → 검수 → 이 마이그레이션으로 prod에 반영(팀 결정: 로컬 검수 후 SQL 이관 방식).
-- id는 전부 auto-increment로 새로 채번한다(로컬 id와 무관) — LAST_INSERT_ID()로 자식 테이블을 연결한다.
-- 이 파일은 로컬 DB의 실제 저장값에서 스크립트로 생성했다(수기 전사 아님) — 내용을 임의로 고치지 않는다.


-- ===================== STEP 1: OS 개요와 역할(커널·시스템콜·인터럽트) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (1, 'OS 개요와 역할(커널·시스템콜·인터럽트)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 2: 프로세스 기본 개념(PCB·프로세스 상태 전이) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (2, '프로세스 기본 개념(PCB·프로세스 상태 전이)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 3: 스레드와 멀티스레딩 =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (3, '스레드와 멀티스레딩', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 4: CPU 스케줄링 기초(FCFS·SJF·라운드로빈·우선순위) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (4, 'CPU 스케줄링 기초(FCFS·SJF·라운드로빈·우선순위)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 5: CPU 스케줄링 심화(선점형·비선점형·멀티레벨 큐·기아와 에이징) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (5, 'CPU 스케줄링 심화(선점형·비선점형·멀티레벨 큐·기아와 에이징)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 6: 프로세스 동기화 기초(임계구역·뮤텍스·세마포어) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (6, '프로세스 동기화 기초(임계구역·뮤텍스·세마포어)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 7: 동기화 심화(생산자-소비자 문제·모니터·경쟁 상태) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (7, '동기화 심화(생산자-소비자 문제·모니터·경쟁 상태)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 8: 교착상태(4대 조건·예방·회피·탐지·복구) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (8, '교착상태(4대 조건·예방·회피·탐지·복구)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 9: 메모리 관리 기초(연속 할당·단편화·페이징·세그멘테이션) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (9, '메모리 관리 기초(연속 할당·단편화·페이징·세그멘테이션)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 10: 가상 메모리(페이지 폴트·페이지 교체 알고리즘·스래싱) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (10, '가상 메모리(페이지 폴트·페이지 교체 알고리즘·스래싱)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 11: 파일 시스템(파일 구조·디렉토리·할당 방식) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (11, '파일 시스템(파일 구조·디렉토리·할당 방식)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 12: 입출력과 디스크 관리(버퍼링·스풀링·디스크 스케줄링) =====================
INSERT INTO quiz_step (step_order, topic, created_at, updated_at)
VALUES (12, '입출력과 디스크 관리(버퍼링·스풀링·디스크 스케줄링)', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- Step1 Slot1 (OX) [local id=4]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '운영체제의 커널은 사용자 프로그램과 완전히 분리된 특권 수준에서 실행되며, 하드웨어 자원 관리의 핵심 역할을 담당한다.', NULL, 'O',
        '[[커널]]은 운영체제의 핵심 부분으로, CPU·메모리·장치 같은 자원을 관리한다.\n일반 사용자 프로그램은 보통 [[사용자 모드]]에서 실행되고, 커널은 더 높은 권한의 [[커널 모드]]에서 실행된다.\n따라서 문장은 참이며, 커널이 자원 관리의 중심이라는 설명은 올바르다.', '응용 프로그램이 파일을 읽으려면 직접 디스크를 제어하지 않고 운영체제에 요청한다.\n이때 [[시스템 콜]]을 통해 [[커널]]에 서비스를 요청하고, 커널이 장치 접근을 수행한다.', '이 문장을 틀렸다고 판단했다면, [[커널]]과 일반 응용 프로그램의 실행 권한 차이를 놓친 것이다.\n응용 프로그램은 보통 [[사용자 모드]]에서 실행되어 하드웨어를 직접 제어하지 못하고, 중요한 자원 관리는 [[커널 모드]]의 커널이 담당한다.\n즉 커널은 운영체제의 핵심이며 특권 수준에서 실행된다는 점이 핵심이다.',
        1, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '사용자 모드와 커널 모드의 가장 큰 차이는 무엇인가?', 1, 1),
  (@qid, '응용 프로그램이 하드웨어를 직접 제어하지 않도록 제한하는 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '사용자 모드와 커널 모드', 1),
  (@qid, '자원 보호', 2),
  (@qid, '시스템 콜', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '커널', '운영체제의 핵심 부분으로 하드웨어 자원 관리와 시스템 서비스 제공을 담당한다.'),
  (@qid, '사용자 모드', '응용 프로그램이 제한된 권한으로 실행되는 CPU 실행 모드이다.'),
  (@qid, '커널 모드', '운영체제 커널이 높은 권한으로 실행되는 CPU 실행 모드이다.'),
  (@qid, '시스템 콜', '응용 프로그램이 운영체제 커널의 기능을 요청하는 인터페이스이다.');

-- Step1 Slot2 (OX) [local id=5]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '인터럽트는 항상 소프트웨어가 명시적으로 발생시키는 사건만을 의미하며, 하드웨어 장치는 인터럽트를 발생시킬 수 없다.', NULL, 'X',
        '[[인터럽트]]는 CPU의 현재 흐름을 잠시 멈추고 특정 처리를 하게 만드는 사건이다.\n키보드 입력, 타이머 만료, 디스크 완료처럼 [[하드웨어]] 장치도 인터럽트를 발생시킬 수 있다.\n따라서 인터럽트가 소프트웨어에 의해서만 발생한다는 문장은 거짓이다.', '사용자가 키를 누르면 키보드 컨트롤러가 [[인터럽트]]를 보내고, 운영체제가 입력 처리를 시작할 수 있다.\n또한 프로그램이 예외 상황을 만들거나 트랩을 호출하는 경우에는 [[소프트웨어 인터럽트]]와 유사한 방식으로 제어가 운영체제로 넘어간다.', '이 문장을 참이라고 생각했다면 [[인터럽트]]의 발생 원인을 너무 좁게 이해한 것이다.\n실제로는 키보드, 네트워크 카드, 타이머 같은 [[하드웨어]]가 CPU에 신호를 보내 처리를 요청할 수 있다.\n소프트웨어에 의한 사건도 있지만, 하드웨어 인터럽트는 운영체제 동작에서 매우 기본적이다.',
        1, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '하드웨어 인터럽트와 소프트웨어 인터럽트의 차이는 무엇인가?', 1, 1),
  (@qid, '타이머 인터럽트가 운영체제에서 중요한 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '하드웨어 인터럽트', 1),
  (@qid, '소프트웨어 인터럽트', 2),
  (@qid, '예외 처리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '인터럽트', 'CPU의 현재 실행을 중단하고 미리 정해진 처리 루틴으로 제어를 넘기게 하는 사건이다.'),
  (@qid, '하드웨어', 'CPU, 메모리, 디스크, 키보드처럼 물리적 장치로 구성된 컴퓨터 자원이다.'),
  (@qid, '소프트웨어 인터럽트', '프로그램 실행 중 명령이나 예외에 의해 발생하여 운영체제로 제어가 넘어가는 사건이다.');

-- Step1 Slot3 (MULTIPLE_CHOICE) [local id=6]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 시스템 콜에 대한 설명으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[시스템 콜]]은 응용 프로그램이 운영체제 기능을 요청하는 공식 인터페이스이다.\n파일 입출력, 프로세스 생성, 메모리 할당 같은 작업은 보통 [[커널]]의 도움 없이는 직접 수행할 수 없다.\n따라서 시스템 콜을 단순한 라이브러리 함수나 하드웨어 자체와 동일시하면 안 된다.', '예를 들어 프로그램이 파일을 열 때 C 라이브러리의 함수 호출 뒤에는 실제로 [[시스템 콜]]이 사용될 수 있다.\n이 과정에서 제어가 [[커널]]로 넘어가 파일 디스크립터를 준비하고 결과를 사용자 프로그램에 돌려준다.', '오답을 고른 경우 [[시스템 콜]]과 일반 함수 호출의 차이를 혼동했을 가능성이 크다.\n시스템 콜은 단순한 사용자 공간 계산이 아니라, 보호된 자원에 접근하기 위해 [[커널]]의 서비스를 요청하는 경로이다.\n즉 하드웨어를 직접 다루는 명령 자체도 아니고, 운영체제와 무관한 보통 함수도 아니다.',
        1, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '응용 프로그램이 운영체제 커널의 기능을 요청하기 위한 인터페이스이다.', 1, 1),
  (@qid, 'CPU가 다음에 실행할 명령어 주소를 저장하는 하드웨어 레지스터이다.', 0, 2),
  (@qid, '운영체제 없이도 항상 동일하게 동작하는 단순한 사용자 함수 호출이다.', 0, 3),
  (@qid, '인터럽트를 완전히 대체하여 장치 제어를 없애는 메커니즘이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '라이브러리 함수 호출과 시스템 콜은 어떤 점에서 구분되는가?', 1, 1),
  (@qid, '파일 입출력 작업이 왜 커널의 도움이 필요한가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '사용자 공간과 커널 공간', 1),
  (@qid, '파일 입출력', 2),
  (@qid, '프로세스 관리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '시스템 콜', '응용 프로그램이 운영체제 커널의 기능을 요청하는 인터페이스이다.'),
  (@qid, '커널', '운영체제의 핵심 부분으로 자원 관리와 보호 기능을 수행한다.');

-- Step1 Slot4 (MULTIPLE_CHOICE) [local id=7]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드와 관련해 가장 알맞은 설명을 고르시오.', 'int fd = open("data.txt", O_RDONLY);\nchar buf[16];\nread(fd, buf, sizeof(buf));', NULL,
        '코드의 open과 read는 파일 접근을 요청하며, 실제 자원 처리는 [[커널]]이 수행한다.\n이런 요청은 보통 [[시스템 콜]]을 통해 사용자 프로그램에서 운영체제로 전달된다.\n즉 프로그램이 디스크를 직접 제어하는 것이 아니라 운영체제 서비스를 이용하는 예이다.', '사용자 프로그램은 버퍼 주소와 읽을 길이를 넘기고, [[커널]]은 파일 상태와 권한을 검사한 뒤 데이터를 복사한다.\n이처럼 [[시스템 콜]]은 보호된 자원에 안전하게 접근하도록 중간 경로를 제공한다.', '오답을 선택했다면 코드에 보이는 함수 이름만 보고 단순한 메모리 연산으로 오해했을 수 있다.\n하지만 파일 열기와 읽기는 운영체제 자원 접근이므로 [[시스템 콜]]과 연결되며, 실제 장치 및 파일 상태 관리는 [[커널]]이 담당한다.\n따라서 사용자 프로그램이 디스크를 직접 읽는다고 보면 틀리다.',
        1, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '사용자 프로그램이 디스크 하드웨어를 직접 제어하는 코드이다.', 0, 1),
  (@qid, '파일 입출력을 위해 운영체제 커널의 서비스를 요청하는 예이다.', 1, 2),
  (@qid, '인터럽트 처리 루틴 내부에서만 실행 가능한 코드이다.', 0, 3),
  (@qid, '시스템 콜 없이도 항상 사용자 모드에서만 완료되는 연산이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'open과 read 같은 호출이 왜 커널의 개입을 필요로 하는가?', 1, 1),
  (@qid, '사용자 모드에서 커널 모드로 전환될 때 어떤 보호 이점이 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '파일 디스크립터', 1),
  (@qid, '모드 전환', 2),
  (@qid, '보호 기법', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '커널', '운영체제의 핵심 부분으로 파일 시스템과 장치 같은 자원을 관리한다.'),
  (@qid, '시스템 콜', '응용 프로그램이 운영체제 기능을 요청하기 위해 사용하는 인터페이스이다.');

-- Step1 Slot5 (KEYWORD_BLANK) [local id=8]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '응용 프로그램이 운영체제의 보호된 기능을 사용하기 위해 요청하는 표준 인터페이스를 ___이라고 한다.', NULL, NULL,
        '응용 프로그램은 보호된 자원에 직접 접근하지 않고 [[시스템 콜]]을 통해 운영체제 기능을 요청한다.\n이 과정에서 CPU는 필요하면 [[커널 모드]]로 전환되어 안전하게 작업을 수행한다.\n따라서 빈칸에는 운영체제 서비스 요청 인터페이스인 시스템 콜이 들어가야 한다.', '예를 들어 파일 읽기, 프로세스 생성, 메모리 매핑 같은 작업은 [[시스템 콜]]을 통해 요청된다.\n이때 실제 자원 관리는 [[커널 모드]]에서 실행되는 운영체제가 담당한다.', '빈칸을 다른 용어로 채웠다면, 운영체제 서비스 요청 경로와 실행 주체를 구분하지 못한 것이다.\n[[시스템 콜]]은 응용 프로그램이 운영체제에 기능을 요청하는 인터페이스이고, 실제 처리는 [[커널 모드]]에서 수행된다.\n즉 커널 자체나 인터럽트 일반을 쓰는 것은 문맥상 정확하지 않다.',
        1, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '시스템 콜'),
  (@qid, 1, 'system call');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '시스템 콜이 필요한 대표적인 작업에는 어떤 것들이 있는가?', 1, 1),
  (@qid, '시스템 콜 호출 시 사용자 모드와 커널 모드 사이에는 어떤 변화가 일어나는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '권한 분리', 1),
  (@qid, '운영체제 서비스 인터페이스', 2),
  (@qid, '모드 전환', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '시스템 콜', '응용 프로그램이 운영체제의 보호된 기능을 요청하는 표준 인터페이스이다.'),
  (@qid, '커널 모드', '운영체제가 높은 권한으로 실행되어 보호된 자원에 접근할 수 있는 실행 모드이다.');

-- Step2 Slot1 (OX) [local id=9]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', 'PCB는 운영체제가 각 프로세스의 상태와 관리 정보를 저장하기 위해 사용하는 자료구조이다.', NULL, 'O',
        '[[PCB]]는 운영체제가 프로세스를 관리하기 위해 유지하는 핵심 자료구조이다.\n여기에는 프로세스 상태, 프로그램 카운터, 레지스터 값, 스케줄링 정보 등이 포함될 수 있다.\n따라서 PCB를 통해 운영체제는 여러 프로세스를 구분하고 문맥 전환을 수행한다.', '운영체제가 [[문맥 전환]]을 할 때 현재 실행 중인 프로세스의 레지스터 값과 상태를 PCB에 저장한 뒤, 다음 프로세스의 PCB에서 값을 복원해 실행을 이어간다.', '틀렸다면 [[PCB]]를 단순한 사용자 프로그램 정보로 오해했을 가능성이 크다. PCB는 운영체제가 커널 내부에서 유지하는 프로세스 관리 정보이며, 프로세스 상태 추적과 스케줄링에 직접 사용된다.',
        2, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'PCB에 저장되는 대표적인 정보 두 가지를 말해볼 수 있나요?', 1, 1),
  (@qid, '문맥 전환 시 PCB가 왜 필요한가요?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '문맥 전환', 1),
  (@qid, '프로세스 스케줄링', 2),
  (@qid, '프로세스 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'PCB', 'Process Control Block의 약자로, 운영체제가 각 프로세스를 관리하기 위해 유지하는 자료구조'),
  (@qid, '문맥 전환', 'CPU가 한 프로세스의 실행 상태를 저장하고 다른 프로세스의 실행 상태를 복원하는 작업');

-- Step2 Slot2 (OX) [local id=10]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '프로세스가 Running 상태에 있으면 반드시 CPU를 사용 중이며, I/O 완료를 기다리는 상태일 수는 없다.', NULL, 'O',
        '[[Running]] 상태는 프로세스가 실제로 CPU를 할당받아 명령을 실행 중인 상태이다.\nI/O 완료를 기다리는 프로세스는 보통 Waiting 또는 Blocked 상태에 있다.\n따라서 Running 상태와 I/O 대기 상태를 같은 것으로 보면 안 된다.', '디스크 입력을 요청한 뒤 결과를 기다리는 동안 프로세스는 [[Waiting]] 상태로 이동하고, I/O가 끝난 뒤 Ready 상태를 거쳐 다시 CPU를 받을 수 있다.', '틀렸다면 [[Running]]과 Waiting 상태를 혼동한 것이다. Running은 CPU를 점유한 상태이고, I/O 완료를 기다리는 동안에는 CPU를 사용하지 않으므로 일반적으로 Waiting 상태로 분류된다.',
        2, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'Ready 상태와 Running 상태의 차이는 무엇인가요?', 1, 1),
  (@qid, 'I/O 완료 후 프로세스는 보통 어떤 상태로 이동하나요?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'Ready 상태', 1),
  (@qid, 'Waiting 상태', 2),
  (@qid, '상태 전이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'Running', '프로세스가 CPU를 할당받아 실제로 실행 중인 상태'),
  (@qid, 'Waiting', '이벤트나 I/O 완료를 기다리며 CPU를 사용하지 않는 상태');

-- Step2 Slot3 (MULTIPLE_CHOICE) [local id=11]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 프로세스가 Waiting 상태에서 Ready 상태로 전이되는 가장 적절한 경우는 무엇인가?', NULL, NULL,
        '[[상태 전이]]는 프로세스가 실행 환경 변화에 따라 상태를 바꾸는 과정이다.\nWaiting에서 Ready로의 전이는 대기하던 사건이 완료되어 다시 CPU 할당을 받을 준비가 되었음을 뜻한다.\n대표적으로 I/O 완료가 발생하면 프로세스는 Ready 큐로 돌아간다.', '키보드 입력을 기다리던 프로세스는 입력이 도착하면 [[Ready]] 상태가 되어 스케줄러의 선택을 기다린다.', '틀렸다면 [[상태 전이]]의 원인을 구분하지 못한 것이다. Waiting에서 Ready로 가려면 기다리던 이벤트가 끝나야 하며, 단순히 CPU를 빼앗기거나 새로 생성되는 상황은 다른 전이에 해당한다.',
        2, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, 'I/O 작업이 완료되었다.', 1, 1),
  (@qid, '타임 슬라이스가 만료되었다.', 0, 2),
  (@qid, '프로세스가 새로 생성되었다.', 0, 3),
  (@qid, '프로세스가 종료되었다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '타임 슬라이스 만료 시에는 보통 어떤 상태 전이가 일어나나요?', 1, 1),
  (@qid, '프로세스 생성 직후 처음 들어가는 상태를 어떻게 설명할 수 있나요?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'Ready 큐', 1),
  (@qid, 'I/O 완료 인터럽트', 2),
  (@qid, '선점 스케줄링', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '상태 전이', '프로세스가 New, Ready, Running, Waiting, Terminated 등의 상태 사이를 이동하는 것'),
  (@qid, 'Ready', 'CPU를 제외한 실행 조건이 충족되어 CPU 할당만 기다리는 상태');

-- Step2 Slot4 (MULTIPLE_CHOICE) [local id=12]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 설명에 가장 알맞은 상태 전이를 고르시오.', '// 단일 CPU 환경 가정\n프로세스 P가 현재 CPU에서 실행 중이다.\n타이머 인터럽트가 발생했고,\n운영체제는 P의 실행 정보를 저장한 뒤\n다른 프로세스에게 CPU를 넘긴다.', NULL,
        '[[타이머 인터럽트]]는 운영체제가 일정 시간이 지나면 현재 실행을 중단하고 스케줄링 기회를 갖게 하는 장치이다.\n이 경우 현재 프로세스는 작업이 끝난 것이 아니라 CPU를 잠시 반납하므로 Running에서 Ready로 이동하는 것이 일반적이다.\n이 과정에서 [[선점]]이 일어나며, 저장된 정보는 나중에 다시 복원될 수 있다.', '라운드 로빈 스케줄링에서는 [[타이머 인터럽트]]가 주기적으로 발생해 실행 중인 프로세스를 Ready 큐 뒤로 보내고, 다음 프로세스가 CPU를 사용한다.', '틀렸다면 [[선점]]과 I/O 대기를 혼동했을 수 있다. 타이머 인터럽트는 보통 CPU 사용 시간을 다 쓴 프로세스를 강제로 멈추는 상황이므로 Waiting이 아니라 Ready로 돌아가는 것이 핵심이다.',
        2, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, 'Running → Waiting', 0, 1),
  (@qid, 'Ready → Running', 0, 2),
  (@qid, 'Running → Ready', 1, 3),
  (@qid, 'New → Ready', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '선점형 스케줄링과 비선점형 스케줄링의 차이는 무엇인가요?', 1, 1),
  (@qid, '타이머 인터럽트가 없다면 어떤 문제가 생길 수 있나요?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '라운드 로빈', 1),
  (@qid, '인터럽트', 2),
  (@qid, 'CPU 스케줄러', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '타이머 인터럽트', '일정 시간이 지나면 CPU에 인터럽트를 발생시켜 운영체제가 제어를 회수하게 하는 메커니즘'),
  (@qid, '선점', '운영체제가 실행 중인 프로세스로부터 CPU를 강제로 회수하는 방식');

-- Step2 Slot5 (KEYWORD_BLANK) [local id=13]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '운영체제가 실행 중인 프로세스의 레지스터 값과 프로그램 카운터 등을 저장해 두었다가, 다른 프로세스로 CPU를 넘긴 뒤 다시 복원하는 작업을 ___이라고 한다.', NULL, NULL,
        '[[문맥 전환]]은 현재 프로세스의 실행 문맥을 저장하고 다른 프로세스의 문맥을 복원하는 작업이다.\n이때 저장되는 정보는 보통 PCB를 통해 관리되며, 레지스터와 프로그램 카운터 등이 포함된다.\n프로세스 상태 전이와 스케줄링을 이해하려면 문맥 전환의 역할을 함께 알아야 한다.', '멀티태스킹 환경에서 운영체제는 [[문맥 전환]]을 반복하면서 여러 프로세스가 번갈아 실행되는 것처럼 보이게 한다.', '틀렸다면 [[문맥 전환]]을 단순한 상태 변경과 같게 본 것일 수 있다. 상태 전이는 Ready, Running, Waiting 같은 분류의 이동이고, 문맥 전환은 실제 실행 정보를 저장·복원하는 구체적 작업이다.',
        2, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '문맥 전환'),
  (@qid, 1, 'context switch'),
  (@qid, 1, '컨텍스트 스위치');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '문맥 전환 시 PCB에 저장되는 정보에는 어떤 것들이 있나요?', 1, 1),
  (@qid, '문맥 전환이 너무 자주 일어나면 성능에 어떤 영향이 있나요?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '프로세스 문맥', 1),
  (@qid, 'PCB', 2),
  (@qid, '스케줄러 오버헤드', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '문맥 전환', '현재 프로세스의 실행 상태를 저장하고 다른 프로세스의 실행 상태를 복원하는 작업');

-- Step3 Slot1 (OX) [local id=14]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '스레드는 같은 프로세스 안에서 코드, 데이터, 힙 메모리를 공유할 수 있다.', NULL, 'O',
        '[[스레드]]는 프로세스 내부의 실행 흐름 단위다.\n같은 프로세스의 스레드들은 [[힙]]과 전역 데이터 같은 자원을 공유한다.\n하지만 각 스레드는 자신의 스택과 프로그램 카운터를 별도로 가진다.', '웹 서버에서 요청마다 [[스레드]]를 만들면 공용 [[힙]]에 있는 캐시나 연결 풀을 함께 사용할 수 있다.', '틀렸다면 스레드와 프로세스의 자원 범위를 혼동한 것이다. 같은 프로세스의 [[스레드]]들은 코드, 데이터, [[힙]]을 공유하지만 스택은 공유하지 않는다.',
        3, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '스레드마다 독립적으로 유지되는 대표적인 메모리 영역은 무엇인가?', 1, 1),
  (@qid, '프로세스와 스레드의 자원 공유 범위는 어떻게 다른가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '프로세스', 1),
  (@qid, '스택', 2),
  (@qid, '공유 메모리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '스레드', '프로세스 내부에서 실행되는 작업 흐름의 단위'),
  (@qid, '힙', '동적 메모리 할당에 사용되며 같은 프로세스의 스레드가 공유하는 메모리 영역');

-- Step3 Slot2 (OX) [local id=15]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '멀티스레딩을 사용하면 항상 프로그램의 실행 속도가 빨라진다.', NULL, 'X',
        '[[멀티스레딩]]은 여러 작업을 동시에 다루게 해 주지만 항상 성능 향상을 보장하지는 않는다.\n[[문맥 교환]] 비용, 락 경합, 코어 수 부족 때문에 오히려 느려질 수 있다.\n작업 성격이 병렬화에 적합한지 먼저 판단해야 한다.', '공유 자원에 자주 접근하는 작업은 [[락]] 경쟁이 심해져 [[멀티스레딩]]을 적용해도 처리량이 늘지 않을 수 있다.', '틀렸다면 동시성과 성능 향상을 같은 것으로 본 것이다. [[멀티스레딩]]은 구조적으로 유용하지만 [[문맥 교환]]과 [[락]] 대기 때문에 항상 빠르지는 않다.',
        3, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '멀티스레딩이 오히려 성능을 떨어뜨리는 대표 원인은 무엇인가?', 1, 1),
  (@qid, 'CPU 바운드 작업과 I/O 바운드 작업에서 멀티스레딩 효과는 어떻게 다를 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '동시성', 1),
  (@qid, '병렬성', 2),
  (@qid, '락 경합', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '멀티스레딩', '하나의 프로세스에서 여러 스레드를 사용해 작업을 수행하는 방식'),
  (@qid, '문맥 교환', 'CPU가 실행 대상을 바꿀 때 상태를 저장하고 복원하는 작업'),
  (@qid, '락', '공유 자원에 대한 동시 접근을 제어하기 위한 동기화 수단');

-- Step3 Slot3 (MULTIPLE_CHOICE) [local id=16]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 스레드 동기화가 필요한 상황으로 가장 적절한 것은 무엇인가?', NULL, NULL,
        '여러 [[스레드]]가 같은 데이터를 수정하면 [[경쟁 상태]]가 발생할 수 있다.\n이때 [[동기화]]를 사용해 한 번에 하나의 실행 흐름만 임계 구역에 들어가게 해야 한다.\n읽기만 하는 독립 데이터에는 항상 동기화가 필요한 것은 아니다.', '여러 [[스레드]]가 같은 계좌 잔액을 갱신할 때는 [[동기화]] 없이 처리하면 [[경쟁 상태]]로 값이 틀어질 수 있다.', '틀렸다면 동기화가 필요한 조건을 놓친 것이다. 핵심은 여러 [[스레드]]가 공유 데이터를 동시에 변경하는지 여부이며, 이런 경우 [[경쟁 상태]]를 막기 위한 [[동기화]]가 필요하다.',
        3, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '여러 스레드가 같은 전역 카운터 값을 동시에 증가시키는 경우', 1, 1),
  (@qid, '각 스레드가 서로 다른 지역 변수만 사용하는 경우', 0, 2),
  (@qid, '하나의 스레드만 파일을 읽는 경우', 0, 3),
  (@qid, '프로그램 시작 직후 메인 스레드만 초기화 코드를 실행하는 경우', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '임계 구역이란 무엇이며 왜 보호해야 하는가?', 1, 1),
  (@qid, '뮤텍스와 세마포어는 어떤 차이가 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '임계 구역', 1),
  (@qid, '뮤텍스', 2),
  (@qid, '세마포어', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '경쟁 상태', '여러 실행 흐름의 접근 순서에 따라 결과가 달라지는 오류 상황'),
  (@qid, '동기화', '여러 스레드의 실행 순서를 조정해 공유 자원을 안전하게 다루는 기법'),
  (@qid, '스레드', '프로세스 내부에서 실행되는 작업 흐름의 단위');

-- Step3 Slot4 (MULTIPLE_CHOICE) [local id=17]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드에 대한 설명으로 가장 알맞은 것은 무엇인가?', 'int counter = 0;\n\nvoid work() {\n    for (int i = 0; i < 100000; i++) {\n        counter++;\n    }\n}', NULL,
        '[[counter++]]는 보통 읽기, 증가, 쓰기의 여러 단계로 처리되어 [[원자성]]이 보장되지 않는다.\n여러 [[스레드]]가 동시에 실행하면 [[경쟁 상태]]로 최종 값이 예상보다 작아질 수 있다.\n락이나 원자적 연산으로 보호해야 안전하다.', '여러 [[스레드]]가 공유 카운터를 갱신할 때는 뮤텍스나 atomic 타입을 사용해 [[원자성]]을 확보한다. 그렇지 않으면 [[counter++]]가 겹쳐 실행되어 값이 유실될 수 있다.', '틀렸다면 증가 연산이 한 번의 기계 명령처럼 항상 안전하다고 생각한 것이다. 실제로 [[counter++]]는 [[원자성]]이 없는 경우가 많아서 여러 [[스레드]]가 동시에 실행하면 [[경쟁 상태]]가 생긴다.',
        3, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, 'counter++는 항상 원자적으로 실행되므로 별도 보호가 필요 없다.', 0, 1),
  (@qid, '여러 스레드가 work()를 동시에 실행하면 counter 값이 기대값보다 작아질 수 있다.', 1, 2),
  (@qid, '지역 변수 i를 사용하므로 counter도 자동으로 스레드별로 분리된다.', 0, 3),
  (@qid, '반복문이 있으므로 데드락이 반드시 발생한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '원자적 연산과 뮤텍스 기반 보호는 어떤 상황에서 각각 유리한가?', 1, 1),
  (@qid, '데드락과 경쟁 상태는 어떻게 다른가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '원자적 연산', 1),
  (@qid, '뮤텍스', 2),
  (@qid, '데드락', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'counter++', '공유 카운터를 1 증가시키는 연산으로 동시 실행 시 안전하지 않을 수 있다'),
  (@qid, '원자성', '연산이 중간에 끼어들기 없이 하나의 단위로 수행되는 성질'),
  (@qid, '경쟁 상태', '여러 실행 흐름의 접근 순서에 따라 결과가 달라지는 오류 상황'),
  (@qid, '스레드', '프로세스 내부에서 실행되는 작업 흐름의 단위');

-- Step3 Slot5 (KEYWORD_BLANK) [local id=18]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '여러 스레드가 서로 상대가 가진 락이 해제되기만 기다리며 영원히 진행하지 못하는 상태를 ___라고 한다.', NULL, NULL,
        '서로 자원을 기다리며 진행이 멈추는 현상을 [[데드락]]이라고 한다.\n보통 여러 [[락]]의 획득 순서가 꼬이거나 자원을 순환 대기할 때 발생한다.\n락 순서 통일, 타임아웃, 자원 계층화 같은 방법으로 예방할 수 있다.', '스레드 A가 [[락]] 1을 잡고 락 2를 기다리고, 스레드 B가 락 2를 잡고 락 1을 기다리면 [[데드락]]이 된다.', '틀렸다면 단순한 성능 저하와 영구 대기를 구분하지 못한 것이다. [[데드락]]은 서로가 가진 [[락]]을 기다하느라 어떤 [[스레드]]도 앞으로 진행하지 못하는 상태다.',
        3, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '데드락'),
  (@qid, 1, '교착 상태');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '데드락을 예방하기 위해 락 획득 순서를 통일하는 이유는 무엇인가?', 1, 1),
  (@qid, '기아 상태와 데드락은 어떻게 구분되는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '기아 상태', 1),
  (@qid, '순환 대기', 2),
  (@qid, '락 순서 규칙', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '데드락', '둘 이상의 스레드나 프로세스가 서로 자원을 기다리며 영원히 멈춘 상태'),
  (@qid, '락', '공유 자원에 대한 동시 접근을 제어하기 위한 동기화 수단'),
  (@qid, '스레드', '프로세스 내부에서 실행되는 작업 흐름의 단위');

-- Step4 Slot1 (OX) [local id=19]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', 'FCFS 스케줄링은 먼저 도착한 프로세스가 먼저 CPU를 할당받는 방식이다.', NULL, 'O',
        '[[FCFS]]는 도착 순서대로 CPU를 배정하는 가장 단순한 스케줄링 방식이다.\n먼저 준비 큐에 들어온 작업이 먼저 실행되므로 도착 순서가 핵심 기준이다.\n따라서 문장은 참이며 정답은 O이다.', '운영체제의 [[준비 큐]]에 P1, P2, P3가 이 순서로 들어오면 FCFS에서는 같은 순서로 CPU를 받는다.\n선점이 없으면 앞의 긴 작업이 끝날 때까지 뒤의 작업은 기다린다.\n이 때문에 평균 대기 시간이 커질 수 있다.', '이 문장을 X로 판단했다면 [[FCFS]]의 기준을 다른 알고리즘과 혼동한 것이다. FCFS는 실행 시간이나 우선순위가 아니라 도착 순서를 기준으로 한다. 또한 [[선점]] 방식이 아니므로 이미 실행 중인 작업을 중간에 빼앗지 않는다.',
        4, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'FCFS에서 긴 작업이 앞에 오면 뒤의 짧은 작업들이 오래 기다리는 현상을 무엇이라고 하는가?', 1, 1),
  (@qid, 'FCFS와 라운드로빈의 가장 큰 차이는 선점 가능 여부 측면에서 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '준비 큐', 1),
  (@qid, '선점형 스케줄링', 2),
  (@qid, '비선점형 스케줄링', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'FCFS', 'First-Come, First-Served의 약자로, 먼저 도착한 프로세스가 먼저 실행되는 스케줄링 방식'),
  (@qid, '준비 큐', 'CPU를 할당받기 위해 대기 중인 프로세스들의 대기열'),
  (@qid, '선점', '실행 중인 프로세스의 CPU를 운영체제가 강제로 회수하는 것');

-- Step4 Slot2 (OX) [local id=20]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '라운드로빈 스케줄링에서 타임 퀀텀이 매우 커지면 동작 특성이 FCFS와 비슷해질 수 있다.', NULL, 'O',
        '[[라운드로빈]]은 각 프로세스에 일정한 시간 조각을 번갈아 주는 선점형 방식이다.\n[[타임 퀀텀]]이 매우 크면 한 프로세스가 거의 끝날 때까지 실행되어 교대 효과가 줄어든다.\n그래서 전체 동작은 FCFS와 비슷해질 수 있으므로 정답은 O이다.', '예를 들어 모든 작업의 CPU 버스트보다 [[타임 퀀텀]]이 더 길다면 각 작업은 한 번 차례가 왔을 때 거의 끝난다.\n이 경우 실제 실행 순서는 도착 순서에 크게 좌우되어 FCFS와 유사해진다.\n반대로 타임 퀀텀이 너무 작으면 문맥 교환이 자주 발생한다.', 'X로 답했다면 [[라운드로빈]]의 핵심인 시간 조각 분할 효과가 타임 퀀텀 크기에 따라 약해질 수 있다는 점을 놓친 것이다. [[문맥 교환]]이 거의 일어나지 않을 정도로 타임 퀀텀이 크면, 프로세스들이 사실상 길게 연속 실행되어 FCFS와 비슷한 결과가 나온다.',
        4, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '타임 퀀텀이 너무 작을 때 시스템 성능에 어떤 오버헤드가 증가하는가?', 1, 1),
  (@qid, '라운드로빈이 대화형 시스템에 자주 쓰이는 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '문맥 교환', 1),
  (@qid, '응답 시간', 2),
  (@qid, '시분할 시스템', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '라운드로빈', '각 프로세스에 동일한 시간 조각을 순환하며 배정하는 선점형 스케줄링 방식'),
  (@qid, '타임 퀀텀', '라운드로빈에서 한 프로세스가 한 번에 사용할 수 있는 CPU 시간 단위'),
  (@qid, '문맥 교환', 'CPU가 한 프로세스에서 다른 프로세스로 실행 대상을 바꿀 때 상태를 저장하고 복원하는 작업');

-- Step4 Slot3 (MULTIPLE_CHOICE) [local id=21]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 SJF 스케줄링의 특징으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[SJF]]는 다음 CPU 사용 시간이 가장 짧은 작업을 먼저 선택하는 방식이다.\n이론적으로 평균 대기 시간을 줄이는 데 유리하지만 실제로는 CPU 버스트 길이를 정확히 알기 어렵다.\n따라서 정답은 짧은 작업을 우선 실행한다는 선택지이다.', '배치 처리 환경에서 짧은 작업을 먼저 실행하면 [[평균 대기 시간]]이 감소할 수 있다.\n하지만 실제 운영체제는 미래의 정확한 [[CPU 버스트]] 길이를 알 수 없어 예측값을 사용하기도 한다.\n그래서 SJF의 이상적 성질이 항상 그대로 구현되지는 않는다.', '오답을 고른 경우 [[SJF]]를 우선순위 스케줄링이나 FCFS와 혼동했을 가능성이 크다. SJF의 핵심 기준은 도착 순서도, 사용자 지정 중요도도 아니라 예상 [[CPU 버스트]] 길이이다. 또한 긴 작업이 뒤로 밀려 기아가 생길 수 있다는 점도 함께 기억해야 한다.',
        4, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '예상 CPU 실행 시간이 가장 짧은 프로세스를 먼저 실행한다.', 1, 1),
  (@qid, '가장 먼저 도착한 프로세스를 항상 끝까지 실행한다.', 0, 2),
  (@qid, '모든 프로세스에 동일한 타임 퀀텀을 순환 배정한다.', 0, 3),
  (@qid, '우선순위 값이 낮을수록 무조건 나중에 실행한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'SJF에서 긴 작업이 계속 뒤로 밀려 실행되지 못하는 현상을 무엇이라고 하는가?', 1, 1),
  (@qid, 'SJF를 실제 시스템에서 구현하기 어려운 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '기아 현상', 1),
  (@qid, 'CPU 버스트 예측', 2),
  (@qid, '평균 대기 시간', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'SJF', 'Shortest Job First의 약자로, CPU 실행 시간이 가장 짧은 작업을 먼저 선택하는 스케줄링 방식'),
  (@qid, '평균 대기 시간', '프로세스들이 CPU를 받기 전까지 기다린 시간의 평균'),
  (@qid, 'CPU 버스트', '프로세스가 입출력 없이 CPU를 연속으로 사용하는 구간');

-- Step4 Slot4 (MULTIPLE_CHOICE) [local id=22]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드 상황에 대한 설명으로 옳은 것을 고르시오.', '프로세스: P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)\n가정: 숫자가 작을수록 우선순위가 높고, 모두 같은 시각에 준비 상태가 된다.\n스케줄링: 비선점형 우선순위 스케줄링', NULL,
        '[[우선순위 스케줄링]]은 우선순위가 가장 높은 프로세스를 먼저 선택한다.\n문제의 가정에서 숫자가 작을수록 높은 우선순위이므로 P2가 가장 먼저 실행된다.\n비선점형이므로 한 번 CPU를 얻은 프로세스는 종료 또는 대기 전까지 계속 실행된다.', '실시간 성격이 있는 작업에 [[우선순위 스케줄링]]을 적용하면 중요한 작업을 먼저 처리할 수 있다.\n하지만 낮은 우선순위 작업은 오래 기다릴 수 있어 [[기아]]가 발생할 수 있다.\n이를 완화하려고 에이징 기법을 함께 쓰기도 한다.', '다른 선택지를 골랐다면 [[우선순위 스케줄링]]의 기준을 잘못 적용했을 수 있다. 이 문제에서는 숫자가 작을수록 우선순위가 높다고 명시되어 있으므로 P2가 먼저다. 또한 [[비선점형]]이므로 실행 중간에 더 높은 우선순위 작업이 와도 즉시 빼앗지 않는다는 점과 구분해야 한다.',
        4, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, 'P1이 먼저 실행된다.', 0, 1),
  (@qid, 'P2가 먼저 실행된다.', 1, 2),
  (@qid, 'P3가 먼저 실행된다.', 0, 3),
  (@qid, '세 프로세스는 라운드로빈처럼 번갈아 즉시 실행된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '우선순위 스케줄링에서 낮은 우선순위 프로세스가 계속 실행되지 못하는 문제를 완화하는 대표 기법은 무엇인가?', 1, 1),
  (@qid, '비선점형 우선순위 스케줄링과 선점형 우선순위 스케줄링의 차이는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '에이징', 1),
  (@qid, '비선점형 스케줄링', 2),
  (@qid, '기아', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '우선순위 스케줄링', '각 프로세스에 부여된 우선순위를 기준으로 실행 순서를 결정하는 스케줄링 방식'),
  (@qid, '기아', '일부 프로세스가 자원을 계속 할당받지 못해 매우 오래 기다리는 현상'),
  (@qid, '비선점형', '한 번 CPU를 얻은 프로세스가 스스로 양보하거나 종료할 때까지 계속 실행되는 방식');

-- Step4 Slot5 (KEYWORD_BLANK) [local id=23]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '라운드로빈 스케줄링에서 ___이(가) 너무 작으면 응답성은 좋아질 수 있지만 문맥 교환 오버헤드가 커질 수 있다.', NULL, NULL,
        '[[라운드로빈]]의 성능은 각 프로세스에 주는 시간 조각 크기에 크게 좌우된다.\n이 시간 조각인 [[타임 퀀텀]]이 너무 작으면 프로세스 전환이 잦아져 오버헤드가 증가한다.\n반대로 너무 크면 FCFS처럼 동작해 응답성이 떨어질 수 있다.', '대화형 시스템에서는 [[응답 시간]]을 줄이기 위해 타임 퀀텀을 너무 크게 잡지 않는다.\n하지만 [[문맥 교환]]이 지나치게 자주 일어나면 CPU가 실제 작업보다 전환 비용에 더 많이 쓰일 수 있다.\n그래서 적절한 타임 퀀텀 선택이 중요하다.', '빈칸에 다른 스케줄링 기준을 넣었다면 [[타임 퀀텀]]이 라운드로빈의 핵심 조절 변수라는 점을 놓친 것이다. 라운드로빈에서 오버헤드 증가는 주로 [[문맥 교환]] 빈도와 연결되며, 그 빈도는 타임 퀀텀 크기에 직접 영향을 받는다.',
        4, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '타임 퀀텀'),
  (@qid, 1, 'time quantum');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '타임 퀀텀이 너무 클 때 라운드로빈이 어떤 알고리즘과 비슷하게 동작하는가?', 1, 1),
  (@qid, '문맥 교환 오버헤드는 왜 CPU 이용 효율을 낮출 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '응답 시간', 1),
  (@qid, '문맥 교환 오버헤드', 2),
  (@qid, '시분할', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '라운드로빈', '프로세스들에게 동일한 시간 조각을 순환 배정하는 선점형 스케줄링 방식'),
  (@qid, '타임 퀀텀', '라운드로빈에서 각 프로세스가 한 번에 사용할 수 있는 CPU 시간'),
  (@qid, '응답 시간', '요청 후 처음으로 반응이 시작될 때까지 걸리는 시간'),
  (@qid, '문맥 교환', '프로세스 전환 시 실행 상태를 저장하고 복원하는 작업');

-- Step5 Slot1 (OX) [local id=24]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '선점형 CPU 스케줄링에서는 실행 중인 프로세스가 타이머 인터럽트나 더 높은 우선순위 프로세스의 도착으로 CPU를 빼앗길 수 있다.', NULL, 'O',
        '[[선점형 스케줄링]]은 운영체제가 실행 중인 작업에서 CPU를 회수할 수 있는 방식이다.\n[[타이머 인터럽트]]는 일정 시간이 지나면 스케줄러가 다시 실행되도록 만들어 선점을 가능하게 한다.\n더 높은 우선순위 작업이 도착하면 현재 작업이 중단되고 새 작업이 CPU를 받을 수 있다.', '[[라운드 로빈]]에서는 정해진 시간 할당량이 끝나면 타이머에 의해 다음 프로세스로 CPU가 넘어간다.\n이처럼 선점은 응답성을 높이는 데 유리하지만 문맥 교환 비용이 추가된다.\n대화형 시스템에서 자주 쓰이는 이유가 여기에 있다.', '이 문장을 틀렸다고 판단했다면 [[선점형 스케줄링]]과 비선점형 방식을 혼동한 것이다.\n선점형에서는 프로세스가 스스로 CPU를 내놓지 않아도 운영체제가 개입해 CPU를 회수할 수 있다.\n특히 [[타이머 인터럽트]]와 우선순위 변화는 대표적인 선점 계기다.',
        5, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '비선점형 스케줄링에서는 어떤 시점에만 CPU가 다른 프로세스로 넘어갈 수 있을까?', 1, 1),
  (@qid, '선점형 스케줄링이 대화형 시스템에서 유리한 이유는 무엇일까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '라운드 로빈', 1),
  (@qid, '문맥 교환', 2),
  (@qid, '우선순위 스케줄링', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '선점형 스케줄링', '운영체제가 실행 중인 프로세스의 CPU를 강제로 회수할 수 있는 스케줄링 방식'),
  (@qid, '타이머 인터럽트', '일정 시간이 지나면 CPU에 인터럽트를 발생시켜 운영체제가 제어를 되찾게 하는 장치'),
  (@qid, '라운드 로빈', '각 프로세스에 동일한 시간 할당량을 주고 순환하며 실행하는 선점형 스케줄링 방식');

-- Step5 Slot2 (OX) [local id=25]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '비선점형 스케줄링에서는 실행 중인 프로세스가 I/O 요청이나 종료를 하기 전에도 운영체제가 언제든지 CPU를 강제로 회수할 수 있다.', NULL, 'X',
        '[[비선점형 스케줄링]]에서는 실행 중인 프로세스가 스스로 CPU를 반납할 때까지 계속 실행된다.\n보통 종료, 대기 상태 진입, 또는 명시적 양보 시점에만 다른 프로세스로 전환된다.\n따라서 운영체제가 임의 시점에 강제로 CPU를 빼앗는다는 설명은 틀리다.', '[[FCFS]] 같은 방식에서는 먼저 CPU를 잡은 작업이 끝나거나 I/O를 요청할 때까지 뒤의 작업이 기다린다.\n이 때문에 긴 CPU 버스트를 가진 작업이 있으면 응답 시간이 나빠질 수 있다.\n반면 구현은 비교적 단순하다.', '이 문장을 맞다고 생각했다면 [[비선점형 스케줄링]]의 핵심 제약을 놓친 것이다.\n비선점형은 현재 실행 중인 작업을 운영체제가 중간에 강제로 멈추지 않는다.\n[[FCFS]]나 비선점형 SJF에서는 CPU를 넘기는 시점이 제한적이다.',
        5, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '비선점형 스케줄링이 선점형보다 구현이 단순한 이유는 무엇일까?', 1, 1),
  (@qid, '비선점형 방식에서 긴 작업 하나가 시스템 응답성에 미치는 영향은 무엇일까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'FCFS', 1),
  (@qid, 'SJF', 2),
  (@qid, '응답 시간', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '비선점형 스케줄링', '실행 중인 프로세스가 자발적으로 CPU를 반납할 때만 스케줄링이 일어나는 방식'),
  (@qid, 'FCFS', '먼저 도착한 프로세스를 먼저 실행하는 비선점형 스케줄링 방식');

-- Step5 Slot3 (MULTIPLE_CHOICE) [local id=26]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '멀티레벨 큐 스케줄링에 대한 설명으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[멀티레벨 큐]]는 프로세스를 성격에 따라 여러 개의 고정된 큐로 나누는 방식이다.\n각 큐는 서로 다른 스케줄링 정책을 가질 수 있고, 큐 사이에는 우선순위가 정해질 수 있다.\n일반적으로 프로세스는 한 번 배정된 큐에 고정되며, 큐 간 이동은 멀티레벨 피드백 큐의 특징이다.', '예를 들어 [[포그라운드 큐]]는 라운드 로빈으로, 백그라운드 큐는 FCFS로 운영할 수 있다.\n이때 상위 큐에 작업이 계속 많으면 하위 큐 작업은 오래 기다릴 수 있다.\n그래서 정책 설계 시 응답성과 공정성을 함께 고려해야 한다.', '오답을 고른 경우 [[멀티레벨 큐]]와 멀티레벨 피드백 큐를 혼동했을 가능성이 크다.\n멀티레벨 큐는 보통 큐가 고정되고, 큐마다 다른 정책을 적용하는 데 초점이 있다.\n반면 큐 사이를 이동하며 우선순위를 조정하는 특징은 [[멀티레벨 피드백 큐]]에 가깝다.',
        5, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '프로세스는 일반적으로 성격에 따라 고정된 큐에 배정되며, 각 큐는 서로 다른 스케줄링 정책을 가질 수 있다.', 1, 1),
  (@qid, '모든 큐는 반드시 동일한 스케줄링 알고리즘을 사용해야 한다.', 0, 2),
  (@qid, '멀티레벨 큐에서는 프로세스가 실행 도중 자동으로 다른 큐로 이동하는 것이 필수이다.', 0, 3),
  (@qid, '멀티레벨 큐는 오직 비선점형 스케줄링에서만 사용할 수 있다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '멀티레벨 큐와 멀티레벨 피드백 큐의 가장 큰 차이는 무엇일까?', 1, 1),
  (@qid, '상위 큐에 작업이 몰릴 때 하위 큐에서 어떤 문제가 발생할 수 있을까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '멀티레벨 피드백 큐', 1),
  (@qid, '포그라운드/백그라운드 분리', 2),
  (@qid, '큐 간 우선순위', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '멀티레벨 큐', '프로세스를 여러 개의 고정된 큐로 나누고 큐별로 다른 스케줄링 정책을 적용하는 방식'),
  (@qid, '포그라운드 큐', '대화형 작업처럼 빠른 응답이 필요한 프로세스를 위한 상위 큐'),
  (@qid, '멀티레벨 피드백 큐', '프로세스의 동작에 따라 큐 사이 이동을 허용해 우선순위를 조정하는 스케줄링 방식');

-- Step5 Slot4 (MULTIPLE_CHOICE) [local id=27]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 상황에서 가장 먼저 CPU를 할당받는 프로세스로 알맞은 것은 무엇인가? 모든 프로세스는 시각 0에 준비 큐에 있으며, 스케줄링은 선점형 우선순위 방식이고 숫자가 작을수록 우선순위가 높다.', 'Process A: priority=3, burst=5\nProcess B: priority=1, burst=8\nProcess C: priority=2, burst=2\nProcess D: priority=4, burst=1', NULL,
        '[[선점형 우선순위 스케줄링]]에서는 준비 상태의 프로세스 중 가장 높은 우선순위를 가진 작업이 먼저 CPU를 받는다.\n문제에서 숫자가 작을수록 우선순위가 높다고 했으므로 priority=1이 가장 높다.\n따라서 B가 가장 먼저 실행된다.', '실행 중에 더 높은 우선순위 작업이 새로 도착하면 [[준비 큐]]에서 선택 규칙이 다시 적용되어 현재 작업이 선점될 수 있다.\n하지만 이 문제는 모든 프로세스가 시각 0에 이미 도착해 있으므로 초기 선택만 보면 된다.\n버스트 시간은 첫 선택이 아니라 이후 실행 순서와 완료 시점에 영향을 준다.', '오답을 고른 경우 [[선점형 우선순위 스케줄링]]의 기준을 버스트 시간과 혼동했을 수 있다.\n이 문제는 SJF가 아니라 우선순위 기반이며, 숫자가 작을수록 더 높은 우선순위라고 명시되어 있다.\n따라서 [[준비 큐]]에서 가장 먼저 선택되는 것은 priority=1인 B다.',
        5, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, 'Process A', 0, 1),
  (@qid, 'Process B', 1, 2),
  (@qid, 'Process C', 0, 3),
  (@qid, 'Process D', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '만약 실행 도중 priority=0인 새 프로세스가 도착하면 현재 실행 중인 프로세스에 어떤 일이 일어날까?', 1, 1),
  (@qid, '동일 우선순위 프로세스가 여러 개라면 어떤 추가 규칙이 필요할까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '우선순위 역전', 1),
  (@qid, '준비 큐', 2),
  (@qid, 'SJF와의 차이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '선점형 우선순위 스케줄링', '우선순위가 더 높은 프로세스가 나타나면 현재 실행 중인 프로세스를 중단시키고 CPU를 할당하는 방식'),
  (@qid, '준비 큐', 'CPU를 기다리는 준비 상태 프로세스들이 들어 있는 큐');

-- Step5 Slot5 (KEYWORD_BLANK) [local id=28]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '우선순위 기반 스케줄링에서 낮은 우선순위 프로세스가 오랫동안 CPU를 받지 못하는 현상을 ___라고 하며, 이를 완화하기 위해 기다린 시간에 따라 우선순위를 점차 높이는 기법을 ___이라고 한다.', NULL, NULL,
        '[[기아]]는 특정 프로세스가 계속 선택되지 못해 무한히 기다릴 수 있는 문제다.\n[[에이징]]은 오래 기다린 프로세스의 우선순위를 점진적으로 높여 기아를 줄이는 방법이다.\n우선순위 스케줄링에서는 공정성을 위해 두 개념을 함께 이해해야 한다.', '상위 우선순위 작업이 계속 들어오는 시스템에서는 낮은 우선순위 배치 작업이 [[기아]] 상태에 빠질 수 있다.\n이때 일정 시간마다 우선순위를 올리는 [[에이징]] 정책을 두면 결국 CPU를 받을 가능성이 커진다.\n실제 운영체제 설계에서는 응답성과 공정성의 균형이 중요하다.', '빈칸을 다르게 채웠다면 [[기아]]와 단순한 긴 대기 시간을 구분하지 못했을 수 있다.\n기아는 우선순위 정책 때문에 특정 작업이 계속 밀리는 현상이고, 이를 완화하는 대표 기법이 [[에이징]]이다.\n둘은 원인과 해결책의 관계로 함께 기억해야 한다.',
        5, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '기아'),
  (@qid, 1, 'starvation'),
  (@qid, 2, '에이징'),
  (@qid, 2, 'aging');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '에이징을 너무 빠르게 적용하면 어떤 부작용이 생길 수 있을까?', 1, 1),
  (@qid, '기아 문제는 멀티레벨 큐의 하위 큐에서도 발생할 수 있을까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '공정성', 1),
  (@qid, '우선순위 스케줄링', 2),
  (@qid, '무한 대기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '기아', '낮은 우선순위 등의 이유로 프로세스가 CPU를 매우 오래 또는 무한히 기다리는 현상'),
  (@qid, '에이징', '오래 기다린 프로세스의 우선순위를 점차 높여 기아를 완화하는 기법');

-- Step6 Slot1 (OX) [local id=29]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '임계구역은 여러 프로세스나 스레드가 동시에 접근해도 항상 안전하도록 별도 보호가 필요 없는 코드 구간이다.', NULL, 'X',
        '[[임계구역]]은 공유 데이터에 접근하는 코드 구간이므로 보호가 필요하다.\n여러 실행 흐름이 동시에 들어가면 [[경쟁 상태]]가 발생할 수 있다.\n따라서 상호 배제를 보장하는 동기화 기법을 사용해야 한다.', '예를 들어 전역 카운터를 증가시키는 코드는 [[임계구역]]이 될 수 있다.\n보호 없이 두 스레드가 동시에 실행하면 [[경쟁 상태]]로 인해 증가 결과가 기대값보다 작아질 수 있다.\n이때 뮤텍스 같은 동기화 도구로 한 번에 하나만 들어가게 만든다.', '이 문장은 틀렸다. [[임계구역]]은 바로 보호가 필요한 구간이다. 여러 실행 흐름이 동시에 공유 자원에 접근하면 [[경쟁 상태]]가 생겨 데이터가 손상되거나 결과가 달라질 수 있다.',
        6, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '임계구역 문제를 해결하기 위한 대표적인 조건인 상호 배제는 무엇을 의미할까?', 1, 1),
  (@qid, '공유 변수를 증가시키는 연산이 왜 임계구역이 되는지 설명할 수 있을까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '상호 배제', 1),
  (@qid, '공유 자원', 2),
  (@qid, '경쟁 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '임계구역', '여러 프로세스나 스레드가 공유 자원에 접근하는 코드 구간'),
  (@qid, '경쟁 상태', '실행 순서에 따라 결과가 달라지는 동시성 오류 상황');

-- Step6 Slot2 (OX) [local id=30]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '뮤텍스는 보통 잠금을 획득한 실행 흐름이 나중에 그 잠금을 해제하는 방식으로 사용된다.', NULL, 'O',
        '[[뮤텍스]]는 상호 배제를 위한 잠금 도구다.\n일반적으로 잠금을 획득한 실행 흐름이 같은 [[잠금]]을 해제한다.\n이 규칙은 임계구역 보호의 일관성을 높인다.', '스레드 A가 [[뮤텍스]]를 lock한 뒤 공유 리스트를 수정했다면, 작업이 끝난 후 스레드 A가 unlock한다.\n다른 스레드는 그 [[잠금]]이 풀릴 때까지 임계구역에 들어가지 못한다.\n이 방식으로 동시에 수정되는 상황을 막는다.', '이 문장은 맞다. [[뮤텍스]]는 보통 소유 개념이 있는 잠금이며, 획득한 실행 흐름이 해제하는 방식으로 사용한다. 이를 무시하면 [[잠금]] 관리가 꼬여 프로그램 오류가 생길 수 있다.',
        6, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '뮤텍스와 세마포어의 사용 방식 차이 중 하나를 말해볼 수 있을까?', 1, 1),
  (@qid, '잠금을 해제하지 않으면 어떤 문제가 생길 수 있을까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '상호 배제', 1),
  (@qid, '락 소유권', 2),
  (@qid, '교착 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '뮤텍스', '한 번에 하나의 실행 흐름만 임계구역에 들어가게 하는 상호 배제 도구'),
  (@qid, '잠금', '공유 자원 접근을 제한하기 위해 거는 lock 상태');

-- Step6 Slot3 (MULTIPLE_CHOICE) [local id=31]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 세마포어에 대한 설명으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[세마포어]]는 정수 값을 바탕으로 접근 가능 개수를 제어하는 동기화 도구다.\nwait(P) 연산은 자원을 요청하고, signal(V) 연산은 반납을 알린다.\n특히 [[카운팅 세마포어]]는 여러 개의 동일 자원을 관리할 때 유용하다.', '예를 들어 연결 풀에 자원 3개가 있으면 [[카운팅 세마포어]] 값을 3으로 둘 수 있다.\n각 스레드는 [[세마포어]]에 wait를 호출해 자원을 하나 얻고, 사용 후 signal로 반환한다.\n그러면 동시에 최대 3개까지만 자원을 사용할 수 있다.', '오답을 고를 경우 세마포어를 단순한 불리언 잠금으로만 이해했을 가능성이 크다. [[세마포어]]는 정수 값을 이용해 접근 수를 조절할 수 있으며, [[카운팅 세마포어]]는 여러 자원을 관리하는 데 쓰인다.',
        6, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '세마포어는 정수 값을 사용해 자원 접근 수를 제어할 수 있다.', 1, 1),
  (@qid, '세마포어는 반드시 잠금을 획득한 스레드만 해제할 수 있다.', 0, 2),
  (@qid, '세마포어는 임계구역 문제와 무관한 메모리 관리 기법이다.', 0, 3),
  (@qid, '세마포어는 한 번 초기화하면 값이 절대 변하지 않는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '이진 세마포어와 카운팅 세마포어의 차이는 무엇일까?', 1, 1),
  (@qid, 'wait와 signal 연산은 각각 어떤 역할을 할까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '이진 세마포어', 1),
  (@qid, 'wait 연산', 2),
  (@qid, 'signal 연산', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '세마포어', '정수 값을 이용해 공유 자원 접근을 조절하는 동기화 도구'),
  (@qid, '카운팅 세마포어', '여러 개의 동일한 자원 수를 세어 관리하는 세마포어');

-- Step6 Slot4 (MULTIPLE_CHOICE) [local id=32]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드에 대한 설명으로 가장 알맞은 것은 무엇인가?', 'semaphore s = 1;\n\nwait(s);\n// critical section\nsignal(s);', NULL,
        '초기값이 1인 [[세마포어]]는 한 번에 하나의 실행 흐름만 통과시키는 데 사용할 수 있다.\n이 코드는 wait 후 [[임계구역]]에 들어가고, 작업이 끝나면 signal로 나간다.\n따라서 상호 배제를 구현하는 전형적인 형태다.', '초기값이 1인 [[세마포어]]는 이진 세마포어처럼 동작할 수 있다.\n스레드 하나가 wait로 들어가 [[임계구역]]을 실행하는 동안 다른 스레드는 대기한다.\n첫 스레드가 signal을 호출하면 다음 스레드가 들어갈 수 있다.', '오답을 선택했다면 초기값 1의 [[세마포어]] 의미를 놓쳤을 수 있다. 값이 1이면 동시에 하나만 진입할 수 있어 [[임계구역]] 보호에 사용할 수 있다. 여러 개를 동시에 허용하는 구조가 아니다.',
        6, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '초기값 1의 세마포어를 이용해 상호 배제를 구현한 예이다.', 1, 1),
  (@qid, '동시에 여러 스레드가 임계구역에 반드시 들어가도록 보장한 예이다.', 0, 2),
  (@qid, '세마포어 값이 1이므로 wait를 호출해도 값은 변하지 않는다.', 0, 3),
  (@qid, 'signal은 임계구역 진입 전에 호출해야 올바른 코드가 된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '초기값을 3으로 바꾸면 이 코드는 어떤 의미를 갖게 될까?', 1, 1),
  (@qid, '뮤텍스로 같은 목적을 구현하면 코드 구조는 어떻게 달라질까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '이진 세마포어', 1),
  (@qid, '상호 배제', 2),
  (@qid, '동시 접근 제한', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '세마포어', '정수 값을 이용해 공유 자원 접근을 조절하는 동기화 도구'),
  (@qid, '임계구역', '공유 자원에 접근하는 코드 구간');

-- Step6 Slot5 (KEYWORD_BLANK) [local id=33]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '공유 자원에 대해 한 시점에 하나의 실행 흐름만 임계구역에 들어가도록 보장하는 성질을 ___라고 한다.', NULL, NULL,
        '[[상호 배제]]는 동시에 둘 이상이 임계구역에 들어가지 못하게 하는 성질이다.\n이 성질이 없으면 공유 데이터에서 [[경쟁 상태]]가 발생할 수 있다.\n뮤텍스와 이진 세마포어는 상호 배제를 구현하는 대표적 방법이다.', '은행 계좌 잔액을 수정하는 코드에서 [[상호 배제]]가 없으면 두 스레드가 같은 값을 읽고 덮어쓸 수 있다.\n이 경우 [[경쟁 상태]]로 인해 최종 잔액이 잘못될 수 있다.\n잠금을 사용하면 한 번에 하나만 수정하게 만들 수 있다.', '빈칸은 [[상호 배제]]다. 단순히 대기나 순서를 뜻하는 말이 아니라, 임계구역에 동시에 하나만 들어가게 하는 성질을 가리킨다. 이를 보장하지 못하면 [[경쟁 상태]]가 생길 수 있다.',
        6, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '상호 배제'),
  (@qid, 1, 'mutual exclusion');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '상호 배제를 만족해도 교착 상태가 발생할 수 있는 이유는 무엇일까?', 1, 1),
  (@qid, '상호 배제를 구현하는 도구로 뮤텍스와 세마포어를 어떻게 사용할 수 있을까?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '진행', 1),
  (@qid, '한정 대기', 2),
  (@qid, '교착 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '상호 배제', '한 시점에 하나의 실행 흐름만 임계구역에 들어가게 하는 성질'),
  (@qid, '경쟁 상태', '실행 순서에 따라 결과가 달라지는 동시성 오류 상황');

-- Step7 Slot1 (OX) [local id=34]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '생산자-소비자 문제에서 공유 버퍼에 접근할 때, 여러 스레드가 동시에 버퍼 상태를 변경해도 항상 올바른 결과가 보장된다.', NULL, 'X',
        '[[경쟁 상태]]는 여러 스레드가 공유 데이터를 동시에 접근해 실행 순서에 따라 결과가 달라지는 문제다.\n생산자-소비자 문제의 공유 버퍼는 임계 구역이므로 보호하지 않으면 데이터 불일치가 생길 수 있다.\n따라서 동기화 없이도 항상 올바른 결과가 보장된다는 주장은 틀리다.', '[[뮤텍스]]를 사용해 버퍼 삽입과 제거 연산을 임계 구역으로 감싸면 한 번에 하나의 스레드만 버퍼 상태를 바꿀 수 있다.\n예를 들어 put()와 get()에서 lock과 unlock을 사용하면 인덱스와 개수 값이 꼬이는 일을 줄일 수 있다.\n이처럼 공유 자원 접근을 직렬화해야 생산자-소비자 문제를 안전하게 구현할 수 있다.', '이 문장을 참이라고 판단했다면 [[임계 구역]] 보호의 필요성을 놓친 것이다. 공유 버퍼의 인덱스나 개수는 여러 스레드가 동시에 갱신하면 값이 덮어써질 수 있다. 이런 상황은 경쟁 상태를 일으켜 버퍼 오버플로우나 언더플로우 같은 잘못된 동작으로 이어질 수 있다.',
        7, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '공유 버퍼에서 임계 구역이 되는 대표 데이터는 무엇인가?', 1, 1),
  (@qid, '뮤텍스와 세마포어는 생산자-소비자 문제에서 각각 어떤 역할로 쓰일 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '임계 구역', 1),
  (@qid, '뮤텍스', 2),
  (@qid, '세마포어', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '경쟁 상태', '여러 실행 흐름이 공유 데이터에 동시에 접근해 실행 순서에 따라 결과가 달라지는 상태'),
  (@qid, '뮤텍스', '한 번에 하나의 스레드만 임계 구역에 들어가도록 하는 상호 배제 동기화 도구'),
  (@qid, '임계 구역', '공유 자원에 접근하므로 동시에 실행되면 안 되는 코드 구간');

-- Step7 Slot2 (OX) [local id=35]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '모니터는 공유 자원에 대한 상호 배제를 구조적으로 지원하며, 조건이 만족되지 않으면 조건 변수를 통해 스레드를 기다리게 할 수 있다.', NULL, 'O',
        '[[모니터]]는 공유 데이터와 그 데이터를 다루는 연산을 하나의 추상화로 묶어 상호 배제를 제공한다.\n또한 [[조건 변수]]를 사용해 특정 조건이 만족될 때까지 스레드를 기다리게 하거나 깨울 수 있다.\n따라서 문장의 설명은 맞다.', '예를 들어 bounded buffer를 [[모니터]]로 만들면 insert와 remove 메서드에 동시에 여러 스레드가 들어가지 못하게 할 수 있다.\n버퍼가 가득 찼을 때 생산자는 조건 변수에서 wait하고, 소비자가 항목을 제거한 뒤 signal할 수 있다.\n이 방식은 락과 조건 대기를 구조적으로 함께 다루게 해 코드 의도를 분명하게 만든다.', '이 문장을 거짓이라고 판단했다면 [[조건 변수]]의 역할을 놓쳤을 가능성이 크다. 모니터는 단순히 함수 묶음이 아니라 상호 배제와 조건 대기를 함께 지원하는 동기화 추상화다. 그래서 생산자-소비자처럼 상태 조건을 기다려야 하는 문제에 적합하다.',
        7, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '모니터에서 조건 변수가 필요한 이유는 무엇인가?', 1, 1),
  (@qid, '모니터와 세마포어를 사용할 때 코드 가독성 측면의 차이는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '상호 배제', 1),
  (@qid, '조건 변수', 2),
  (@qid, 'bounded buffer', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '모니터', '공유 데이터와 그 연산을 캡슐화하고 상호 배제를 제공하는 동기화 추상화'),
  (@qid, '조건 변수', '특정 조건이 만족될 때까지 스레드를 기다리게 하고 이후 깨우는 동기화 도구');

-- Step7 Slot3 (MULTIPLE_CHOICE) [local id=36]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '세마포어를 사용한 생산자-소비자 문제에서 일반적으로 empty 세마포어의 의미로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[세마포어]]는 정수 값을 이용해 자원 수나 진입 가능 횟수를 관리하는 동기화 도구다.\n생산자-소비자 문제에서 [[empty]]는 보통 버퍼의 비어 있는 칸 수를 나타낸다.\n생산자는 empty가 0이면 기다리고, 소비 후 빈 칸이 생기면 값이 증가한다.', '크기가 N인 버퍼에서 초기 [[empty]] 값은 보통 N이고, full 값은 0으로 둔다.\n생산자는 empty를 감소시킨 뒤 항목을 넣고 full을 증가시킨다.\n이 순서를 지키면 가득 찬 버퍼에 잘못 삽입하는 일을 막을 수 있다.', '오답을 고른 경우 [[세마포어]] 값이 무엇을 세는지 혼동했을 수 있다. empty는 소비 가능한 항목 수가 아니라 생산 가능한 빈 칸 수를 뜻한다. 항목 수는 보통 full 세마포어가 나타낸다.',
        7, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '버퍼에 현재 비어 있는 칸의 수', 1, 1),
  (@qid, '버퍼에 현재 들어 있는 항목의 수', 0, 2),
  (@qid, '임계 구역에 동시에 들어갈 수 있는 스레드의 최대 수', 0, 3),
  (@qid, '대기 중인 소비자 스레드의 수', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '크기가 10인 버퍼라면 empty와 full의 초기값은 보통 어떻게 설정하는가?', 1, 1),
  (@qid, '뮤텍스와 empty/full 세마포어는 각각 어떤 자원을 보호하거나 표현하는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'full 세마포어', 1),
  (@qid, '버퍼 용량', 2),
  (@qid, '동기화 순서', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '세마포어', '정수 카운터와 원자적 연산으로 동기화를 수행하는 기법'),
  (@qid, 'empty', '생산자-소비자 문제에서 버퍼의 남은 빈 칸 수를 나타내는 세마포어 이름으로 자주 쓰이는 값');

-- Step7 Slot4 (MULTIPLE_CHOICE) [local id=37]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드에서 발생할 수 있는 가장 적절한 문제를 고르시오.', 'int counter = 0;\n\n// Thread A\nfor (int i = 0; i < 100000; i++) {\n    counter++;\n}\n\n// Thread B\nfor (int i = 0; i < 100000; i++) {\n    counter++;\n}', NULL,
        '[[counter++]]는 보통 읽기, 증가, 쓰기의 여러 단계로 이루어져 원자적이지 않을 수 있다.\n두 스레드가 이를 동시에 수행하면 [[경쟁 상태]]가 발생해 일부 증가가 사라질 수 있다.\n따라서 최종 counter 값이 항상 200000이라고 보장할 수 없다.', '이 코드는 [[원자적 연산]]이 아니므로 lock을 사용하거나 원자 변수로 바꾸는 방식이 필요하다.\n예를 들어 뮤텍스로 증가 구간을 감싸면 한 번에 하나의 스레드만 counter를 수정한다.\n또는 언어가 제공하는 atomic increment를 사용하면 경쟁 상태를 줄일 수 있다.', '오답을 선택했다면 [[counter++]]를 한 번의 기계 명령처럼 생각했을 수 있다. 하지만 일반적으로 이 연산은 중간 상태가 있어 다른 스레드와 충돌할 수 있다. 그래서 문제의 핵심은 데드락이 아니라 경쟁 상태로 인한 값 손실 가능성이다.',
        7, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '경쟁 상태로 인해 최종 counter 값이 200000보다 작아질 수 있다.', 1, 1),
  (@qid, '반드시 데드락이 발생해 두 스레드가 종료되지 않는다.', 0, 2),
  (@qid, 'counter는 지역 변수처럼 동작하므로 각 스레드가 독립적으로 값을 가진다.', 0, 3),
  (@qid, '두 스레드가 동시에 실행되어도 counter++는 항상 원자적이므로 문제없다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'counter++를 안전하게 만들기 위한 대표적인 두 방법은 무엇인가?', 1, 1),
  (@qid, '원자적 연산과 임계 구역 보호는 어떤 관계가 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '원자성', 1),
  (@qid, '락', 2),
  (@qid, '원자 변수', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'counter++', '공유 변수 증가 연산의 예로, 일반적으로 여러 단계로 수행될 수 있다'),
  (@qid, '경쟁 상태', '여러 실행 흐름이 공유 데이터에 동시에 접근해 실행 순서에 따라 결과가 달라지는 상태'),
  (@qid, '원자적 연산', '중간에 끼어들 수 없는 하나의 불가분 작업처럼 수행되는 연산');

-- Step7 Slot5 (KEYWORD_BLANK) [local id=38]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '모니터에서 어떤 조건이 만족될 때까지 스레드를 잠들게 하고, 이후 다른 스레드가 그 조건 변화에 맞춰 깨울 수 있게 하는 동기화 도구는 ___이다.', NULL, NULL,
        '[[모니터]] 안에서는 상태 조건이 맞지 않을 때 스레드를 계속 바쁘게 기다리게 하지 않는 것이 중요하다.\n이때 [[조건 변수]]를 사용하면 wait로 잠들고 signal 같은 연산으로 다시 깰 수 있다.\n따라서 빈칸에는 조건 변수가 들어간다.', 'bounded buffer [[모니터]]에서 버퍼가 비어 있으면 소비자는 조건 변수에서 기다릴 수 있다.\n생산자가 데이터를 넣은 뒤 signal을 호출하면 대기 중인 소비자가 다시 실행될 수 있다.\n이 구조는 상태 조건과 상호 배제를 함께 표현하기 좋다.', '빈칸을 세마포어나 뮤텍스로 적었다면 [[조건 변수]]와 역할을 구분해야 한다. 뮤텍스는 상호 배제를 위한 도구이고, 조건 변수는 특정 상태가 될 때까지 기다렸다가 깨우는 데 초점이 있다. 모니터에서 조건 대기를 표현하는 핵심 용어는 조건 변수다.',
        7, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '조건 변수'),
  (@qid, 1, 'condition variable');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '조건 변수의 wait를 호출할 때 왜 상태 조건을 함께 확인해야 하는가?', 1, 1),
  (@qid, '모니터에서 signal과 broadcast는 어떤 차이가 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'wait', 1),
  (@qid, 'signal', 2),
  (@qid, '바쁜 대기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '모니터', '공유 데이터와 그 연산을 캡슐화하고 상호 배제를 제공하는 동기화 추상화'),
  (@qid, '조건 변수', '특정 조건이 만족될 때까지 스레드를 기다리게 하고 이후 깨우는 동기화 도구');

-- Step8 Slot1 (OX) [local id=39]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '교착상태의 4대 필요 조건 중 하나라도 성립하지 않으면 교착상태는 발생할 수 없다.', NULL, 'O',
        '[[교착상태]]는 여러 프로세스가 서로 자원을 기다리며 영원히 진행하지 못하는 상태다.\n[[필요 조건]]은 상호 배제, 점유와 대기, 비선점, 순환 대기의 네 가지다.\n이 네 조건은 모두 동시에 성립해야 하므로 하나라도 깨지면 교착상태는 성립하지 않는다.', '운영체제가 [[비선점]]을 허용하지 않고 자원을 강제로 회수할 수 있다면 4대 조건 중 하나가 깨져 교착상태가 성립하지 않는다.', '이 문장을 틀리게 판단했다면 [[필요 조건]]의 의미를 반대로 이해한 것이다. 교착상태는 네 조건이 모두 필요하므로 하나라도 없으면 [[교착상태]]는 발생할 수 없다.',
        8, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '4대 필요 조건 각각을 한 문장씩 설명할 수 있는가?', 1, 1),
  (@qid, '순환 대기 조건을 깨는 대표적인 방법은 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '교착상태 4대 조건', 1),
  (@qid, '상호 배제', 2),
  (@qid, '순환 대기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '교착상태', '둘 이상의 프로세스가 서로 자원을 기다리며 무한히 대기하는 상태'),
  (@qid, '필요 조건', '어떤 현상이 성립하기 위해 반드시 만족해야 하는 조건'),
  (@qid, '비선점', '이미 할당된 자원을 강제로 빼앗을 수 없는 성질');

-- Step8 Slot2 (OX) [local id=40]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '교착상태 회피는 시스템이 이미 교착상태에 빠진 뒤 이를 탐지하고 복구하는 기법이다.', NULL, 'X',
        '[[교착상태 회피]]는 자원 요청 시 미래의 상태를 검사해 위험한 할당을 피하는 방법이다.\n반면 [[탐지]]는 교착상태가 발생했는지 확인하는 단계다.\n발생 후 처리인 [[복구]]와 회피는 목적과 시점이 다르다.', '대표적인 [[안전 상태]] 판단 기반 회피 기법으로 은행원 알고리즘이 있다. 이 방식은 요청을 즉시 허용하지 않고 시스템이 안전한지 먼저 본다.', '이 문장을 맞다고 생각했다면 [[교착상태 회피]]와 발생 후 처리 기법을 혼동한 것이다. 회피는 사전에 위험한 할당을 막는 방법이고, [[복구]]는 이미 발생한 문제를 해결하는 단계다.',
        8, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '교착상태 예방과 회피의 차이를 설명할 수 있는가?', 1, 1),
  (@qid, '안전 상태와 불안전 상태는 어떻게 구분되는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '교착상태 회피', 1),
  (@qid, '안전 상태', 2),
  (@qid, '은행원 알고리즘', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '교착상태 회피', '자원 할당 전에 미래 상태를 고려하여 교착상태 가능성을 피하는 기법'),
  (@qid, '탐지', '교착상태가 실제로 발생했는지 검사하는 과정'),
  (@qid, '복구', '탐지된 교착상태를 해소하기 위해 프로세스 종료나 자원 회수 등을 수행하는 과정'),
  (@qid, '안전 상태', '모든 프로세스가 어떤 순서로든 완료될 수 있는 자원 할당 상태');

-- Step8 Slot3 (MULTIPLE_CHOICE) [local id=41]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 교착상태 예방(prevention)을 위해 순환 대기 조건을 직접 깨는 방법으로 가장 적절한 것은 무엇인가?', NULL, NULL,
        '[[예방]]은 교착상태의 필요 조건 중 적어도 하나가 성립하지 않도록 설계하는 방법이다.\n그중 [[순환 대기]]를 깨려면 자원 종류에 전역적인 순서를 부여하고 그 순서대로만 요청하게 하면 된다.\n이 방식은 대기 관계의 고리를 원천적으로 만들기 어렵게 한다.', '예를 들어 락 A의 번호를 1, 락 B의 번호를 2로 두고 항상 [[자원 순서]]가 낮은 것부터 획득하게 하면 A를 가진 채 B를 기다리는 것은 가능해도 그 반대 방향의 고리를 줄일 수 있다.', '오답을 고른 경우 [[예방]]과 회피·탐지를 섞어 생각했을 가능성이 크다. 순환 대기를 직접 깨는 대표 방법은 [[자원 순서]]를 정해 요청 순서를 강제하는 것이며, 단순한 탐지 주기 조정이나 사후 종료는 예방이 아니다.',
        8, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '자원 종류마다 전역 순서를 정하고 모든 프로세스가 그 순서대로만 자원을 요청하게 한다.', 1, 1),
  (@qid, '프로세스가 자원을 요청할 때마다 안전 상태인지 검사한 뒤 허용한다.', 0, 2),
  (@qid, '주기적으로 대기 그래프를 검사해 사이클이 있으면 프로세스를 종료한다.', 0, 3),
  (@qid, '프로세스가 필요한 자원을 일부만 먼저 요청하고 나머지는 실행 중에 추가 요청하게 한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '자원에 전역 순서를 부여하면 왜 순환 대기가 어려워지는가?', 1, 1),
  (@qid, '예방 기법이 시스템 자원 활용률에 줄 수 있는 단점은 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '교착상태 예방', 1),
  (@qid, '자원 순서 부여', 2),
  (@qid, '순환 대기 제거', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '예방', '교착상태의 필요 조건이 성립하지 않도록 미리 설계하는 방법'),
  (@qid, '순환 대기', '프로세스들이 원형으로 서로의 자원을 기다리는 상태'),
  (@qid, '자원 순서', '자원 요청 순서를 강제하기 위해 자원 종류에 부여한 전역적 순번');

-- Step8 Slot4 (MULTIPLE_CHOICE) [local id=42]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드 상황에 대한 설명으로 가장 적절한 것은 무엇인가?', '// 스레드 T1\nlock(A);\nlock(B);\n\n// 스레드 T2\nlock(B);\nlock(A);', NULL,
        '서로 다른 스레드가 락 획득 순서를 반대로 사용하면 [[교착상태]]가 발생할 수 있다.\n이 상황은 각 스레드가 하나의 락을 가진 채 다른 락을 기다리므로 [[점유와 대기]]가 나타난다.\n또한 A→B, B→A 형태의 [[순환 대기]] 가능성이 생긴다.', '실무에서는 모든 코드 경로에서 [[락 순서]]를 A 다음 B처럼 일관되게 맞추는 규칙을 둔다. 그러면 반대 방향 대기가 줄어들어 교착상태 위험을 낮출 수 있다.', '오답을 고른 경우 코드에서 대기 관계를 놓친 것이다. T1은 A를 잡고 B를 기다릴 수 있고, T2는 B를 잡고 A를 기다릴 수 있어 [[순환 대기]]가 가능하다. 따라서 단순 경쟁 상태가 아니라 [[교착상태]] 위험이 있는 패턴이다.',
        8, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '두 스레드가 서로 다른 락을 하나씩 점유한 채 상대 락을 기다릴 수 있으므로 교착상태 위험이 있다.', 1, 1),
  (@qid, '락이 두 개이므로 동시에 실행되어도 교착상태는 절대 발생하지 않는다.', 0, 2),
  (@qid, '이 코드는 비선점 조건이 깨져 있으므로 교착상태와 무관하다.', 0, 3),
  (@qid, '한 스레드가 lock을 두 번 호출했으므로 반드시 기아만 발생한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '이 코드에서 교착상태를 예방하려면 어떤 락 획득 규칙을 적용해야 하는가?', 1, 1),
  (@qid, '교착상태와 경쟁 상태는 어떻게 다른가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '락 순서 일관성', 1),
  (@qid, '점유와 대기', 2),
  (@qid, '멀티스레드 동기화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '교착상태', '서로 자원을 기다리며 진행이 멈춘 상태'),
  (@qid, '점유와 대기', '자원을 가진 상태에서 추가 자원을 기다리는 조건'),
  (@qid, '순환 대기', '프로세스나 스레드들이 원형으로 서로를 기다리는 조건'),
  (@qid, '락 순서', '여러 락을 획득할 때 따르는 고정된 순서 규칙');

-- Step8 Slot5 (KEYWORD_BLANK) [local id=43]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '은행원 알고리즘에서 현재 자원 할당 상태가 모든 프로세스가 어떤 순서로든 완료될 수 있는 상태라면 이를 ___라고 한다.', NULL, NULL,
        '은행원 알고리즘은 [[최대 필요량]]과 현재 할당량을 바탕으로 미래의 자원 요청을 판단한다.\n모든 프로세스가 완료 가능한 순서를 찾을 수 있는 상태를 [[안전 상태]]라고 한다.\n반대로 그런 완료 순서를 보장할 수 없으면 [[불안전 상태]]이며, 곧바로 교착상태라는 뜻은 아니지만 위험하다.', '예를 들어 가용 자원과 각 프로세스의 남은 필요량을 비교해 완료 가능한 프로세스를 하나씩 찾는 [[안전 순서]]가 존재하면 그 상태는 안전 상태로 본다.', '오답을 적었다면 은행원 알고리즘의 핵심 용어를 혼동한 것이다. 완료 가능한 순서를 찾을 수 있는 상태는 [[안전 상태]]이며, 이는 단순히 현재 대기가 없다는 뜻이 아니라 미래까지 고려한 개념이다.',
        8, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '안전 상태');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '안전 상태와 불안전 상태의 차이를 예시로 설명할 수 있는가?', 1, 1),
  (@qid, '불안전 상태가 항상 즉시 교착상태를 의미하지 않는 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '은행원 알고리즘', 1),
  (@qid, '안전 순서', 2),
  (@qid, '불안전 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '최대 필요량', '프로세스가 실행을 완료하기 위해 최대로 요구할 수 있는 자원 수'),
  (@qid, '안전 상태', '모든 프로세스가 어떤 순서로든 완료될 수 있는 자원 할당 상태'),
  (@qid, '불안전 상태', '안전 순서를 보장할 수 없어 교착상태 가능성이 있는 상태'),
  (@qid, '안전 순서', '모든 프로세스가 차례로 완료될 수 있음을 보이는 실행 순서');

-- Step9 Slot1 (OX) [local id=44]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '외부 단편화는 연속 할당 방식에서 빈 메모리 공간이 여러 조각으로 흩어져, 총합은 충분해도 큰 프로세스를 배치하지 못하는 현상을 말한다.', NULL, 'O',
        '[[외부 단편화]]는 빈 공간이 여러 작은 조각으로 나뉘는 현상이다.\n[[연속 할당]]에서는 프로세스가 한 덩어리의 연속된 메모리 공간을 필요로 한다.\n따라서 전체 여유 공간의 합이 충분해도 연속된 큰 공간이 없으면 적재에 실패할 수 있다.', '메모리에 10KB, 12KB, 8KB의 빈 공간이 흩어져 있고 25KB 프로세스를 넣어야 한다고 하자.\n총 여유 공간은 30KB지만 [[연속 할당]]에서는 하나의 연속 구간이 필요하다.\n이때 [[외부 단편화]] 때문에 적재할 수 없다.', '틀렸다면 [[외부 단편화]]와 내부 단편화를 혼동했을 가능성이 크다. 외부 단편화는 빈 공간이 바깥쪽에서 잘게 나뉘는 문제이고, [[연속 할당]]에서 특히 잘 나타난다. 반면 내부 단편화는 이미 할당된 블록 내부의 남는 공간 문제다.',
        9, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '외부 단편화를 완화하기 위해 사용할 수 있는 대표적인 메모리 관리 기법은 무엇인가?', 1, 1),
  (@qid, '연속 할당에서 compaction은 어떤 상황에서 도움이 되는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '내부 단편화', 1),
  (@qid, 'compaction', 2),
  (@qid, '가변 분할 방식', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '외부 단편화', '빈 메모리 공간이 여러 조각으로 흩어져 큰 연속 공간을 만들기 어려운 현상'),
  (@qid, '연속 할당', '프로세스를 하나의 연속된 물리 메모리 구간에 배치하는 방식');

-- Step9 Slot2 (OX) [local id=45]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '페이징에서는 프로세스의 논리 주소 공간과 물리 메모리 공간을 같은 크기의 단위로 나누어 관리하므로 외부 단편화를 줄일 수 있다.', NULL, 'O',
        '[[페이징]]은 논리 메모리를 페이지, 물리 메모리를 프레임으로 같은 크기로 나눈다.\n이 방식은 프로세스를 흩어진 [[프레임]]들에 배치할 수 있어 큰 연속 공간이 꼭 필요하지 않다.\n그래서 외부 단편화는 크게 줄지만, 페이지 마지막 부분에서는 내부 단편화가 생길 수 있다.', '크기가 4KB인 [[프레임]] 단위로 메모리를 관리하면 프로세스의 각 페이지를 서로 다른 위치에 둘 수 있다.\n따라서 큰 연속 공간을 찾지 않아도 되어 [[페이징]]은 외부 단편화 완화에 유리하다.\n다만 마지막 페이지가 꽉 차지 않으면 일부 공간이 남을 수 있다.', '틀렸다면 [[페이징]]이 단편화를 완전히 없앤다고 생각했을 수 있다. 실제로는 큰 연속 공간이 필요 없어서 외부 단편화는 줄지만, 고정 크기 [[프레임]]에 맞추는 과정에서 내부 단편화는 남을 수 있다.',
        9, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '페이징에서 내부 단편화가 발생하는 대표적인 위치는 어디인가?', 1, 1),
  (@qid, '페이지와 프레임의 크기가 서로 같아야 하는 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '페이지 테이블', 1),
  (@qid, '내부 단편화', 2),
  (@qid, '가상 메모리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '페이징', '논리 메모리와 물리 메모리를 같은 크기 블록으로 나누어 매핑하는 기법'),
  (@qid, '프레임', '물리 메모리를 일정한 크기로 나눈 블록');

-- Step9 Slot3 (MULTIPLE_CHOICE) [local id=46]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 세그멘테이션에 대한 설명으로 가장 옳은 것은 무엇인가?', NULL, NULL,
        '[[세그멘테이션]]은 프로그램을 의미 단위의 가변 크기 구역으로 나눈다.\n각 [[세그먼트]]는 코드, 데이터, 스택처럼 논리적 구조를 반영할 수 있다.\n가변 크기이므로 보호와 공유에 유리하지만 외부 단편화가 발생할 수 있다.', '예를 들어 코드 영역은 읽기 전용, 데이터 영역은 읽기/쓰기로 다르게 보호할 수 있다.\n이처럼 [[세그먼트]]별 속성을 다르게 두는 점이 [[세그멘테이션]]의 장점이다.\n반면 빈 공간이 여러 크기로 남아 배치가 어려워질 수 있다.', '오답을 골랐다면 [[세그멘테이션]]과 페이징의 차이를 혼동했을 가능성이 있다. 세그멘테이션은 고정 크기 분할이 아니라 가변 크기 [[세그먼트]]를 사용하며, 프로그램의 논리 구조를 반영한다. 따라서 외부 단편화 가능성이 있다.',
        9, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '프로세스를 같은 크기의 페이지로만 나누며 논리적 의미는 고려하지 않는다.', 0, 1),
  (@qid, '프로그램을 코드, 데이터, 스택 같은 가변 크기 구역으로 나누어 관리한다.', 1, 2),
  (@qid, '외부 단편화와 내부 단편화가 모두 절대 발생하지 않는다.', 0, 3),
  (@qid, '물리 메모리의 모든 구역을 반드시 연속적으로 사용해야 한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '세그멘테이션에서 세그먼트마다 서로 다른 접근 권한을 둘 수 있는 이유는 무엇인가?', 1, 1),
  (@qid, '세그멘테이션이 외부 단편화에 취약한 이유를 설명할 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '세그먼트 테이블', 1),
  (@qid, '보호 비트', 2),
  (@qid, '논리 주소', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '세그멘테이션', '프로그램을 논리적 의미를 가진 가변 크기 구역으로 나누는 메모리 관리 기법'),
  (@qid, '세그먼트', '코드, 데이터, 스택처럼 의미 단위로 나뉜 메모리 구역');

-- Step9 Slot4 (MULTIPLE_CHOICE) [local id=47]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드 지문을 보고 가장 옳은 설명을 고르시오.', 'pageSize = 4096\nlogicalAddress = 10000\npageNumber = logicalAddress / pageSize\noffset = logicalAddress % pageSize', NULL,
        '[[논리 주소]]를 페이지 번호와 변위로 나누는 것은 [[페이징]]의 기본 동작이다.\n여기서 pageNumber는 어떤 페이지인지, [[오프셋]]은 그 페이지 내부의 위치인지를 뜻한다.\n주어진 식은 주소를 페이지 단위로 분해하는 과정이지, 물리 주소를 직접 계산한 것은 아니다.', 'logicalAddress가 10000이고 페이지 크기가 4096이면 페이지 번호는 2, [[오프셋]]은 1808이 된다.\n이후 [[페이지 테이블]]을 조회해 해당 페이지가 어느 프레임에 있는지 찾아야 물리 주소를 구할 수 있다.\n즉 코드만으로는 최종 물리 주소가 아직 완성되지 않았다.', '틀렸다면 [[논리 주소]] 분해와 물리 주소 계산을 같은 단계로 본 것일 수 있다. 이 코드는 [[페이징]]에서 주소를 페이지 번호와 오프셋으로 나누는 단계만 보여 준다. 실제 물리 주소를 얻으려면 페이지 번호로 [[페이지 테이블]]을 조회해 프레임 번호를 찾아야 한다.',
        9, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '이 코드는 세그먼트 번호와 세그먼트 길이를 계산한다.', 0, 1),
  (@qid, '이 코드는 논리 주소를 페이지 번호와 오프셋으로 분해하는 과정이다.', 1, 2),
  (@qid, '이 코드는 물리 메모리의 연속 빈 공간을 찾는 최초 적합(first fit) 알고리즘이다.', 0, 3),
  (@qid, '이 코드는 내부 단편화를 제거하기 위한 compaction 과정이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '페이지 번호를 얻은 뒤 물리 주소 계산에 추가로 필요한 자료구조는 무엇인가?', 1, 1),
  (@qid, '오프셋 값은 왜 페이지 크기보다 항상 작은가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '페이지 테이블', 1),
  (@qid, '주소 변환', 2),
  (@qid, '프레임 번호', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '논리 주소', 'CPU가 생성하는 주소로, 가상 주소 공간에서의 위치'),
  (@qid, '페이징', '주소 공간을 같은 크기의 페이지와 프레임으로 나누어 매핑하는 기법'),
  (@qid, '오프셋', '페이지나 세그먼트 내부에서의 상대적 위치'),
  (@qid, '페이지 테이블', '페이지 번호를 물리 메모리의 프레임 번호로 매핑하는 자료구조');

-- Step9 Slot5 (KEYWORD_BLANK) [local id=48]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '연속 할당에서 빈 공간이 여러 조각으로 흩어져 큰 프로세스를 배치하지 못하는 현상을 ___라고 하며, 이를 줄이기 위해 메모리의 사용 중인 블록들을 한쪽으로 모아 큰 연속 공간을 만드는 작업을 ___이라고 한다.', NULL, NULL,
        '[[외부 단편화]]는 총 여유 공간이 충분해도 큰 연속 공간이 없어 배치가 실패하는 문제다.\n이를 완화하는 방법 중 하나인 [[압축]]은 흩어진 빈 공간을 합쳐 더 큰 연속 공간을 만든다.\n다만 압축은 데이터 이동 비용이 커서 항상 수행하기 좋은 방법은 아니다.', '가변 분할 메모리에서 프로세스 종료가 반복되면 중간중간 작은 빈칸이 많이 생길 수 있다.\n이때 [[압축]]을 수행하면 사용 중인 블록을 재배치해 [[외부 단편화]]를 줄일 수 있다.\n하지만 실행 중인 프로세스의 위치를 옮기는 작업은 부담이 될 수 있다.', '틀렸다면 [[외부 단편화]]와 내부 단편화를 구분하지 못했을 수 있다. 문제의 핵심은 빈 공간이 여러 조각으로 흩어져 있다는 점이다. 또 이를 줄이기 위해 블록을 재배치해 큰 연속 공간을 만드는 작업은 [[압축]]이며, 단순한 페이지 교체나 세그먼트 보호와는 다른 개념이다.',
        9, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '외부 단편화'),
  (@qid, 2, '압축'),
  (@qid, 2, 'compaction');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '압축이 외부 단편화를 줄일 수 있지만 자주 사용되지 않을 수 있는 이유는 무엇인가?', 1, 1),
  (@qid, '페이징은 왜 압축 없이도 외부 단편화 문제를 완화할 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '내부 단편화', 1),
  (@qid, '가변 분할', 2),
  (@qid, '재배치 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '외부 단편화', '빈 메모리 공간이 여러 조각으로 흩어져 큰 연속 공간 확보가 어려운 현상'),
  (@qid, '압축', '사용 중인 메모리 블록을 재배치해 빈 공간을 한곳으로 모으는 작업');

-- Step10 Slot1 (OX) [local id=49]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '페이지 폴트는 프로세스가 접근한 페이지가 현재 물리 메모리에 없을 때 발생한다.', NULL, 'O',
        '[[페이지 폴트]]는 참조한 페이지가 현재 주기억장치에 없을 때 발생한다.\n운영체제는 해당 페이지를 보조기억장치에서 읽어 와 [[프레임]]에 적재한다.\n따라서 문장은 참이다.', '프로세스가 아직 적재되지 않은 배열 구간을 처음 읽으면 [[페이지 폴트]]가 발생할 수 있다.\n운영체제는 빈 [[프레임]]이 있으면 그곳에 페이지를 올리고, 없으면 교체를 수행한다.\n이후 같은 주소를 다시 접근하면 보통 메모리에서 바로 처리된다.', '이 문장을 거짓으로 판단했다면 [[페이지 폴트]]의 의미를 예외 오류와 혼동했을 가능성이 크다. 페이지 폴트는 잘못된 접근만을 뜻하지 않고, 유효한 가상 주소라도 해당 페이지가 아직 메모리에 없으면 발생한다. 이때 운영체제는 페이지를 적재할 [[프레임]]을 확보해 실행을 계속한다.',
        10, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '유효한 가상 주소 접근에서도 페이지 폴트가 발생할 수 있는 이유는 무엇인가?', 1, 1),
  (@qid, '페이지 폴트 처리 시 빈 프레임이 없으면 운영체제는 다음에 무엇을 하는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '요구 페이징', 1),
  (@qid, '가상 주소 공간', 2),
  (@qid, '페이지 적재', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '페이지 폴트', '프로세스가 참조한 가상 메모리 페이지가 현재 물리 메모리에 없어서 발생하는 사건'),
  (@qid, '프레임', '물리 메모리를 페이지 크기와 같은 고정 크기로 나눈 블록');

-- Step10 Slot2 (OX) [local id=50]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', 'LRU 페이지 교체 알고리즘은 앞으로 가장 오랫동안 사용되지 않을 페이지를 정확히 예측하여 교체한다.', NULL, 'X',
        '[[LRU]]는 과거 사용 이력을 바탕으로 가장 오래 전에 사용된 페이지를 교체한다.\n반면 [[OPT]]는 미래에 가장 나중에 사용될 페이지를 교체하는 이론적 기준이다.\n따라서 문장은 거짓이다.', '최근에 참조되지 않은 페이지를 내보내는 것이 [[LRU]]의 핵심이다.\n하지만 미래 참조를 정확히 알아야 하는 [[OPT]]와 달리, LRU는 과거 정보만 사용한다.\n그래서 실제 시스템에서는 근사 기법과 함께 쓰이는 경우가 많다.', '이 문장을 참으로 봤다면 [[LRU]]와 [[OPT]]를 혼동한 것이다. LRU는 ''앞으로''를 예측하지 않으며, 과거에 가장 오래 사용되지 않은 페이지를 선택한다. 미래 참조를 정확히 아는 알고리즘은 OPT이고, 이는 비교 기준으로 주로 사용된다.',
        10, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'LRU와 OPT의 가장 중요한 차이는 어떤 정보에 기반해 교체 대상을 고른다는 점인가?', 1, 1),
  (@qid, '실제 운영체제에서 순수 LRU를 그대로 구현하기 어려운 이유는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '최적 페이지 교체', 1),
  (@qid, '참조 지역성', 2),
  (@qid, 'LRU 근사 알고리즘', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'LRU', '가장 오랫동안 사용되지 않은 페이지를 교체하는 페이지 교체 알고리즘'),
  (@qid, 'OPT', '앞으로 가장 늦게 다시 사용될 페이지를 교체하는 이론적 최적 알고리즘');

-- Step10 Slot3 (MULTIPLE_CHOICE) [local id=51]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 FIFO 페이지 교체 알고리즘의 특징으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[FIFO]]는 메모리에 가장 먼저 들어온 페이지를 먼저 내보낸다.\n구현은 단순하지만 [[Belady의 이상 현상]]처럼 프레임 수를 늘려도 페이지 폴트가 증가할 수 있다.\n따라서 정답은 도착 순서만으로 교체 대상을 정한다는 선택지다.', '큐를 사용하면 [[FIFO]]를 쉽게 구현할 수 있다.\n하지만 [[Belady의 이상 현상]] 때문에 프레임을 늘렸는데도 성능이 나빠질 수 있어 주의가 필요하다.\n이 점은 스택 알고리즘 계열과 구별되는 중요한 특징이다.', '오답을 골랐다면 [[FIFO]]의 기준을 최근 사용 여부나 미래 예측과 혼동했을 수 있다. FIFO는 이름 그대로 먼저 들어온 페이지를 먼저 교체한다. 또한 [[Belady의 이상 현상]]이 나타날 수 있다는 점도 FIFO의 대표적 특징이다.',
        10, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '메모리에 가장 먼저 들어온 페이지를 먼저 교체한다.', 1, 1),
  (@qid, '앞으로 가장 늦게 사용될 페이지를 교체한다.', 0, 2),
  (@qid, '가장 최근에 사용된 페이지를 교체한다.', 0, 3),
  (@qid, '페이지의 수정 비트가 1인 페이지만 교체한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'FIFO에서 Belady의 이상 현상이 왜 중요한가?', 1, 1),
  (@qid, 'FIFO와 LRU는 교체 대상을 고르는 기준이 어떻게 다른가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '큐 자료구조', 1),
  (@qid, '페이지 폴트율', 2),
  (@qid, '스택 알고리즘', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'FIFO', '먼저 들어온 페이지를 먼저 교체하는 페이지 교체 알고리즘'),
  (@qid, 'Belady의 이상 현상', '프레임 수를 늘렸는데도 페이지 폴트 수가 증가할 수 있는 현상');

-- Step10 Slot4 (MULTIPLE_CHOICE) [local id=52]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드가 페이지 참조열을 순서대로 처리한다고 할 때, LRU 알고리즘의 설명으로 가장 알맞은 것은 무엇인가?', 'references = [1, 2, 3, 2, 4]\nframes = 3\n# 각 숫자는 페이지 번호를 의미한다.', NULL,
        '[[LRU]]는 가장 최근에 사용되지 않은 페이지를 교체한다.\n주어진 참조열에서 4를 적재할 때는 가장 오래 전에 사용된 페이지 1이 교체 대상이 된다.\n따라서 정답은 페이지 1이 교체된다는 선택지다.', '참조열 1, 2, 3까지 처리하면 세 [[프레임]]이 모두 찬다.\n그다음 2를 다시 참조하면 2는 최신 사용 페이지가 되고, 4가 들어올 때 [[LRU]] 기준으로 1이 가장 오래전에 사용된 페이지가 된다.\n그래서 1이 교체된다.', '오답을 골랐다면 [[LRU]]가 ''가장 작은 번호''나 ''가장 먼저 들어온 페이지''를 고른다고 생각했을 수 있다. 하지만 LRU는 최근 사용 시점을 기준으로 판단한다. 이 참조열에서는 4를 넣는 순간 [[프레임]] 안의 1, 2, 3 중 1이 가장 오래전에 사용되었으므로 1이 교체된다.',
        10, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '페이지 2가 교체된다. 가장 최근에 다시 참조되었기 때문이다.', 0, 1),
  (@qid, '페이지 1이 교체된다. 가장 오래 전에 사용되었기 때문이다.', 1, 2),
  (@qid, '페이지 3이 교체된다. 가장 큰 번호가 아니기 때문이다.', 0, 3),
  (@qid, '어떤 페이지도 교체되지 않는다. 프레임이 자동으로 늘어나기 때문이다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '같은 참조열에서 FIFO를 적용하면 어떤 페이지가 교체되는가?', 1, 1),
  (@qid, 'LRU를 정확히 구현하려면 어떤 추가 정보가 필요한가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '참조열 분석', 1),
  (@qid, '최근 사용 시점', 2),
  (@qid, '페이지 교체 시뮬레이션', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'LRU', '가장 오랫동안 사용되지 않은 페이지를 교체하는 알고리즘'),
  (@qid, '프레임', '페이지가 적재되는 물리 메모리의 고정 크기 공간');

-- Step10 Slot5 (KEYWORD_BLANK) [local id=53]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '프로세스들이 동시에 과도한 페이지 폴트를 일으켜 CPU 이용률이 떨어지고, 운영체제가 더 많은 다중 프로그래밍을 허용하려 하면서 상황이 악화되는 현상을 ___이라고 한다.', NULL, NULL,
        '[[스래싱]]은 과도한 페이지 교체로 대부분의 시간이 실제 실행보다 메모리 관리에 쓰이는 상태다.\n이때 [[페이지 폴트]]가 급증하고 CPU 이용률은 오히려 낮아질 수 있다.\n작업 집합 조절이나 다중 프로그래밍 수준 감소가 대표적 대응 방법이다.', '동시에 많은 프로세스가 실행되는데 각 프로세스의 [[작업 집합]]을 담을 메모리가 부족하면 [[스래싱]]이 발생하기 쉽다.\n이 경우 시스템은 계속 페이지를 들고 나르느라 바빠지고, 사용자 프로그램의 진전은 느려진다.\n프로세스 수를 줄이거나 메모리 할당을 조정해 완화할 수 있다.', '정답을 쓰지 못했다면 [[스래싱]]을 단순한 한 번의 [[페이지 폴트]]와 혼동했을 수 있다. 스래싱은 개별 폴트 사건이 아니라, 폴트가 지나치게 많아 시스템 전체 성능이 급격히 떨어지는 상태를 말한다. 특히 메모리 부족과 과도한 다중 프로그래밍이 주요 원인이다.',
        10, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '스래싱'),
  (@qid, 1, 'thrashing');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '스래싱을 줄이기 위해 운영체제가 조절할 수 있는 대표적인 요소는 무엇인가?', 1, 1),
  (@qid, '작업 집합 모델은 스래싱을 설명할 때 왜 중요한가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '작업 집합 모델', 1),
  (@qid, '다중 프로그래밍 수준', 2),
  (@qid, 'CPU 이용률 저하', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '스래싱', '과도한 페이지 폴트와 페이지 교체로 시스템 성능이 급격히 저하되는 현상'),
  (@qid, '페이지 폴트', '참조한 페이지가 현재 물리 메모리에 없어서 발생하는 사건'),
  (@qid, '작업 집합', '프로세스가 일정 시간 동안 자주 참조하는 페이지들의 집합');

-- Step11 Slot1 (OX) [local id=54]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '연속 할당(contiguous allocation)은 하나의 파일을 디스크 상에서 연속된 블록들에 저장하는 방식이다.', NULL, 'O',
        '[[연속 할당]]은 파일의 데이터 블록을 디스크의 연속된 위치에 배치하는 방식이다.\n이 방식은 순차 접근과 임의 접근이 모두 빠를 수 있다.\n하지만 파일 크기가 늘어나면 [[외부 단편화]]와 확장 어려움이 문제가 될 수 있다.', '예를 들어 어떤 파일이 100번 블록부터 109번 블록까지 저장되면 이것은 [[연속 할당]]의 전형적인 형태다.\n이 경우 시작 블록과 길이만 알면 원하는 위치를 빠르게 계산할 수 있다.\n반면 중간중간 빈 공간이 흩어져 있으면 [[외부 단편화]] 때문에 새 파일을 연속으로 배치하기 어려워진다.', '이 문장은 맞다. [[연속 할당]]의 정의 자체가 파일을 연속된 블록들에 저장하는 것이다.\n만약 연결 리스트처럼 흩어진 블록을 포인터로 잇는 방식을 떠올렸다면 그것은 [[연결 할당]]에 가깝다.\n연속 저장 여부가 핵심 구분 기준이다.',
        11, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '연속 할당이 파일 확장에 불리한 이유는 무엇인가?', 1, 1),
  (@qid, '연속 할당에서 외부 단편화가 발생하는 원인을 설명해볼 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '외부 단편화', 1),
  (@qid, '연결 할당', 2),
  (@qid, '임의 접근', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '연속 할당', '파일을 디스크의 연속된 블록들에 저장하는 파일 할당 방식'),
  (@qid, '외부 단편화', '자유 공간이 여러 조각으로 흩어져 큰 연속 공간을 만들기 어려운 현상'),
  (@qid, '연결 할당', '파일 블록들을 포인터로 연결하여 저장하는 파일 할당 방식');

-- Step11 Slot2 (OX) [local id=55]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '트리 구조 디렉토리에서는 하나의 파일이 반드시 하나의 경로로만 접근 가능하므로, 같은 파일을 여러 디렉토리에서 공유할 수 없다.', NULL, 'X',
        '이 문장은 틀리다. 기본적인 [[트리 구조 디렉토리]]는 계층적 경로를 제공하지만, 시스템에 따라 [[링크]]를 통해 같은 파일을 여러 위치에서 참조할 수 있다.\n특히 하드 링크나 심볼릭 링크 같은 메커니즘은 파일 공유를 가능하게 한다.\n따라서 ''반드시 하나의 경로로만 접근 가능하다''는 일반화는 옳지 않다.', '유닉스 계열 시스템에서는 [[링크]]를 사용해 한 파일을 다른 디렉토리 항목으로도 가리킬 수 있다.\n이때 사용자는 서로 다른 경로로 같은 내용을 가진 파일 객체에 접근할 수 있다.\n즉 [[트리 구조 디렉토리]]가 있다고 해서 공유 가능성이 완전히 사라지는 것은 아니다.', '트리 형태의 디렉토리만 보고 항상 경로가 하나뿐이라고 생각하면 오답이 된다. [[링크]]는 디렉토리 엔트리가 기존 파일을 다시 참조하게 만든다.\n그래서 논리적 이름은 여러 개일 수 있고, 실제 파일 데이터는 하나일 수 있다.\n즉 [[트리 구조 디렉토리]]와 파일 공유 가능성은 서로 배타적인 개념이 아니다.',
        11, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '하드 링크와 심볼릭 링크의 차이는 무엇인가?', 1, 1),
  (@qid, '트리 구조 디렉토리의 장점은 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '하드 링크', 1),
  (@qid, '심볼릭 링크', 2),
  (@qid, '계층적 파일 시스템', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '트리 구조 디렉토리', '루트에서 시작해 하위 디렉토리로 분기되는 계층적 디렉토리 구조'),
  (@qid, '링크', '기존 파일이나 디렉토리를 다른 이름이나 경로로 참조하게 하는 메커니즘');

-- Step11 Slot3 (MULTIPLE_CHOICE) [local id=56]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 FAT(File Allocation Table) 방식의 특징으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[FAT]]는 각 디스크 블록 또는 클러스터의 연결 정보를 테이블에 저장하는 방식이다.\n파일의 다음 블록 위치를 테이블에서 따라가며 찾기 때문에 [[연결 할당]]의 성격을 가진다.\n구현은 단순하지만 큰 파일이나 큰 디스크에서는 탐색과 관리 효율이 떨어질 수 있다.', '예를 들어 어떤 파일이 5→9→13번 클러스터 순서로 저장되면 [[FAT]] 테이블에는 각 클러스터의 다음 위치가 기록된다.\n운영체제는 이 정보를 따라가며 파일 전체를 읽는다.\n이 구조는 [[연결 할당]]처럼 물리적으로 연속되지 않은 공간도 활용할 수 있게 한다.', '정답은 FAT가 블록 연결 정보를 테이블로 관리한다는 점이다. [[인덱스 블록]] 하나에 모든 포인터를 넣는 방식은 보통 인덱스 할당의 설명이다.\n또 파일이 반드시 연속된 블록에만 저장된다는 설명은 연속 할당의 특징이다.\n[[FAT]]는 연결 관계를 별도 테이블에 둔다는 점이 핵심이다.',
        11, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '파일의 모든 블록 주소를 하나의 인덱스 블록에만 저장한다.', 0, 1),
  (@qid, '파일은 반드시 연속된 블록에만 저장되어야 한다.', 0, 2),
  (@qid, '각 블록 또는 클러스터의 다음 위치 정보를 테이블로 관리한다.', 1, 3),
  (@qid, '디렉토리 엔트리에 파일의 모든 데이터가 직접 저장된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'FAT 방식이 큰 저장장치에서 비효율적일 수 있는 이유는 무엇인가?', 1, 1),
  (@qid, '인덱스 할당과 FAT 방식의 차이를 비교해볼 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '인덱스 할당', 1),
  (@qid, '클러스터', 2),
  (@qid, '파일 시스템 메타데이터', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'FAT', '파일 블록 또는 클러스터의 연결 정보를 테이블로 관리하는 파일 시스템 방식'),
  (@qid, '연결 할당', '파일 블록들을 연결 정보로 이어 저장하는 할당 방식'),
  (@qid, '인덱스 블록', '파일이 사용하는 데이터 블록들의 주소를 모아 둔 블록');

-- Step11 Slot4 (MULTIPLE_CHOICE) [local id=57]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드 지문이 설명하는 파일 할당 방식으로 가장 적절한 것은 무엇인가?', 'start = inode.indexBlock\nfor i in range(fileBlockCount):\n    dataBlock = read(start[i])\n    process(dataBlock)', NULL,
        '코드에서는 [[인덱스 블록]]에 저장된 블록 주소들을 순서대로 읽어 데이터 블록에 접근한다.\n이것은 파일의 데이터 블록 위치를 별도 색인 구조에 모아 두는 [[인덱스 할당]]의 전형적인 형태다.\n연속 저장을 강제하지 않으면서도 직접 접근이 가능하다는 장점이 있다.', '유닉스 계열 파일 시스템의 [[inode]]는 파일 메타데이터와 함께 데이터 블록 위치 정보를 가진다.\n작은 파일은 직접 포인터로, 더 큰 파일은 간접 블록을 통해 주소를 찾기도 한다.\n이처럼 주소 목록을 이용해 접근하는 발상은 [[인덱스 할당]]과 연결된다.', '정답은 인덱스 할당이다. 코드가 블록 주소 배열을 읽고 있으므로 [[인덱스 블록]] 기반 접근으로 봐야 한다.\n만약 다음 블록 포인터를 따라가며 이동했다면 연결 할당에 더 가깝다.\n또 시작 블록과 길이만으로 계산하는 구조가 아니므로 [[연속 할당]]도 아니다.',
        11, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '연속 할당', 0, 1),
  (@qid, '연결 할당', 0, 2),
  (@qid, '인덱스 할당', 1, 3),
  (@qid, '단일 수준 디렉토리', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '인덱스 할당이 직접 접근에 유리한 이유는 무엇인가?', 1, 1),
  (@qid, 'inode에서 직접 블록 포인터와 간접 블록 포인터는 어떤 차이가 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'inode', 1),
  (@qid, '직접 접근', 2),
  (@qid, '간접 블록', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '인덱스 블록', '파일 데이터 블록들의 주소를 모아 저장하는 블록'),
  (@qid, '인덱스 할당', '파일의 데이터 블록 주소를 별도 인덱스 구조에 저장하는 할당 방식'),
  (@qid, 'inode', '유닉스 계열 파일 시스템에서 파일 메타데이터를 담는 자료구조'),
  (@qid, '연속 할당', '파일을 연속된 디스크 블록에 저장하는 방식');

-- Step11 Slot5 (KEYWORD_BLANK) [local id=58]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '유닉스 계열 파일 시스템에서 파일의 소유자, 권한, 크기, 데이터 블록 위치 같은 메타데이터를 저장하는 자료구조는 ___ 이다.', NULL, NULL,
        '[[inode]]는 파일 이름을 제외한 다양한 파일 메타데이터를 저장하는 핵심 자료구조다.\n여기에는 권한, 소유자, 크기, 시간 정보와 데이터 블록 위치 정보가 포함될 수 있다.\n반면 [[디렉토리 엔트리]]는 보통 파일 이름과 해당 inode를 연결하는 역할을 한다.', '사용자가 ls -i 같은 명령으로 inode 번호를 확인할 수 있는 시스템이 있다.\n같은 파일을 여러 이름으로 참조하는 [[하드 링크]]는 여러 디렉토리 항목이 하나의 inode를 가리키는 방식으로 이해할 수 있다.\n즉 이름과 실제 메타데이터 저장 위치를 분리하는 것이 [[inode]] 기반 구조의 중요한 특징이다.', '빈칸의 정답은 [[inode]]다. 파일 이름까지 모두 inode에 저장된다고 생각하면 혼동하기 쉽다.\n유닉스 계열에서는 이름은 보통 [[디렉토리 엔트리]] 쪽에서 관리되고, inode는 파일 자체의 메타데이터와 블록 위치를 담당한다.\n또 [[하드 링크]]는 여러 이름이 같은 inode를 가리킬 수 있음을 보여준다.',
        11, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, 'inode'),
  (@qid, 1, 'i-node');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '디렉토리 엔트리와 inode의 역할 차이를 설명할 수 있는가?', 1, 1),
  (@qid, '하드 링크가 inode와 어떤 관계를 가지는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '디렉토리 엔트리', 1),
  (@qid, '하드 링크', 2),
  (@qid, '파일 메타데이터', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'inode', '유닉스 계열 파일 시스템에서 파일 메타데이터와 블록 위치를 저장하는 자료구조'),
  (@qid, '디렉토리 엔트리', '파일 이름과 해당 파일의 식별 정보를 연결하는 디렉토리 항목'),
  (@qid, '하드 링크', '하나의 inode를 여러 디렉토리 이름으로 참조하는 링크 방식');

-- Step12 Slot1 (OX) [local id=59]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '버퍼링은 입출력 장치와 프로세스 사이의 속도 차이를 완화하기 위해 메모리의 중간 저장 공간을 사용하는 기법이다.', NULL, 'O',
        '[[버퍼링]]은 데이터 전송 중간에 메모리 공간을 두어 처리 속도 차이를 줄인다.\nCPU나 프로세스가 장치보다 빠르거나 느릴 때 대기 시간을 완화하는 데 유용하다.\n따라서 제시된 설명은 참이다.', '운영체제가 [[버퍼]]에 키보드 입력을 잠시 모아 두었다가 프로그램에 전달하면, 프로그램은 장치 속도에 직접 맞추지 않아도 된다.', '이 문장을 거짓으로 판단했다면 [[버퍼링]]의 목적을 다른 기법과 혼동한 것이다. 버퍼링은 중간 저장 공간을 사용해 생산자와 소비자의 속도 차이를 완화하는 대표적인 입출력 기법이다.',
        12, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '버퍼링과 캐싱은 목적이 어떻게 다른가?', 1, 1),
  (@qid, '단일 버퍼와 이중 버퍼의 차이는 무엇인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '이중 버퍼링', 1),
  (@qid, '입출력 성능 최적화', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '버퍼링', '입출력 과정에서 속도 차이를 줄이기 위해 중간 메모리 공간을 사용하는 기법'),
  (@qid, '버퍼', '데이터를 일시적으로 저장하는 메모리 영역');

-- Step12 Slot2 (OX) [local id=60]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '스풀링은 여러 작업의 출력을 디스크 등에 모아 두었다가 순서대로 처리하게 하므로, 프린터처럼 한 번에 하나의 작업만 처리하는 장치의 공유에 활용될 수 있다.', NULL, 'O',
        '[[스풀링]]은 작업 요청을 디스크 같은 보조 저장장치에 모아 두고 순차 처리한다.\n이 방식은 프린터처럼 동시에 하나의 작업만 수행하는 장치 공유에 적합하다.\n따라서 제시된 설명은 참이다.', '여러 사용자가 동시에 인쇄를 요청하면 운영체제는 [[프린터 큐]]에 작업을 쌓아 두고 한 장치가 차례대로 처리하게 한다.', '오답으로 판단했다면 [[스풀링]]을 단순한 메모리 버퍼와 혼동했을 가능성이 크다. 스풀링은 보통 디스크에 작업을 대기열 형태로 저장해 장치를 순차적으로 공유하게 만드는 방식이다.',
        12, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '버퍼링과 스풀링의 저장 위치와 사용 목적은 어떻게 다른가?', 1, 1),
  (@qid, '프린터 스풀러가 장애를 일으키면 어떤 문제가 발생할 수 있는가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '프린터 스풀러', 1),
  (@qid, '작업 대기열', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '스풀링', '입출력 작업을 디스크 등에 모아 두고 장치가 순서대로 처리하게 하는 기법'),
  (@qid, '프린터 큐', '인쇄 요청 작업들이 대기하는 순서 목록');

-- Step12 Slot3 (MULTIPLE_CHOICE) [local id=61]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 디스크 스케줄링 알고리즘 SSTF의 특징으로 가장 알맞은 것은 무엇인가?', NULL, NULL,
        '[[SSTF]]는 현재 헤드 위치에서 가장 가까운 요청을 먼저 처리한다.\n이 방식은 평균 탐색 시간을 줄일 수 있지만, 먼 요청은 오래 기다릴 수 있다.\n즉 처리 효율은 좋아질 수 있으나 [[기아]] 가능성이 있다.', '현재 헤드가 50에 있고 요청이 10, 48, 90이라면 [[탐색 시간]]을 줄이기 위해 48을 먼저 선택하는 식으로 동작한다.', '틀렸다면 [[SSTF]]와 FCFS 또는 SCAN의 동작 원리를 섞어 기억했을 수 있다. SSTF는 도착 순서가 아니라 현재 헤드에서 가장 가까운 실린더를 우선 선택하며, 이 때문에 먼 요청의 [[기아]]가 생길 수 있다.',
        12, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '도착한 순서대로 요청을 처리한다.', 0, 1),
  (@qid, '현재 헤드 위치에서 가장 가까운 요청을 우선 처리한다.', 1, 2),
  (@qid, '항상 바깥쪽 실린더에서 안쪽 실린더 방향으로만 이동한다.', 0, 3),
  (@qid, '모든 요청을 동일한 시간 안에 반드시 처리한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'SSTF에서 기아를 줄이기 위해 어떤 알고리즘을 고려할 수 있는가?', 1, 1),
  (@qid, 'SSTF와 SCAN은 헤드 이동 패턴이 어떻게 다른가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'FCFS 디스크 스케줄링', 1),
  (@qid, 'SCAN 알고리즘', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'SSTF', '현재 디스크 헤드 위치에서 가장 가까운 요청을 먼저 처리하는 스케줄링 알고리즘'),
  (@qid, '기아', '일부 요청이 계속 우선순위에서 밀려 매우 오래 기다리는 현상'),
  (@qid, '탐색 시간', '디스크 헤드가 원하는 실린더로 이동하는 데 걸리는 시간');

-- Step12 Slot4 (MULTIPLE_CHOICE) [local id=62]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 코드 상황에 대한 설명으로 가장 알맞은 것을 고르시오.', 'print(job1)\nprint(job2)\nprint(job3)', NULL,
        '여러 인쇄 요청을 즉시 장치에 직접 보내지 않고 모아 두었다가 처리하는 방식은 [[스풀링]]과 관련이 깊다.\n운영체제는 보통 디스크 기반의 대기열을 두고 프린터가 가능한 순서대로 작업을 꺼내 처리하게 한다.\n따라서 이 상황을 가장 잘 설명하는 개념은 [[스풀러]]를 통한 인쇄 작업 관리이다.', '여러 프로그램이 동시에 출력을 요청해도 [[스풀러]]가 각 작업을 저장해 두면 프린터 한 대가 순서대로 처리할 수 있다.', '틀렸다면 [[버퍼링]]과 스풀링의 차이를 놓쳤을 수 있다. 버퍼링은 주로 속도 차이 완화를 위한 임시 메모리 저장이고, 프린터처럼 독립적인 작업들을 줄 세워 장치 공유를 관리하는 것은 [[스풀링]]에 더 가깝다.',
        12, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '이 상황은 프린터 작업을 대기열에 저장해 순차 처리하는 스풀링의 예이다.', 1, 1),
  (@qid, '이 상황은 디스크 헤드 이동 거리를 최소화하는 SSTF의 예이다.', 0, 2),
  (@qid, '이 상황은 페이지 교체를 위한 LRU 캐시의 예이다.', 0, 3),
  (@qid, '이 상황은 CPU 스케줄링의 라운드 로빈만으로 설명된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, '프린터 스풀링에서 디스크를 사용하는 이유는 무엇인가?', 1, 1),
  (@qid, '버퍼링과 스풀링은 저장 위치와 작업 단위에서 어떻게 다른가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '인쇄 시스템', 1),
  (@qid, '장치 공유', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '스풀링', '입출력 작업을 저장해 두고 장치가 순서대로 처리하게 하는 방식'),
  (@qid, '스풀러', '스풀링 작업을 관리하는 운영체제 구성 요소'),
  (@qid, '버퍼링', '속도 차이 완화를 위해 데이터를 잠시 저장하는 기법');

-- Step12 Slot5 (KEYWORD_BLANK) [local id=63]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '디스크 스케줄링에서 헤드가 한 방향으로 이동하며 요청을 처리하다가 끝에 도달하면 방향을 바꾸어 다시 처리하는 방식은 ___ 알고리즘이다.', NULL, NULL,
        '[[SCAN]]은 디스크 헤드가 엘리베이터처럼 한 방향으로 이동하며 요청을 처리한다.\n끝 지점에 도달하면 방향을 바꾸어 반대편 요청들을 계속 처리한다.\n이 방식은 SSTF보다 공정성이 나아져 [[기아]]를 줄이는 데 도움이 된다.', '실린더 번호가 증가하는 방향으로 이동하며 요청을 처리한 뒤, 끝에서 반대로 이동하는 패턴은 [[엘리베이터 알고리즘]]이라고도 불린다.', '오답이라면 [[SCAN]]과 C-SCAN 또는 SSTF를 혼동했을 수 있다. SCAN은 끝까지 갔다가 방향을 바꾸는 방식이고, C-SCAN은 한쪽 방향만 서비스한 뒤 처음 위치로 되돌아가며, SSTF는 가장 가까운 요청을 고른다.',
        12, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, 'SCAN');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order) VALUES
  (@qid, 'SCAN과 C-SCAN의 서비스 공정성 차이는 무엇인가?', 1, 1),
  (@qid, 'SCAN이 SSTF보다 유리한 상황은 언제인가?', 0, 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'C-SCAN', 1),
  (@qid, '엘리베이터 알고리즘', 2);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'SCAN', '디스크 헤드가 한 방향으로 이동하며 요청을 처리하고 끝에서 방향을 바꾸는 스케줄링 알고리즘'),
  (@qid, '기아', '일부 요청이 계속 뒤로 밀려 오래 기다리는 현상'),
  (@qid, '엘리베이터 알고리즘', 'SCAN 알고리즘의 별칭으로, 엘리베이터처럼 왕복 이동하며 요청을 처리하는 방식');

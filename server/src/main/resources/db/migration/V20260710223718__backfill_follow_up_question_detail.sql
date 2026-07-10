-- 정식 커리큘럼 60문제의 꼬리질문 120건에 상세 콘텐츠를 채운다(#133).
-- 서버는 one_line_answer IS NULL 을 "상세 없음"으로 보고 그 꼬리질문을 해설 응답에서 제외한다.
-- 이 파일이 적용되기 전까지 실커리큘럼 해설 화면에는 꼬리질문이 하나도 노출되지 않았다.
--
-- 꼬리질문은 다른 문제로 라우팅되지 않는다 — 읽기 전용 설명 화면이라 스스로 콘텐츠를 갖는다(#108).
-- 마커 규칙은 해설 본문과 같되 사전이 다르다: 마커 안 문자열은 그 꼬리질문의
-- quiz_follow_up_keyword.keyword 와 정확히 일치한다(부모 문제의 quiz_keyword가 아니다).
--
-- id는 로컬과 prod가 다르므로 (step_order, slot_order) → quiz_id → (quiz_id, display_order) 로 찾는다.
-- 좌표가 어긋나 @fq가 NULL이 되면 이어지는 INSERT가 NOT NULL 제약에 걸려 마이그레이션이 실패한다(의도).
-- 이 파일은 저작본 JSON에서 스크립트로 생성했다(수기 전사 아님) — 내용을 임의로 고치지 않는다.

-- ===================== STEP 1: OS 개요와 역할(커널·시스템콜·인터럽트) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 1 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step1 Slot1 꼬리질문1: 사용자 모드와 커널 모드의 가장 큰 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '실행할 수 있는 명령과 접근할 수 있는 자원의 범위가 다릅니다 — [[커널 모드]]는 [[특권 명령]]까지 모두 실행할 수 있지만, [[사용자 모드]]는 제한된 명령만 실행할 수 있습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '커널 모드', 'CPU가 특권 명령을 실행하고 모든 메모리와 장치에 접근할 수 있는 실행 상태'),
       (@fq, '사용자 모드', '특권 명령 실행과 커널 메모리 접근이 차단된 제한된 실행 상태. 응용 프로그램이 실행되는 모드'),
       (@fq, '특권 명령', '장치 제어나 인터럽트 설정처럼 커널 모드에서만 실행이 허용되는 CPU 명령'),
       (@fq, '모드 비트', 'CPU가 현재 사용자 모드인지 커널 모드인지를 나타내는 하드웨어 상태 값');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'CPU는 자신이 지금 어느 모드로 실행 중인지를 [[모드 비트]]로 구분한다. [[커널 모드]]에서는 장치 제어나 인터럽트 설정 같은 [[특권 명령]]을 모두 실행할 수 있고 어떤 메모리 영역에도 접근할 수 있다. [[사용자 모드]]에서는 이런 명령이 차단되며, 억지로 시도하면 CPU가 예외를 일으켜 제어가 운영체제로 넘어간다.', 1),
       (@fq, '왜 나누는가', 'TEXT', '모드를 나누면 잘못 작성된 프로그램 하나가 다른 프로그램이나 운영체제를 망가뜨리지 못한다. 응용 프로그램은 평소 [[사용자 모드]]에 머무르고, 보호된 작업이 필요할 때만 시스템 콜로 [[커널 모드]] 진입을 요청한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step1 Slot1 꼬리질문2: 응용 프로그램이 하드웨어를 직접 제어하지 않도록 제한하는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '하드웨어를 직접 만지게 두면 [[보호]]가 깨지고 [[자원 공유]] 순서가 무너지기 때문에, 운영체제가 중간에서 장치 접근을 대신 수행합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '보호', '한 프로그램의 오류나 악의가 다른 프로그램과 운영체제에 영향을 주지 못하도록 격리하는 것'),
       (@fq, '자원 공유', '여러 프로그램이 하나의 장치를 순서대로 나눠 쓰도록 운영체제가 조정하는 일'),
       (@fq, '장치 드라이버', '특정 하드웨어를 제어하는 코드. 커널이 관리하며 응용 프로그램 대신 장치와 통신한다'),
       (@fq, '추상화', '장치마다 다른 제어 방식을 감추고 공통된 인터페이스로 제공하는 것');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '응용 프로그램이 디스크 컨트롤러를 직접 조작할 수 있다면 다른 프로그램의 파일을 덮어쓰거나 장치를 멈춰 세울 수 있다. 운영체제는 장치 접근을 독점해 요청마다 권한을 검사하고 순서를 정함으로써 [[보호]]와 [[자원 공유]]를 동시에 보장한다. 잘못된 요청은 커널이 걸러 내므로 오류의 영향이 그 프로그램 안에 갇힌다.', 1),
       (@fq, '부가 이점', 'TEXT', '장치를 실제로 다루는 일은 [[장치 드라이버]]가 담당하고, 응용 프로그램은 파일이나 소켓처럼 [[추상화]]를 거친 인터페이스만 본다. 덕분에 저장 장치가 HDD든 SSD든 같은 코드로 파일을 읽을 수 있다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 1 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step1 Slot2 꼬리질문1: 하드웨어 인터럽트와 소프트웨어 인터럽트의 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[하드웨어 인터럽트]]는 장치가 CPU 바깥에서 비동기로 보내는 신호이고, [[소프트웨어 인터럽트]]는 실행 중인 명령이 스스로 일으켜 동기적으로 발생한다는 점이 다릅니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '하드웨어 인터럽트', '키보드, 타이머, 디스크 같은 장치가 CPU에 보내는 신호. 실행 중인 명령과 무관한 시점에 들어온다'),
       (@fq, '소프트웨어 인터럽트', '실행 중인 명령 자체가 일으키는 인터럽트. 시스템 콜 명령이나 예외가 여기에 속한다'),
       (@fq, '트랩', '프로그램의 명령 실행이 의도적으로 또는 예외로 커널에 제어를 넘기는 것. 소프트웨어 인터럽트의 다른 이름'),
       (@fq, '인터럽트 벡터 테이블', '인터럽트 번호마다 어떤 처리 루틴으로 가야 하는지 주소를 담아 둔 표');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[하드웨어 인터럽트]]는 키보드 입력이나 타이머 만료처럼 CPU가 무슨 명령을 실행 중이든 상관없이 임의의 시점에 들어온다. [[소프트웨어 인터럽트]]는 시스템 콜 명령이나 0으로 나누기 같은 예외처럼 특정 명령을 실행하는 순간에 발생하므로, 같은 입력으로 다시 실행하면 같은 자리에서 다시 발생한다. 이런 성질 때문에 소프트웨어 인터럽트를 [[트랩]]이라고 부르기도 한다.', 1),
       (@fq, '공통점', 'TEXT', '발생 원인은 달라도 처리 경로는 같다. CPU는 하던 일의 상태를 저장하고, [[인터럽트 벡터 테이블]]에서 번호에 맞는 처리 루틴 주소를 찾아 커널 모드로 점프한다. 처리가 끝나면 중단됐던 지점으로 돌아와 원래 흐름을 이어 간다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step1 Slot2 꼬리질문2: 타이머 인터럽트가 운영체제에서 중요한 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[타이머 인터럽트]]가 있어야 운영체제가 CPU를 다시 돌려받을 수 있고, 그래야 [[선점형 스케줄링]]으로 어떤 프로그램도 CPU를 독점하지 못하게 막을 수 있습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '타이머 인터럽트', '하드웨어 타이머가 일정 주기마다 CPU에 보내는 인터럽트. 제어를 커널로 되돌리는 장치'),
       (@fq, '선점형 스케줄링', '실행 중인 프로세스에서 CPU를 강제로 회수해 다른 프로세스에 넘기는 방식'),
       (@fq, '타임 슬라이스', '한 프로세스가 한 번에 CPU를 사용할 수 있도록 배정된 시간 조각'),
       (@fq, '문맥 교환', '실행 중이던 프로세스의 상태를 저장하고 다른 프로세스의 상태를 복원해 CPU를 넘겨주는 작업');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'CPU는 한 번에 하나의 코드만 실행하므로, 사용자 프로그램이 도는 동안 운영체제는 아무 일도 하지 못한다. 하드웨어 타이머가 정해진 주기마다 [[타이머 인터럽트]]를 걸어야 제어가 커널로 돌아오고, 커널은 그 시점에 [[타임 슬라이스]]를 다 쓴 프로세스에서 CPU를 회수한다. 이 장치가 없으면 무한 루프에 빠진 프로그램 하나가 시스템 전체를 멈춰 세운다.', 1),
       (@fq, '무엇을 가능하게 하는가', 'TEXT', '[[선점형 스케줄링]]은 [[타이머 인터럽트]] 위에서 동작한다. 커널은 인터럽트를 받은 김에 [[문맥 교환]]을 수행해 다음 프로세스를 CPU에 올린다. 시각 갱신이나 알람 만료처럼 시간에 기대는 작업도 같은 인터럽트를 계기로 처리된다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 1 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step1 Slot3 꼬리질문1: 라이브러리 함수 호출과 시스템 콜은 어떤 점에서 구분되는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[라이브러리 함수]]는 내 프로그램 안에서 그대로 실행되지만, [[시스템 콜]]은 [[모드 전환]]을 거쳐 커널이 대신 실행해 준다는 점이 다릅니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '라이브러리 함수', '프로그램에 링크되어 사용자 모드의 같은 주소 공간에서 실행되는 일반 함수'),
       (@fq, '시스템 콜', '응용 프로그램이 커널에 서비스를 요청하는 공식 인터페이스. 실행 중 커널 모드로 전환된다'),
       (@fq, '모드 전환', 'CPU의 실행 권한 수준이 사용자 모드와 커널 모드 사이에서 바뀌는 것'),
       (@fq, '래퍼 함수', '시스템 콜을 감싸 호출을 편하게 만들어 주는 라이브러리 함수');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[라이브러리 함수]]는 프로그램에 링크되어 사용자 모드의 같은 주소 공간에서 실행되므로, 호출 비용이 평범한 함수 호출과 다르지 않다. [[시스템 콜]]은 전용 명령으로 트랩을 일으켜 커널에 제어를 넘기고, 커널이 권한을 검사한 뒤 작업을 수행하고 돌아온다. 이 [[모드 전환]] 때문에 시스템 콜은 같은 일을 하는 라이브러리 함수보다 훨씬 비싸다.', 1),
       (@fq, '헷갈리는 지점', 'TEXT', '함수 이름만 보고는 어느 쪽인지 알 수 없다. C의 printf는 [[라이브러리 함수]]지만 내부에서 결국 write [[시스템 콜]]을 부르고, glibc의 read는 시스템 콜을 얇게 감싼 [[래퍼 함수]]다. 소스에서는 똑같은 함수 호출로 보여도 실제로 커널에 들어가는지는 구현을 봐야 안다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step1 Slot3 꼬리질문2: 파일 입출력 작업이 왜 커널의 도움이 필요한가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '디스크는 모든 프로세스가 함께 쓰는 자원이라, [[접근 권한 검사]]와 블록 배치를 커널이 독점해야 파일이 안전하게 유지되기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '접근 권한 검사', '요청한 프로세스가 그 파일을 읽거나 쓸 자격이 있는지 커널이 확인하는 절차'),
       (@fq, '파일 시스템', '디스크의 블록들을 파일과 디렉터리라는 구조로 관리하는 커널의 계층'),
       (@fq, '파일 디스크립터', '열린 파일을 가리키는 정수 식별자. 실제 파일 정보는 커널이 보관한다'),
       (@fq, '페이지 캐시', '디스크에서 읽은 데이터를 메모리에 보관해 두었다가 재사용하는 커널의 캐시');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '디스크에는 여러 사용자의 파일이 뒤섞여 있으므로, 아무나 원하는 블록을 읽고 쓰면 남의 데이터를 훔치거나 망가뜨릴 수 있다. 커널은 요청마다 [[접근 권한 검사]]를 하고, [[파일 시스템]]이 관리하는 메타데이터를 뒤져 그 파일이 실제로 어느 블록에 있는지 찾아 준다. 사용자 프로그램은 블록 번호를 알 필요도, 알아서도 안 된다.', 1),
       (@fq, '커널이 대신 해 주는 일', 'TEXT', '커널은 [[파일 디스크립터]]마다 열린 파일의 상태와 현재 읽기 위치를 대신 기억해 준다. 또 한 번 읽어 온 블록을 [[페이지 캐시]]에 남겨 두어, 같은 데이터를 다시 요청하면 디스크에 가지 않고 메모리에서 돌려준다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 1 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step1 Slot4 꼬리질문1: open과 read 같은 호출이 왜 커널의 개입을 필요로 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '디스크를 실제로 움직이는 일에는 [[특권 명령]]이 필요하고, 프로그램이 넘긴 버퍼가 정말 그 프로세스의 것인지 [[주소 검증]]도 해야 하므로 커널만 이 작업을 수행할 수 있습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '특권 명령', '장치 레지스터 접근처럼 커널 모드에서만 실행할 수 있는 CPU 명령'),
       (@fq, '주소 검증', '사용자 프로그램이 넘긴 버퍼 주소가 정말 그 프로세스의 영역인지 커널이 확인하는 절차'),
       (@fq, '장치 제어', '디스크 컨트롤러 같은 장치에 명령을 내리고 완료 인터럽트를 처리하는 일'),
       (@fq, '블로킹', '요청한 데이터가 준비될 때까지 프로세스를 대기 상태로 두는 것');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'open은 경로를 따라가 파일을 찾고 권한을 확인한 뒤 열린 파일 정보를 만드는데, 이 정보는 커널 메모리에 놓이므로 사용자 프로그램이 직접 만들 수 없다. read는 디스크 컨트롤러에 명령을 내리는 [[장치 제어]]를 동반하고, 그런 동작은 [[특권 명령]]으로만 가능하다. 게다가 커널은 프로그램이 넘긴 버퍼 주소를 그대로 믿지 않고 [[주소 검증]]을 거쳐야 커널 메모리를 덮어쓰는 공격을 막을 수 있다.', 1),
       (@fq, '호출 뒤에 일어나는 일', 'TEXT', '요청한 데이터가 아직 메모리에 없으면 커널은 디스크에 읽기를 지시하고 그 프로세스를 [[블로킹]] 상태로 재운다. 완료 인터럽트가 도착하면 커널이 데이터를 사용자 버퍼로 복사하고 프로세스를 다시 실행 가능 상태로 만든다. 기다리는 동안 CPU는 놀지 않고 다른 프로세스를 실행한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step1 Slot4 꼬리질문2: 사용자 모드에서 커널 모드로 전환될 때 어떤 보호 이점이 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '전환은 커널이 정해 둔 [[진입점]]으로만 일어나므로 사용자 코드가 커널의 임의 위치로 뛰어들 수 없고, [[메모리 보호]] 아래에서 검사를 통과한 요청만 수행됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '진입점', '커널이 미리 등록해 둔 고정된 통로. 모드 전환은 반드시 이 주소로만 들어간다'),
       (@fq, '메모리 보호', '사용자 코드가 커널 영역의 메모리를 읽거나 쓰지 못하도록 하드웨어가 막는 것'),
       (@fq, '인자 검증', '사용자 프로그램이 넘긴 값이 유효한지 커널이 사용하기 전에 확인하는 절차'),
       (@fq, '커널 스택', '모드 전환 시 사용자 스택 대신 사용하는, 프로세스마다 커널이 따로 두는 스택');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '모드 전환은 아무 데서나 일어나지 않는다. 시스템 콜 명령은 CPU를 커널 모드로 올리는 동시에 미리 등록된 [[진입점]]으로 점프시키므로, 프로그램은 커널 코드 중간으로 들어가 검사 부분을 건너뛸 수 없다. 커널 모드에 들어간 뒤에도 커널은 넘겨받은 값을 그대로 쓰지 않고 [[인자 검증]]을 먼저 수행한다.', 1),
       (@fq, '격리는 어떻게 유지되는가', 'TEXT', '[[메모리 보호]] 덕분에 사용자 모드에서는 커널이 쓰는 페이지에 아예 접근할 수 없고, 시도하면 예외가 발생해 커널이 그 프로그램을 중단시킨다. 전환 직후 CPU는 사용자 스택 대신 [[커널 스택]]으로 갈아타므로, 프로그램이 스택 포인터를 조작해 두었더라도 커널이 그 값을 그대로 쓰지 않는다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 1 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step1 Slot5 꼬리질문1: 시스템 콜이 필요한 대표적인 작업에는 어떤 것들이 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[프로세스 제어]], [[파일 조작]], [[장치 관리]], [[프로세스 간 통신]]처럼 보호된 자원을 건드리는 작업은 모두 시스템 콜을 거칩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '프로세스 제어', '프로세스를 생성하고, 기다리고, 종료하는 작업 갈래'),
       (@fq, '파일 조작', '파일을 열고 읽고 쓰고 닫는 작업 갈래'),
       (@fq, '장치 관리', '장치를 요청하고 반납하며 읽고 쓰는 작업 갈래'),
       (@fq, '프로세스 간 통신', '파이프, 소켓, 공유 메모리처럼 프로세스끼리 데이터를 주고받는 작업 갈래');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '교재는 시스템 콜을 쓰임새에 따라 몇 갈래로 나눈다. 프로세스를 만들고 끝내는 [[프로세스 제어]], 파일을 열고 읽고 쓰는 [[파일 조작]], 장치를 요청하고 반납하는 [[장치 관리]], 시각이나 프로세스 정보를 조회하는 정보 관리, 파이프와 소켓을 다루는 [[프로세스 간 통신]]이 대표적이다. 공통점은 하나같이 여러 프로세스가 함께 쓰는 자원을 건드린다는 것이다.', 1),
       (@fq, '반대로 필요 없는 것', 'TEXT', '메모리에 있는 값을 더하거나 문자열을 비교하는 계산에는 시스템 콜이 필요 없다. 자기 주소 공간 안에서 끝나는 일이라 다른 프로세스에 영향을 주지 않기 때문이다. 그래서 계산이 대부분인 프로그램은 커널에 거의 들어가지 않고도 빠르게 돈다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step1 Slot5 꼬리질문2: 시스템 콜 호출 시 사용자 모드와 커널 모드 사이에는 어떤 변화가 일어나는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[트랩]]이 발생해 CPU가 커널 모드로 올라가고, [[문맥 저장]]을 거쳐 [[시스템 콜 번호]]에 해당하는 커널 함수가 실행된 뒤 다시 사용자 모드로 내려옵니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '트랩', '소프트웨어가 의도적으로 일으켜 커널에 제어를 넘기는 인터럽트'),
       (@fq, '문맥 저장', '되돌아갈 수 있도록 레지스터와 프로그램 카운터 값을 보관해 두는 일'),
       (@fq, '시스템 콜 번호', '어떤 서비스를 요청하는지 나타내는 정수. 커널은 이 번호로 처리 함수를 고른다'),
       (@fq, '시스템 콜 테이블', '시스템 콜 번호와 그것을 처리하는 커널 함수를 짝지어 둔 표');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '프로그램은 요청할 서비스의 [[시스템 콜 번호]]를 약속된 레지스터에 담고 전용 명령을 실행한다. 이 명령이 [[트랩]]을 일으켜 CPU를 커널 모드로 올리고 미리 등록된 처리 루틴으로 점프시킨다. 커널은 돌아갈 자리를 잃지 않도록 [[문맥 저장]]을 먼저 하고, [[시스템 콜 테이블]]에서 번호에 맞는 함수를 찾아 실행한다.', 1),
       (@fq, '돌아올 때', 'TEXT', '커널 함수가 끝나면 반환값을 약속된 레지스터에 담고, 저장해 둔 문맥을 복원한 뒤 전용 복귀 명령으로 사용자 모드로 내려온다. 프로그램 입장에서는 함수 하나가 값을 돌려주고 끝난 것처럼 보이지만, 그 사이 CPU의 권한 수준은 올라갔다 내려온 것이다.', 2),
       (@fq, '주의점', 'TEXT', '이 왕복에는 적지 않은 비용이 든다. 그래서 한 바이트씩 read를 부르는 대신 큰 버퍼에 모아 한 번에 읽는 편이 훨씬 빠르다. 표준 입출력 라이브러리가 내부에 버퍼를 두는 이유도 시스템 콜 횟수를 줄이기 위해서다.', 3);

-- ===================== STEP 2: 프로세스 기본 개념(PCB·프로세스 상태 전이) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 2 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step2 Slot1 꼬리질문1: PCB에 저장되는 대표적인 정보 두 가지를 말해볼 수 있나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[프로세스 상태]]와 [[프로그램 카운터]]가 대표적이고, 그 밖에 [[CPU 레지스터]] 값과 스케줄링 정보도 PCB에 함께 저장됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '프로세스 상태', '프로세스가 지금 준비·실행·대기 중 어디에 있는지를 나타내는 값'),
       (@fq, '프로그램 카운터', '다음에 실행할 명령어의 주소를 담고 있는 레지스터'),
       (@fq, 'CPU 레지스터', 'CPU 안에서 연산 중간값과 주소를 임시로 담아 두는 저장 공간'),
       (@fq, '프로세스 식별자', '커널이 프로세스를 구분하기 위해 부여하는 고유 번호. 흔히 PID라고 부른다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'PCB에 담기는 정보는 크게 프로세스를 구분하는 값, 실행을 재개하는 데 필요한 값, 자원 관리를 위한 값으로 나뉜다. [[프로세스 식별자]]는 커널이 프로세스를 구분하는 고유 번호이고, [[프로세스 상태]]는 그 프로세스가 준비·실행·대기 중 어디에 있는지를 나타낸다. 실행을 이어가려면 다음에 실행할 명령의 주소인 [[프로그램 카운터]]와 연산 도중의 값을 담은 [[CPU 레지스터]] 값이 필요하다.', 1),
       (@fq, '함께 저장되는 것들', 'TEXT', '이 밖에도 우선순위나 대기열 위치 같은 스케줄링 정보, 열린 파일 목록과 메모리 영역 정보 같은 자원 정보가 PCB에 함께 관리된다. 어떤 항목을 두는지는 운영체제마다 다르지만, 프로세스를 중단했다가 그대로 되살리는 데 필요한 값이라는 점은 공통이다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step2 Slot1 꼬리질문2: 문맥 전환 시 PCB가 왜 필요한가요?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = 'CPU를 넘기는 프로세스의 [[실행 문맥]]을 어딘가에 적어 두어야 나중에 그대로 이어서 실행할 수 있는데, PCB가 바로 그 저장 장소이기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '실행 문맥', '프로세스가 중단된 지점부터 다시 이어가는 데 필요한 값 전체. 레지스터, 프로그램 카운터, 스택 포인터 등이 여기 속한다'),
       (@fq, '프로그램 카운터', '다음에 실행할 명령어의 주소를 담고 있는 레지스터'),
       (@fq, '스케줄러', '대기 중인 프로세스 가운데 다음에 CPU를 줄 하나를 고르는 운영체제 구성 요소');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'CPU 안의 레지스터는 한 벌뿐이라 다음 프로세스가 곧바로 덮어쓴다. 그래서 운영체제는 CPU를 넘기기 전에 [[프로그램 카운터]]를 비롯한 [[실행 문맥]]을 그 프로세스의 PCB에 옮겨 적고, 나중에 다시 CPU를 줄 때 PCB에서 값을 읽어 레지스터로 되돌려 놓는다. PCB가 없다면 중단된 프로세스는 어디까지 실행했는지 알 길이 없어 처음부터 다시 시작할 수밖에 없다.', 1),
       (@fq, '함께 보는 개념', 'TEXT', '[[스케줄러]]는 다음에 실행할 프로세스를 고르기만 하고, 실제로 값을 저장하고 복원하는 일은 문맥 전환 코드가 PCB를 통해 처리한다. 프로세스마다 PCB가 따로 있기 때문에 여러 프로세스가 동시에 중단돼 있어도 각자의 중단 지점이 섞이지 않는다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 2 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step2 Slot2 꼬리질문1: Ready 상태와 Running 상태의 차이는 무엇인가요?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[Ready]]는 CPU만 받으면 곧바로 실행할 수 있는 대기 상태이고, Running은 실제로 CPU를 할당받아 명령을 실행하고 있는 상태입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'Ready', 'CPU만 주어지면 곧바로 실행할 수 있는 상태. 실행에 필요한 다른 조건은 모두 갖춰져 있다'),
       (@fq, '준비 큐', 'Ready 상태의 프로세스들이 CPU를 기다리며 늘어서 있는 대기열'),
       (@fq, '디스패치', '스케줄러가 고른 프로세스에 실제로 CPU를 넘겨 실행시키는 동작');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '두 상태는 실행할 준비가 됐는지가 아니라 지금 CPU를 쥐고 있는지로 갈린다. [[Ready]] 상태의 프로세스는 필요한 자원을 모두 갖춘 채 [[준비 큐]]에서 차례를 기다리고, 스케줄러가 [[디스패치]]하는 순간 Running으로 바뀐다. 단일 CPU에서는 Running 상태인 프로세스가 언제나 하나뿐이지만, Ready 상태의 프로세스는 여럿일 수 있다.', 1),
       (@fq, '흔한 오해', 'TEXT', '[[Ready]]는 아직 준비가 덜 됐다는 뜻이 아니다. 오히려 실행에 필요한 자원을 모두 갖추고 CPU만 기다리는 상태다. 자원이 갖춰지지 않아 기다리는 쪽은 Waiting이며, 두 상태를 뭉뚱그리면 상태 전이를 따라가기 어려워진다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step2 Slot2 꼬리질문2: I/O 완료 후 프로세스는 보통 어떤 상태로 이동하나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '곧바로 실행되는 것이 아니라 Waiting에서 Ready 상태로 옮겨져 [[Ready 큐]]에서 다시 CPU 차례를 기다립니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '인터럽트', '하드웨어나 소프트웨어가 CPU에 사건 발생을 알려 현재 실행을 잠시 멈추게 하는 신호'),
       (@fq, 'Ready 큐', '실행 준비를 마친 프로세스들이 CPU 할당을 기다리며 늘어서는 대기열'),
       (@fq, '스케줄러', '대기 중인 프로세스 가운데 다음에 CPU를 줄 하나를 고르는 운영체제 구성 요소');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'I/O가 끝나면 장치 컨트롤러가 [[인터럽트]]를 걸어 완료 사실을 운영체제에 알린다. 운영체제는 그 I/O를 기다리던 프로세스를 찾아 Waiting에서 Ready로 옮기고 [[Ready 큐]]에 넣는다. 그 프로세스가 다시 Running이 되는 시점은 [[스케줄러]]가 그를 고를 때이므로, I/O 완료와 실행 재개는 같은 순간이 아니다.', 1),
       (@fq, '주의점', 'TEXT', 'I/O가 끝난 순간 곧바로 CPU를 되찾는다고 오해하기 쉽다. 완료 [[인터럽트]]는 프로세스를 실행시키는 것이 아니라 다시 경쟁에 참여할 자격을 돌려줄 뿐이다. 우선순위가 높은 프로세스라면 곧 CPU를 받겠지만, 그 경로도 반드시 Ready를 거친다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 2 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step2 Slot3 꼬리질문1: 타임 슬라이스 만료 시에는 보통 어떤 상태 전이가 일어나나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '실행 중이던 프로세스가 Running에서 Ready로 내려가는 [[선점]]이 일어나고, 스케줄러가 준비 큐에서 다음 프로세스를 골라 CPU를 넘깁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '타임 슬라이스', '한 프로세스가 한 번에 연속으로 CPU를 사용할 수 있는 시간 상한'),
       (@fq, '타이머 인터럽트', '일정 시간이 지나면 하드웨어 타이머가 CPU에 거는 인터럽트. 운영체제가 스케줄링 기회를 얻는 근거가 된다'),
       (@fq, '선점', '실행 중인 프로세스에게서 운영체제가 CPU를 강제로 회수하는 것'),
       (@fq, '라운드 로빈', '모든 프로세스에 같은 크기의 타임 슬라이스를 돌아가며 나눠 주는 스케줄링 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[타임 슬라이스]]는 한 프로세스가 한 번에 CPU를 쓸 수 있는 시간 상한이다. 이 시간이 다 되면 [[타이머 인터럽트]]가 발생하고, 운영체제는 실행 중이던 프로세스의 문맥을 PCB에 저장한 뒤 그를 준비 큐 뒤로 보낸다. 이때 프로세스는 할 일이 남아 있으므로 Waiting이 아니라 Ready로 간다는 점이 중요하다.', 1),
       (@fq, '비교', 'TEXT', 'Running에서 Ready로 가는 [[선점]]은 프로세스가 스스로 CPU를 놓은 것이 아니라 빼앗긴 경우다. 반면 Running에서 Waiting으로 가는 전이는 프로세스가 I/O나 이벤트를 기다리려고 스스로 CPU를 반납한 경우다. [[라운드 로빈]] 스케줄링은 앞의 전이를 규칙적으로 일으켜 모든 프로세스에 시간을 고르게 나눠 준다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step2 Slot3 꼬리질문2: 프로세스 생성 직후 처음 들어가는 상태를 어떻게 설명할 수 있나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '먼저 [[New]] 상태에 놓였다가, 운영체제가 실행에 필요한 자원을 마련해 [[승인]]하면 [[준비 큐]]로 들어가 Ready 상태가 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'New', '프로세스 자료구조는 만들어졌지만 아직 실행 준비가 끝나지 않아 준비 큐에 들어가지 못한 상태'),
       (@fq, '승인', '운영체제가 New 상태의 프로세스를 받아들여 준비 큐에 넣는 동작'),
       (@fq, '준비 큐', '실행 준비를 마친 프로세스들이 CPU를 기다리며 늘어서 있는 대기열');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[New]]는 PCB가 만들어지고 프로세스 식별자가 부여됐지만 아직 실행 대상으로 인정받지는 못한 상태다. 운영체제는 메모리 공간처럼 실행에 필요한 자원을 확보할 수 있는지 확인한 뒤, 가능하면 그 프로세스를 [[승인]]해 [[준비 큐]]에 넣는다. 이 시점부터 프로세스는 CPU만 받으면 실행될 수 있는 Ready 상태다.', 1),
       (@fq, '왜 따로 두는가', 'TEXT', '[[New]] 상태를 따로 두는 이유는 자원이 모자라 지금 당장 실행시킬 수 없는 프로세스를 붙들어 두기 위해서다. 한꺼번에 너무 많은 프로세스를 [[준비 큐]]에 올리면 메모리가 부족해 오히려 전체 성능이 떨어지므로, 운영체제는 [[승인]] 단계에서 그 수를 조절한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 2 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step2 Slot4 꼬리질문1: 선점형 스케줄링과 비선점형 스케줄링의 차이는 무엇인가요?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[선점형 스케줄링]]은 운영체제가 실행 중인 프로세스에게서 CPU를 강제로 회수할 수 있고, [[비선점형 스케줄링]]은 프로세스가 스스로 CPU를 놓을 때까지 기다립니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '선점형 스케줄링', '실행 중인 프로세스의 CPU를 운영체제가 강제로 회수할 수 있는 스케줄링 방식'),
       (@fq, '비선점형 스케줄링', '프로세스가 종료하거나 스스로 CPU를 놓을 때까지 기다리는 스케줄링 방식'),
       (@fq, '응답 시간', '요청이 들어온 뒤 첫 반응이 나오기까지 걸리는 시간');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[비선점형 스케줄링]]에서는 프로세스가 종료되거나 I/O를 요청해 Waiting으로 갈 때만 CPU가 다음 프로세스에게 넘어간다. 따라서 오래 걸리는 계산 작업 하나가 CPU를 붙들면 나머지 프로세스는 그동안 아무 일도 하지 못한다. [[선점형 스케줄링]]은 타이머 인터럽트 같은 장치를 이용해 실행 중인 프로세스를 Ready로 내리고 CPU를 회수하므로, 한 프로세스가 CPU를 독점하지 못한다.', 1),
       (@fq, '비교', 'TEXT', '선점형은 짧은 주기로 CPU를 돌려 [[응답 시간]]이 짧아지는 대신 문맥 전환이 잦아 그만큼 비용을 치른다. 비선점형은 문맥 전환이 적어 단순하지만, 대화형 프로그램이 뒤로 밀려 반응이 느려질 수 있다. 오늘날의 범용 운영체제는 대부분 선점형을 택한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step2 Slot4 꼬리질문2: 타이머 인터럽트가 없다면 어떤 문제가 생길 수 있나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '운영체제가 실행 중인 프로세스를 강제로 멈출 수단을 잃기 때문에, 프로그램 하나가 [[CPU 독점]]을 해도 시스템 전체가 멈춘 채 손쓸 수 없게 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'CPU 독점', '한 프로세스가 CPU를 계속 붙들고 놓지 않아 다른 프로세스가 실행되지 못하는 상황'),
       (@fq, '무한 루프', '종료 조건이 만족되지 않아 끝나지 않고 계속 반복되는 실행 흐름'),
       (@fq, '협조적 멀티태스킹', '각 프로그램이 스스로 CPU를 양보해 주기를 전제로 여러 프로그램을 번갈아 실행하는 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '타이머 인터럽트는 운영체제가 주기적으로 CPU를 되찾아 스케줄링 판단을 내리게 해 주는 장치다. 이것이 없으면 커널은 프로세스가 시스템 콜을 부르거나 스스로 끝날 때까지 실행될 기회를 얻지 못한다. 따라서 어떤 프로그램이 [[무한 루프]]에 빠지면 그 프로세스는 영영 CPU를 놓지 않고, 다른 프로세스는 물론 운영체제 자신도 개입할 수 없다.', 1),
       (@fq, '대안과 한계', 'TEXT', '[[협조적 멀티태스킹]]은 각 프로그램이 적당한 시점에 스스로 CPU를 양보하리라 믿는 방식이다. 프로그램 하나만 규칙을 어겨도 전체가 멈추기 때문에 안정성이 낮다. 오늘날의 운영체제는 타이머 인터럽트를 근거로 CPU를 강제로 회수해 이 신뢰 문제를 없앤다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 2 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step2 Slot5 꼬리질문1: 문맥 전환 시 PCB에 저장되는 정보에는 어떤 것들이 있나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '다음에 실행할 명령의 주소인 [[프로그램 카운터]], 스택의 꼭대기를 가리키는 [[스택 포인터]], 연산 중이던 [[범용 레지스터]] 값이 저장되고, 프로세스 상태와 [[메모리 관리 정보]]도 함께 갱신됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '프로그램 카운터', '다음에 실행할 명령어의 주소를 담고 있는 레지스터'),
       (@fq, '스택 포인터', '현재 스택의 꼭대기 주소를 가리키는 레지스터'),
       (@fq, '범용 레지스터', '연산 중간값과 주소를 담아 두는 CPU 내부의 일반 저장 공간'),
       (@fq, '메모리 관리 정보', '페이지 테이블 위치처럼 프로세스가 사용하는 주소 공간을 가리키는 값');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '문맥 전환은 CPU가 지금 보고 있는 값을 통째로 옮겨 적는 일이다. [[프로그램 카운터]]가 없으면 어느 명령부터 이어갈지 알 수 없고, [[스택 포인터]]와 [[범용 레지스터]]가 없으면 계산 도중의 값과 함수 호출 이력이 사라진다. 그래서 이 값들은 CPU를 넘기기 직전에 PCB로 옮겨지고, 그 프로세스가 다시 CPU를 받을 때 레지스터로 되돌려진다.', 1),
       (@fq, '레지스터 밖의 정보', 'TEXT', 'PCB에는 실행 재개에 직접 쓰이는 값 말고도 프로세스 상태, 우선순위 같은 스케줄링 정보, 페이지 테이블 위치 같은 [[메모리 관리 정보]]가 함께 들어 있다. 주소 공간이 다른 프로세스로 넘어갈 때는 이 값까지 바꿔야 하므로, 같은 프로세스에 속한 스레드끼리 전환할 때보다 비용이 크다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step2 Slot5 꼬리질문2: 문맥 전환이 너무 자주 일어나면 성능에 어떤 영향이 있나요?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '문맥을 저장하고 복원하는 [[오버헤드]]가 쌓이는 데다, 캐시와 [[TLB]]에 쌓아 둔 내용까지 쓸모없어져 정작 일하는 시간이 줄어듭니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '오버헤드', '본래 하려던 일이 아니라 그 일을 준비하고 관리하는 데 드는 추가 비용'),
       (@fq, 'TLB', '가상 주소를 물리 주소로 바꾼 결과를 담아 두는 주소 변환 전용 캐시'),
       (@fq, '캐시 지역성', '최근에 쓴 데이터와 그 주변을 다시 쓰게 되는 경향. 캐시 적중률을 높이는 근거가 된다'),
       (@fq, '처리량', '단위 시간 동안 완료한 작업의 양');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '문맥 전환 자체는 사용자 프로그램의 일을 조금도 진행시키지 않는 순수한 [[오버헤드]]다. 레지스터를 PCB에 옮기고 스케줄러가 다음 프로세스를 고르는 시간이 직접 비용이고, 여기에 눈에 잘 띄지 않는 간접 비용이 더해진다. 전환이 잦을수록 이 비용이 차지하는 비율이 커져 전체 [[처리량]]이 떨어진다.', 1),
       (@fq, '간접 비용', 'TEXT', '프로세스마다 다루는 데이터가 다르므로 전환 직후에는 캐시에 남아 있던 이전 프로세스의 데이터가 도움이 되지 않아 [[캐시 지역성]]이 깨진다. 주소 공간이 바뀌면 [[TLB]]에 저장해 둔 주소 변환 결과도 더 이상 쓸 수 없어 다시 채워야 한다. 그래서 타임 슬라이스를 지나치게 짧게 잡으면 응답성은 좋아져도 [[처리량]]은 오히려 나빠진다.', 2);

-- ===================== STEP 3: 스레드와 멀티스레딩 =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 3 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step3 Slot1 꼬리질문1: 스레드마다 독립적으로 유지되는 대표적인 메모리 영역은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '각 스레드는 자기 함수 호출 기록을 담는 [[스택]]과 실행 위치를 가리키는 [[프로그램 카운터]], 연산 중인 값을 담는 [[레지스터]]를 따로 가집니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '스택', '함수 호출 정보와 지역 변수가 쌓이는 메모리 영역. 스레드마다 하나씩 따로 할당된다'),
       (@fq, '프로그램 카운터', '다음에 실행할 명령어의 주소를 가리키는 레지스터. 스레드마다 값이 다르다'),
       (@fq, '레지스터', 'CPU 안에서 연산 중인 값을 잠깐 담아 두는 저장 공간. 문맥 교환 때 저장·복원된다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '스레드는 저마다 다른 함수를 호출하고 다른 지역 변수를 다루므로 [[스택]]을 독립적으로 할당받는다. 지금 어느 명령어를 실행할 차례인지 가리키는 [[프로그램 카운터]]와 계산 중인 값을 담아 두는 [[레지스터]] 역시 스레드마다 따로 유지된다. 운영체제는 문맥 교환이 일어날 때 이 값들을 통째로 저장했다가 나중에 복원해, 각 스레드가 자기 흐름을 이어 가게 한다.', 1),
       (@fq, '흔한 오해', 'TEXT', '스레드가 가볍다는 말 때문에 메모리를 거의 쓰지 않는다고 오해하기 쉽다. 스레드를 만들 때마다 [[스택]]이 별도로 잡히므로, 스레드를 수천 개 띄우면 스택만으로도 상당한 메모리를 차지한다. 스레드가 가볍다는 것은 프로세스에 비해 생성 비용과 전환 비용이 낮다는 뜻이지 공짜라는 뜻이 아니다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step3 Slot1 꼬리질문2: 프로세스와 스레드의 자원 공유 범위는 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '프로세스끼리는 [[주소 공간]]이 분리돼 있어 [[프로세스 간 통신]] 수단을 거쳐야 하지만, 한 프로세스 안의 스레드들은 그 주소 공간과 [[파일 디스크립터]]를 그대로 함께 씁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '주소 공간', '프로세스가 사용할 수 있는 메모리 주소의 범위. 프로세스마다 독립적으로 주어진다'),
       (@fq, '프로세스 간 통신', '분리된 프로세스끼리 데이터를 주고받는 방법. 파이프, 소켓, 공유 메모리 등이 있다'),
       (@fq, '파일 디스크립터', '프로세스가 열어 둔 파일이나 소켓을 가리키는 정수 식별자. 같은 프로세스의 스레드들이 공유한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '프로세스는 운영체제가 자원을 할당하는 단위라 서로의 [[주소 공간]]에 직접 접근할 수 없다. 데이터를 주고받으려면 파이프나 소켓, 공유 메모리 같은 [[프로세스 간 통신]] 수단을 따로 마련해야 한다. 반면 같은 프로세스에 속한 스레드들은 코드와 전역 데이터, 힙, 그리고 열어 둔 [[파일 디스크립터]] 목록까지 공유하므로 전역 변수 하나를 여러 스레드가 곧바로 읽고 쓸 수 있다.', 1),
       (@fq, '주의점', 'TEXT', '공유 범위가 넓다는 것은 편리함과 위험을 동시에 뜻한다. 한 스레드가 잘못된 메모리 접근으로 죽으면 같은 [[주소 공간]]을 쓰는 프로세스 전체가 함께 내려가지만, 프로세스는 서로 격리돼 있어 하나가 죽어도 나머지는 살아남는다. 브라우저가 탭을 스레드가 아닌 프로세스로 분리하는 이유도 여기에 있다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 3 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step3 Slot2 꼬리질문1: 멀티스레딩이 오히려 성능을 떨어뜨리는 대표 원인은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '스레드를 늘릴수록 커지는 문맥 교환 비용과, 공유 자원을 두고 벌어지는 [[락 경합]]이 대표적인 원인입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '락 경합', '여러 스레드가 같은 락을 동시에 얻으려 다투며 대기하게 되는 상황'),
       (@fq, '거짓 공유', '서로 다른 스레드가 수정하는 변수들이 같은 캐시 라인에 놓여, 캐시가 불필요하게 무효화되며 성능이 떨어지는 현상'),
       (@fq, '암달의 법칙', '병렬화할 수 없는 순차 구간의 비율이 전체 성능 향상의 상한을 결정한다는 법칙');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '스레드가 코어 수보다 많아지면 운영체제가 CPU를 번갈아 배정하며 레지스터와 스택 포인터를 저장·복원하는 문맥 교환 비용이 계속 쌓인다. 공유 자원을 락으로 감싸면 [[락 경합]]이 생겨, 한 스레드가 임계 구역에 있는 동안 나머지는 대기하므로 그 구간은 사실상 순차 실행이 된다. 여기에 더해 서로 다른 스레드가 같은 캐시 라인에 놓인 변수를 각각 수정하면 [[거짓 공유]]가 일어나 캐시가 반복해서 무효화되고, 단일 스레드보다 느려지기도 한다.', 1),
       (@fq, '이론적 한계', 'TEXT', '[[암달의 법칙]]에 따르면 전체 작업 중 순차로 실행할 수밖에 없는 비율이 남아 있는 한, 코어를 아무리 늘려도 속도 향상에는 상한이 있다. 순차 구간이 전체의 10퍼센트라면 코어를 무한히 늘려도 최대 10배를 넘지 못한다. 그래서 병렬화 이전에 순차 구간을 얼마나 줄일 수 있는지부터 따져야 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step3 Slot2 꼬리질문2: CPU 바운드 작업과 I/O 바운드 작업에서 멀티스레딩 효과는 어떻게 다를 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[CPU 바운드]] 작업은 코어 수를 넘어서면 이득이 없지만, [[I/O 바운드]] 작업은 기다리는 동안 다른 스레드가 일할 수 있어 코어 수보다 많은 스레드로도 처리량이 늘어납니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'CPU 바운드', '실행 시간의 대부분을 CPU 연산에 쓰는 작업. 코어 수가 병렬 처리량의 상한이 된다'),
       (@fq, 'I/O 바운드', '실행 시간의 대부분을 디스크·네트워크 응답 대기에 쓰는 작업'),
       (@fq, '블로킹', '결과가 준비될 때까지 스레드가 아무 일도 하지 못하고 멈춰 기다리는 동작 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[CPU 바운드]] 작업은 계산 자체가 병목이라, 실제로 동시에 계산할 수 있는 코어 수만큼만 빨라진다. 코어보다 스레드를 많이 만들면 일이 나뉘는 게 아니라 문맥 교환만 늘어난다. [[I/O 바운드]] 작업은 디스크나 네트워크 응답을 기다리는 [[블로킹]] 구간이 길고 그동안 CPU가 놀기 때문에, 다른 스레드가 그 빈 시간을 채워 전체 처리량이 올라간다.', 1),
       (@fq, '실무 사용처', 'TEXT', '이미지 인코딩이나 암호 연산처럼 계산이 대부분인 작업은 코어 수에 맞춘 고정 크기 스레드 풀을 쓴다. 외부 API 호출이나 DB 조회가 많은 웹 서버는 스레드 풀을 코어 수보다 넉넉히 잡거나, 아예 [[블로킹]]을 피하는 비동기 방식으로 적은 스레드가 많은 요청을 처리하게 만든다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 3 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step3 Slot3 꼬리질문1: 임계 구역이란 무엇이며 왜 보호해야 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[임계 구역]]은 여러 스레드가 [[공유 자원]]에 접근하는 코드 구간이며, 한 번에 하나의 스레드만 들어가도록 [[상호 배제]]를 보장해야 값이 깨지지 않습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '임계 구역', '여러 스레드가 공유 자원에 접근하므로 동시에 실행되면 안 되는 코드 구간'),
       (@fq, '공유 자원', '여러 스레드가 함께 읽고 쓰는 데이터나 장치. 전역 변수, 파일, 커넥션 풀 등'),
       (@fq, '상호 배제', '임계 구역에 한 번에 하나의 실행 흐름만 들어가도록 보장하는 성질');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[임계 구역]] 안의 갱신은 대개 읽기, 수정, 쓰기의 여러 단계로 나뉘어 실행된다. 그 사이에 다른 스레드가 끼어들면 이미 낡아 버린 값을 기준으로 결과를 덮어써서 갱신이 유실된다. 그래서 락이나 세마포어로 [[상호 배제]]를 걸어, 한 번에 하나의 스레드만 [[공유 자원]]을 만지도록 만든다.', 1),
       (@fq, '주의점', 'TEXT', '임계 구역은 필요한 만큼만 짧게 잡는 것이 좋다. 보호 범위가 지나치게 넓으면 나머지 스레드가 대기하는 시간이 길어져 병렬성이 사라지고, 반대로 너무 좁으면 함께 보호해야 할 연산이 밖으로 새어 나가 경쟁 상태가 그대로 남는다. 네트워크 호출처럼 오래 걸리는 작업은 [[임계 구역]] 밖으로 빼내는 편이 좋다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step3 Slot3 꼬리질문2: 뮤텍스와 세마포어는 어떤 차이가 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[뮤텍스]]는 한 번에 하나만 통과시키고 잠근 스레드가 [[소유권]]을 갖는 자물쇠이고, [[세마포어]]는 정해진 개수만큼 동시 접근을 허용하는 신호 장치입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '뮤텍스', '한 번에 하나의 스레드만 임계 구역에 들어가게 하는 잠금 장치. 잠근 스레드가 해제해야 한다'),
       (@fq, '세마포어', '내부 카운터로 동시 접근 가능한 수를 제한하거나 스레드 간 신호를 전달하는 동기화 도구'),
       (@fq, '소유권', '락을 획득한 스레드만 그 락을 해제할 수 있다는 규칙. 뮤텍스에는 있고 세마포어에는 없다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[뮤텍스]]는 잠금과 해제를 같은 스레드가 수행해야 한다는 [[소유권]] 개념이 있어, 임계 구역을 상호 배제로 보호하는 데 쓴다. [[세마포어]]는 내부에 카운터를 두고 값이 0보다 클 때만 통과시키므로, 동시에 접근할 수 있는 수를 N개로 제한하거나 스레드 사이에 신호를 주고받는 데 쓴다. 카운터가 1인 세마포어는 뮤텍스처럼 동작하지만 소유권이 없어 잠그지 않은 스레드가 해제할 수도 있다.', 1),
       (@fq, '실무 사용처', 'TEXT', '공유 변수 하나를 보호하거나 컬렉션을 안전하게 갱신할 때는 [[뮤텍스]]를 쓴다. DB 커넥션 풀처럼 자원이 N개뿐이라 동시 사용자 수를 N으로 묶어야 하거나, 생산자가 데이터를 넣었음을 소비자에게 알려야 할 때는 [[세마포어]]를 쓴다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 3 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step3 Slot4 꼬리질문1: 원자적 연산과 뮤텍스 기반 보호는 어떤 상황에서 각각 유리한가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '변수 하나를 갱신하는 짧은 연산은 락 없이 처리하는 [[원자적 연산]]이 빠르고, 여러 값을 한 덩어리로 일관되게 바꿔야 하면 [[뮤텍스]]로 묶는 편이 안전합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '원자적 연산', '중간에 다른 스레드가 끼어들 수 없도록 더 이상 쪼개지지 않는 단위로 처리되는 연산'),
       (@fq, '뮤텍스', '임계 구역을 한 번에 하나의 스레드만 실행하도록 보호하는 잠금 장치'),
       (@fq, 'CAS', 'Compare-And-Swap — 값이 예상과 같을 때만 새 값으로 바꾸는 CPU 명령. 원자적 연산의 기반이 된다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[원자적 연산]]은 CPU가 제공하는 [[CAS]] 같은 명령으로 읽기와 비교와 쓰기를 한 번에 끝내므로, 스레드를 대기 상태로 재우지 않는다. 그래서 카운터 증가나 플래그 전환처럼 대상이 하나뿐인 연산에서는 문맥 교환 비용 없이 갱신할 수 있다. 반대로 잔액을 빼면서 이체 기록도 함께 남기는 것처럼 여러 값이 동시에 바뀌어야 하면, 그 전체를 [[뮤텍스]]로 감싸야 중간 상태가 다른 스레드에 보이지 않는다.', 1),
       (@fq, '주의점', 'TEXT', '원자 변수를 여러 개 늘어놓는다고 그 조합까지 원자적이 되지는 않는다. 원자적 잔액 감소와 원자적 로그 추가를 이어 붙이면, 두 연산 사이에 끼어든 스레드가 어긋난 상태를 볼 수 있다. 또 경합이 아주 심하면 [[CAS]]가 실패해 재시도를 반복하느라 오히려 락보다 느려지기도 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step3 Slot4 꼬리질문2: 데드락과 경쟁 상태는 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[경쟁 상태]]는 실행 순서에 따라 결과가 틀어지는 정확성 문제이고, [[데드락]]은 서로의 락을 기다리느라 아무도 나아가지 못해 멈춰 버리는 진행성 문제입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '경쟁 상태', '여러 스레드의 실행 순서에 따라 결과가 달라지는 상태. 갱신 유실 같은 잘못된 값을 낳는다'),
       (@fq, '데드락', '여러 스레드가 서로 상대가 가진 자원을 기다리며 아무도 진행하지 못하는 상태'),
       (@fq, '순환 대기', '스레드들의 대기 관계가 고리를 이루어 처음으로 되돌아오는 구조. 데드락의 필요조건 중 하나');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[경쟁 상태]]에 빠진 프로그램은 멈추지 않고 계속 돌아가지만, 두 스레드의 실행이 겹친 순간에 갱신이 유실되어 잘못된 값을 남긴다. [[데드락]]은 값이 틀리는 것이 아니라 결과가 아예 나오지 않는다. 스레드들이 [[순환 대기]] 고리를 이루어, 서로가 쥔 락이 풀리기를 무한정 기다리기 때문이다.', 1),
       (@fq, '증상과 진단', 'TEXT', '[[경쟁 상태]]는 실행 시점의 타이밍에 좌우되므로 재현이 어렵고, 로그를 찍어 속도가 달라지는 순간 증상이 사라지기도 한다. [[데드락]]은 관련 스레드가 영원히 대기 상태로 남으므로, 스레드 덤프를 뜨면 누가 어떤 락을 쥐고 무엇을 기다리는지 그대로 드러난다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 3 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step3 Slot5 꼬리질문1: 데드락을 예방하기 위해 락 획득 순서를 통일하는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '모든 스레드가 같은 순서로 락을 잡으면 서로를 기다리는 고리인 [[순환 대기]]가 만들어질 수 없어, 데드락의 필요조건 하나가 깨지기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '순환 대기', '스레드들의 대기 관계가 고리를 이루어 서로를 무한히 기다리는 구조'),
       (@fq, '코프만 조건', '데드락이 성립하려면 상호 배제, 점유 대기, 비선점, 순환 대기가 동시에 만족해야 한다는 네 가지 조건'),
       (@fq, '자원 순서화', '자원에 전역 순서를 매기고 항상 그 순서대로만 획득하게 해 순환 대기를 막는 기법');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '데드락은 [[코프만 조건]] 네 가지가 동시에 성립할 때만 일어나므로, 그중 하나만 무너뜨려도 예방된다. 락마다 전역 번호를 매기고 언제나 작은 번호부터 잡는 [[자원 순서화]]를 적용하면, 어떤 스레드든 자기가 쥔 것보다 번호가 큰 락만 기다리게 된다. 번호가 커지기만 하는 대기 관계에서는 출발점으로 되돌아오는 [[순환 대기]] 고리를 만들 수 없다.', 1),
       (@fq, '주의점', 'TEXT', '순서를 통일하려면 어떤 락을 언제 잡는지 코드 전체에서 파악할 수 있어야 한다. 콜백이나 외부 라이브러리가 내부에서 몰래 락을 잡으면 순서를 보장할 수 없으므로, 락을 쥔 채 남의 코드를 호출하지 않는다는 규칙을 함께 지킨다. [[자원 순서화]]를 세우기 어려운 곳에서는 락 획득에 타임아웃을 걸고, 실패하면 쥔 락을 모두 놓았다가 재시도하는 방법을 쓴다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step3 Slot5 꼬리질문2: 기아 상태와 데드락은 어떻게 구분되는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[데드락]]은 얽힌 스레드 전부가 영원히 멈추는 상태이고, [[기아 상태]]는 시스템은 계속 돌아가는데 특정 스레드만 자원을 얻지 못하고 계속 밀리는 상태입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '데드락', '여러 스레드가 서로 상대가 가진 자원을 기다리며 모두 멈춰 버리는 상태'),
       (@fq, '기아 상태', '다른 스레드는 진행하는데 특정 스레드만 계속 자원을 얻지 못해 무한정 대기하는 상태'),
       (@fq, '라이브락', '스레드들이 멈추지는 않지만 서로 양보만 반복하며 실질적인 진행을 못 하는 상태');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[데드락]]에 빠진 스레드들은 서로가 쥔 자원을 기다리므로 외부 개입 없이는 누구도 진행하지 못한다. [[기아 상태]]에서는 다른 스레드들이 계속 자원을 얻어 일을 끝내지만, 우선순위가 낮거나 순번에서 밀리는 특정 스레드만 무한정 기다린다. 즉 데드락은 관련된 전체가 멈추고, 기아 상태는 일부만 진행하지 못한다.', 1),
       (@fq, '비교', 'TEXT', '진행은 하는데 아무 결과도 못 내는 [[라이브락]]도 있다. 두 스레드가 서로 양보하며 상태만 계속 바꾸느라 끝내 임계 구역에 들어가지 못하는 경우다. [[기아 상태]]는 오래 기다린 요청의 우선순위를 점점 올려 주는 에이징 기법으로, 라이브락은 재시도 간격에 무작위 지연을 섞는 방식으로 완화한다.', 2);

-- ===================== STEP 4: CPU 스케줄링 기초(FCFS·SJF·라운드로빈·우선순위) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 4 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step4 Slot1 꼬리질문1: FCFS에서 긴 작업이 앞에 오면 뒤의 짧은 작업들이 오래 기다리는 현상을 무엇이라고 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '긴 작업 하나가 CPU를 오래 붙들어 뒤의 짧은 작업들이 줄줄이 밀리는 현상을 [[호위 효과]]라고 합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '호위 효과', '긴 작업 하나가 CPU를 오래 점유해 뒤에 대기하던 짧은 작업들이 함께 지연되는 현상 (convoy effect)'),
       (@fq, '비선점형', '실행 중인 프로세스에서 CPU를 강제로 빼앗지 않고, 스스로 놓을 때까지 기다리는 방식'),
       (@fq, 'CPU 버스트', '프로세스가 입출력을 기다리지 않고 CPU를 연속으로 사용하는 구간'),
       (@fq, '평균 대기 시간', '각 프로세스가 준비 큐에서 자기 차례를 기다린 시간의 평균');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[호위 효과]]는 [[비선점형]]인 FCFS에서 [[CPU 버스트]]가 긴 프로세스가 먼저 도착했을 때 나타난다. 뒤에 선 짧은 작업들은 앞 작업이 끝날 때까지 CPU를 얻지 못하므로 전체 [[평균 대기 시간]]이 크게 늘어난다. 짧은 작업이 아무리 많아도 순서를 앞당길 방법이 없다는 점이 문제다.', 1),
       (@fq, '완화 방법', 'TEXT', '타임 퀀텀 단위로 CPU를 회수하는 라운드로빈이나, 짧은 작업을 먼저 뽑는 SJF를 쓰면 [[호위 효과]]를 줄일 수 있다. 실제 운영체제가 순수 FCFS를 단독으로 쓰지 않는 이유 중 하나다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step4 Slot1 꼬리질문2: FCFS와 라운드로빈의 가장 큰 차이는 선점 가능 여부 측면에서 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = 'FCFS는 한 번 CPU를 준 프로세스에서 이를 다시 빼앗지 않지만, 라운드로빈은 [[타임 퀀텀]]이 끝나면 CPU를 회수하는 [[선점]] 방식이라는 점입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '선점', '실행 중인 프로세스에서 운영체제가 CPU를 강제로 회수할 수 있는 성질 (preemption)'),
       (@fq, '타임 퀀텀', '라운드로빈에서 프로세스 하나가 연속으로 CPU를 쓸 수 있도록 허용된 시간 조각'),
       (@fq, '타이머 인터럽트', '정해진 시간이 지나면 하드웨어 타이머가 CPU에 걸어 제어를 운영체제로 되돌리는 신호'),
       (@fq, '문맥 교환', '실행 중인 프로세스의 상태를 저장하고 다른 프로세스의 상태를 복원해 CPU를 넘기는 작업');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'FCFS에서는 실행 중인 프로세스가 종료되거나 입출력을 기다리기 전까지 CPU를 놓지 않는다. 라운드로빈은 [[타임 퀀텀]]이 만료되면 운영체제가 [[타이머 인터럽트]]로 CPU를 거둬들여 프로세스를 준비 큐 맨 뒤로 보낸다. 이 [[선점]] 여부가 두 방식을 가르는 핵심 차이다.', 1),
       (@fq, '결과의 차이', 'TEXT', '그래서 FCFS는 뒤에 온 짧은 작업이 앞 작업이 끝날 때까지 아무 진전도 못 보지만, 라운드로빈은 모든 프로세스가 일정 주기로 CPU를 받는다. 대신 라운드로빈은 프로세스를 교대할 때마다 [[문맥 교환]] 비용을 치른다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 4 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step4 Slot2 꼬리질문1: 타임 퀀텀이 너무 작을 때 시스템 성능에 어떤 오버헤드가 증가하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '프로세스를 자주 갈아 끼우게 되어 [[문맥 교환]] 오버헤드가 증가합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '문맥 교환', '실행 중인 프로세스의 상태를 저장하고 다른 프로세스의 상태를 복원해 CPU를 넘기는 작업 (context switch)'),
       (@fq, '프로세스 제어 블록', '운영체제가 프로세스마다 유지하는 상태 정보 구조체 (PCB). 레지스터 값, 프로그램 카운터, 프로세스 상태 등을 담는다'),
       (@fq, '처리량', '단위 시간 동안 완료한 작업의 수 (throughput)');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[문맥 교환]]은 실행 중이던 프로세스의 레지스터와 프로그램 카운터를 [[프로세스 제어 블록]]에 저장하고, 다음 프로세스의 값을 복원하는 작업이다. 타임 퀀텀이 작을수록 이 교체가 잦아져 CPU가 실제 계산 대신 전환 작업에 쓰는 시간이 늘어난다. 그만큼 단위 시간당 [[처리량]]이 떨어진다.', 1),
       (@fq, '균형점', 'TEXT', '그렇다고 타임 퀀텀을 무작정 키우면 라운드로빈이 FCFS처럼 동작해 응답성이 나빠진다. 그래서 보통 타임 퀀텀은 대다수 프로세스의 CPU 버스트보다는 짧게, [[문맥 교환]]에 드는 시간보다는 충분히 길게 잡는다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step4 Slot2 꼬리질문2: 라운드로빈이 대화형 시스템에 자주 쓰이는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '모든 프로세스가 일정 시간 안에 차례를 받으므로 [[응답 시간]]이 짧고 예측 가능해, 사용자 입력에 곧바로 반응해야 하는 [[대화형 시스템]]에 잘 맞기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '응답 시간', '요청을 낸 뒤 첫 반응이 나오기까지 걸린 시간 (response time)'),
       (@fq, '대화형 시스템', '사용자의 입력에 즉시 반응해야 하는 시스템. 셸이나 데스크톱 환경이 대표적이다'),
       (@fq, '기아', '특정 프로세스가 CPU를 계속 얻지 못한 채 무기한 대기하는 상태 (starvation)');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '프로세스가 n개이고 타임 퀀텀이 q라면, 어떤 프로세스든 늦어도 n에서 1을 뺀 수에 q를 곱한 시간 안에는 다시 CPU를 받는다. 이 상한 덕분에 [[응답 시간]]이 특정 프로세스에만 몰리지 않고, 어떤 작업도 무한정 밀려나는 [[기아]]에 빠지지 않는다.', 1),
       (@fq, '다른 방식과의 비교', 'TEXT', 'FCFS는 앞선 긴 작업이 끝날 때까지 아무 반응이 없고, SJF는 긴 작업이 계속 뒤로 밀릴 수 있다. 라운드로빈은 평균 대기 시간 면에서 최적은 아니지만, 타자 입력이나 화면 갱신처럼 반응 속도가 체감 품질을 좌우하는 [[대화형 시스템]]에서는 공평한 교대가 더 중요하다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 4 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step4 Slot3 꼬리질문1: SJF에서 긴 작업이 계속 뒤로 밀려 실행되지 못하는 현상을 무엇이라고 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '짧은 작업이 계속 도착해 긴 작업이 영영 차례를 받지 못하는 현상을 [[기아]]라고 합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '기아', '특정 프로세스가 필요한 CPU나 자원을 계속 얻지 못하고 무기한 대기하는 상태 (starvation)'),
       (@fq, '준비 큐', 'CPU를 받을 준비가 끝난 프로세스들이 모여 자기 차례를 기다리는 큐'),
       (@fq, '에이징', '대기 시간이 길어진 프로세스의 우선순위를 점진적으로 높여 기아를 막는 기법 (aging)');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'SJF는 [[준비 큐]]에서 실행 시간이 가장 짧은 작업을 고르므로, 짧은 작업이 꾸준히 들어오면 긴 작업은 계속 뒤로 밀린다. 이렇게 특정 프로세스가 무기한 CPU를 얻지 못하는 상태가 [[기아]]다. 시스템 전체 처리량은 좋아 보여도, 밀려난 작업 입장에서는 사실상 멈춘 것과 같다.', 1),
       (@fq, '완화 기법', 'TEXT', '대기 시간이 길어질수록 그 작업의 우선순위를 조금씩 올려 주는 [[에이징]]을 함께 적용하면, 긴 작업도 언젠가는 가장 앞자리를 차지해 실행된다. 우선순위 스케줄링에서도 같은 문제에 같은 해법을 쓴다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step4 Slot3 꼬리질문2: SJF를 실제 시스템에서 구현하기 어려운 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '다음에 얼마나 오래 CPU를 쓸지, 즉 [[CPU 버스트]] 길이를 미리 정확히 알 수 없기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'CPU 버스트', '프로세스가 입출력을 기다리지 않고 CPU를 연속으로 사용하는 구간과 그 길이'),
       (@fq, '지수 평균', '과거 측정값의 가중치를 지수적으로 줄여 가며 다음 값을 추정하는 방법. 최근 값일수록 예측에 크게 반영된다'),
       (@fq, '배치 시스템', '사용자와 상호작용 없이, 미리 제출된 작업을 모아 순서대로 처리하는 시스템');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'SJF가 최적이 되려면 각 프로세스의 다음 [[CPU 버스트]] 길이를 알아야 하지만, 운영체제는 프로그램이 앞으로 무슨 일을 할지 미리 알 수 없다. 그래서 실제 구현은 과거 버스트 기록으로 다음 값을 추정하며, 최근 값에 더 큰 가중치를 주는 [[지수 평균]]이 대표적인 예측 방법이다. 추정이 빗나가는 만큼 SJF의 이론적 이점도 줄어든다.', 1),
       (@fq, '실제 적용', 'TEXT', '그래서 순수 SJF는 작업 시간을 사용자가 미리 제출하는 [[배치 시스템]]에서 주로 쓰였다. 오늘날의 범용 운영체제는 우선순위와 시간 조각을 조합한 다단계 큐 방식을 쓰면서, 짧은 작업을 우대한다는 SJF의 아이디어만 부분적으로 반영한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 4 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step4 Slot4 꼬리질문1: 우선순위 스케줄링에서 낮은 우선순위 프로세스가 계속 실행되지 못하는 문제를 완화하는 대표 기법은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '기다린 시간만큼 우선순위를 조금씩 올려 주는 [[에이징]]입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '에이징', '대기 시간이 길어진 프로세스의 우선순위를 점진적으로 높여 기아를 막는 기법 (aging)'),
       (@fq, '기아', '특정 프로세스가 CPU를 계속 얻지 못하고 무기한 대기하는 상태 (starvation)'),
       (@fq, '동적 우선순위', '실행 중에 대기 시간이나 시스템 상황에 따라 값이 바뀌는 우선순위. 처음 정한 값을 끝까지 쓰는 정적 우선순위와 대비된다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '우선순위가 고정돼 있으면, 높은 우선순위 작업이 계속 도착할 때 낮은 우선순위 프로세스는 CPU를 영영 받지 못하는 [[기아]]에 빠진다. [[에이징]]은 준비 큐에서 오래 기다린 프로세스의 우선순위를 일정 시간마다 한 단계씩 올린다. 충분히 기다린 작업은 결국 가장 높은 우선순위가 되어 실행되므로 무기한 대기가 사라진다.', 1),
       (@fq, '효과와 대가', 'TEXT', '[[동적 우선순위]]로 순위를 바꾸면 모든 작업의 실행이 보장되지만, 원래 의도했던 중요도 순서는 그만큼 흐려진다. 그래서 우선순위를 올리는 간격과 폭을 어떻게 잡을지가 설계 문제로 남는다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step4 Slot4 꼬리질문2: 비선점형 우선순위 스케줄링과 선점형 우선순위 스케줄링의 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '더 높은 우선순위 프로세스가 도착했을 때, 선점형은 실행 중인 프로세스에서 CPU를 즉시 빼앗지만 [[비선점형]]은 현재 작업이 끝날 때까지 기다립니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '비선점형', '실행 중인 프로세스가 스스로 CPU를 놓을 때까지 강제로 빼앗지 않는 방식'),
       (@fq, '준비 큐', 'CPU를 받을 준비가 끝난 프로세스들이 모여 자기 차례를 기다리는 큐'),
       (@fq, '문맥 교환', '실행 중인 프로세스의 상태를 저장하고 다른 프로세스의 상태를 복원해 CPU를 넘기는 작업');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[비선점형]]에서는 CPU를 얻은 프로세스가 종료하거나 입출력을 기다릴 때까지 실행을 이어 간다. 새로 도착한 더 높은 우선순위 프로세스는 [[준비 큐]]에서 다음 선택 시점이 올 때까지 기다려야 한다. 선점형은 도착 즉시 실행 중인 프로세스를 중단시키고 CPU를 넘긴다.', 1),
       (@fq, '트레이드오프', 'TEXT', '선점형은 급한 작업의 반응이 빨라 실시간 성격의 시스템에 유리하지만, [[문맥 교환]]이 잦아지고 공유 자원을 다루던 프로세스가 도중에 멈춰 동기화 문제가 생기기 쉽다. [[비선점형]]은 구현이 단순한 대신, 긴 작업이 실행 중이면 급한 작업도 그것이 끝날 때까지 기다려야 한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 4 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step4 Slot5 꼬리질문1: 타임 퀀텀이 너무 클 때 라운드로빈이 어떤 알고리즘과 비슷하게 동작하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[타임 퀀텀]]이 모든 프로세스의 [[CPU 버스트]]보다 길어지면, 사실상 도착 순서대로 끝까지 실행하는 [[FCFS]]와 같아집니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'FCFS', 'First Come First Served — 준비 큐에 먼저 도착한 프로세스에 CPU를 먼저 주는 비선점 스케줄링'),
       (@fq, '타임 퀀텀', '라운드로빈에서 프로세스 하나가 연속으로 CPU를 쓸 수 있도록 허용된 시간 조각'),
       (@fq, 'CPU 버스트', '프로세스가 입출력을 기다리지 않고 CPU를 연속으로 사용하는 구간');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '라운드로빈은 [[타임 퀀텀]]이 끝날 때 CPU를 회수하는데, 퀀텀이 버스트보다 길면 회수 시점이 오기 전에 프로세스가 스스로 끝난다. 결국 아무도 선점당하지 않고 준비 큐에 들어온 순서대로 실행이 완료되므로 [[FCFS]]와 구분되지 않는다. 라운드로빈의 선점 효과는 퀀텀이 [[CPU 버스트]]보다 짧을 때만 나타난다.', 1),
       (@fq, '반대 극단', 'TEXT', '퀀텀을 극단적으로 줄이면 프로세스들이 조금씩 번갈아 실행돼 모두가 CPU를 나눠 쓰는 것처럼 보이지만, 전환 비용 때문에 실제 처리 속도는 오히려 느려진다. 그래서 퀀텀은 대다수 [[CPU 버스트]]보다는 짧게, 문맥 교환에 드는 시간보다는 충분히 길게 잡는 것이 일반적인 기준이다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step4 Slot5 꼬리질문2: 문맥 교환 오버헤드는 왜 CPU 이용 효율을 낮출 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[문맥 교환]]이 일어나는 동안 CPU는 사용자 작업을 전혀 진행하지 못하고, 교환이 끝난 뒤에도 캐시가 식어 있어 한동안 느리게 동작하기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '문맥 교환', '실행 중인 프로세스의 상태를 저장하고 다른 프로세스의 상태를 복원해 CPU를 넘기는 작업 (context switch)'),
       (@fq, '프로세스 제어 블록', '운영체제가 프로세스마다 유지하는 상태 정보 구조체 (PCB). 레지스터 값, 프로그램 카운터, 프로세스 상태 등을 담는다'),
       (@fq, '캐시 지역성', '최근 접근한 데이터와 그 주변을 다시 접근하는 경향. 캐시는 이 성질에 기대어 성능을 낸다'),
       (@fq, 'TLB', 'Translation Lookaside Buffer — 가상 주소를 물리 주소로 변환한 결과를 캐싱해 주소 변환을 빠르게 하는 하드웨어 버퍼');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[문맥 교환]] 동안 CPU는 이전 프로세스의 레지스터와 프로그램 카운터를 [[프로세스 제어 블록]]에 저장하고, 다음 프로세스의 값을 복원한다. 이 시간에는 어떤 사용자 코드도 실행되지 않으므로 순수한 낭비다. 교환이 잦을수록 전체 실행 시간에서 이 낭비가 차지하는 비율이 커진다.', 1),
       (@fq, '숨은 비용', 'TEXT', '눈에 보이는 저장과 복원 시간 말고도, 새 프로세스가 실행되면 이전 프로세스가 채워 둔 캐시가 쓸모없어져 [[캐시 지역성]]이 깨진다. 주소 공간이 바뀌면 [[TLB]]에 남아 있던 항목도 무효화되므로 교환 직후의 메모리 접근은 평소보다 느리다. 그래서 [[문맥 교환]]의 실제 비용은 저장과 복원에 든 시간보다 크다.', 2);

-- ===================== STEP 5: CPU 스케줄링 심화(선점형·비선점형·멀티레벨 큐·기아와 에이징) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 5 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step5 Slot1 꼬리질문1: 비선점형 스케줄링에서는 어떤 시점에만 CPU가 다른 프로세스로 넘어갈 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '비선점형에서는 실행 중인 프로세스가 종료하거나 I/O 요청으로 [[대기 상태]]에 들어가는 등 스스로 CPU를 놓는 [[자발적 양보]] 시점에만 CPU가 다른 프로세스로 넘어갑니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '대기 상태', 'I/O 완료 같은 사건을 기다리느라 CPU를 쓰지 않는 프로세스 상태'),
       (@fq, '자발적 양보', '프로세스가 스스로 CPU를 반납해 다른 프로세스에 넘겨주는 행위'),
       (@fq, 'CPU 버스트', '프로세스가 I/O 없이 연속으로 CPU만 사용하는 구간'),
       (@fq, '문맥 교환', '실행 프로세스를 바꾸며 레지스터와 프로그램 카운터 등 실행 상태를 저장하고 복원하는 작업');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '비선점형 스케줄러는 실행 중인 프로세스에서 CPU를 강제로 회수하지 않는다. 그래서 전환은 프로세스가 [[CPU 버스트]]를 끝내고 종료하거나, I/O를 요청해 [[대기 상태]]로 옮겨 가거나, [[자발적 양보]]로 스스로 CPU를 내놓을 때만 일어난다. 세 경우 모두 프로세스가 자기 상태를 정리해 둔 안전한 지점이다.', 1),
       (@fq, '흔한 오해', 'TEXT', '비선점형이라고 해서 타이머 인터럽트가 발생하지 않는 것은 아니다. 인터럽트는 그대로 걸리지만 처리가 끝나면 CPU는 원래 프로세스로 돌아가고, 스케줄러는 [[문맥 교환]]을 일으키지 않는다. 인터럽트가 걸린다는 사실과 스케줄러가 실행 프로세스를 바꾼다는 사실은 별개다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step5 Slot1 꼬리질문2: 선점형 스케줄링이 대화형 시스템에서 유리한 이유는 무엇일까?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '한 프로세스가 CPU를 오래 붙잡고 있어도 [[시간 할당량]]이 끝나면 운영체제가 CPU를 회수해 다른 작업에 넘길 수 있어, 사용자 입력에 대한 [[응답 시간]]이 짧게 유지되기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '시간 할당량', '한 프로세스가 한 번에 연속으로 CPU를 사용할 수 있는 최대 시간'),
       (@fq, '응답 시간', '요청이 들어온 뒤 첫 반응이 나올 때까지 걸리는 시간'),
       (@fq, '문맥 교환', '실행 프로세스를 바꾸며 레지스터와 프로그램 카운터 등 실행 상태를 저장하고 복원하는 작업');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '대화형 작업은 CPU를 짧게 쓰고 곧 사용자 입력을 기다리는 특성이 있다. 선점형에서는 [[시간 할당량]]이 만료되는 순간 타이머 인터럽트가 스케줄러를 깨우므로, 긴 계산 작업 하나가 CPU를 독점해도 금방 회수된다. 덕분에 모든 작업이 일정 주기 안에 한 번씩 CPU를 잡고, 사용자가 체감하는 [[응답 시간]]이 예측 가능한 범위에 머무른다.', 1),
       (@fq, '치르는 대가', 'TEXT', '선점은 공짜가 아니다. 프로세스를 바꿀 때마다 레지스터와 메모리 매핑 정보를 저장하고 복원하는 [[문맥 교환]]이 일어나며, 그 시간 동안에는 어떤 작업도 진행되지 않는다. 대화형 시스템은 처리량을 조금 내주고 응답성을 사는 쪽을 택한 것이다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 5 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step5 Slot2 꼬리질문1: 비선점형 스케줄링이 선점형보다 구현이 단순한 이유는 무엇일까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '프로세스가 스스로 CPU를 놓는 안전한 순간에만 전환이 일어나므로, 임의의 시점에 중단됐을 때 생기는 [[경쟁 상태]]와 중간 상태 보존 문제를 다룰 필요가 없기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '경쟁 상태', '둘 이상의 실행 흐름이 공유 데이터를 동시에 다룰 때 실행 순서에 따라 결과가 달라지는 오류'),
       (@fq, '임계 구역', '한 번에 하나의 실행 흐름만 들어가야 하는 공유 자원 접근 구간'),
       (@fq, '문맥 교환', '실행 프로세스를 바꾸며 레지스터와 프로그램 카운터 등 실행 상태를 저장하고 복원하는 작업');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '선점형에서는 프로세스가 공유 자료구조를 반쯤 고쳐 놓은 [[임계 구역]] 한복판에서도 CPU를 빼앗길 수 있다. 그래서 커널은 락이나 인터럽트 차단으로 그 구간을 보호해야 하고, 설계를 놓치면 [[경쟁 상태]]가 생긴다. 비선점형에서는 전환 지점이 프로세스가 스스로 고른 안전한 위치뿐이라 이런 보호 장치가 훨씬 적게 필요하다.', 1),
       (@fq, '그 대가', 'TEXT', '구현이 단순한 대신 스케줄러가 아무것도 강제하지 못한다. 무한 루프에 빠진 프로세스는 CPU를 계속 붙잡고, 운영체제는 그것을 되찾을 방법이 없다. 오늘날 범용 운영체제가 [[문맥 교환]] 비용을 감수하고도 선점형을 쓰는 이유가 여기에 있다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step5 Slot2 꼬리질문2: 비선점형 방식에서 긴 작업 하나가 시스템 응답성에 미치는 영향은 무엇일까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '짧은 작업들이 긴 작업 하나 뒤에 줄줄이 밀리는 [[호위 효과]]가 나타나 [[평균 대기 시간]]이 크게 늘어납니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '호위 효과', '긴 작업 하나 때문에 뒤따르는 짧은 작업들이 한꺼번에 밀려 대기 시간이 급증하는 현상'),
       (@fq, '평균 대기 시간', '각 프로세스가 준비 큐에서 기다린 시간을 모두 더해 프로세스 수로 나눈 값'),
       (@fq, 'CPU 버스트', '프로세스가 I/O 없이 연속으로 CPU만 사용하는 구간');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '비선점형에서는 먼저 CPU를 잡은 작업이 [[CPU 버스트]]를 다 쓸 때까지 아무도 끼어들 수 없다. 긴 작업이 앞에 서면 뒤의 짧은 작업들은 자기 실행 시간과 무관하게 그만큼 기다려야 한다. 이렇게 짧은 작업이 긴 작업 뒤에 줄지어 밀리는 현상을 [[호위 효과]]라고 부른다.', 1),
       (@fq, '수치로 확인', 'TEXT', '실행 시간이 각각 100, 1, 1인 작업 세 개가 그 순서로 도착하면 대기 시간은 0, 100, 101이 되어 [[평균 대기 시간]]은 67이다. 순서만 1, 1, 100으로 바꾸면 대기 시간이 0, 1, 2가 되어 평균은 1로 떨어진다. 전체 작업량은 똑같은데 순서 하나로 체감 응답성이 완전히 달라진다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 5 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step5 Slot3 꼬리질문1: 멀티레벨 큐와 멀티레벨 피드백 큐의 가장 큰 차이는 무엇일까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '멀티레벨 큐는 프로세스를 한 큐에 [[고정 배정]]하는 반면, 멀티레벨 피드백 큐는 실행 양상을 보고 프로세스를 다른 큐로 옮기는 [[큐 간 이동]]을 허용한다는 점이 가장 큰 차이입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '고정 배정', '프로세스가 생성 시점에 정해진 큐에 계속 머무르며 다른 큐로 옮겨 가지 않는 방식'),
       (@fq, '큐 간 이동', '실행 특성이나 대기 시간에 따라 프로세스를 다른 우선순위의 큐로 옮기는 것'),
       (@fq, 'CPU 집중 프로세스', 'CPU 버스트가 길어 시간 할당량을 대부분 소진하는 계산 위주의 프로세스'),
       (@fq, '입출력 집중 프로세스', 'CPU를 짧게 쓰고 곧 I/O를 기다리는, 대화형 작업에 흔한 프로세스');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '멀티레벨 큐에서는 프로세스가 만들어질 때 성격에 따라 큐가 정해지고 그 뒤로는 바뀌지 않는다. 멀티레벨 피드백 큐는 실행을 관찰해 시간 할당량을 다 써 버린 프로세스를 아래 큐로 내리고, 오래 기다린 프로세스를 위 큐로 올린다. 결국 [[고정 배정]]이냐 [[큐 간 이동]]이냐가 두 방식을 가르는 핵심이다.', 1),
       (@fq, '왜 이동이 필요한가', 'TEXT', '프로세스의 성격은 미리 알기 어렵고 실행 도중에 바뀌기도 한다. 시간 할당량을 매번 다 쓰는 [[CPU 집중 프로세스]]는 아래 큐로 내려보내고, 짧게 쓰고 곧 입력을 기다리는 [[입출력 집중 프로세스]]는 위 큐에 두면 응답성이 좋아진다. 멀티레벨 피드백 큐는 이 분류를 미리 정하지 않고 실행 결과로 알아낸다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step5 Slot3 꼬리질문2: 상위 큐에 작업이 몰릴 때 하위 큐에서 어떤 문제가 발생할 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '상위 큐가 비어야만 하위 큐를 실행하는 [[절대 우선순위]] 규칙 때문에, 하위 큐의 작업은 상위 큐가 붐비는 동안 차례를 받지 못해 [[기아]]에 빠질 수 있습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '절대 우선순위', '상위 큐가 완전히 비어 있을 때만 하위 큐를 스케줄링하는 큐 간 순서 규칙'),
       (@fq, '기아', '실행 준비가 되어 있는데도 계속 선택되지 못해 무한정 CPU를 받지 못하는 상태'),
       (@fq, '큐 간 시간 분배', '각 큐에 전체 CPU 시간의 일정 비율을 나눠 주어 하위 큐의 실행도 보장하는 방식'),
       (@fq, '에이징', '기다린 시간이 길어질수록 우선순위를 점차 높여 기아를 완화하는 기법');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '많은 멀티레벨 큐 구현은 상위 큐에 프로세스가 하나라도 있으면 하위 큐를 아예 건드리지 않는 [[절대 우선순위]]를 쓴다. 대화형 작업이 끊임없이 도착하는 시스템에서는 상위 큐가 비는 순간이 좀처럼 오지 않는다. 그러면 하위 큐의 배치 작업은 실행 준비를 마친 채로 계속 남아 [[기아]]에 빠진다.', 1),
       (@fq, '완화 방법', 'TEXT', '각 큐에 CPU 시간의 비율을 미리 배정하는 [[큐 간 시간 분배]]를 쓰면 하위 큐도 최소한의 몫을 보장받는다. 또는 오래 기다린 프로세스의 우선순위를 올려 주는 [[에이징]]을 적용해 언젠가는 실행되도록 만든다. 두 방법 모두 상위 큐의 응답성을 조금 희생하고 공정성을 얻는 절충이다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 5 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step5 Slot4 꼬리질문1: 만약 실행 도중 priority=0인 새 프로세스가 도착하면 현재 실행 중인 프로세스에 어떤 일이 일어날까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = 'priority=0은 실행 중인 priority=1보다 우선순위가 높으므로, 실행 중이던 프로세스는 즉시 CPU를 빼앗겨 [[준비 상태]]로 돌아가고 새 프로세스가 곧바로 CPU를 받습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '준비 상태', '실행에 필요한 조건은 모두 갖췄고 CPU 배정만 기다리는 프로세스 상태'),
       (@fq, 'PCB', '프로세스 제어 블록. 레지스터 값, 프로그램 카운터, 상태 등 프로세스의 실행 정보를 담은 커널 자료구조'),
       (@fq, '잔여 버스트 시간', '프로세스가 이번 CPU 버스트를 마치기까지 아직 필요한 실행 시간');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '선점형 우선순위 스케줄링은 새 프로세스가 도착할 때마다 우선순위를 다시 비교한다. 숫자가 작을수록 우선순위가 높다는 규칙에 따라 priority=0이 실행 중인 priority=1을 앞선다. 커널은 실행 중이던 프로세스의 레지스터와 프로그램 카운터를 [[PCB]]에 저장하고 그 프로세스를 [[준비 상태]]로 되돌린 뒤, 새 프로세스에게 CPU를 넘긴다.', 1),
       (@fq, '선점된 프로세스의 운명', 'TEXT', '선점된 프로세스는 종료되지도, 처음부터 다시 시작하지도 않는다. 이미 실행한 만큼은 그대로 인정되고 [[잔여 버스트 시간]]만 남는다. 나중에 다시 선택되면 저장해 둔 [[PCB]]의 내용을 복원해 중단된 명령어부터 이어서 실행한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step5 Slot4 꼬리질문2: 동일 우선순위 프로세스가 여러 개라면 어떤 추가 규칙이 필요할까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '우선순위만으로는 순서가 완전히 정해지지 않으므로, 같은 우선순위끼리는 도착 순서를 따르는 [[FCFS]]나 시간 할당량을 돌아가며 쓰는 [[라운드 로빈]] 같은 [[동점 처리 규칙]]이 필요합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '동점 처리 규칙', '우선순위가 같은 프로세스들 사이에서 실행 순서를 정하는 보조 규칙'),
       (@fq, 'FCFS', 'First Come First Served. 준비 큐에 먼저 도착한 순서대로 CPU를 배정하는 방식'),
       (@fq, '라운드 로빈', '정해진 시간 할당량 단위로 프로세스들을 돌아가며 실행하는 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '우선순위는 전체 순서를 만들어 주지 못하고 같은 등급의 묶음만 만들어 준다. 그래서 실제 스케줄러는 각 우선순위 큐 안에서 다시 순서를 정하는 [[동점 처리 규칙]]을 함께 둔다. 이 규칙이 없으면 어느 프로세스가 먼저 실행되는지가 구현 세부에 따라 달라져 동작을 예측할 수 없다.', 1),
       (@fq, '규칙 선택의 결과', 'TEXT', '[[FCFS]]를 쓰면 먼저 도착한 프로세스가 끝날 때까지 같은 우선순위의 다른 프로세스가 기다린다. [[라운드 로빈]]을 쓰면 같은 등급끼리 시간 할당량을 나눠 쓰므로 응답 시간이 고르게 퍼진다. 대화형 작업이 많은 시스템은 라운드 로빈을, 처리량이 중요한 배치 시스템은 FCFS를 택하는 편이다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 5 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step5 Slot5 꼬리질문1: 에이징을 너무 빠르게 적용하면 어떤 부작용이 생길 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '낮은 우선순위 작업이 순식간에 최상위까지 올라와 우선순위 체계가 사실상 무의미해지고, 잦은 재정렬과 [[문맥 교환]]으로 [[스케줄링 오버헤드]]만 커집니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '문맥 교환', '실행 프로세스를 바꾸며 레지스터와 프로그램 카운터 등 실행 상태를 저장하고 복원하는 작업'),
       (@fq, '스케줄링 오버헤드', '다음 실행 대상을 고르고 자료구조를 갱신하는 데 쓰이는, 실제 작업이 아닌 CPU 시간'),
       (@fq, '마감 시간', '작업이 늦어도 그때까지는 반드시 끝나야 하는 시각');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '에이징은 기다린 시간에 비례해 우선순위를 올려 주는 기법이므로, 올리는 속도가 곧 정책의 전부다. 증가 속도가 지나치게 빠르면 모든 프로세스가 금세 같은 최상위 등급에 도달하고, 스케줄러는 우선순위가 아니라 도착 순서로만 결정하는 상태가 된다. 애초에 높은 우선순위를 부여하려던 작업이 누리던 이점이 사라지는 셈이다.', 1),
       (@fq, '실시간 시스템에서의 위험', 'TEXT', '우선순위가 작업의 급박함을 나타내는 시스템에서는 이 부작용이 더 치명적이다. 급박한 작업이 여유 있는 작업과 같은 등급으로 묶이면 [[마감 시간]]을 놓칠 수 있다. 게다가 우선순위가 자주 뒤바뀌면 실행 대상도 자주 바뀌어 [[문맥 교환]]이 늘고 실제로 일하는 시간이 줄어든다.', 2),
       (@fq, '균형점', 'TEXT', '실무의 에이징은 대기 시간이 일정 임계값을 넘었을 때만, 그것도 한 단계씩 보수적으로 올리도록 설계한다. 목적은 우선순위 순서를 뒤집는 것이 아니라 굶고 있는 프로세스를 구제하는 것이기 때문이다. 올리는 폭과 주기를 조절해 공정성과 우선순위 존중 사이의 균형을 잡는다.', 3);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step5 Slot5 꼬리질문2: 기아 문제는 멀티레벨 큐의 하위 큐에서도 발생할 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '상위 큐가 비어야만 하위 큐를 실행하는 [[절대 우선순위]] 구조라면 상위 큐에 작업이 끊이지 않는 한 하위 큐 프로세스는 영영 CPU를 받지 못하므로, 기아는 얼마든지 발생합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '절대 우선순위', '상위 큐가 완전히 비어 있을 때만 하위 큐를 스케줄링하는 큐 간 순서 규칙'),
       (@fq, '시간 할당량 분배', '전체 CPU 시간을 큐별 비율로 나눠 배정해 모든 큐의 실행 기회를 보장하는 방식'),
       (@fq, '큐 승격', '오래 기다린 프로세스를 더 높은 우선순위의 큐로 옮겨 실행 기회를 주는 조치');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '기아는 우선순위 스케줄링만의 문제가 아니라 선택되지 못하는 구조가 있는 곳이면 어디서든 나타난다. 멀티레벨 큐가 큐 사이의 순서를 [[절대 우선순위]]로 정하면 큐 번호가 곧 우선순위가 되고, 하위 큐는 상위 큐가 완전히 빌 때만 차례를 받는다. 대화형 작업이 계속 들어오는 서버라면 그 순간이 끝내 오지 않을 수 있다.', 1),
       (@fq, '구조적 해법', 'TEXT', '각 큐에 CPU 시간의 비율을 미리 정해 주는 [[시간 할당량 분배]]를 쓰면 상위 큐가 아무리 바빠도 하위 큐가 정해진 몫을 받는다. 고전적인 예로 상위 큐에 80퍼센트, 하위 큐에 20퍼센트를 배정하는 구성이 있다. 또는 오래 기다린 프로세스를 위 큐로 옮기는 [[큐 승격]]을 함께 두어 개별 프로세스를 구제한다.', 2);

-- ===================== STEP 6: 프로세스 동기화 기초(임계구역·뮤텍스·세마포어) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 6 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step6 Slot1 꼬리질문1: 임계구역 문제를 해결하기 위한 대표적인 조건인 상호 배제는 무엇을 의미할까?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[상호 배제]]는 한 실행 흐름이 임계구역에 들어가 있는 동안 다른 흐름은 그 구역에 들어올 수 없도록 막는 성질을 의미합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '상호 배제', '한 시점에 하나의 실행 흐름만 임계구역에 들어가도록 보장하는 성질'),
       (@fq, '진행', '임계구역이 비어 있다면 진입을 원하는 흐름 중 하나는 반드시 들어갈 수 있어야 한다는 조건'),
       (@fq, '한정 대기', '진입을 요청한 흐름이 무한히 밀리지 않고 유한한 횟수 안에 차례를 얻어야 한다는 조건');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[상호 배제]]는 공유 자원을 다루는 임계구역에 한 시점에 오직 하나의 실행 흐름만 존재하도록 보장한다. 한 스레드가 잠금을 쥐고 있는 동안 나머지 스레드는 진입하지 못하고 대기한다. 이 성질이 깨지면 두 흐름이 같은 데이터를 동시에 읽고 써서 결과가 어긋난다.', 1),
       (@fq, '나머지 두 조건', 'TEXT', '임계구역 문제의 해결 조건으로는 [[상호 배제]] 외에 [[진행]]과 [[한정 대기]]를 함께 든다. 진행은 임계구역이 비어 있다면 들어가려는 흐름 중 하나는 반드시 들어갈 수 있어야 한다는 뜻이다. 한정 대기는 진입을 요청한 흐름이 무한정 밀리지 않고 유한한 횟수 안에 차례를 얻어야 한다는 뜻이다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step6 Slot1 꼬리질문2: 공유 변수를 증가시키는 연산이 왜 임계구역이 되는지 설명할 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '공유 변수를 1 증가시키는 코드는 기계어 수준에서 [[읽기-수정-쓰기]] 세 단계로 나뉘어 [[원자적 연산]]이 아니기 때문에, 중간에 다른 실행 흐름이 끼어들면 증가가 사라질 수 있어 보호가 필요합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '읽기-수정-쓰기', '메모리 값을 읽어 와 계산한 뒤 다시 저장하는 세 단계 연산. 단계 사이에 다른 흐름이 끼어들 틈이 있다'),
       (@fq, '원자적 연산', '중간에 다른 실행 흐름이 끼어들 수 없어 전부 수행되거나 전혀 수행되지 않는 연산'),
       (@fq, '문맥 교환', 'CPU가 실행 중인 흐름을 잠시 멈추고 다른 흐름으로 전환하는 동작'),
       (@fq, '갱신 손실', '여러 흐름이 같은 원본 값을 읽고 각자 계산해 덮어써서 일부 갱신이 없던 일이 되는 현상');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '고급 언어에서 한 줄인 증가 연산도 실제로는 값을 레지스터로 불러오고, 1을 더하고, 다시 메모리에 저장하는 [[읽기-수정-쓰기]] 세 단계로 수행된다. 이 세 단계 사이에서 [[문맥 교환]]이 일어나면 두 스레드가 같은 원본 값을 읽고 각자 1을 더해 같은 값을 저장한다. 그래서 이 구간은 보호가 필요한 임계구역이 된다.', 1),
       (@fq, '갱신이 사라지는 과정', 'TEXT', '카운터가 0일 때 스레드 A와 B가 모두 0을 읽는다. A가 1을 저장한 뒤 B도 자신이 계산한 1을 저장하면 최종 값은 2가 아니라 1이 되는데, 이것이 [[갱신 손실]]이다. 증가 연산을 [[원자적 연산]]으로 만들거나 잠금으로 감싸면 한 스레드가 세 단계를 끝까지 마친 뒤에 다음 스레드가 시작한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 6 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step6 Slot2 꼬리질문1: 뮤텍스와 세마포어의 사용 방식 차이 중 하나를 말해볼 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '뮤텍스는 잠근 흐름이 직접 풀어야 하는 [[소유권]] 개념이 있는 반면, [[세마포어]]는 소유권이 없어 다른 흐름이 대신 값을 올려 줄 수 있습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '소유권', '잠금을 획득한 실행 흐름만 그 잠금을 해제할 수 있다는 규칙'),
       (@fq, '세마포어', '정수 카운터로 동시에 접근 가능한 개수를 제어하는 동기화 도구'),
       (@fq, '시그널링', '한 실행 흐름이 다른 흐름에게 사건이 일어났음을 알리는 동기화 용법');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '뮤텍스는 임계구역을 보호하는 잠금이고, 잠금을 획득한 흐름이 같은 잠금을 해제한다는 [[소유권]] 규칙을 따른다. [[세마포어]]는 정수 카운터라서 값을 줄인 흐름과 값을 늘리는 흐름이 서로 달라도 된다. 또 뮤텍스는 한 번에 하나만 통과시키지만, 세마포어는 초기값만큼 여러 흐름을 동시에 통과시킬 수 있다.', 1),
       (@fq, '실무 사용처', 'TEXT', '공유 자료구조를 짧게 보호할 때는 뮤텍스가 자연스럽다. 생산자가 데이터를 넣었다고 소비자에게 알리는 [[시그널링]]처럼 서로 다른 흐름이 신호를 주고받아야 한다면 [[세마포어]]가 어울린다. 자원 풀처럼 동시에 여러 개를 허용해야 하는 경우도 세마포어 쪽이 맞다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step6 Slot2 꼬리질문2: 잠금을 해제하지 않으면 어떤 문제가 생길 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '잠금을 획득한 뒤 해제하지 않으면 그 잠금을 기다리는 다른 실행 흐름들이 [[무한 대기]]에 빠져 [[임계구역]]에 영영 들어가지 못합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '무한 대기', '필요한 자원이 영영 풀리지 않아 실행 흐름이 계속 멈춰 있는 상태'),
       (@fq, '임계구역', '공유 자원에 접근하기 때문에 동시에 여러 흐름이 들어가면 안 되는 코드 구간'),
       (@fq, '교착 상태', '둘 이상의 실행 흐름이 서로가 점유한 자원을 기다리며 아무도 진행하지 못하는 상태');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '잠금은 획득과 해제가 짝을 이뤄야 한다. 해제를 빠뜨리면 잠금이 계속 점유된 상태로 남아, 그 잠금을 기다리던 흐름들이 [[무한 대기]] 상태가 된다. 대기하는 흐름들이 다른 자원까지 붙잡고 있다면 서로 맞물려 [[교착 상태]]로 번질 수도 있다.', 1),
       (@fq, '흔한 원인', 'TEXT', '[[임계구역]] 안에서 예외가 발생하거나 조건에 걸려 중간에 반환하면 해제 코드를 건너뛰기 쉽다. 그래서 언어마다 잠금 해제를 자동으로 보장하는 장치를 제공한다. 자바의 try-finally 블록이나 C++의 스코프 기반 잠금 객체가 그런 장치다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 6 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step6 Slot3 꼬리질문1: 이진 세마포어와 카운팅 세마포어의 차이는 무엇일까?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[이진 세마포어]]는 값이 0과 1뿐이라 한 번에 하나만 통과시키고, [[카운팅 세마포어]]는 값이 자원 개수만큼 커질 수 있어 여러 흐름을 동시에 통과시킵니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '이진 세마포어', '값이 0 또는 1만 가지는 세마포어. 잠금처럼 상호 배제에 쓰인다'),
       (@fq, '카운팅 세마포어', '0 이상의 정수 값을 가져 동일한 자원 여러 개를 관리하는 세마포어'),
       (@fq, '상호 배제', '한 시점에 하나의 실행 흐름만 임계구역에 들어가도록 보장하는 성질');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '세마포어는 내부에 정수 값을 두고, 진입을 요청하면 값을 하나 줄이며 값이 0이면 흐름을 대기시킨다. [[이진 세마포어]]는 이 값을 0과 1로만 제한해 사실상 잠금처럼 동작하므로 [[상호 배제]]를 구현하는 데 쓴다. [[카운팅 세마포어]]는 초기값을 n으로 두어 동시에 최대 n개의 흐름이 자원을 쓰도록 허용한다.', 1),
       (@fq, '예시', 'TEXT', '프린터가 한 대뿐이라면 [[이진 세마포어]]로 한 번에 하나의 작업만 출력하게 만든다. 데이터베이스 커넥션이 다섯 개인 풀은 [[카운팅 세마포어]]의 초기값을 5로 두어 여섯 번째 요청부터 대기시킨다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step6 Slot3 꼬리질문2: wait와 signal 연산은 각각 어떤 역할을 할까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[wait 연산]]은 세마포어 값을 하나 줄여 자원을 요청하고 값이 0이면 흐름을 재우며, [[signal 연산]]은 값을 하나 늘려 반납을 알리고 기다리던 흐름을 깨웁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'wait 연산', '세마포어 값을 1 줄이고 값이 0이면 실행 흐름을 대기시키는 연산. P 연산이라고도 한다'),
       (@fq, 'signal 연산', '세마포어 값을 1 늘리고 대기 중인 흐름을 깨우는 연산. V 연산이라고도 한다'),
       (@fq, '대기 큐', '자원을 얻지 못해 잠든 실행 흐름들이 차례를 기다리며 모여 있는 자료구조'),
       (@fq, '원자성', '연산이 중간에 끼어들기 없이 한 덩어리로 수행되는 성질');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[wait 연산]]은 P 연산이라고도 하며, 세마포어 값이 0보다 크면 값을 1 줄이고 그대로 진행한다. 값이 0이면 요청한 흐름을 [[대기 큐]]에 넣고 재운다. [[signal 연산]]은 V 연산이라고도 하며, 값을 1 늘리고 대기 큐에 기다리는 흐름이 있으면 그중 하나를 깨워 진입시킨다.', 1),
       (@fq, '주의점', 'TEXT', '두 연산은 반드시 [[원자성]]을 가져야 한다. 값을 검사하고 줄이는 사이에 다른 흐름이 끼어들면 세마포어 자신이 경쟁 상태에 빠지기 때문이다. 그래서 운영체제는 이 연산을 하드웨어가 보장하는 원자적 명령이나 인터럽트 차단으로 구현한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 6 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step6 Slot4 꼬리질문1: 초기값을 3으로 바꾸면 이 코드는 어떤 의미를 갖게 될까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '초기값이 3이면 [[상호 배제]]가 아니라 최대 세 개의 실행 흐름이 동시에 임계구역을 지나가도록 허용하는 [[카운팅 세마포어]]가 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '상호 배제', '한 시점에 하나의 실행 흐름만 임계구역에 들어가도록 보장하는 성질'),
       (@fq, '카운팅 세마포어', '0 이상의 정수 값을 가져 동시에 접근 가능한 개수를 제어하는 세마포어'),
       (@fq, '자원 풀', '미리 만들어 둔 동일한 자원 여러 개를 빌려 쓰고 반납하는 구조');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '초기값이 1일 때는 첫 진입에서 값이 0이 되므로 뒤따르는 흐름이 모두 막혀 한 번에 하나만 통과한다. 초기값이 3이면 세 번째 흐름까지는 값이 0보다 커서 그대로 통과하고, 네 번째 흐름부터 대기한다. 즉 [[상호 배제]]는 더 이상 보장되지 않고 동시 접근 개수의 상한만 3으로 제한된다.', 1),
       (@fq, '실무 사용처', 'TEXT', '이런 형태는 [[자원 풀]]의 크기를 제한할 때 쓴다. 커넥션 세 개짜리 풀이나 동시에 세 건까지만 처리하는 외부 호출 제한이 대표적이다. 다만 임계구역 안의 코드가 공유 데이터를 수정한다면 [[카운팅 세마포어]]만으로는 세 흐름이 동시에 망가뜨릴 수 있으므로 별도의 잠금이 더 필요하다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step6 Slot4 꼬리질문2: 뮤텍스로 같은 목적을 구현하면 코드 구조는 어떻게 달라질까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '초기값 선언이 사라지고 wait와 signal 대신 lock과 unlock을 호출하며, 잠근 흐름이 반드시 직접 풀어야 한다는 [[소유권]] 제약이 붙는 형태로 [[뮤텍스]] 코드가 달라집니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '소유권', '잠금을 획득한 실행 흐름만 그 잠금을 해제할 수 있다는 규칙'),
       (@fq, '뮤텍스', '상호 배제를 위한 잠금 도구. lock과 unlock으로 임계구역을 감싼다'),
       (@fq, '스코프 기반 잠금', '코드 블록을 벗어날 때 잠금이 자동으로 해제되도록 만든 장치');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '세마포어 코드는 초기값 1을 선언한 뒤 wait로 들어가고 signal로 나온다. [[뮤텍스]]는 개수 개념이 없으므로 초기값 선언이 필요 없고, lock으로 들어가 unlock으로 나온다. 동작 결과는 같지만 뮤텍스에는 잠근 흐름만 풀 수 있다는 [[소유권]] 규칙이 있어 다른 흐름이 실수로 해제하는 일을 막아 준다.', 1),
       (@fq, '주의점', 'TEXT', '[[뮤텍스]]를 쓰면 해제 누락이 곧바로 잠금 점유로 이어지므로, 많은 언어가 [[스코프 기반 잠금]]을 제공해 블록을 벗어날 때 자동으로 해제하도록 돕는다. 자바의 synchronized 블록과 C++의 lock_guard가 그런 예다. 세마포어로 상호 배제를 흉내 내면 이런 안전장치를 쓰기 어렵다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 6 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step6 Slot5 꼬리질문1: 상호 배제를 만족해도 교착 상태가 발생할 수 있는 이유는 무엇일까?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '상호 배제는 [[교착 상태]]가 성립하기 위한 네 가지 필요조건 중 하나일 뿐이어서, [[점유와 대기]]·[[비선점]]·[[순환 대기]]가 함께 만족되면 교착 상태가 발생합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '교착 상태', '둘 이상의 실행 흐름이 서로가 점유한 자원을 기다리며 아무도 진행하지 못하는 상태'),
       (@fq, '점유와 대기', '자원을 이미 쥔 채로 다른 자원을 추가로 기다리는 조건'),
       (@fq, '비선점', '다른 흐름이 점유한 자원을 강제로 빼앗을 수 없다는 조건'),
       (@fq, '순환 대기', '대기 관계가 원을 이루어 서로가 서로를 기다리는 조건');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[교착 상태]]는 상호 배제, [[점유와 대기]], [[비선점]], [[순환 대기]] 네 조건이 모두 성립할 때 일어난다. 상호 배제는 교착 상태를 막는 장치가 아니라 오히려 교착 상태의 전제 조건에 가깝다. 자원을 독점적으로 써야 하는 상황이기 때문에 서로가 서로의 자원을 기다리는 그림이 만들어질 수 있다.', 1),
       (@fq, '발생 시나리오', 'TEXT', '스레드 A가 잠금 1을 쥔 채 잠금 2를 기다리고, 스레드 B가 잠금 2를 쥔 채 잠금 1을 기다리면 둘 다 영원히 진행하지 못한다. 각 잠금은 한 번에 하나만 통과시키는 규칙을 완벽히 지키고 있다. 그럼에도 두 스레드가 자원을 쥔 채 다른 자원을 기다리고 그 대기 관계가 원을 이루기 때문에 아무도 앞으로 나아가지 못한다.', 2),
       (@fq, '예방 방법', 'TEXT', '모든 스레드가 잠금을 같은 순서로 획득하게 정하면 [[순환 대기]]가 깨져 [[교착 상태]]를 예방할 수 있다. 필요한 자원을 처음에 한꺼번에 요청하게 하면 [[점유와 대기]]가 사라진다. 잠금 획득에 제한 시간을 두어 실패하면 쥐고 있던 자원을 놓게 만드는 방식은 [[비선점]] 조건을 완화하는 효과가 있다.', 3);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step6 Slot5 꼬리질문2: 상호 배제를 구현하는 도구로 뮤텍스와 세마포어를 어떻게 사용할 수 있을까?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[뮤텍스]]는 [[임계구역]]을 lock과 unlock으로 감싸고, 세마포어는 초기값을 1로 둔 [[이진 세마포어]]로 만들어 wait와 signal로 감싸면 상호 배제가 구현됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '뮤텍스', '상호 배제를 위한 잠금 도구. lock과 unlock으로 임계구역을 감싼다'),
       (@fq, '임계구역', '공유 자원에 접근하기 때문에 동시에 여러 흐름이 들어가면 안 되는 코드 구간'),
       (@fq, '이진 세마포어', '값이 0 또는 1만 가지는 세마포어. 잠금처럼 상호 배제에 쓰인다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[뮤텍스]]를 쓸 때는 공유 자원을 건드리는 [[임계구역]] 직전에 lock을 호출하고 직후에 unlock을 호출한다. 세마포어를 쓸 때는 값을 1로 초기화해 [[이진 세마포어]]로 만들고, 진입 전 wait로 값을 0으로 낮춘 뒤 나올 때 signal로 되돌린다. 두 방식 모두 한 시점에 하나의 흐름만 임계구역을 지나가게 만든다.', 1),
       (@fq, '선택 기준', 'TEXT', '단순히 공유 데이터를 보호하는 목적이라면 [[뮤텍스]]가 의도를 더 분명히 드러내고, 잠근 흐름만 해제할 수 있어 실수도 줄여 준다. 세마포어는 초기값을 잘못 두면 상호 배제가 깨지고, 아무 흐름이나 signal을 호출해 값을 올려 버릴 수 있다. 그래서 상호 배제 자체가 목적이면 뮤텍스를, 자원 개수 제한이나 흐름 간 신호 전달이 목적이면 세마포어를 고른다.', 2);

-- ===================== STEP 7: 동기화 심화(생산자-소비자 문제·모니터·경쟁 상태) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 7 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step7 Slot1 꼬리질문1: 공유 버퍼에서 임계 구역이 되는 대표 데이터는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[공유 버퍼]] 배열 자체와, 다음에 넣고 뺄 위치를 가리키는 [[인덱스]], 그리고 현재 들어 있는 [[항목 개수]] 변수가 대표적입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '공유 버퍼', '생산자와 소비자가 함께 접근하는 저장 공간. 보통 크기가 정해진 배열로 구현한다'),
       (@fq, '인덱스', '버퍼에서 다음에 값을 넣거나 뺄 위치를 가리키는 변수'),
       (@fq, '항목 개수', '버퍼에 현재 들어 있는 데이터의 수를 세는 변수');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '생산자가 항목을 넣을 때는 [[인덱스]]를 읽고, 그 자리에 값을 쓰고, 인덱스를 옮기고, [[항목 개수]]를 늘린다. 이 여러 단계가 한 덩어리로 실행되지 않으면 다른 스레드가 중간에 끼어들어 같은 자리에 두 번 쓰거나 개수가 실제 내용과 어긋난다. 그래서 [[공유 버퍼]]의 배열과 그것을 가리키는 보조 변수들이 하나의 임계 구역으로 함께 묶인다.', 1),
       (@fq, '주의점', 'TEXT', '[[인덱스]]만 락으로 보호하고 [[항목 개수]] 갱신을 빼놓는 식으로 일부만 감싸면 상태는 여전히 어긋난다. 하나의 논리적 상태를 이루는 변수들은 같은 락 아래에서 함께 갱신해야 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step7 Slot1 꼬리질문2: 뮤텍스와 세마포어는 생산자-소비자 문제에서 각각 어떤 역할로 쓰일 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[뮤텍스]]는 버퍼를 한 번에 한 스레드만 만지게 하는 [[상호 배제]] 용도로, [[세마포어]]는 빈 칸과 찬 칸의 개수를 세어 넣고 뺄 시점을 조절하는 용도로 씁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '뮤텍스', '한 번에 하나의 스레드만 임계 구역에 들어가게 하는 상호 배제 락'),
       (@fq, '세마포어', '정수 값으로 자원의 개수를 관리하며 wait와 signal로 대기와 진행을 조절하는 동기화 도구'),
       (@fq, '상호 배제', '한 시점에 오직 하나의 스레드만 공유 자원을 사용하도록 보장하는 성질');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '생산자-소비자 구현에서는 보통 두 도구를 함께 쓴다. [[세마포어]] empty와 full은 버퍼에 남은 빈 칸 수와 채워진 항목 수를 세어, 넣을 자리가 없거나 꺼낼 항목이 없는 스레드를 대기시킨다. 그 뒤 실제로 버퍼를 건드리는 짧은 구간만 [[뮤텍스]]로 감싸 [[상호 배제]]를 보장한다.', 1),
       (@fq, '비교', 'TEXT', '[[뮤텍스]]는 잠근 스레드가 직접 풀어야 하는 소유권 개념이 있고 잠김과 풀림 두 상태만 가진다. [[세마포어]]는 소유자가 정해져 있지 않아 한 스레드가 기다리고 다른 스레드가 값을 올려 깨우는 신호 전달에 쓸 수 있다. 이 차이 때문에 개수 조절은 세마포어가, 짧은 구간 보호는 뮤텍스가 맡는다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 7 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step7 Slot2 꼬리질문1: 모니터에서 조건 변수가 필요한 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '상호 배제만으로는 원하는 상태가 될 때까지 기다릴 수 없어서, 락을 놓고 잠들었다가 다시 깨어나게 해 주는 [[조건 변수]]가 필요합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '조건 변수', '모니터 안에서 특정 상태 조건을 기다리고 알리는 대기 큐. wait와 signal 연산을 제공한다'),
       (@fq, '바쁜 대기', '조건이 만족될 때까지 반복문을 돌며 CPU를 계속 소모하는 대기 방식'),
       (@fq, 'wait', '조건 변수에서 스레드를 잠재우는 연산. 모니터 락을 놓고 대기 큐에 들어갔다가 깨어날 때 락을 다시 잡는다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[조건 변수]]가 없다면 스레드는 버퍼가 빌 때까지 반복문을 돌며 확인하는 [[바쁜 대기]]를 하거나, 락을 쥔 채로 멈춰 서게 된다. 락을 쥔 채 멈추면 상태를 바꿔 줄 다른 스레드가 모니터 안으로 들어오지 못해 아무도 진행하지 못한다. 조건 변수의 [[wait]]는 락을 놓는 일과 잠드는 일을 한 번에 처리해 이 문제를 없앤다.', 1),
       (@fq, '주의점', 'TEXT', '잠에서 깬 스레드가 곧바로 조건이 참이라고 믿으면 안 된다. 깨어나 락을 다시 잡는 사이에 다른 스레드가 상태를 바꿔 놓을 수 있으므로, [[wait]]는 조건을 다시 검사하는 반복문 안에서 호출한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step7 Slot2 꼬리질문2: 모니터와 세마포어를 사용할 때 코드 가독성 측면의 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[모니터]]는 락과 조건 대기를 데이터 곁에 [[캡슐화]]해 의도가 드러나지만, [[세마포어]]는 wait와 signal 호출이 코드 곳곳에 흩어져 규칙을 눈으로 좇아야 합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '모니터', '공유 데이터와 그 데이터를 다루는 연산을 하나로 묶어 상호 배제를 자동으로 보장하는 동기화 구조'),
       (@fq, '캡슐화', '데이터와 그 데이터를 다루는 연산을 한 단위로 묶고 외부에서 직접 건드리지 못하게 감추는 것'),
       (@fq, '세마포어', '정수 값으로 자원의 개수를 관리하며 wait와 signal로 대기와 진행을 조절하는 동기화 도구');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[세마포어]]로 짠 코드는 어떤 wait가 어떤 signal과 짝인지, 호출 순서가 왜 그래야 하는지가 코드에 드러나지 않는다. 순서를 바꿔 쓰거나 signal을 빠뜨려도 컴파일러가 잡아 주지 않고, 실행 중 드물게 멈추는 형태로만 나타난다. [[모니터]]는 공유 데이터와 그것을 다루는 연산을 한 덩어리로 [[캡슐화]]하고 진입할 때 락을 자동으로 잡아, 무엇을 어디까지 보호하는지가 코드 구조 자체로 보인다.', 1),
       (@fq, '주의점', 'TEXT', '가독성이 좋다고 해서 모니터가 언제나 옳은 선택은 아니다. 자원 개수를 세거나 동시에 실행할 스레드 수를 제한하는 일은 [[세마포어]]가 더 직접적이고, 언어나 라이브러리가 모니터를 제공하지 않는 환경도 있다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 7 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step7 Slot3 꼬리질문1: 크기가 10인 버퍼라면 empty와 full의 초기값은 보통 어떻게 설정하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '처음에는 버퍼가 비어 있으므로 [[empty]]는 10, [[full]]은 0으로 두고, 버퍼 접근을 지키는 뮤텍스는 1로 시작합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'empty', '버퍼의 비어 있는 칸 수를 세는 세마포어. 생산자가 감소시키고 소비자가 증가시킨다'),
       (@fq, 'full', '버퍼에 채워진 항목 수를 세는 세마포어. 생산자가 증가시키고 소비자가 감소시킨다'),
       (@fq, '계수 세마포어', '0 이상의 정수 값을 가져 여러 개의 자원을 셀 수 있는 세마포어. 값이 0이면 대기한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[empty]]는 남은 빈 칸 수를, [[full]]은 들어 있는 항목 수를 세는 [[계수 세마포어]]다. 생산자는 empty를 하나 줄여 자리를 확보한 뒤 값을 넣고 full을 하나 늘리며, 소비자는 반대로 full을 줄이고 항목을 꺼낸 뒤 empty를 늘린다. 그래서 두 값을 합쳐도 버퍼 크기인 10을 넘지 않는다.', 1),
       (@fq, '흔한 오해', 'TEXT', '[[empty]]를 0으로, [[full]]을 10으로 뒤집어 두면 생산자는 첫 항목부터 넣지 못하고 소비자는 있지도 않은 항목을 꺼내려 든다. 초기값은 버퍼의 처음 상태를 그대로 옮긴 숫자라고 생각하면 헷갈리지 않는다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step7 Slot3 꼬리질문2: 뮤텍스와 empty/full 세마포어는 각각 어떤 자원을 보호하거나 표현하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[뮤텍스]]는 버퍼 자료구조를 실제로 만지는 구간을 보호하고, [[empty]]와 [[full]]은 빈 칸과 채워진 항목이라는 자원의 개수를 표현합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '뮤텍스', '한 번에 하나의 스레드만 임계 구역에 들어가게 하는 상호 배제 락'),
       (@fq, 'empty', '버퍼의 비어 있는 칸 수를 세는 세마포어'),
       (@fq, 'full', '버퍼에 채워진 항목 수를 세는 세마포어'),
       (@fq, '교착 상태', '서로가 상대편이 쥔 자원을 기다려 아무도 진행하지 못하고 멈추는 상태');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[empty]]와 [[full]]이 하는 일은 잠금이 아니라 개수 세기다. 값이 0이면 쓸 자원이 없다는 뜻이라 스레드를 재우고, 반대쪽이 자원을 만들어 주면 값이 올라가면서 깨운다. 반면 [[뮤텍스]]는 개수를 세지 않고, 인덱스와 배열을 실제로 갱신하는 짧은 구간에 한 스레드만 들어가도록 막는다.', 1),
       (@fq, '주의점', 'TEXT', '두 종류를 잡는 순서를 바꾸면 [[교착 상태]]가 생긴다. 생산자가 [[뮤텍스]]를 먼저 잡은 채로 빈 칸을 기다리면, 버퍼를 비워 줄 소비자가 뮤텍스를 얻지 못해 아무도 진행하지 못한다. 개수를 세는 세마포어를 먼저 얻고 뮤텍스를 나중에 잡는 순서를 지켜야 한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 7 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step7 Slot4 꼬리질문1: counter++를 안전하게 만들기 위한 대표적인 두 방법은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '증가 구간을 [[락]]으로 감싸 [[임계 구역]]으로 만들거나, 하드웨어가 지원하는 [[원자 변수]]의 증가 연산으로 바꾸면 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '락', '임계 구역에 한 스레드만 들어가도록 잠그고 빠져나올 때 푸는 동기화 도구'),
       (@fq, '임계 구역', '한 번에 하나의 스레드만 실행해야 하는 공유 자원 접근 코드 구간'),
       (@fq, '원자 변수', '증가나 교환 같은 연산을 하드웨어 지원으로 쪼개지지 않게 수행하는 변수 타입');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '첫 번째 방법은 [[락]]을 잡아 lock과 unlock 사이에 증가 코드를 넣고, 읽기와 증가와 쓰기 세 단계가 끝날 때까지 다른 스레드가 끼어들지 못하게 하는 것이다. 두 번째 방법은 [[원자 변수]]를 써서 그 세 단계를 쪼갤 수 없는 하나의 연산으로 처리하는 것이다. 결과는 같지만 전자는 [[임계 구역]]을 코드에 명시적으로 만들고, 후자는 변수 타입이 그 보장을 떠안는다.', 1),
       (@fq, '비교', 'TEXT', '값 하나만 증가시키는 단순한 경우에는 [[원자 변수]]가 더 빠르고 코드도 짧다. 하지만 여러 변수를 함께 일관되게 갱신해야 한다면 원자 변수만으로는 부족하고, 갱신 구간 전체를 [[락]]으로 묶어야 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step7 Slot4 꼬리질문2: 원자적 연산과 임계 구역 보호는 어떤 관계가 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[임계 구역]] 보호는 여러 명령의 묶음에 [[원자적 연산]]과 같은 성질을 소프트웨어로 만들어 주는 일이고, 그 락 자체도 결국 하드웨어의 원자적 명령 위에 세워집니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '원자적 연산', '중간 상태가 다른 스레드에게 보이지 않고, 전부 실행되거나 전혀 실행되지 않는 연산'),
       (@fq, '임계 구역', '한 번에 하나의 스레드만 실행해야 하는 공유 자원 접근 코드 구간'),
       (@fq, 'test-and-set', '값을 읽는 동시에 새 값을 쓰는 원자적 하드웨어 명령. 락 구현의 기초가 된다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[원자적 연산]]은 중간 상태가 다른 스레드에게 보이지 않고 전부 실행되거나 전혀 실행되지 않는다. 하드웨어가 그렇게 보장해 주는 단위는 [[test-and-set]] 같은 몇몇 명령뿐이라, 읽고 계산하고 쓰는 여러 줄짜리 갱신은 그 보장을 받지 못한다. [[임계 구역]]을 락으로 감싸는 일은 그런 여러 줄을 바깥에서 보기에 한 덩어리처럼 보이게 만드는 것이다.', 1),
       (@fq, '흔한 오해', 'TEXT', '원자적 연산만 쓰면 [[임계 구역]]이 필요 없다고 생각하기 쉽다. 개별 연산이 원자적이어도 여러 연산에 걸친 규칙은 깨질 수 있어서, 잔액을 확인한 뒤 출금하는 두 단계짜리 흐름은 여전히 하나의 구간으로 묶어야 한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 7 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step7 Slot5 꼬리질문1: 조건 변수의 wait를 호출할 때 왜 상태 조건을 함께 확인해야 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '깨어난 순간에도 조건이 참이라는 보장이 없기 때문에, [[wait]]는 조건을 다시 검사하는 반복문 안에서 호출해야 합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'wait', '조건 변수에서 스레드를 잠재우는 연산. 락을 놓고 대기 큐에 들어갔다가 깨어날 때 락을 다시 잡는다'),
       (@fq, 'Mesa 방식', 'signal을 받은 스레드가 즉시 실행되지 않고 락을 다시 얻어야 진행하는 방식. 실제 구현 대부분이 이를 따른다'),
       (@fq, '허위 기상', 'signal이 없었는데도 wait가 반환되어 스레드가 깨어나는 현상');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '대부분의 구현이 따르는 [[Mesa 방식]]에서는 signal이 대기 스레드를 깨우기만 하고, 그 스레드는 락을 다시 얻은 뒤에야 실행된다. 그 틈에 다른 소비자가 먼저 들어와 항목을 가져가면, 깨어난 스레드가 볼 때 버퍼는 다시 비어 있다. 게다가 signal이 없었는데도 [[wait]]가 돌아오는 [[허위 기상]]을 허용하는 환경도 있다.', 1),
       (@fq, '주의점', 'TEXT', '그래서 조건을 한 번만 검사하고 [[wait]]하면, 조건이 거짓인 채로 다음 코드를 실행하는 버그가 생긴다. 반복문으로 감싸 깨어날 때마다 조건을 다시 확인하고, 아직 거짓이면 다시 잠들게 해야 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step7 Slot5 꼬리질문2: 모니터에서 signal과 broadcast는 어떤 차이가 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[signal]]은 [[대기 큐]]에서 기다리는 스레드 중 하나만 깨우고, [[broadcast]]는 기다리는 스레드를 전부 깨웁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'signal', '조건 변수에서 기다리는 스레드 중 하나를 깨우는 연산'),
       (@fq, 'broadcast', '조건 변수에서 기다리는 모든 스레드를 깨우는 연산. 자바의 notifyAll이 이에 해당한다'),
       (@fq, '대기 큐', '조건 변수에서 잠든 스레드들이 줄지어 기다리는 자료구조');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '기다리는 이유가 한 가지뿐이고 항목을 하나만 넣었다면, 하나만 깨우는 [[signal]]로 충분하고 불필요한 경쟁도 줄어든다. 반면 서로 다른 이유로 기다리는 스레드가 같은 조건 변수의 [[대기 큐]]에 섞여 있으면, 하나만 깨웠을 때 조건이 맞지 않는 스레드가 걸려 다시 잠들고 아무도 진행하지 못할 수 있다. 이럴 때는 [[broadcast]]로 전부 깨워 각자 조건을 다시 검사하게 한다.', 1),
       (@fq, '주의점', 'TEXT', '[[broadcast]]는 안전한 대신, 깨어난 스레드들이 락을 얻으려 한꺼번에 몰렸다가 대부분 조건만 확인하고 다시 잠든다. 기다리는 조건마다 조건 변수를 따로 두면 [[signal]]만으로도 필요한 스레드를 정확히 깨울 수 있다.', 2);

-- ===================== STEP 8: 교착상태(4대 조건·예방·회피·탐지·복구) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 8 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step8 Slot1 꼬리질문1: 4대 필요 조건 각각을 한 문장씩 설명할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[상호 배제]]는 자원을 한 번에 하나만 쓰는 것, [[점유와 대기]]는 자원을 쥔 채 다른 자원을 기다리는 것, [[비선점]]은 남이 쥔 자원을 강제로 뺏지 못하는 것, [[순환 대기]]는 대기 관계가 고리를 이루는 것입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '상호 배제', '한 자원을 한 번에 하나의 프로세스만 사용할 수 있는 성질'),
       (@fq, '점유와 대기', '자원을 이미 쥔 채로 다른 자원을 추가로 기다리는 상태'),
       (@fq, '비선점', '자원을 쥔 프로세스가 스스로 반납하기 전에는 그 자원을 빼앗을 수 없는 성질'),
       (@fq, '순환 대기', '프로세스들의 대기 관계가 원형 고리를 이루는 상태');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[상호 배제]]는 프린터처럼 동시에 나눠 쓸 수 없는 자원에서 생긴다. [[점유와 대기]]는 이미 확보한 자원을 놓지 않은 채 새 자원을 요청할 때 나타난다. [[비선점]]은 자원을 쥔 프로세스가 스스로 반납하기 전까지 운영체제가 회수하지 못한다는 뜻이다. [[순환 대기]]는 P1이 P2의 자원을, P2가 P1의 자원을 기다리는 식으로 대기 관계가 원을 그리는 상태다.', 1),
       (@fq, '함께 봐야 하는 이유', 'TEXT', '네 조건은 각각이 교착상태의 원인이 아니라, 넷이 동시에 성립할 때만 교착상태가 된다. 그래서 예방 기법은 넷 중 하나만 골라 깨뜨린다. 다만 [[상호 배제]]는 자원의 성질 자체라 없애기 어려운 경우가 많아, 나머지 세 조건 중 하나를 노리는 편이 흔하다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step8 Slot1 꼬리질문2: 순환 대기 조건을 깨는 대표적인 방법은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '모든 자원에 전역 번호를 매기고 항상 번호가 커지는 방향으로만 요청하게 하는 [[자원 순서 부여]]가 대표적입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '자원 순서 부여', '모든 자원 종류에 전역 번호를 매기고 그 번호가 커지는 방향으로만 요청하게 하는 예방 기법'),
       (@fq, '순환 대기', '프로세스들의 대기 관계가 원형 고리를 이루는 상태'),
       (@fq, '대기 그래프', '어떤 프로세스가 어떤 프로세스를 기다리는지 간선으로 나타낸 그래프');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[순환 대기]]는 대기 관계가 고리를 이룰 때 성립한다. 자원마다 번호를 붙이고 프로세스가 오름차순으로만 자원을 요청하면, 큰 번호를 쥔 프로세스가 작은 번호를 기다리는 일이 없어진다. 그래서 [[대기 그래프]]에 고리가 만들어지지 않는다.', 1),
       (@fq, '실무 사용처', 'TEXT', '여러 락을 함께 잡는 코드에서는 락에 순서를 정해 두고 모든 실행 경로에서 같은 순서로 획득한다. 계좌 이체처럼 두 계좌의 락이 동시에 필요한 경우, 계좌 번호가 작은 쪽부터 잠그는 규칙이 [[자원 순서 부여]]의 흔한 적용이다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 8 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step8 Slot2 꼬리질문1: 교착상태 예방과 회피의 차이를 설명할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[예방]]은 4대 필요 조건 중 하나가 아예 성립하지 못하도록 설계하는 것이고, [[회피]]는 조건은 그대로 두되 자원 요청마다 안전한지 검사해 위험한 할당을 거절하는 것입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '예방', '교착상태의 4대 필요 조건 중 하나가 아예 성립하지 못하도록 시스템을 설계하는 기법'),
       (@fq, '회피', '자원 요청마다 시스템이 안전 상태로 남는지 검사해 위험한 할당을 거절하는 기법'),
       (@fq, '안전 상태', '모든 프로세스를 완료시킬 수 있는 실행 순서가 하나 이상 존재하는 자원 할당 상태'),
       (@fq, '은행원 알고리즘', '최대 필요량과 가용 자원을 비교해 안전 순서가 존재하는지 검사하는 회피 알고리즘');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[예방]]은 설계 시점에 조건 하나를 구조적으로 없앤다. 자원에 전역 순서를 부여해 순환 대기를 막는 방식이 그 예다. [[회피]]는 실행 중에 판단한다. 자원 요청을 받을 때마다 그 요청을 들어줘도 시스템이 [[안전 상태]]로 남는지 계산하고, 아니면 요청을 미룬다.', 1),
       (@fq, '비교', 'TEXT', '[[예방]]은 실행 중 판단 비용이 없는 대신 자원 활용률이 떨어진다. [[회피]]는 활용률이 낫지만 각 프로세스의 최대 자원 요구량을 미리 알아야 하고 요청마다 검사 비용을 낸다. [[은행원 알고리즘]]이 회피의 대표적인 구현이다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step8 Slot2 꼬리질문2: 안전 상태와 불안전 상태는 어떻게 구분되는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '모든 프로세스를 끝까지 완료시키는 [[안전 순서]]가 하나라도 존재하면 [[안전 상태]]이고, 그런 순서를 하나도 찾을 수 없으면 [[불안전 상태]]입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '안전 순서', '가용 자원만으로 차례차례 모든 프로세스를 완료시킬 수 있는 프로세스 나열'),
       (@fq, '안전 상태', '안전 순서가 하나 이상 존재하는 자원 할당 상태'),
       (@fq, '불안전 상태', '안전 순서를 하나도 찾을 수 없는 자원 할당 상태'),
       (@fq, '가용 자원', '현재 어느 프로세스에도 할당되지 않고 남아 있는 자원');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '판단은 [[가용 자원]]에서 출발한다. 남은 필요량이 가용 자원 이하인 프로세스를 찾아 그 프로세스가 끝났다고 가정하고, 쥐고 있던 자원을 가용 자원에 되돌린다. 이 과정을 반복해 모든 프로세스를 소진하면 그 나열이 [[안전 순서]]이고 현재 상태는 [[안전 상태]]다. 도중에 더 진행시킬 프로세스가 없으면 [[불안전 상태]]다.', 1),
       (@fq, '흔한 오해', 'TEXT', '[[불안전 상태]]는 교착상태와 같은 말이 아니다. 안전 순서를 보장하지 못할 뿐, 프로세스들이 실제로 최대 요구량까지 요청하지 않으면 무사히 끝날 수도 있다. 회피 기법은 그 불확실성을 감수하지 않고, 불안전 상태로 넘어가는 요청 자체를 거절한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 8 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step8 Slot3 꼬리질문1: 자원에 전역 순서를 부여하면 왜 순환 대기가 어려워지는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '모두가 [[전역 순서]]가 커지는 방향으로만 자원을 요청하면 대기 화살표가 한쪽으로만 흐르는데, 고리를 닫으려면 큰 번호에서 작은 번호로 되돌아가는 대기가 있어야 하기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '전역 순서', '시스템의 모든 자원에 매긴 하나뿐인 번호 체계'),
       (@fq, '순환 대기', '프로세스들의 대기 관계가 원형 고리를 이루는 상태'),
       (@fq, '자원 할당 그래프', '프로세스와 자원을 노드로, 요청과 할당을 간선으로 표현한 그래프'),
       (@fq, '사이클', '그래프에서 출발한 노드로 다시 돌아오는 경로');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[순환 대기]]가 성립하려면 [[자원 할당 그래프]]에 [[사이클]]이 있어야 한다. 프로세스가 이미 쥔 자원의 번호보다 큰 번호만 요청한다면, 모든 대기 간선은 번호가 증가하는 방향을 향한다. 증가하는 방향만 있는 경로는 출발한 노드로 되돌아올 수 없으므로 고리가 만들어지지 않는다.', 1),
       (@fq, '주의점', 'TEXT', '이 규칙은 모든 코드 경로가 예외 없이 지켜야 효과가 있다. 한 곳이라도 번호를 거슬러 요청하면 그 지점에서 [[사이클]]이 다시 가능해진다. 그래서 실무에서는 락 획득 순서를 문서로 못 박거나 정적 분석 도구로 위반을 잡는다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step8 Slot3 꼬리질문2: 예방 기법이 시스템 자원 활용률에 줄 수 있는 단점은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '당장 쓰지 않을 자원까지 미리 붙잡아 두거나 정해진 순서를 지키느라 기다리게 되어 [[자원 활용률]]이 떨어지고, 심하면 [[기아]]까지 생길 수 있다는 점입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '일괄 할당', '프로세스가 시작할 때 필요한 자원을 한꺼번에 모두 요청해 받는 방식'),
       (@fq, '자원 활용률', '전체 자원 중 실제로 일하는 데 쓰이고 있는 비율'),
       (@fq, '선점', '자원을 쥐고 있는 프로세스에게서 그 자원을 강제로 회수하는 것'),
       (@fq, '기아', '특정 프로세스가 필요한 자원을 계속 얻지 못해 무한정 기다리게 되는 현상');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '점유와 대기 조건을 깨려고 필요한 자원을 시작 시점에 [[일괄 할당]]하면, 나중에야 쓸 자원까지 처음부터 붙잡고 있어 [[자원 활용률]]이 떨어진다. 비선점 조건을 깨려고 [[선점]]을 허용하면 자원을 빼앗긴 프로세스는 하던 작업을 되돌리고 다시 해야 한다. 순환 대기를 막는 자원 순서 규칙도, 실제로 필요한 순서와 정해진 순서가 어긋나면 불필요한 대기를 만든다.', 1),
       (@fq, '주의점', 'TEXT', '자원을 모두 모을 때까지 시작하지 못하는 프로세스는 요구 자원이 많을수록 계속 뒤로 밀려 [[기아]]에 빠질 수 있다. 예방이 안전한 대신 보수적이라는 뜻이며, 그래서 범용 운영체제는 예방을 전면 적용하지 않는다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 8 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step8 Slot4 꼬리질문1: 이 코드에서 교착상태를 예방하려면 어떤 락 획득 규칙을 적용해야 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '두 스레드가 모두 A를 먼저 잡고 B를 나중에 잡도록 [[락 획득 순서]]를 한 방향으로 통일하면 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '락 획득 순서', '여러 락을 잡을 때 모든 코드가 지키기로 약속한 전역적인 획득 순서'),
       (@fq, '순환 대기', '프로세스나 스레드의 대기 관계가 원형 고리를 이루는 상태'),
       (@fq, '락 계층', '락에 등급을 매겨 낮은 등급에서 높은 등급 방향으로만 획득하게 하는 규칙'),
       (@fq, '타임아웃', '정해진 시간 안에 락을 얻지 못하면 포기하고 되돌아가는 기법');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', 'T2가 B, A 순으로 잡기 때문에 T1은 A를 쥐고 B를, T2는 B를 쥐고 A를 기다리는 [[순환 대기]]가 만들어진다. T2를 lock(A) 다음 lock(B)로 바꾸면 두 스레드의 대기 방향이 같아져 고리가 닫히지 않는다. 이렇게 락에 전역 순서를 정하고 모두가 그 순서로만 획득하게 하는 규칙을 [[락 계층]]이라 부른다.', 1),
       (@fq, '순서를 못 정할 때', 'TEXT', '순서를 항상 정할 수 없다면 락 획득에 [[타임아웃]]을 두고, 시간 안에 얻지 못하면 쥐고 있던 락을 모두 풀고 처음부터 다시 시도하는 방법도 있다. 다만 이는 교착상태를 예방한다기보다 빠져나오는 쪽에 가깝고, 재시도가 계속 어긋나면 라이브락이 될 수 있다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step8 Slot4 꼬리질문2: 교착상태와 경쟁 상태는 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[교착상태]]는 서로를 기다리다 아무도 진행하지 못해 멈추는 문제고, [[경쟁 상태]]는 실행 순서에 따라 결과가 달라져 값이 틀어지는 문제입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '교착상태', '여러 프로세스가 서로의 자원을 기다리며 아무도 진행하지 못하는 상태'),
       (@fq, '경쟁 상태', '여러 스레드의 실행 순서에 따라 공유 데이터의 결과가 달라지는 상태'),
       (@fq, '임계 구역', '공유 자원을 다루기 때문에 한 번에 하나의 스레드만 들어가야 하는 코드 영역'),
       (@fq, '동기화', '여러 스레드가 공유 자원에 접근하는 순서를 조율하는 것');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[경쟁 상태]]는 둘 이상의 스레드가 [[임계 구역]]에 동시에 들어가 공유 데이터를 덮어쓸 때 생긴다. 증상은 멈춤이 아니라 잘못된 값이며, 실행 타이밍에 따라 재현되기도 하고 안 되기도 한다. [[교착상태]]는 반대로 결과가 틀리는 게 아니라 아무 결과도 나오지 않는다.', 1),
       (@fq, '비교', 'TEXT', '[[경쟁 상태]]는 락 같은 [[동기화]] 수단으로 막고, [[교착상태]]는 그 동기화 수단을 잘못 쓸 때 생긴다. 락을 걸지 않으면 경쟁 상태가, 여러 락을 엇갈린 순서로 걸면 교착상태가 나타나는 셈이다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 8 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step8 Slot5 꼬리질문1: 안전 상태와 불안전 상태의 차이를 예시로 설명할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '자원 12개를 세 프로세스가 나눠 쓸 때 남은 자원으로 한 프로세스를 끝내고 그 반납분으로 나머지를 차례차례 끝낼 수 있으면 [[안전 상태]]이고, 그 연쇄가 도중에 끊기면 [[불안전 상태]]입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '안전 상태', '모든 프로세스를 완료시킬 수 있는 실행 순서가 하나 이상 존재하는 자원 할당 상태'),
       (@fq, '불안전 상태', '모든 프로세스의 완료를 보장하는 실행 순서를 하나도 찾을 수 없는 자원 할당 상태'),
       (@fq, '안전 순서', '가용 자원만으로 차례차례 모든 프로세스를 완료시킬 수 있는 프로세스 나열'),
       (@fq, '가용 자원', '현재 어느 프로세스에도 할당되지 않고 남아 있는 자원');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '자원 12개를 세 프로세스가 쓰고 최대 필요량이 각각 10, 4, 9인데 지금 5개, 2개, 2개를 쥐고 있다고 하자. [[가용 자원]]은 3개다. 최대 4개가 필요한 프로세스는 2개만 더 받으면 끝나고, 끝나면서 4개를 반납해 가용 자원이 5개가 된다. 그러면 5개가 더 필요한 프로세스가 끝나고 이어서 마지막 프로세스도 끝나므로, 이 완료 나열이 [[안전 순서]]이고 현재는 [[안전 상태]]다.', 1),
       (@fq, '불안전 상태 예시', 'TEXT', '같은 상황에서 최대 9개가 필요한 프로세스에 1개를 더 주면 가용 자원은 2개로 줄어든다. 최대 4개짜리 프로세스는 여전히 끝낼 수 있지만, 반납 뒤 가용 자원이 4개뿐이라 5개가 더 필요한 프로세스도 6개가 더 필요한 프로세스도 진행하지 못한다. 완료 순서를 만들 수 없으니 [[불안전 상태]]이며, 은행원 알고리즘은 이 요청을 거절한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step8 Slot5 꼬리질문2: 불안전 상태가 항상 즉시 교착상태를 의미하지 않는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[불안전 상태]]는 모든 프로세스가 [[최대 필요량]]까지 요청하는 최악의 경우를 가정한 판정이라, 실제로 그만큼 요청하지 않으면 교착상태 없이 끝날 수도 있기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '불안전 상태', '모든 프로세스의 완료를 보장하는 실행 순서를 하나도 찾을 수 없는 자원 할당 상태'),
       (@fq, '최대 필요량', '프로세스가 실행을 마치기까지 필요하다고 미리 선언한 자원의 최대치'),
       (@fq, '교착상태', '여러 프로세스가 서로의 자원을 기다리며 아무도 진행하지 못하는 상태'),
       (@fq, '은행원 알고리즘', '최대 필요량과 가용 자원을 비교해 안전 순서가 존재하는지 검사하는 회피 알고리즘');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[은행원 알고리즘]]은 각 프로세스가 선언한 [[최대 필요량]]을 전부 요청한다는 최악의 시나리오로 안전 순서를 찾는다. 그 시나리오에서 완료 순서를 찾지 못하면 [[불안전 상태]]로 판정한다. 하지만 실제 프로세스는 최대치까지 요청하지 않고 일찍 자원을 반납할 수도 있다. 그래서 불안전 상태는 [[교착상태]]로 갈 가능성이 있는 상태일 뿐, 이미 교착상태라는 뜻은 아니다.', 1),
       (@fq, '관계 정리', 'TEXT', '[[교착상태]]에 빠진 상태는 모두 [[불안전 상태]]지만, 그 역은 성립하지 않는다. [[은행원 알고리즘]]은 이 여유를 활용하지 않고 불안전 상태로 넘어가는 요청을 미리 거절한다. 교착상태를 확실히 막는 대신, 실제로는 문제없었을 요청까지 지연시키는 보수적인 선택이다.', 2);

-- ===================== STEP 9: 메모리 관리 기초(연속 할당·단편화·페이징·세그멘테이션) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 9 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step9 Slot1 꼬리질문1: 외부 단편화를 완화하기 위해 사용할 수 있는 대표적인 메모리 관리 기법은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '메모리를 같은 크기 단위로 나누어 흩어진 자리에 적재하는 [[페이징]]이 [[외부 단편화]]를 완화하는 대표적인 기법입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '페이징', '논리 메모리를 페이지로, 물리 메모리를 같은 크기의 프레임으로 나누어 관리하는 기법'),
       (@fq, '외부 단편화', '빈 공간의 총합은 충분하지만 연속된 큰 공간이 없어 적재하지 못하는 현상'),
       (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 단위');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[외부 단편화]]는 프로세스가 연속된 한 덩어리의 공간을 요구하기 때문에 생긴다. [[페이징]]은 논리 주소 공간을 페이지로, 물리 메모리를 같은 크기의 [[프레임]]으로 나눈 뒤 각 페이지를 비어 있는 아무 프레임에나 올린다. 연속 배치라는 제약이 사라지므로 빈 공간이 조각나 있어도 총합만 충분하면 적재할 수 있다.', 1),
       (@fq, '남는 대가', 'TEXT', '[[페이징]]은 [[외부 단편화]]를 없애는 대신 내부 단편화를 남긴다. 프로세스 크기가 페이지 크기의 배수가 아니면 마지막 페이지의 뒷부분이 비어 있게 되기 때문이다. 다만 낭비되는 크기가 페이지 하나를 넘지 않아, 흩어진 빈칸을 모아야 하는 외부 단편화보다 다루기 쉽다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step9 Slot1 꼬리질문2: 연속 할당에서 compaction은 어떤 상황에서 도움이 되는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '빈 공간의 총합은 충분한데 연속된 큰 자리가 없어 적재가 막힐 때, 그리고 주소를 실행 중에 다시 계산하는 [[동적 재배치]]가 가능할 때 [[압축]]이 도움이 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '압축', '사용 중인 메모리 블록을 한쪽으로 모아 흩어진 빈 공간을 하나의 큰 연속 공간으로 합치는 작업'),
       (@fq, '외부 단편화', '빈 공간의 총합은 충분하지만 연속된 큰 공간이 없어 적재하지 못하는 현상'),
       (@fq, '동적 재배치', '프로그램의 주소를 실행 시점에 기준 레지스터로 다시 계산해, 적재 위치를 옮겨도 정상 동작하게 하는 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[압축]]은 사용 중인 블록들을 메모리 한쪽으로 밀어 붙여 흩어진 빈칸을 하나의 큰 연속 공간으로 합치는 작업이다. 총 여유 공간은 넉넉한데 [[외부 단편화]] 때문에 큰 프로세스가 들어가지 못하는 상황이 바로 이 작업이 필요한 순간이다. 반대로 여유 공간 자체가 부족하다면 아무리 모아도 적재할 수 없으므로 소용이 없다.', 1),
       (@fq, '전제와 비용', 'TEXT', '[[압축]]은 프로세스를 실제로 옮기는 일이라, 주소가 적재 시점에 고정되면 쓸 수 없고 [[동적 재배치]]처럼 실행 중에 주소를 다시 계산할 수 있어야 한다. 또 옮기는 동안 해당 프로세스를 멈춰야 하고 복사 비용이 옮기는 데이터의 크기에 비례해 커진다. 그래서 [[외부 단편화]]가 심각할 때만 제한적으로 쓴다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 9 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step9 Slot2 꼬리질문1: 페이징에서 내부 단편화가 발생하는 대표적인 위치는 어디인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '프로세스가 차지하는 마지막 [[페이지]]로, 크기가 페이지 단위로 딱 떨어지지 않으면 그 페이지의 남는 뒷부분이 [[내부 단편화]]가 됩니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '내부 단편화', '할당받은 공간 안에서 실제로 쓰이지 않고 남아 낭비되는 부분'),
       (@fq, '페이지', '프로세스의 논리 주소 공간을 나눈 고정 크기 단위'),
       (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 단위');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '페이징은 프로세스를 페이지 단위로 잘라 [[프레임]]에 올리므로, 프로세스 크기가 페이지 크기의 배수가 아니면 마지막 조각이 프레임을 다 채우지 못한다. 이때 남은 자투리는 다른 프로세스에게 줄 수 없고 그대로 낭비되는데 이것이 [[내부 단편화]]다. 할당된 공간 안에서 생기는 낭비라는 점이 빈 공간 사이에서 생기는 외부 단편화와 다르다.', 1),
       (@fq, '크기로 보기', 'TEXT', '페이지 크기가 4KB이고 프로세스 크기가 9KB라면 [[페이지]]가 세 개 필요하고 세 번째 페이지에는 1KB만 들어간다. 남은 3KB가 [[내부 단편화]]로 버려진다. 프로세스 하나가 낭비하는 양은 평균적으로 페이지 크기의 절반쯤이므로, 페이지를 키우면 페이지 테이블은 작아지지만 낭비는 늘어난다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step9 Slot2 꼬리질문2: 페이지와 프레임의 크기가 서로 같아야 하는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '크기가 같아야 어떤 [[페이지]]든 빈 [[프레임]] 아무 곳에나 들어가고, 주소 변환에서 [[오프셋]]을 그대로 둔 채 앞쪽 번호만 바꿔치기할 수 있기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '페이지', '프로세스의 논리 주소 공간을 나눈 고정 크기 단위'),
       (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 단위'),
       (@fq, '오프셋', '페이지 내부에서 몇 번째 위치인지를 나타내는 변위 값'),
       (@fq, '페이지 테이블', '페이지 번호를 그 페이지가 올라가 있는 프레임 번호로 대응시키는 표');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '논리 주소는 페이지 번호와 [[오프셋]]으로 나뉘고, 물리 주소는 프레임 번호와 같은 오프셋을 합쳐 만들어진다. 페이지와 프레임의 크기가 같으면 [[페이지 테이블]]에서 찾은 프레임 번호를 앞에 붙이기만 하면 되고 오프셋은 손댈 필요가 없다. 크기가 다르면 오프셋이 프레임의 범위를 벗어날 수 있어 이 변환식이 성립하지 않는다.', 1),
       (@fq, '배치의 자유', 'TEXT', '크기가 같으면 모든 [[프레임]]이 서로 완전히 대체 가능해서, 운영체제는 빈 프레임 목록에서 아무거나 하나 꺼내 [[페이지]]를 올리면 된다. 어느 자리가 맞는지 크기를 따져 고를 필요가 없으니 할당이 단순해지고 외부 단편화도 사라진다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 9 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step9 Slot3 꼬리질문1: 세그멘테이션에서 세그먼트마다 서로 다른 접근 권한을 둘 수 있는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[세그먼트]]가 코드·데이터·스택처럼 의미 단위로 나뉘어 있고, [[세그먼트 테이블]]의 항목마다 [[보호 비트]]를 따로 둘 수 있기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '세그먼트', '코드·데이터·스택처럼 논리적 의미 단위로 나눈 가변 크기 구역'),
       (@fq, '세그먼트 테이블', '세그먼트마다 시작 주소·길이·접근 권한 정보를 담아 주소 변환에 쓰는 표'),
       (@fq, '보호 비트', '해당 구역에 읽기·쓰기·실행을 허용할지 표시해 하드웨어가 검사하는 비트');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '세그멘테이션은 프로그램을 크기가 제각각인 의미 단위로 나누므로 한 [[세그먼트]] 안에는 성격이 같은 내용만 들어간다. 코드만 담긴 구역과 읽고 쓰는 데이터만 담긴 구역이 분리돼 있으니 구역 단위로 권한을 매기는 것이 자연스럽다. 페이징처럼 고정 크기로 자르면 한 페이지에 코드와 데이터가 섞일 수 있어 이런 구분이 어렵다.', 1),
       (@fq, '하드웨어의 역할', 'TEXT', '[[세그먼트 테이블]]의 각 항목은 시작 주소와 길이뿐 아니라 읽기·쓰기·실행 허용 여부를 나타내는 [[보호 비트]]를 함께 담는다. 주소 변환 때 하드웨어가 이 비트를 검사해, 코드 구역에 쓰기를 시도하면 예외를 발생시킨다. 덕분에 읽기 전용 코드 구역을 여러 프로세스가 안전하게 공유할 수도 있다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step9 Slot3 꼬리질문2: 세그멘테이션이 외부 단편화에 취약한 이유를 설명할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[세그먼트]]가 [[가변 크기]]인데다 각각 [[연속 할당]]되어야 해서, 크기가 제각각인 빈칸이 남고 [[외부 단편화]]가 생깁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '세그먼트', '코드·데이터·스택처럼 논리적 의미 단위로 나눈 가변 크기 구역'),
       (@fq, '가변 크기', '구역마다 크기가 제각각이어서 고정된 단위로 떨어지지 않는 성질'),
       (@fq, '연속 할당', '프로세스나 구역을 물리 메모리의 끊기지 않은 한 덩어리 공간에 배치하는 방식'),
       (@fq, '외부 단편화', '빈 공간의 총합은 충분하지만 연속된 큰 공간이 없어 적재하지 못하는 현상');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '각 [[세그먼트]]는 물리 메모리에서 하나의 연속된 구간을 통째로 차지해야 한다. 세그먼트마다 크기가 다르므로 적재와 해제를 반복하면 크고 작은 빈칸이 불규칙하게 흩어진다. 그 결과 총 여유 공간은 충분한데도 새 세그먼트가 들어갈 자리가 없는 [[외부 단편화]]가 나타난다.', 1),
       (@fq, '페이징과의 비교', 'TEXT', '페이징은 모든 조각이 같은 크기라 빈 프레임이면 무조건 들어가지만, 세그멘테이션은 [[가변 크기]] 블록을 [[연속 할당]]하므로 최초 적합이나 최적 적합 같은 배치 전략이 필요하다. 어떤 전략을 쓰든 남는 자투리를 완전히 없앨 수는 없다. 그래서 실제 시스템은 세그먼트를 다시 페이지 단위로 나누어 관리하기도 한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 9 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step9 Slot4 꼬리질문1: 페이지 번호를 얻은 뒤 물리 주소 계산에 추가로 필요한 자료구조는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '페이지 번호를 [[프레임 번호]]로 바꿔 주는 [[페이지 테이블]]입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '페이지 테이블', '페이지 번호를 그 페이지가 올라가 있는 프레임 번호로 대응시키는 표'),
       (@fq, '프레임 번호', '물리 메모리를 나눈 프레임 각각에 붙은 번호. 물리 주소의 앞부분을 이룬다'),
       (@fq, 'TLB', 'Translation Lookaside Buffer — 최근 주소 변환 결과를 저장해 페이지 테이블 조회를 건너뛰게 하는 하드웨어 캐시');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[페이지 테이블]]은 프로세스마다 하나씩 있으며, 페이지 번호를 색인으로 삼아 그 페이지가 올라가 있는 [[프레임 번호]]를 알려준다. 물리 주소는 이 프레임 번호에 페이지 크기를 곱한 값에 오프셋을 더해 얻는다. 오프셋은 그대로 두고 앞쪽 번호만 갈아 끼우는 셈이다.', 1),
       (@fq, '속도 문제', 'TEXT', '[[페이지 테이블]]도 메모리에 있으므로, 주소를 한 번 참조할 때마다 메모리를 두 번 읽게 된다. 한 번은 테이블을 읽고 한 번은 실제 데이터를 읽는 것이다. 이 손해를 줄이려고 최근 변환 결과를 담아 두는 [[TLB]]라는 캐시를 하드웨어에 둔다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step9 Slot4 꼬리질문2: 오프셋 값은 왜 페이지 크기보다 항상 작은가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[오프셋]]이 논리 주소를 [[페이지 크기]]로 나눈 [[나머지 연산]]의 결과이고, 나머지는 항상 나누는 수보다 작기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '오프셋', '페이지 내부에서 몇 번째 위치인지를 나타내는 변위 값'),
       (@fq, '페이지 크기', '페이지 하나가 담는 바이트 수. 보통 2의 거듭제곱으로 정한다'),
       (@fq, '나머지 연산', '나눗셈에서 남는 값을 구하는 연산. 결과는 항상 0 이상이고 나누는 수보다 작다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[나머지 연산]]의 결과는 0 이상이면서 나누는 수보다 작다는 성질을 갖는다. 오프셋은 논리 주소를 [[페이지 크기]]로 나눈 나머지이므로 0부터 페이지 크기보다 1 작은 값까지만 가질 수 있다. 만약 오프셋이 페이지 크기와 같아진다면 그 위치는 이미 다음 페이지에 속하고 페이지 번호가 하나 늘어난다.', 1),
       (@fq, '의미로 보기', 'TEXT', '[[오프셋]]은 그 페이지 안에서 몇 번째 바이트인지를 가리키는 값이다. 페이지 크기가 4096이면 한 페이지에는 0번부터 4095번까지의 자리만 있으므로 4096번째 자리는 애초에 존재하지 않는다. 그래서 페이지 크기를 2의 거듭제곱으로 잡으면 오프셋은 주소의 하위 비트 몇 개로 그대로 표현된다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 9 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step9 Slot5 꼬리질문1: 압축이 외부 단편화를 줄일 수 있지만 자주 사용되지 않을 수 있는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[압축]]은 사용 중인 블록을 실제로 복사해 옮겨야 해서 [[오버헤드]]가 크고, 주소를 실행 중에 다시 계산하는 [[동적 재배치]]가 지원될 때만 가능하기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '압축', '사용 중인 메모리 블록을 한쪽으로 모아 흩어진 빈 공간을 하나의 큰 연속 공간으로 합치는 작업'),
       (@fq, '오버헤드', '본래 목적의 작업 외에 추가로 드는 시간·자원 비용'),
       (@fq, '동적 재배치', '프로그램의 주소를 실행 시점에 기준 레지스터로 다시 계산해, 적재 위치를 옮겨도 정상 동작하게 하는 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[압축]]을 하려면 메모리에 올라간 프로세스들의 내용을 한쪽으로 밀어 붙여 복사해야 하고, 복사량은 옮기는 데이터의 크기에 비례한다. 그동안 해당 프로세스는 실행을 멈춰야 하므로 CPU가 놀고 응답 시간이 길어진다. 얻는 것은 빈 공간의 재배열일 뿐 전체 여유 공간의 양이 늘지는 않는다는 점도 감안해야 한다.', 1),
       (@fq, '전제 조건', 'TEXT', '옮긴 뒤에도 프로그램이 정상 동작하려면 주소가 적재 시점에 고정되어 있으면 안 된다. [[동적 재배치]]처럼 기준 레지스터 값을 바꾸는 것만으로 새 위치를 반영할 수 있어야 압축이 성립한다. 이런 전제와 [[오버헤드]] 때문에, 현대 운영체제는 압축 대신 페이징으로 문제를 아예 피해 간다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step9 Slot5 꼬리질문2: 페이징은 왜 압축 없이도 외부 단편화 문제를 완화할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[페이징]]은 프로세스를 같은 크기 조각으로 나눠 흩어진 [[프레임]] 아무 곳에나 올리므로, 애초에 연속된 큰 공간을 찾을 필요가 없기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '페이징', '논리 메모리를 페이지로, 물리 메모리를 같은 크기의 프레임으로 나누어 관리하는 기법'),
       (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 단위'),
       (@fq, '외부 단편화', '빈 공간의 총합은 충분하지만 연속된 큰 공간이 없어 적재하지 못하는 현상'),
       (@fq, '페이지 테이블', '페이지 번호를 그 페이지가 올라가 있는 프레임 번호로 대응시키는 표');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[외부 단편화]]는 프로세스가 연속된 한 덩어리를 요구하기 때문에 생기는 문제다. [[페이징]]은 물리 메모리를 같은 크기의 프레임으로 미리 잘라 두고, 프로세스의 페이지를 비어 있는 프레임이라면 어디든 배치한다. 빈 프레임의 개수만 충분하면 그것들이 메모리 곳곳에 흩어져 있어도 상관없으므로 블록을 옮겨 붙이는 압축이 필요 없다.', 1),
       (@fq, '바꿔 치른 비용', 'TEXT', '흩어진 [[프레임]]을 하나의 연속된 주소 공간처럼 보이게 하려면 페이지마다 어느 프레임에 있는지를 기록한 [[페이지 테이블]]이 필요하다. 즉 페이징은 데이터를 옮기는 비용을 주소 변환 비용과 테이블 저장 공간으로 맞바꾼 셈이다. 여기에 마지막 페이지의 자투리로 내부 단편화가 남지만 그 크기는 페이지 하나를 넘지 않는다.', 2);

-- ===================== STEP 10: 가상 메모리(페이지 폴트·페이지 교체 알고리즘·스래싱) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 10 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step10 Slot1 꼬리질문1: 유효한 가상 주소 접근에서도 페이지 폴트가 발생할 수 있는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[요구 페이징]] 방식에서는 유효한 주소라도 그 페이지가 아직 물리 메모리에 올라와 있지 않을 수 있어, 접근하는 순간 [[페이지 폴트]]가 발생합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '요구 페이징', '페이지를 미리 다 올려 두지 않고, 실제로 참조되는 시점에 보조기억장치에서 메모리로 적재하는 방식'),
       (@fq, '페이지 폴트', '참조한 페이지가 물리 메모리에 없어 CPU가 트랩을 걸고 운영체제가 개입하는 사건'),
       (@fq, '페이지 테이블', '가상 페이지 번호를 물리 프레임 번호로 변환하는 표. 페이지마다 상태 비트를 함께 담는다'),
       (@fq, '유효 비트', '페이지 테이블 항목에 있는 비트로, 해당 페이지가 지금 물리 메모리에 있는지를 표시한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[요구 페이징]]은 프로세스를 시작할 때 모든 페이지를 올리지 않고 실제로 참조되는 페이지만 그때그때 적재한다. 그래서 주소 공간에 정상적으로 매핑된 유효한 주소라도 해당 페이지가 아직 메모리에 없을 수 있다. 이때 [[페이지 테이블]]의 [[유효 비트]]가 무효로 표시돼 있어 CPU가 트랩을 발생시키는데, 이것이 [[페이지 폴트]]다.', 1),
       (@fq, '흔한 오해', 'TEXT', '유효한 주소에서 생긴 [[페이지 폴트]]는 정상 동작의 일부라, 운영체제가 페이지를 올려 준 뒤 폴트를 낸 명령어를 다시 실행한다. 반면 매핑되지 않은 주소를 건드리면 운영체제가 잘못된 접근으로 판단해 프로세스를 종료시킨다. 두 경우 모두 트랩으로 시작하지만 결과는 정반대다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step10 Slot1 꼬리질문2: 페이지 폴트 처리 시 빈 프레임이 없으면 운영체제는 다음에 무엇을 하는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[페이지 교체 알고리즘]]으로 내보낼 [[희생 페이지]]를 고르고, 필요하면 그 내용을 디스크에 기록한 뒤 비워진 [[프레임]]에 새 페이지를 올립니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 구획'),
       (@fq, '페이지 교체 알고리즘', '빈 프레임이 없을 때 어떤 페이지를 내보낼지 정하는 규칙. FIFO, LRU, 클럭 등이 있다'),
       (@fq, '희생 페이지', '새 페이지를 올릴 자리를 만들기 위해 메모리에서 밀려나는 페이지'),
       (@fq, '변경 비트', '페이지가 메모리에 올라온 뒤 수정됐는지를 표시하는 비트. 켜져 있으면 내보낼 때 디스크에 써야 한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '빈 [[프레임]]이 없으면 운영체제는 [[페이지 교체 알고리즘]]을 돌려 내보낼 [[희생 페이지]]를 고른다. 희생 페이지의 [[변경 비트]]가 켜져 있으면 메모리 내용이 디스크와 달라졌다는 뜻이라 먼저 보조기억장치에 기록한다. 그다음 비워진 프레임에 요청된 페이지를 읽어 오고, 페이지 테이블을 갱신한 뒤 폴트를 일으킨 명령어를 다시 실행한다.', 1),
       (@fq, '주의점', 'TEXT', '[[희생 페이지]]를 디스크에 쓰는 작업과 새 페이지를 읽어 오는 작업이 겹치면 디스크 입출력이 두 번 일어난다. [[변경 비트]]가 꺼진 페이지를 골라 내보내면 쓰기를 생략할 수 있어 폴트 처리 비용이 절반으로 줄어든다. 그래서 실제 교체 알고리즘은 최근 사용 여부뿐 아니라 수정 여부도 함께 본다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 10 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step10 Slot2 꼬리질문1: LRU와 OPT의 가장 중요한 차이는 어떤 정보에 기반해 교체 대상을 고른다는 점인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[LRU]]는 이미 지나간 과거 참조 이력만 보고 고르고, [[OPT]]는 앞으로 이어질 [[참조열]]을 미리 안다고 가정하고 고릅니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'LRU', 'Least Recently Used — 가장 오래전에 사용된 페이지를 교체하는 알고리즘'),
       (@fq, 'OPT', 'Optimal — 앞으로 가장 오랫동안 사용되지 않을 페이지를 교체하는 이론상 최적 알고리즘'),
       (@fq, '참조열', '프로세스가 접근하는 페이지 번호를 시간 순서대로 나열한 것');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[LRU]]는 지금까지의 참조 기록을 근거로 가장 오래전에 사용된 페이지를 내보낸다. [[OPT]]는 아직 오지 않은 [[참조열]]을 들여다보고 가장 나중에 다시 쓰일 페이지를 내보낸다. 같은 목표를 두고 한쪽은 과거를, 다른 한쪽은 미래를 근거로 삼는 셈이다.', 1),
       (@fq, 'OPT를 배우는 이유', 'TEXT', '[[OPT]]는 미래를 알아야 하므로 실제 시스템에서는 구현할 수 없다. 대신 어떤 알고리즘도 이보다 페이지 폴트를 적게 낼 수 없으므로, 다른 알고리즘의 성능을 재는 기준선으로 쓴다. [[LRU]]가 좋은 알고리즘으로 평가받는 이유도 이 기준선에 비교적 가깝기 때문이다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step10 Slot2 꼬리질문2: 실제 운영체제에서 순수 LRU를 그대로 구현하기 어려운 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '메모리를 참조할 때마다 사용 순서를 갱신해야 해서 비용이 너무 크기 때문에, 실제 운영체제는 [[참조 비트]]를 활용한 [[클럭 알고리즘]] 같은 [[근사 LRU]]를 씁니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '참조 비트', '페이지가 최근에 참조됐는지를 표시하는 1비트 정보. 접근이 일어나면 하드웨어가 1로 설정한다'),
       (@fq, '클럭 알고리즘', '프레임을 원형으로 순회하며 참조 비트가 0인 페이지를 교체하는 기법. 2차 기회 알고리즘이라고도 한다'),
       (@fq, '근사 LRU', '정확한 사용 순서를 추적하는 대신 참조 비트 등으로 LRU에 가깝게 흉내 내는 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '정확한 LRU는 페이지를 참조할 때마다 그 페이지를 사용 순서의 맨 앞으로 옮겨야 한다. 메모리 참조는 명령어 하나를 처리하는 동안에도 여러 번 일어나므로, 그때마다 소프트웨어가 목록을 갱신하면 감당할 수 없는 오버헤드가 생긴다. 그래서 대부분의 CPU는 페이지에 접근할 때 [[참조 비트]]를 1로 켜 주는 정도만 지원한다.', 1),
       (@fq, '실제 구현', 'TEXT', '운영체제는 이 비트를 주기적으로 0으로 지워 두고, 교체가 필요하면 [[클럭 알고리즘]]처럼 프레임을 원형으로 돌면서 비트가 0인 페이지를 골라 내보낸다. 정확한 사용 순서는 몰라도 최근에 쓰이지 않은 페이지를 대체로 찾아내므로 이를 [[근사 LRU]]라고 부른다. 널리 쓰이는 운영체제들이 택한 방식이 모두 이 계열이다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 10 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step10 Slot3 꼬리질문1: FIFO에서 Belady의 이상 현상이 왜 중요한가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[프레임]]을 늘리면 페이지 폴트가 줄어든다는 당연해 보이는 가정이 FIFO에서는 깨질 수 있음을 [[Belady의 이상 현상]]이 보여 주기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'Belady의 이상 현상', '프레임 수를 늘렸는데도 오히려 페이지 폴트가 늘어나는 현상. FIFO에서 나타난다'),
       (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 구획'),
       (@fq, '스택 알고리즘', '프레임 수를 늘리면 메모리에 남는 페이지 집합이 늘리기 전 집합을 항상 포함하는 성질을 가진 교체 알고리즘. Belady의 이상 현상이 생기지 않는다'),
       (@fq, 'LRU', '가장 오래전에 사용된 페이지를 교체하는 알고리즘');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[Belady의 이상 현상]]은 FIFO로 페이지를 교체할 때 [[프레임]] 수를 늘렸는데도 페이지 폴트가 오히려 늘어나는 경우를 말한다. FIFO는 도착 순서만 보고 내보낼 페이지를 정하므로, 곧 다시 쓸 페이지를 단지 먼저 들어왔다는 이유로 내보내기도 한다. 메모리를 늘리는 것이 언제나 성능 향상으로 이어지지는 않는다는 반례이기 때문에 중요하다.', 1),
       (@fq, '비교', 'TEXT', '[[LRU]]나 OPT는 [[스택 알고리즘]]에 속해서, [[프레임]]을 늘리면 메모리에 남는 페이지 집합이 늘리기 전 집합을 항상 포함한다. 그래서 이 알고리즘들에서는 프레임을 늘렸을 때 페이지 폴트가 늘어나는 일이 생기지 않는다. 이 현상은 그런 성질을 갖지 못한 FIFO 계열의 약점을 드러낸다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step10 Slot3 꼬리질문2: FIFO와 LRU는 교체 대상을 고르는 기준이 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[FIFO]]는 메모리에 들어온 시점이 가장 이른 페이지를 내보내고, [[LRU]]는 마지막으로 사용된 시점이 가장 이른 페이지를 내보냅니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'FIFO', 'First In First Out — 메모리에 먼저 적재된 페이지를 먼저 교체하는 알고리즘'),
       (@fq, 'LRU', 'Least Recently Used — 마지막 사용 시점이 가장 오래된 페이지를 교체하는 알고리즘'),
       (@fq, '참조 지역성', '최근에 참조한 데이터와 그 주변을 곧 다시 참조하는 프로그램의 경향');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[FIFO]]는 적재 시각만 본다. 어떤 페이지가 지금 아무리 자주 쓰이고 있어도 가장 먼저 들어온 페이지라면 교체 대상이 된다. [[LRU]]는 마지막 사용 시각을 보므로, 계속 쓰이고 있는 페이지는 계속 메모리에 남는다.', 1),
       (@fq, '성능 차이의 이유', 'TEXT', '프로그램은 [[참조 지역성]] 때문에 최근에 쓴 페이지를 곧 다시 쓰는 경향이 있다. [[LRU]]는 이 성질을 그대로 활용하므로 대체로 [[FIFO]]보다 페이지 폴트가 적다. 대신 마지막 사용 시각을 추적해야 해서 구현 비용은 더 크다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 10 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step10 Slot4 꼬리질문1: 같은 참조열에서 FIFO를 적용하면 어떤 페이지가 교체되는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[FIFO]]도 가장 먼저 적재된 페이지 1을 내보내므로, 이 참조열에서는 [[LRU]]와 교체 결과가 같습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'FIFO', 'First In First Out — 메모리에 먼저 적재된 페이지를 먼저 교체하는 알고리즘. 적중이 일어나도 적재 순서를 갱신하지 않는다'),
       (@fq, 'LRU', 'Least Recently Used — 마지막 사용 시점이 가장 오래된 페이지를 교체하는 알고리즘'),
       (@fq, '페이지 적중', '참조한 페이지가 이미 프레임에 올라와 있어 페이지 폴트 없이 처리되는 경우');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '참조열 1, 2, 3을 차례로 처리하면 세 프레임이 각각 1, 2, 3으로 채워진다. 네 번째 참조인 2는 [[페이지 적중]]이라 프레임 내용도, [[FIFO]]가 보는 적재 순서도 바뀌지 않는다. 따라서 4를 올릴 차례가 되면 가장 먼저 들어온 1이 밀려난다.', 1),
       (@fq, 'LRU와 비교', 'TEXT', '[[LRU]] 기준으로도 마지막 사용 시각이 가장 이른 페이지는 1이므로 똑같이 1이 교체된다. 다시 참조된 페이지 2가 마침 가장 오래된 페이지가 아니었던 덕분에 두 알고리즘의 결과가 우연히 일치한 것이다. 네 번째 참조가 2가 아니라 1이었다면 [[FIFO]]는 여전히 1을 내보내지만 LRU는 2를 내보내 결과가 갈린다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step10 Slot4 꼬리질문2: LRU를 정확히 구현하려면 어떤 추가 정보가 필요한가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '각 페이지가 마지막으로 사용된 시점을 알아야 하므로, 참조할 때마다 갱신되는 [[타임스탬프]]나 사용 순서를 유지하는 [[스택]] 같은 추가 정보가 필요합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '타임스탬프', '페이지를 참조한 시각을 기록해 두는 값. 교체할 때 가장 오래된 값을 가진 페이지를 고른다'),
       (@fq, '스택', '참조된 페이지를 맨 위로 올려 사용 순서를 유지하는 자료구조. 맨 아래가 가장 오래 안 쓰인 페이지다'),
       (@fq, '하드웨어 지원', '메모리를 참조할 때마다 기록을 대신 갱신해 주는 CPU와 MMU 차원의 도움');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '정확한 LRU는 페이지마다 마지막 사용 시점을 항상 알고 있어야 한다. 한 가지 방법은 페이지 테이블 항목에 [[타임스탬프]]를 두고 참조가 일어날 때마다 논리 시계 값을 기록하는 것이다. 다른 방법은 페이지 번호를 [[스택]]에 넣어 두고 참조된 페이지를 맨 위로 끌어올려, 맨 아래에 가장 오래 안 쓰인 페이지가 남게 하는 것이다.', 1),
       (@fq, '구현이 어려운 이유', 'TEXT', '문제는 이 갱신이 모든 메모리 참조마다 일어나야 한다는 점이다. 소프트웨어로 처리하면 메모리 접근 한 번마다 부가 작업이 붙어 크게 느려지므로 [[하드웨어 지원]] 없이는 감당하기 어렵다. 그래서 실제 운영체제는 참조 비트를 이용해 LRU를 흉내 내는 근사 방식을 택한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 10 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step10 Slot5 꼬리질문1: 스래싱을 줄이기 위해 운영체제가 조절할 수 있는 대표적인 요소는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '동시에 메모리에 올려 두는 프로세스 수, 즉 [[다중 프로그래밍 정도]]를 낮추는 것이 대표적이고, 각 프로세스의 [[프레임 할당량]]을 [[작업 집합]] 크기에 맞추는 방법도 함께 쓰입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '다중 프로그래밍 정도', '메모리에 동시에 올라와 있는 프로세스의 수'),
       (@fq, '프레임 할당량', '한 프로세스에 배정된 물리 프레임의 개수'),
       (@fq, '작업 집합', '최근 일정 구간 동안 프로세스가 실제로 참조한 페이지들의 집합'),
       (@fq, '스와핑', '프로세스를 통째로 메모리에서 보조기억장치로 내보내거나 다시 들여오는 일');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '스래싱은 실행 중인 프로세스들이 각자의 [[작업 집합]]을 담을 만큼의 프레임을 확보하지 못할 때 생긴다. 그래서 가장 직접적인 처방은 [[다중 프로그래밍 정도]]를 낮춰 메모리를 나눠 쓰는 프로세스 수 자체를 줄이는 것이다. CPU 이용률이 떨어지는데 페이지 폴트가 급증한다면, 프로세스를 더 들이는 대신 오히려 줄여야 한다는 신호다.', 1),
       (@fq, '구체적인 수단', 'TEXT', '각 프로세스의 [[프레임 할당량]]을 [[작업 집합]] 크기에 맞춰 조정하면 폴트가 잦은 프로세스에 프레임을 더 줄 수 있다. 페이지 폴트율이 상한을 넘으면 프레임을 늘리고 하한 아래로 떨어지면 회수하는 방식도 쓰인다. 그래도 메모리가 부족하면 일부 프로세스를 [[스와핑]]으로 통째로 내보내 나머지가 정상 속도로 돌게 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step10 Slot5 꼬리질문2: 작업 집합 모델은 스래싱을 설명할 때 왜 중요한가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[작업 집합]] 모델은 각 프로세스가 지금 필요로 하는 페이지 수를 수치로 잡아 주고, 그 합이 전체 [[프레임]] 수를 넘어서는 순간 [[스래싱]]이 시작된다고 설명해 주기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '작업 집합', '최근 일정 시간 동안 프로세스가 참조한 페이지들의 집합. 프로세스가 지금 필요로 하는 메모리 양의 근사치다'),
       (@fq, '지역성', '프로그램이 한동안 특정 페이지 묶음만 집중적으로 참조하는 성질'),
       (@fq, '프레임', '물리 메모리를 페이지와 같은 크기로 나눈 고정 크기 구획'),
       (@fq, '스래싱', '과도한 페이지 폴트로 대부분의 시간을 페이지 교체에 쓰느라 실제 실행이 진전되지 않는 상태');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[작업 집합]]은 최근 일정 구간 동안 프로세스가 실제로 참조한 페이지들의 모음이다. 프로그램은 [[지역성]] 때문에 한동안 비슷한 페이지 묶음만 참조하므로, 이 모음의 크기가 프로세스에 지금 필요한 메모리 양의 근사치가 된다. 운영체제는 각 프로세스의 작업 집합 크기를 더해 시스템 전체의 메모리 수요를 가늠할 수 있다.', 1),
       (@fq, '스래싱의 판정 기준', 'TEXT', '작업 집합 크기의 합이 쓸 수 있는 [[프레임]] 수보다 커지면 어떤 프로세스는 자기 작업 집합을 메모리에 다 담지 못한다. 그 프로세스는 페이지를 들여오고 내보내기를 반복하게 되고, 이것이 시스템 전체로 번지면 [[스래싱]]이 된다. 그래서 작업 집합 모델은 프로세스 수를 줄여야 할지 판단하는 정량적 근거가 된다.', 2);

-- ===================== STEP 11: 파일 시스템(파일 구조·디렉토리·할당 방식) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 11 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step11 Slot1 꼬리질문1: 연속 할당이 파일 확장에 불리한 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[연속 할당]]은 파일 바로 뒤 블록을 이미 다른 파일이 차지하고 있으면 그 자리에서 늘릴 수 없어, 더 큰 빈 구간을 찾아 파일 전체를 [[재배치]]해야 하기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '연속 할당', '파일의 데이터 블록을 디스크의 이어진 위치에 나란히 저장하는 방식. 시작 블록 번호와 길이만으로 전체 위치가 정해진다'),
       (@fq, '재배치', '지금 위치로는 파일을 더 늘릴 수 없을 때, 충분히 큰 빈 연속 구간을 찾아 파일 전체를 옮겨 다시 저장하는 일'),
       (@fq, '압축', '디스크 곳곳에 흩어진 빈 공간을 한쪽으로 모아 큰 연속 구간을 만들어 내는 정리 작업(compaction)');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[연속 할당]]에서 파일의 위치는 시작 블록 번호와 블록 개수라는 두 값으로 정해진다. 파일이 커지려면 바로 다음 블록까지 이어서 써야 하는데, 그 자리를 다른 파일이 이미 쓰고 있으면 더 늘릴 수 없다. 결국 지금보다 큰 빈 연속 구간을 찾아 파일 전체를 [[재배치]]해야 하고, 파일이 클수록 복사 비용이 그대로 커진다.', 1),
       (@fq, '대응 방법', 'TEXT', '파일을 만들 때 여유 블록을 미리 붙여 잡아 두면 어느 정도까지는 제자리에서 늘릴 수 있지만, 여유분을 다 쓰면 같은 문제가 돌아온다. 흩어진 빈 공간을 한쪽으로 모으는 [[압축]]으로 큰 연속 구간을 되찾을 수도 있으나, 디스크 대부분을 옮겨야 해서 비용이 크다. 연결 할당이나 인덱스 할당은 블록이 흩어져도 되므로 확장에 훨씬 자유롭다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step11 Slot1 꼬리질문2: 연속 할당에서 외부 단편화가 발생하는 원인을 설명해볼 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '파일이 만들어지고 지워지기를 반복하면서 빈 공간이 자잘한 조각으로 흩어져, 총합은 충분해도 이어진 구간이 없어지는 것이 [[외부 단편화]]입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '외부 단편화', '빈 공간이 작은 조각으로 흩어져, 남은 용량의 총합은 충분한데도 연속된 구간이 없어 새 파일을 배치하지 못하는 상태'),
       (@fq, '연속 할당', '파일의 데이터 블록을 디스크의 이어진 위치에 나란히 저장하는 방식. 파일마다 크기가 맞는 연속 구간 하나를 요구한다'),
       (@fq, '내부 단편화', '할당 단위(블록)보다 실제 데이터가 조금 작아 블록 끝에 쓰이지 못한 채 남는 자투리 공간');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[연속 할당]]은 파일 하나마다 크기가 맞는 연속 구간 하나를 요구한다. 파일이 삭제되면 그 자리만큼 빈 구간이 남는데, 새로 만들어지는 파일의 크기는 제각각이라 빈 구간이 딱 맞게 채워지지 않는다. 이런 일이 쌓이면 쓸 만한 큰 구간은 사라지고 작은 조각만 남아, 남은 용량을 다 더하면 충분한데도 새 파일을 배치하지 못하는 [[외부 단편화]]에 이른다.', 1),
       (@fq, '비교', 'TEXT', '[[내부 단편화]]는 할당 단위 안에서 생기는 낭비로, 블록 크기보다 파일이 조금 작을 때 블록 끝에 남는 자투리를 가리킨다. [[외부 단편화]]는 할당 단위 바깥, 즉 파일과 파일 사이에 생기는 낭비다. 빈 조각을 한쪽으로 모으는 압축 작업으로 외부 단편화는 줄일 수 있지만, 내부 단편화는 블록 크기를 줄이지 않는 한 그대로 남는다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 11 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step11 Slot2 꼬리질문1: 하드 링크와 심볼릭 링크의 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[하드 링크]]는 같은 [[inode]]를 가리키는 또 하나의 이름이고, [[심볼릭 링크]]는 대상의 경로 문자열을 내용으로 담은 별개의 파일입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '하드 링크', '같은 inode를 가리키는 디렉토리 항목을 하나 더 만들어, 한 파일에 이름을 여러 개 붙이는 방식'),
       (@fq, '심볼릭 링크', '대상 파일의 경로 문자열을 내용으로 갖는 별개의 파일. 대상이 사라지면 끊어진 링크가 된다'),
       (@fq, 'inode', '파일 이름을 뺀 메타데이터와 데이터 블록 위치를 담는 유닉스 계열 파일 시스템의 자료구조'),
       (@fq, '링크 카운트', '하나의 inode를 가리키는 디렉토리 항목의 개수. 0이 되어야 파일의 데이터가 회수된다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[하드 링크]]를 만들면 디렉토리에 이름이 하나 더 생기고, 그 이름은 원본과 똑같은 [[inode]]를 가리킨다. inode의 [[링크 카운트]]가 하나 오를 뿐이므로 원본 이름을 지워도 다른 이름이 남아 있는 한 데이터는 사라지지 않는다. [[심볼릭 링크]]는 대상 경로를 적어 둔 작은 파일이라, 대상이 사라지면 가리킬 곳이 없는 끊어진 링크가 된다.', 1),
       (@fq, '주의점', 'TEXT', '[[하드 링크]]는 [[inode]] 번호에 기대므로 같은 파일 시스템 안에서만 만들 수 있고, 순환 경로가 생기는 것을 막기 위해 디렉토리에는 보통 걸 수 없다. [[심볼릭 링크]]는 파일 시스템 경계를 넘고 아직 없는 경로도 가리킬 수 있지만, 접근할 때마다 적힌 경로를 한 번 더 해석해야 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step11 Slot2 꼬리질문2: 트리 구조 디렉토리의 장점은 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[트리 구조 디렉토리]]의 장점은 파일을 계층으로 묶어 이름 충돌을 없애고, [[경로명]] 하나로 어떤 파일이든 유일하게 지목하며 탐색 범위를 한 갈래로 좁힐 수 있다는 점입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '트리 구조 디렉토리', '디렉토리 안에 디렉토리를 둘 수 있는 계층형 구조. 뿌리에서 뻗어 나가는 나무 모양으로 파일을 조직한다'),
       (@fq, '경로명', '디렉토리 계층을 따라 파일에 이르는 이름의 나열. 트리 구조에서 파일을 유일하게 지목하는 수단'),
       (@fq, '작업 디렉토리', '지금 작업 중인 기준 디렉토리. 상대 경로는 이 위치를 출발점으로 해석된다'),
       (@fq, '단일 단계 디렉토리', '계층 없이 모든 파일이 하나의 목록에 놓이는 가장 단순한 디렉토리 구조. 파일 이름이 전부 달라야 한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[트리 구조 디렉토리]]는 디렉토리 안에 다시 디렉토리를 둘 수 있어 파일을 주제나 사용자별로 묶어 둔다. 서로 다른 디렉토리에 같은 이름의 파일이 있어도 뿌리에서부터 이어지는 [[경로명]]이 다르므로 서로 다른 파일로 구분된다. 파일을 찾을 때도 전체 목록을 훑지 않고 해당 가지만 따라 내려가면 된다.', 1),
       (@fq, '비교', 'TEXT', '[[단일 단계 디렉토리]]는 모든 파일이 한 목록에 놓여 이름이 전부 달라야 하고, 파일이 늘수록 이름 짓기와 검색이 함께 어려워진다. 트리 구조에서는 [[작업 디렉토리]]를 기준으로 상대 경로를 쓸 수 있어 긴 절대 경로를 매번 적지 않아도 된다. 접근 권한도 가지 단위로 걸기 쉬워진다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 11 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step11 Slot3 꼬리질문1: FAT 방식이 큰 저장장치에서 비효율적일 수 있는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[FAT]]은 [[클러스터]] 개수만큼 테이블 항목을 가져 장치가 커질수록 테이블이 함께 커지고, 파일 뒤쪽에 닿으려면 사슬을 앞에서부터 따라가야 하기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'FAT', 'File Allocation Table. 저장장치의 각 클러스터마다 다음 클러스터 번호를 적어 두는 한 장의 테이블로 파일을 사슬처럼 잇는 방식'),
       (@fq, '클러스터', '여러 개의 디스크 블록을 묶은 파일 시스템의 할당 단위. FAT은 클러스터 하나마다 테이블 항목 하나를 갖는다'),
       (@fq, '연결 할당', '각 블록이 다음 블록의 위치를 가리켜 파일을 사슬 형태로 잇는 할당 방식. 블록이 흩어져도 되지만 앞에서부터 따라가야 한다'),
       (@fq, '임의 접근', '파일의 처음부터 훑지 않고 원하는 위치로 곧바로 가는 접근. 랜덤 액세스라고도 한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[FAT]]은 저장장치의 모든 [[클러스터]]마다 다음 클러스터 번호를 적을 칸을 하나씩 둔다. 장치 용량이 커지면 칸의 개수도, 번호를 담는 칸의 폭도 함께 늘어 테이블을 통째로 메모리에 올려 두기가 부담스러워진다. 게다가 [[연결 할당]] 구조라 파일의 뒤쪽 블록을 읽으려면 앞에서부터 사슬을 따라가야 해서 [[임의 접근]]이 느리다.', 1),
       (@fq, '대응 방법', 'TEXT', '[[클러스터]] 크기를 키우면 테이블 항목 수는 줄지만, 작은 파일이 많을 때 블록 끝에 남는 내부 단편화가 커진다. 그래서 큰 볼륨에서는 파일마다 색인을 두는 인덱스 방식이나, 이어진 구간을 하나의 범위로 기록하는 익스텐트 방식을 쓰는 파일 시스템이 유리하다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step11 Slot3 꼬리질문2: 인덱스 할당과 FAT 방식의 차이를 비교해볼 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[FAT]]은 장치 전체의 블록 연결 정보를 테이블 한 장에 모으고, [[인덱스 할당]]은 파일마다 [[인덱스 블록]]에 그 파일의 블록 주소만 모아 둔다는 것이 핵심 차이입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'FAT', 'File Allocation Table. 장치의 모든 블록에 대한 다음 블록 번호를 한 장의 테이블에 모아 파일을 사슬로 잇는 방식'),
       (@fq, '인덱스 할당', '파일마다 블록 주소 목록을 담은 색인을 두어 데이터 블록을 찾는 할당 방식'),
       (@fq, '인덱스 블록', '한 파일의 데이터 블록 주소들을 순서대로 모아 둔 블록. 색인 역할을 한다'),
       (@fq, '임의 접근', '파일의 앞부분을 거치지 않고 원하는 위치로 곧바로 가는 접근 방식');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[FAT]]에서는 블록 번호가 곧 테이블 칸의 번호이고 그 칸에 다음 블록 번호가 들어 있어, 파일 하나가 사슬 형태로 표현된다. [[인덱스 할당]]은 파일마다 [[인덱스 블록]]을 하나 두고 그 안에 데이터 블록 주소를 순서대로 적는다. 두 방식 모두 데이터 블록이 물리적으로 흩어져도 되지만, 주소 정보를 장치 단위로 모으느냐 파일 단위로 모으느냐가 갈린다.', 1),
       (@fq, '트레이드오프', 'TEXT', '[[인덱스 할당]]은 파일의 특정 위치에 해당하는 주소를 색인에서 바로 꺼내므로 [[임의 접근]]이 빠르다. 대신 아주 작은 파일에도 [[인덱스 블록]]을 통째로 하나 소비하고, 파일이 커지면 간접 블록 같은 다단 구조가 필요해진다. [[FAT]]은 구조가 단순하고 테이블이 메모리에 올라와 있으면 사슬 추적에 디스크 읽기가 들지 않지만, 테이블이 커질수록 그 전제가 흔들린다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 11 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step11 Slot4 꼬리질문1: 인덱스 할당이 직접 접근에 유리한 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '파일의 특정 위치에 해당하는 블록 주소가 [[인덱스 블록]]의 정해진 칸에 있어, 앞쪽 블록을 하나도 읽지 않고 곧장 목표 블록으로 갈 수 있기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '인덱스 할당', '파일마다 블록 주소 목록을 담은 색인을 두고, 그 색인을 통해 데이터 블록에 접근하는 할당 방식'),
       (@fq, '인덱스 블록', '한 파일의 데이터 블록 주소들을 순서대로 담은 블록. n번째 칸이 n번째 데이터 블록의 주소를 가리킨다'),
       (@fq, '직접 접근', '앞부분을 거치지 않고 파일의 원하는 위치로 곧바로 가는 접근 방식'),
       (@fq, '연결 할당', '각 데이터 블록이 다음 블록의 주소를 품어 파일을 사슬처럼 잇는 방식. 뒤쪽 블록에 닿으려면 앞을 차례로 거쳐야 한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[인덱스 할당]]은 파일의 데이터 블록 주소를 [[인덱스 블록]] 한 곳에 순서대로 모아 둔다. 파일 중간을 읽고 싶으면 그 지점이 몇 번째 블록인지 계산해 색인의 해당 칸만 꺼내 보면 된다. 이렇게 앞을 거치지 않고 원하는 곳으로 바로 가는 접근이 [[직접 접근]]이다.', 1),
       (@fq, '비교', 'TEXT', '[[연결 할당]]에서는 다음 블록의 주소가 각 데이터 블록 안에 들어 있다. 그래서 뒤쪽 블록에 닿으려면 앞의 블록들을 차례로 읽어 주소를 얻어야 하고, 읽기 횟수가 위치에 비례해 늘어난다. 처음부터 끝까지 훑는 순차 접근에는 무리가 없지만, 파일 중간을 곧바로 읽는 작업에는 불리하다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step11 Slot4 꼬리질문2: inode에서 직접 블록 포인터와 간접 블록 포인터는 어떤 차이가 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[직접 블록 포인터]]는 데이터 블록을 곧바로 가리키고, [[간접 블록 포인터]]는 데이터가 아니라 주소 목록이 담긴 블록을 가리켜 한 단계를 더 거치는 포인터입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'inode', '파일 이름을 뺀 메타데이터와 데이터 블록 위치 정보를 담는 유닉스 계열 파일 시스템의 자료구조'),
       (@fq, '직접 블록 포인터', 'inode 안에서 데이터 블록을 곧바로 가리키는 포인터. 작은 파일은 이것만으로 표현된다'),
       (@fq, '간접 블록 포인터', '데이터가 아니라 블록 주소 목록이 담긴 블록을 가리키는 포인터. 한 단계를 더 거쳐 데이터 블록에 닿는다'),
       (@fq, '이중 간접 블록', '간접 블록의 주소를 담은 블록. 단계를 한 번 더 늘려 더 큰 파일의 블록 주소를 표현한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[inode]]는 앞쪽에 [[직접 블록 포인터]]를 몇 개 두어 작은 파일의 데이터 블록을 바로 가리킨다. 파일이 커져 직접 포인터가 모자라면 [[간접 블록 포인터]]를 쓰는데, 이 포인터가 가리키는 블록에는 데이터가 아니라 또 다른 블록 주소들이 들어 있다. 더 큰 파일은 [[이중 간접 블록]]처럼 단계를 한 번 더 늘려 표현한다.', 1),
       (@fq, '이렇게 나눈 이유', 'TEXT', '작은 파일이 대다수라는 경향을 전제로, 흔한 경우는 [[inode]]만 읽고 데이터 블록에 닿게 하고 드문 큰 파일에만 추가 읽기를 물린 설계다. 그 대가로 파일이 커질수록 블록 하나에 도달하기까지 거쳐야 하는 단계가 늘어난다. 덕분에 inode 크기를 고정해 두고도 아주 큰 파일까지 표현할 수 있다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 11 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step11 Slot5 꼬리질문1: 디렉토리 엔트리와 inode의 역할 차이를 설명할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[디렉토리 엔트리]]는 파일 이름과 [[inode]] 번호를 짝지어 두는 목록의 한 줄이고, inode는 이름을 뺀 나머지 [[메타데이터]]와 데이터 블록 위치를 담는 자료구조입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '디렉토리 엔트리', '디렉토리가 가진 목록의 한 줄. 파일 이름과 그 파일의 inode 번호를 짝지어 둔다'),
       (@fq, 'inode', '파일 이름을 뺀 나머지 메타데이터와 데이터 블록 위치를 담는 자료구조. 파일의 실체에 해당한다'),
       (@fq, '메타데이터', '파일의 내용이 아니라 파일에 관한 정보. 소유자, 권한, 크기, 시간 정보 등이 여기 속한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[디렉토리 엔트리]]에는 사람이 쓰는 파일 이름과 그 파일의 [[inode]] 번호가 들어 있다. inode에는 소유자, 권한, 크기, 시간 정보 같은 [[메타데이터]]와 데이터 블록의 위치가 담기고, 파일 이름은 담기지 않는다. 그래서 이름을 바꾸는 일은 디렉토리 쪽 항목만 고치면 끝나고 파일 내용과 메타데이터는 그대로 남는다.', 1),
       (@fq, '왜 나눠 두는가', 'TEXT', '이름과 실체를 분리해 두었기에 한 파일에 이름을 여러 개 붙이는 하드 링크가 가능해진다. 경로를 따라가는 일은 [[디렉토리 엔트리]]에서 이름에 맞는 [[inode]] 번호를 얻고, 그 inode를 읽어 다음 디렉토리의 데이터 블록을 찾는 과정의 반복이다. 이름 검색과 [[메타데이터]] 조회가 서로 다른 자료구조에서 일어나는 셈이다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step11 Slot5 꼬리질문2: 하드 링크가 inode와 어떤 관계를 가지는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[하드 링크]]는 같은 [[inode]]를 가리키는 [[디렉토리 엔트리]]를 하나 더 만드는 일이라, 이름은 달라도 실체는 하나입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '하드 링크', '같은 inode를 가리키는 디렉토리 항목을 하나 더 만들어, 한 파일에 여러 이름을 붙이는 방식'),
       (@fq, 'inode', '파일의 메타데이터와 데이터 블록 위치를 담는 자료구조. 파일 이름은 담지 않아 이름과 실체가 분리된다'),
       (@fq, '디렉토리 엔트리', '파일 이름과 inode 번호를 짝지어 둔 디렉토리 목록의 한 줄'),
       (@fq, '링크 카운트', '하나의 inode를 가리키는 디렉토리 항목의 개수. 0이 되어야 데이터 블록과 inode가 회수된다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[하드 링크]]를 만들면 새 이름을 담은 [[디렉토리 엔트리]]가 하나 추가되고, 그 항목은 기존 파일과 똑같은 [[inode]]를 가리킨다. inode 안의 [[링크 카운트]]는 자신을 가리키는 디렉토리 항목의 수를 세며 링크가 늘 때마다 1씩 올라간다. 어느 이름으로 열어도 같은 데이터와 같은 권한을 보게 되는 이유가 여기에 있다.', 1),
       (@fq, '주의점', 'TEXT', '이름 하나를 지우는 것은 [[링크 카운트]]를 1 줄이는 일일 뿐이고, 이 값이 0이 되어야 데이터 블록과 [[inode]]가 회수된다. inode 번호는 그 파일 시스템 안에서만 뜻이 통하므로 [[하드 링크]]는 다른 파일 시스템의 파일에는 걸 수 없다. 디렉토리에 하드 링크를 거는 일도 순환 경로를 만들 수 있어 보통 막혀 있다.', 2);

-- ===================== STEP 12: 입출력과 디스크 관리(버퍼링·스풀링·디스크 스케줄링) =====================
SET @qid = (SELECT id FROM quiz WHERE step_order = 12 AND slot_order = 1);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step12 Slot1 꼬리질문1: 버퍼링과 캐싱은 목적이 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[버퍼링]]은 속도 차이를 완화하려고 데이터를 잠시 모아 두는 기법이고, [[캐싱]]은 한 번 읽은 데이터를 다시 빠르게 쓰려고 가까운 곳에 복사해 두는 기법입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '버퍼링', '속도가 다른 두 주체 사이에 중간 저장 공간을 두어 서로 기다리는 시간을 줄이는 기법'),
       (@fq, '캐싱', '한 번 접근한 데이터를 더 빠른 저장 계층에 복사해 두었다가 재요청 시 원본 대신 사용하는 기법'),
       (@fq, '지역성', '최근 접근한 데이터나 그 근처의 데이터가 곧 다시 접근될 가능성이 높다는 성질. 캐시가 효과를 내는 전제');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[버퍼링]]의 목적은 생산자와 소비자의 속도 차이에서 오는 대기를 줄이는 것이고, 버퍼에 담긴 데이터는 한 번 소비되면 대개 사라진다. [[캐싱]]의 목적은 이미 접근한 데이터를 더 빠른 저장 계층에 복사해 두고, 같은 데이터를 다시 요청할 때 원본까지 가지 않도록 하는 것이다. 요약하면 버퍼링은 속도 차 완화, 캐싱은 재사용 가속이다.', 1),
       (@fq, '비교', 'TEXT', '[[캐싱]]은 같은 데이터가 다시 요청되리라는 [[지역성]] 가정 위에서만 이득을 본다. [[버퍼링]]은 재요청이 없어도 이득이 있다. 데이터를 한 번만 흘려보내도 양쪽이 서로를 기다리는 시간이 줄기 때문이다. 실제 운영체제에서는 디스크 블록을 담아 두는 같은 메모리 공간이 버퍼 역할과 캐시 역할을 함께 맡기도 한다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step12 Slot1 꼬리질문2: 단일 버퍼와 이중 버퍼의 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[단일 버퍼]]는 버퍼 하나를 채우고 비우는 동안 장치와 프로세스가 서로 기다려야 하지만, [[이중 버퍼]]는 버퍼 두 개를 번갈아 써서 채우기와 비우기를 동시에 진행합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '단일 버퍼', '버퍼를 하나만 두는 방식. 채우는 쪽과 비우는 쪽이 같은 공간을 다투므로 한쪽이 일하는 동안 다른 쪽은 대기한다'),
       (@fq, '이중 버퍼', '버퍼를 두 개 두고 번갈아 사용하는 방식. 한쪽을 채우는 동안 다른 쪽을 비울 수 있어 입출력과 처리가 겹쳐 진행된다'),
       (@fq, '생산자-소비자', '데이터를 만들어 내는 쪽과 꺼내 쓰는 쪽이 공유 버퍼를 사이에 두고 협력하는 구조');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[단일 버퍼]]에서는 장치가 버퍼를 채우는 동안 프로세스가 그 버퍼를 읽을 수 없고, 프로세스가 비우는 동안 장치는 새 데이터를 넣을 수 없다. [[이중 버퍼]]는 버퍼를 두 개 두고 한쪽이 채워지는 동안 다른 쪽을 소비하게 해 이 대기를 없앤다. 그 결과 장치의 전송과 프로세스의 처리가 시간상 겹쳐 진행된다.', 1),
       (@fq, '주의점', 'TEXT', '버퍼를 두 개로 늘린다고 처리량이 두 배가 되지는 않는다. [[생산자-소비자]] 중 한쪽이 확연히 느리면 전체 속도는 결국 느린 쪽에 맞춰진다. 데이터가 몰렸다 끊겼다 하는 입출력에서는 버퍼를 여러 개 이어 붙인 순환 버퍼를 써서 순간적인 폭주를 흡수한다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 12 AND slot_order = 2);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step12 Slot2 꼬리질문1: 버퍼링과 스풀링의 저장 위치와 사용 목적은 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[버퍼링]]은 메인 메모리에 데이터를 잠시 담아 속도 차를 줄이고, [[스풀링]]은 디스크에 작업 전체를 쌓아 두어 장치 한 대를 여러 작업이 나눠 쓰게 합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '버퍼링', '메인 메모리의 중간 저장 공간에 데이터를 잠시 담아 장치와 프로세스의 속도 차이를 완화하는 기법'),
       (@fq, '스풀링', '작업을 디스크 같은 보조 저장장치에 모아 두고 장치가 처리 가능한 순서대로 꺼내 쓰게 하는 기법'),
       (@fq, '스풀 디렉터리', '스풀링된 작업이 파일 형태로 저장되는 디스크상의 디렉터리. 리눅스에서는 /var/spool 아래에 둔다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[버퍼링]]은 데이터 조각 단위로 동작한다. 메인 메모리의 작은 공간에 바이트나 블록을 잠시 담았다가 곧바로 흘려보내므로 장치와 프로세스가 동시에 살아 있어야 한다. [[스풀링]]은 작업 단위로 동작한다. 인쇄물 한 건이 통째로 디스크에 저장되므로, 요청한 프로세스가 종료된 뒤에도 출력은 남아서 차례를 기다린다.', 1),
       (@fq, '비교', 'TEXT', '저장 위치가 다르면 담아 둘 수 있는 양과 기간도 달라진다. 메모리의 버퍼는 크기가 제한적이라 데이터를 오래 붙들지 못하지만, 디스크의 [[스풀 디렉터리]]는 여러 작업을 넉넉히 보관한다. 그래서 프린터나 배치 작업처럼 처리가 오래 걸리는 대상은 [[스풀링]]으로 다루고, 키보드 입력이나 네트워크 수신처럼 흐름이 끊기면 안 되는 대상은 [[버퍼링]]으로 다룬다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step12 Slot2 꼬리질문2: 프린터 스풀러가 장애를 일으키면 어떤 문제가 발생할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[스풀러]] 프로세스가 멈추면 인쇄 요청은 [[스풀 큐]]에 쌓이기만 하고 출력되지 않으며, 쌓인 작업 파일이 디스크 공간을 잠식합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '스풀러', '스풀 큐에 쌓인 작업을 꺼내 실제 장치로 전달하는 프로그램. 보통 데몬 형태로 계속 떠 있다'),
       (@fq, '스풀 큐', '장치가 처리하기를 기다리는 작업들이 순서대로 쌓여 있는 대기열. 디스크의 파일로 보관된다'),
       (@fq, '단일 장애 지점', '그 하나가 멈추면 전체 기능이 멈추는 구성 요소. 스풀러처럼 장치를 독점 관리하는 프로세스가 여기에 해당한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[스풀러]]는 디스크에 쌓인 작업을 꺼내 프린터로 보내는 역할을 맡는다. 이 프로세스가 죽으면 응용 프로그램은 여전히 작업을 [[스풀 큐]]에 넣을 수 있지만 아무것도 출력되지 않는다. 큐가 비워지지 않으면 작업 파일이 계속 남아 디스크 용량을 잡아먹고, 손상된 작업 하나가 큐 앞을 막으면 뒤따르는 작업까지 함께 멈춘다.', 1),
       (@fq, '주의점', 'TEXT', '[[스풀러]]는 장치 한 대를 대표해 관리하므로 [[단일 장애 지점]]이 되기 쉽다. 복구는 보통 스풀러 서비스를 재시작하고 큐에 남은 작업 파일을 정리하는 순서로 한다. 큐가 디스크를 가득 채우는 사태를 막으려면 스풀 영역을 별도 파티션에 두거나 용량 상한을 건다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 12 AND slot_order = 3);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step12 Slot3 꼬리질문1: SSTF에서 기아를 줄이기 위해 어떤 알고리즘을 고려할 수 있는가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '헤드를 한 방향으로 끝까지 훑는 [[SCAN]]이나, 항상 같은 방향으로만 훑어 대기 시간을 고르게 만드는 [[C-SCAN]]을 쓰면 [[기아]]를 줄일 수 있습니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'SSTF', 'Shortest Seek Time First. 현재 헤드 위치에서 탐색 거리가 가장 짧은 요청을 먼저 처리하는 디스크 스케줄링 알고리즘'),
       (@fq, '기아', '특정 요청이 계속 뒤로 밀려 오랫동안, 또는 영영 처리되지 못하는 현상'),
       (@fq, 'SCAN', '헤드가 한 방향으로 이동하며 경로상의 요청을 처리하고 끝에 닿으면 방향을 바꾸는 알고리즘. 엘리베이터 알고리즘이라고도 한다'),
       (@fq, 'C-SCAN', '끝에 닿으면 요청을 처리하지 않고 반대쪽 끝으로 되돌아가 항상 같은 방향으로만 훑는 SCAN 변형. 대기 시간이 더 균일하다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[SSTF]]는 가까운 요청만 골라 처리하므로 헤드에서 먼 요청이 계속 밀려 [[기아]]가 생긴다. [[SCAN]]은 헤드가 한쪽 끝까지 이동하며 경로에 놓인 요청을 모두 처리하고 방향을 바꾸므로, 어떤 요청도 헤드가 한 번 왕복하는 시간 안에는 처리된다. 대기 시간에 상한이 생긴다는 점이 핵심이다.', 1),
       (@fq, '비교', 'TEXT', '[[C-SCAN]]은 한쪽 끝에 도달하면 요청을 처리하지 않고 반대쪽 끝으로 되돌아간 뒤 다시 같은 방향으로 훑는다. 방금 지나온 위치의 요청이 곧바로 다시 처리되는 [[SCAN]]의 불균형이 사라져 대기 시간이 더 고르게 분포한다. 실제 구현에서는 마지막 요청까지만 이동하고 되돌아가는 LOOK, C-LOOK 변형이 흔히 쓰인다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step12 Slot3 꼬리질문2: SSTF와 SCAN은 헤드 이동 패턴이 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'MEDIUM',
    one_line_answer = '[[SSTF]]는 매번 가장 가까운 요청을 찾아 방향을 가리지 않고 오가지만, [[SCAN]]은 한 방향으로 끝까지 이동한 뒤 방향을 바꾸는 규칙적인 왕복을 합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'SSTF', '현재 헤드에서 탐색 거리가 가장 짧은 요청을 먼저 처리하는 알고리즘. 이동 방향이 자주 바뀐다'),
       (@fq, 'SCAN', '헤드가 한 방향으로 끝까지 이동하며 요청을 처리하고, 끝에 닿으면 방향을 바꿔 되돌아오는 알고리즘'),
       (@fq, '탐색 시간', '디스크 헤드가 목표 실린더까지 이동하는 데 걸리는 시간. 디스크 접근 시간의 큰 부분을 차지한다'),
       (@fq, '엘리베이터 알고리즘', 'SCAN의 별칭. 엘리베이터가 한 방향으로 올라가며 승객을 태우고 꼭대기에서 방향을 바꾸는 모습에서 나온 이름');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[SSTF]]는 요청 목록에서 헤드와의 거리가 최소인 요청을 고르므로 이동 방향이 수시로 뒤바뀐다. [[SCAN]]은 방향을 정해 놓고 그 방향에 놓인 요청을 순서대로 처리하다가 끝에서만 방향을 바꾼다. 그래서 SSTF의 이동 경로는 예측하기 어렵고, SCAN의 경로는 실린더 번호를 따라 오르내리는 톱니 모양이 된다.', 1),
       (@fq, '비교', 'TEXT', '평균 [[탐색 시간]]만 보면 [[SSTF]]가 유리한 경우가 많다. 매번 가장 가까운 곳으로 가기 때문이다. 대신 요청 하나하나가 기다리는 시간의 편차는 커진다. [[SCAN]]은 헤드가 [[엘리베이터 알고리즘]]처럼 층을 오르내리며 지나가는 요청을 모두 태우므로 개별 요청의 대기 시간을 예측할 수 있다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 12 AND slot_order = 4);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step12 Slot4 꼬리질문1: 프린터 스풀링에서 디스크를 사용하는 이유는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '인쇄 작업은 용량이 크고 처리에 오래 걸려 [[메인 메모리]]에 붙들어 둘 수 없고, 디스크에 [[스풀 파일]]로 남겨 두면 [[비휘발성]] 저장 덕분에 요청한 프로세스가 끝난 뒤에도 작업이 살아남기 때문입니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '메인 메모리', 'CPU가 직접 접근하는 주기억장치. 빠르지만 용량이 제한적이고 전원이 꺼지면 내용이 사라진다'),
       (@fq, '스풀 파일', '디스크에 저장된 인쇄 작업 하나의 실체. 스풀러가 이 파일을 읽어 장치로 보낸다'),
       (@fq, '비휘발성', '전원이 끊겨도 저장된 내용이 사라지지 않는 성질. 디스크와 SSD가 여기에 해당한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '프린터는 초당 처리량이 낮아 문서 한 건을 뽑는 데도 시간이 걸린다. 그동안 인쇄 데이터를 [[메인 메모리]]에 잡아 두면 여러 작업이 겹칠 때 메모리가 금세 모자란다. 디스크는 용량이 크고 값이 싸서 큰 작업 여러 개를 [[스풀 파일]]로 담아 둘 수 있고, [[비휘발성]]이라 시스템이 재부팅돼도 남은 작업을 이어서 처리할 수 있다.', 1),
       (@fq, '실무 사용처', 'TEXT', '리눅스의 인쇄 시스템은 인쇄 작업을 /var/spool 아래에 파일로 저장하고, 데몬이 이를 하나씩 꺼내 프린터로 보낸다. 메일 서버가 아직 보내지 못한 편지를 큐 디렉터리에 파일로 쌓아 두는 것도 같은 이유에서다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step12 Slot4 꼬리질문2: 버퍼링과 스풀링은 저장 위치와 작업 단위에서 어떻게 다른가?
UPDATE quiz_follow_up_question
SET difficulty      = 'EASY',
    one_line_answer = '[[버퍼링]]은 메모리에서 바이트나 블록 같은 데이터 조각을 다루고, [[스풀링]]은 디스크에서 인쇄물 한 건 같은 [[작업 단위]]를 다룹니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, '버퍼링', '메모리의 중간 공간에 데이터 조각을 잠시 담아 두어 장치와 프로세스의 속도 차를 완화하는 기법'),
       (@fq, '스풀링', '작업 전체를 디스크에 저장해 두고 장치가 순서대로 꺼내 처리하게 하는 기법. 장치 공유를 가능하게 한다'),
       (@fq, '작업 단위', '장치가 한 번에 처리하는 논리적 묶음. 스풀링에서는 인쇄물 한 건처럼 완결된 작업 하나가 여기에 해당한다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[버퍼링]]이 다루는 단위는 바이트나 블록이다. 버퍼가 차면 곧바로 소비되고 그 공간은 다음 데이터에 재사용된다. [[스풀링]]이 다루는 단위는 작업 하나 전체다. 문서 한 건이 통째로 디스크에 저장되고, 프린터는 그 작업을 처음부터 끝까지 처리한 뒤에야 다음 작업으로 넘어간다.', 1),
       (@fq, '비교', 'TEXT', '저장 위치의 차이는 곧 수명의 차이다. 메모리에 있는 버퍼의 내용은 프로세스가 끝나거나 전원이 꺼지면 사라지지만, 디스크에 있는 스풀 파일은 그대로 남는다. 그래서 여러 프로세스가 프린터 한 대를 나눠 쓰는 [[작업 단위]] 공유에는 [[스풀링]]이 맞고, 장치와 프로세스의 속도 차를 메우는 데는 [[버퍼링]]이 맞다.', 2);

SET @qid = (SELECT id FROM quiz WHERE step_order = 12 AND slot_order = 5);
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
-- Step12 Slot5 꼬리질문1: SCAN과 C-SCAN의 서비스 공정성 차이는 무엇인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '[[SCAN]]은 방향을 바꾼 직후 방금 지나온 구역을 다시 훑어 가운데 실린더가 양 끝보다 자주 서비스되지만, [[C-SCAN]]은 항상 한 방향으로만 훑어 [[대기 시간]] 분포를 고르게 만듭니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'SCAN', '헤드가 한 방향 끝까지 이동하며 요청을 처리하고 방향을 뒤집어 되돌아오는 알고리즘. 왕복 경로 양쪽에서 요청을 처리한다'),
       (@fq, 'C-SCAN', '끝에 닿으면 요청 처리 없이 반대쪽 끝으로 되돌아가 늘 같은 방향으로만 훑는 알고리즘. 실린더를 원형으로 취급한다'),
       (@fq, '대기 시간', '요청이 큐에 들어온 뒤 실제로 서비스받기까지 걸리는 시간. 평균값뿐 아니라 편차와 상한도 중요하다'),
       (@fq, '공정성', '어느 요청도 부당하게 오래 기다리지 않는 성질. 평균 성능이 좋아도 편차가 크면 공정하지 않다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '[[SCAN]]은 끝에 닿으면 방향을 뒤집어 왔던 길을 되돌아오며 요청을 처리한다. 그래서 헤드가 막 지나친 위치의 요청은 짧게 기다리고, 반대쪽 끝의 요청은 한 번의 왕복을 다 기다린다. [[C-SCAN]]은 끝에 닿으면 요청을 처리하지 않고 반대쪽 끝으로 되돌아간 뒤 같은 방향으로 다시 훑기 때문에, 모든 실린더가 한 바퀴에 한 번씩 서비스된다.', 1),
       (@fq, '비교', 'TEXT', '[[공정성]]의 차이는 평균 [[대기 시간]]이 아니라 그 편차로 드러난다. [[C-SCAN]]은 되돌아가는 이동에 시간을 쓰므로 전체 처리량은 [[SCAN]]보다 조금 불리할 수 있지만, 어느 요청도 한 바퀴 이상 기다리지 않아 대기 시간의 상한이 명확하다. 응답 시간의 예측 가능성이 중요한 시스템에서는 C-SCAN을 고른다.', 2);

SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
-- Step12 Slot5 꼬리질문2: SCAN이 SSTF보다 유리한 상황은 언제인가?
UPDATE quiz_follow_up_question
SET difficulty      = 'HARD',
    one_line_answer = '요청이 끊임없이 들어와 디스크 [[부하]]가 높고 [[기아]] 위험이 큰 상황, 그리고 요청별 응답 시간의 상한을 보장해야 하는 상황에서 [[SCAN]]이 [[SSTF]]보다 유리합니다.'
WHERE id = @fq;
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@fq, 'SCAN', '헤드가 한 방향으로 끝까지 훑고 방향을 바꾸는 알고리즘. 모든 요청이 한 왕복 안에 처리되어 대기 시간에 상한이 생긴다'),
       (@fq, 'SSTF', '가장 가까운 요청을 먼저 처리하는 알고리즘. 평균 탐색 시간은 짧지만 먼 요청이 계속 밀릴 수 있다'),
       (@fq, '기아', '특정 요청이 다른 요청에 계속 밀려 오랫동안 처리되지 못하는 현상. 부하가 높을수록 심해진다'),
       (@fq, '부하', '단위 시간에 들어오는 요청의 양. 부하가 높아 큐가 길어질수록 스케줄링 알고리즘의 차이가 뚜렷해진다');
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@fq, '해설', 'TEXT', '요청이 드문드문 들어오면 [[SSTF]]와 [[SCAN]]의 성능 차이는 거의 없다. 문제는 [[부하]]가 높을 때다. 큐에 요청이 계속 쌓이면 SSTF는 헤드 근처의 요청만 골라 처리하느라 멀리 있는 요청을 무한정 미루고, 이때 [[기아]]가 실제로 발생한다. SCAN은 헤드가 한 방향으로 끝까지 가므로 모든 요청이 한 번의 왕복 안에 처리된다.', 1),
       (@fq, '실무 사용처', 'TEXT', '여러 사용자의 요청이 실린더 전체에 흩어지는 파일 서버나 데이터베이스 서버가 대표적이다. 반대로 요청이 한 영역에 몰려 있고 큐가 짧은 워크로드라면 [[SSTF]]의 짧은 탐색 거리가 그대로 이득이 된다. 다만 오늘날의 SSD는 헤드 이동이 없어 이런 스케줄링 자체의 의미가 크게 줄었다.', 2);

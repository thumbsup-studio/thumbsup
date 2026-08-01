-- #233 지식 그래프: Concept 마스터 데이터·관계 큐레이션, 기존 quiz_derived_concept 정규화.
-- 문제(퀴즈)당 핵심 개념 1개만 그래프에 연결하기로 하고, 문제 지문·해설을 직접 읽어 70개 문제 각각의
-- 핵심 개념을 판단했다 — 원본 205개 파생개념(문제당 최대 3개) 중 실제로 연결되는 것은 64개뿐이다.
-- 관계(concept_relation)는 co-occurrence 통계가 아니라 CS 도메인 의미를 기준으로 직접 설계했다 — 코스·스텝 경계를 넘어 연결될 수 있다.
-- concept_description은 개념이 여러 스텝에 걸쳐 다른 뉘앙스로 등장하는 경우(3개: wait 연산/문맥 전환/임계 구역)를
-- 대비해 스텝 단위로 문장을 쪼갠 것이다 — 조회 시 유저가 실제로 완료한 step_order의 문장만 노출된다.
--
-- ⚠️ 큐레이션 불변식: 하나의 개념은 하나의 코스에서만 출제된다(현재 OS 1~12스텝 / 디자인패턴 13~14스텝이
-- 완전히 분리). LearnedConceptRecorder의 조회-후-삽입이 코스 단위 락만으로 안전한 근거이므로,
-- 개념이 코스를 넘나들게 큐레이션을 바꾸면 그쪽 기록 로직을 멱등(upsert)으로 함께 바꿔야 한다.

INSERT INTO concept (id, name, category, created_at, updated_at) VALUES
  (1, 'CPU 버스트', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (2, 'CPU 이용률', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (3, 'FCFS', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (4, 'FCFS 디스크 스케줄링', '입출력', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (5, 'I/O 완료 인터럽트', '프로세스', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (6, 'SCAN 알고리즘', '입출력', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (7, 'Waiting 상태', '프로세스', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (8, 'double-checked locking', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (9, 'wait 연산', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (10, '가변 분할', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (11, '간접 블록', '파일시스템', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (12, '개방-폐쇄 원칙', '객체지향 설계', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (13, '공유 메모리', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (14, '관련 객체 집합 생성', '객체지향 설계', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (15, '교착상태 4대 조건', '교착상태', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (16, '교착상태 회피', '교착상태', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (17, '구조 패턴', '생성 패턴', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (18, '동시성', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (19, '락 소유권', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (20, '멀티레벨 피드백 큐', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (21, '무한 대기', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (22, '문맥 전환', '프로세스', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (23, '버퍼 용량', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (24, '버퍼링', '입출력', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (25, '비선점형 스케줄링', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (26, '사용자 공간·커널 공간', '운영체제 개요', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (27, '사용자 모드·커널 모드', '운영체제 개요', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (28, '상호 배제', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (29, '생성 책임 분리', '객체지향 설계', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (30, '세그먼트 테이블', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (31, '순환 대기', '교착상태', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (32, '시스템 콜', '운영체제 개요', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (33, '안전 순서', '교착상태', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (34, '압축', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (35, '외부 단편화', '파일시스템', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (36, '요구 페이징', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (37, '우선순위 스케줄링', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (38, '원자성', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (39, '원자적 연산', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (40, '이진 세마포어', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (41, '인쇄 시스템', '입출력', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (42, '인터럽트', '프로세스', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (43, '임계 구역', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (44, '자원 순서 부여', '교착상태', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (45, '점유와 대기', '교착상태', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (46, '제품군 교체', '객체지향 설계', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (47, '제품군 일관성', '객체지향 설계', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (48, '조건 변수', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (49, '주소 변환', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (50, '준비 큐', '스케줄링', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (51, '지연 초기화', '생성 패턴', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (52, '진행', '동시성', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (53, '참조열', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (54, '최적 페이지 교체', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (55, '큐', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (56, '클러스터', '파일시스템', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (57, '파일 디스크립터', '운영체제 개요', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (58, '파일 메타데이터', '파일시스템', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (59, '팩토리 메서드', '생성 패턴', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (60, '페이지 테이블', '메모리', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (61, '프로세스 문맥', '프로세스', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (62, '프린터 스풀러', '입출력', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (63, '하드 링크', '파일시스템', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (64, '하드웨어 인터럽트', '운영체제 개요', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

INSERT INTO concept_description (concept_id, content, step_order, created_at, updated_at) VALUES
  (1, 'CPU가 다음에 실행할 프로세스에 필요한 연산 시간이다. SJF 계열 스케줄링은 이를 미리 추정해 실행 순서를 정하지만, 실제로는 정확히 예측하기 어렵다.', 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (2, 'CPU가 실제로 연산에 사용된 시간의 비율이다. 스래싱이 심해지면 페이징 처리에 시간을 뺏겨 CPU 이용률이 오히려 낮아질 수 있다.', 10, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (3, '먼저 도착한 프로세스를 먼저 실행하는 비선점형 스케줄링 방식', 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (4, '디스크 입출력 요청을 들어온 순서대로 처리하는 가장 단순한 디스크 스케줄링 방식이다.', 12, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (5, '입출력 장치가 요청한 작업을 끝냈을 때 CPU에 알리기 위해 발생시키는 인터럽트다.', 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (6, '디스크 헤드가 한쪽 끝에서 반대쪽 끝까지 이동하며 경로상의 모든 요청을 처리하는 디스크 스케줄링 알고리즘으로, 엘리베이터가 오르내리는 모습과 닮아 엘리베이터 알고리즘이라고도 부른다.', 12, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (7, '입출력 완료 등 특정 이벤트를 기다리느라 CPU를 할당받아도 실행할 수 없는 프로세스 상태다.', 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (8, '지연 초기화된 싱글턴에서 동기화 비용을 줄이기 위해 두 번 검사하는 기법', 13, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (9, '세마포어 값을 확인·감소시키고, 값이 부족하면 스레드를 대기시키는 연산이다.', 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (9, '모니터의 조건 변수에서, 조건이 아직 만족되지 않았을 때 스레드를 재우는 연산이다. 바쁜 대기 없이 잠들어 있다가 signal 연산으로 깨어난다.', 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (10, '프로세스 크기에 맞춰 메모리를 필요한 만큼씩 나누어 할당하는 연속 할당 방식이다.', 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (11, '직접 블록만으로 표현할 수 없는 큰 파일을 위해, 데이터 블록 주소를 담은 블록을 다시 가리키는 인덱스 구조다.', 11, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (12, '기존 코드를 변경하지 않고 새 구현체를 추가하는 것만으로 기능을 확장할 수 있어야 한다는 객체지향 설계 원칙이다(OCP).', 14, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (13, '여러 프로세스나 스레드가 같은 메모리 영역을 함께 읽고 쓸 수 있도록 제공하는 통신 방식이다.', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (14, '서로 관련된 여러 객체를 일관된 조합으로 한 번에 생성하는 것으로, 추상 팩토리가 다루는 문제다.', 14, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (15, '상호 배제·점유와 대기·비선점·순환 대기, 이 네 가지가 모두 성립할 때 교착상태가 발생할 수 있다.', 8, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (16, '자원 할당 전에 미래 상태를 고려하여 교착상태 가능성을 피하는 기법', 8, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (17, '클래스와 객체를 조합해 더 큰 구조를 만드는 디자인 패턴의 한 분류로, 생성 패턴과 대비된다.', 13, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (18, '여러 작업이 겹치는 시간 동안 논리적으로 함께 진행되는 것처럼 보이는 성질이다.', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (19, '특정 시점에 어떤 스레드가 락을 획득해 보유하고 있는지를 나타내는 개념이다.', 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (20, '프로세스의 동작에 따라 큐 사이 이동을 허용해 우선순위를 조정하는 스케줄링 방식', 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (21, '우선순위가 낮은 프로세스가 계속 밀려 CPU를 영원히 할당받지 못하는 기아 상태다.', 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (22, '현재 프로세스의 실행 상태를 PCB에 저장하고 다른 프로세스의 실행 상태를 복원하는 작업이다.', 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (22, '타임 퀀텀이 너무 작으면 문맥 전환이 잦아져 그 자체가 CPU 시간을 소모하는 오버헤드가 된다.', 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (23, 'bounded buffer가 한 번에 담을 수 있는 항목의 최대 개수다.', 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (24, '입출력 장치와 프로세스 사이의 속도 차이를 완화하기 위해 메모리에 중간 저장 공간을 두는 기법이다.', 12, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (25, '실행 중인 프로세스가 자발적으로 CPU를 반납할 때만 스케줄링이 일어나는 방식', 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (26, '응용 프로그램이 실행되는 사용자 공간과 운영체제 커널이 실행되는 커널 공간을 구분하는 메모리 영역 개념이다.', 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (27, 'CPU 실행 권한을 응용 프로그램용(사용자 모드)과 운영체제용(커널 모드)으로 나눈 두 실행 모드다.', 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (28, '한 시점에 하나의 실행 흐름만 임계구역에 들어가게 하는 성질', 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (29, '객체를 사용하는 코드와 객체를 생성하는 코드를 분리해 결합도를 낮추는 설계 원칙이다.', 14, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (30, '세그먼트 번호를 물리 메모리 상의 위치와 길이에 매핑하는 자료구조다.', 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (31, '프로세스나 스레드들이 원형으로 서로를 기다리는 조건', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (32, '응용 프로그램이 운영체제의 보호된 기능을 요청하는 표준 인터페이스이다.', 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (33, '모든 프로세스가 차례로 완료될 수 있음을 보이는 실행 순서', 8, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (34, '흩어진 빈 공간을 한쪽으로 모아 큰 연속 공간을 만드는 작업이다. 단편화를 줄이지만 데이터 이동 비용이 커서 항상 수행하기 좋은 방법은 아니다.', 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (35, '자유 공간이 여러 조각으로 흩어져 큰 연속 공간을 만들기 어려운 현상', 11, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (36, '페이지를 미리 모두 적재하지 않고, 실제로 필요할 때(페이지 폴트 시점에) 메모리에 가져오는 방식이다.', 10, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (37, '각 프로세스에 부여된 우선순위를 기준으로 실행 순서를 결정하는 스케줄링 방식', 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (38, '연산이 중간에 끼어들기 없이 하나의 단위로 수행되는 성질', 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (39, '중간에 끼어들 수 없는 하나의 불가분 작업처럼 수행되는 연산', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (40, '값이 0과 1만 가질 수 있어 뮤텍스처럼 동작하는 세마포어의 한 형태다.', 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (41, '여러 인쇄 요청을 스풀러로 관리해 프린터라는 단일 자원을 여러 프로세스가 공유하게 하는 시스템이다.', 12, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (42, 'CPU의 현재 실행을 중단하고 미리 정해진 처리 루틴으로 제어를 넘기게 하는 사건이다.', 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (43, '공유 자원에 접근하므로 동시에 실행되면 안 되는 코드 구간이다.', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (43, '생산자-소비자 문제의 공유 버퍼 접근 구간처럼, 여러 스레드가 동시에 상태를 바꾸면 데이터 불일치가 생길 수 있는 대표적인 임계 구역 사례다.', 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (44, '모든 자원에 전역적인 순서를 매겨, 프로세스가 항상 그 순서대로만 자원을 요청하게 하는 교착상태 예방 기법이다.', 8, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (45, '자원을 가진 상태에서 추가 자원을 기다리는 조건', 8, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (46, '추상 팩토리 구현체만 바꿔서, 코드 변경 없이 서로 다른 제품군 전체를 교체하는 것이다.', 14, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (47, '함께 생성된 객체들이 서로 호환되는 같은 제품군에 속하도록 보장하는 것이다.', 14, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (48, '특정 조건이 만족될 때까지 스레드를 기다리게 하고 이후 깨우는 동기화 도구', 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (49, 'CPU가 생성한 논리 주소를 실제 물리 메모리 주소로 바꾸는 과정이다.', 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (50, 'CPU를 기다리는 준비 상태 프로세스들이 들어 있는 큐', 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (51, '객체 생성 비용을 아끼기 위해, 실제로 필요해지는 시점까지 초기화를 미루는 기법이다.', 13, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (52, '임계구역에 아무도 없다면, 들어가려는 스레드 중 하나는 유한 시간 안에 반드시 진입할 수 있어야 한다는 동기화 요구 조건이다.', 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (53, '프로세스가 페이지를 참조하는 순서를 기록한 열로, 여러 페이지 교체 알고리즘의 폴트 횟수를 비교하는 데 쓰인다.', 10, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (54, '앞으로 가장 오랫동안 사용되지 않을 페이지를 교체하는, 이론상 페이지 폴트가 가장 적은 알고리즘이다.', 10, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (55, '먼저 들어온 것이 먼저 나가는(FIFO) 자료구조로, FIFO 페이지 교체 알고리즘이 페이지 적재 순서를 기록하는 데 쓴다.', 10, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (56, '디스크 입출력의 기본 단위로 묶은, 여러 섹터로 이루어진 블록이다.', 11, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (57, '프로세스가 열어 둔 파일이나 장치를 가리키기 위해 운영체제가 부여하는 정수 식별자다.', 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (58, '파일 크기·권한·수정 시각처럼 파일 자체의 데이터가 아니라 파일에 대한 부가 정보다.', 11, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (59, '서브클래스가 구체 생성 대상을 결정하도록 하는 생성 패턴', 13, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (60, '페이지 번호를 물리 메모리의 프레임 번호로 매핑하는 자료구조', 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (61, '프로세스가 실행을 재개하는 데 필요한 레지스터 값·프로그램 카운터 등 실행 상태 정보다.', 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (62, '인쇄 요청을 디스크에 임시 저장해 두었다가 프린터가 준비되는 대로 순서대로 처리하는 소프트웨어다.', 12, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (63, '하나의 inode를 여러 디렉토리 이름으로 참조하는 링크 방식', 11, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (64, '키보드·타이머·디스크 같은 하드웨어 장치가 CPU에 신호를 보내 처리를 요청하는 인터럽트다.', 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

INSERT INTO concept_relation (source_concept_id, target_concept_id, created_at, updated_at) VALUES
  (27, 32, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (26, 27, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (32, 57, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (22, 61, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (5, 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (5, 42, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (42, 64, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (28, 43, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (38, 39, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (28, 52, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (8, 51, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (3, 25, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (15, 28, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (15, 45, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (15, 31, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (49, 60, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (30, 60, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (10, 34, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (4, 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (3, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (41, 62, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (23, 24, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (29, 59, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
  (46, 47, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- 문제(Quiz)당 파생개념 3개 중 문제 지문·해설을 직접 읽고 판단한 '핵심 개념' 1개만 quiz_concept로 연결한다.
-- quiz_derived_concept(저작 원본)은 건드리지 않는다 — 이 링크는 quiz_concept라는 별도 테이블의 관심사다.
-- quiz_id는 환경마다 auto_increment 값이 달라 (step_order, slot_order)로 정확히 그 퀴즈 하나만 지정한다.
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 27, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 1 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 64, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 1 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 26, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 1 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 57, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 1 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 32, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 1 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 22, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 2 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 7, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 2 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 2 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 42, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 2 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 61, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 2 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 13, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 3 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 18, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 3 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 43, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 3 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 39, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 3 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 31, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 3 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 25, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 4 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 22, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 4 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 4 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 25, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 4 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 22, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 4 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 37, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 5 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 5 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 20, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 5 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 50, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 5 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 21, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 5 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 28, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 6 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 19, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 6 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 6 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 40, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 6 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 52, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 6 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 43, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 7 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 48, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 7 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 23, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 7 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 38, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 7 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 9, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 7 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 15, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 8 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 16, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 8 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 44, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 8 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 45, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 8 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 33, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 8 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 10, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 9 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 60, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 9 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 30, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 9 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 49, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 9 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 34, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 9 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 36, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 10 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 54, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 10 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 55, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 10 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 53, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 10 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 10 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 35, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 11 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 63, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 11 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 56, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 11 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 11, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 11 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 58, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 11 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 24, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 12 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 62, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 12 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 12 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 41, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 12 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 6, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 12 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 59, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 13 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 51, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 13 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 17, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 13 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 8, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 13 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 51, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 13 AND q.slot_order = 5;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 12, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 14 AND q.slot_order = 1;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 47, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 14 AND q.slot_order = 2;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 29, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 14 AND q.slot_order = 3;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 46, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 14 AND q.slot_order = 4;
INSERT INTO quiz_concept (quiz_id, concept_id, created_at, updated_at) SELECT q.id, 14, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) FROM quiz q WHERE q.step_order = 14 AND q.slot_order = 5;

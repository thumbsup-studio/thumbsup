-- #318: 사람이 승인한 디자인 패턴 저작 콘텐츠 14개 스텝을 기존 코스에 추가한다.
-- 기존 디자인 패턴 1~2스텝은 보존하고, 로컬 auto-increment ID 대신 LAST_INSERT_ID()로 부모·자식 관계를 연결한다.
-- 저작용 outline/draft/revision/job 및 사용자 데이터는 포함하지 않는다.

CREATE TEMPORARY TABLE design_pattern_seed_guard (
    id INT NOT NULL PRIMARY KEY
);
INSERT INTO design_pattern_seed_guard (id) VALUES (1);

-- 코스가 없거나 중복되면 PK 충돌로 발행을 중단한다.
INSERT INTO design_pattern_seed_guard (id)
SELECT 1 WHERE (SELECT COUNT(*) FROM course WHERE title = '디자인 패턴') <> 1;
SET @design_pattern_course_id = (SELECT id FROM course WHERE title = '디자인 패턴');

-- 승인 기준인 기존 2스텝·10문제 또는 핵심 주제가 달라졌다면 일부만 덧붙이지 않는다.
INSERT INTO design_pattern_seed_guard (id)
SELECT 1 WHERE (SELECT COUNT(*) FROM quiz_step WHERE course_id = @design_pattern_course_id) <> 2;
INSERT INTO design_pattern_seed_guard (id)
SELECT 1 WHERE (SELECT COUNT(*) FROM quiz_step WHERE course_id = @design_pattern_course_id AND ((step_order = 1 AND topic = '생성 패턴 개요와 싱글턴(스레드 안전성 포함)') OR (step_order = 2 AND topic = '팩토리 메서드와 추상 팩토리'))) <> 2;
INSERT INTO design_pattern_seed_guard (id)
SELECT 1 WHERE (SELECT COUNT(*) FROM quiz q JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = @design_pattern_course_id) <> 10;

-- STEP 3. 빌더와 안전한 객체 조립
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (3, '빌더와 안전한 객체 조립', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '빌더는 복잡한 객체를 한 번에 만들지 않고 필요한 값을 모은 뒤 완성한다. 생성 과정과 완성된 객체를 나누면 읽기 쉬운 호출과 일관된 검증을 함께 얻을 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '조립 중인 값과 완성된 객체를 나눈다', '필수값과 선택값이 많으면 긴 생성자는 각 값의 뜻을 알아보기 어렵다. 빌더는 조립 중인 값을 별도 객체에 모으고, 마지막 단계에서 실제 객체를 만든다. 이 경계에서 누락된 값과 서로 맞지 않는 값도 함께 검사할 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '설정 객체를 만드는 경우', '백업 설정에 저장 경로는 필수이고 압축 방식, 보존 기간, 암호화는 선택이라고 하자. 호출자는 필요한 값만 이름 있는 메서드로 지정하고, 마지막에 완성을 요청할 수 있다. 완성 단계에서는 암호화를 켰는데 키가 없는 조합처럼 사용할 수 없는 상태를 거부한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '메서드 체이닝만으로는 부족하다', '각 메서드가 자기 자신을 반환한다고 해서 생성 책임이 자동으로 정리되지는 않는다. 결과 객체가 계속 바뀔 수 있거나 검증이 여러 호출자에게 흩어지면 빌더의 장점이 약해진다. 값이 적고 규칙도 단순하다면 생성자나 이름 있는 팩토리가 더 읽기 쉬울 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 3 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '백업 설정에는 필수 저장 경로와 선택적인 압축 방식·보존 기간이 있다. 빌더가 값을 모은 뒤 build 시점에 ''보존 기간은 1일 이상이어야 한다''는 규칙을 검사하도록 한 것은 빌더의 적절한 활용이다.', NULL, '값을 모으는 동안의 임시 상태와 실제로 사용할 수 있는 최종 객체가 언제 구분되는지 살펴보세요.', 'O', '빌더는 여러 입력을 모은 뒤 최종 객체 생성을 한곳에서 마무리한다.\nbuild 시점에 [[불변식]]을 검사하면 잘못된 객체가 밖으로 나가는 것을 막을 수 있다.\n필수값과 선택값의 조합이 많을수록 이런 분리가 유용하다.', '백업 경로가 없거나 보존 기간이 0일인 설정은 완성 단계에서 거부하고, 검증을 통과한 설정만 실행기에 전달할 수 있다.', '빌더를 단순히 값을 편하게 넣는 문법으로만 보면 완성 단계의 역할을 놓치기 쉽다. 생성과 검증을 한 경계에 모으면 사용하는 쪽마다 같은 규칙을 반복하지 않아도 된다.', 3, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '빌더를 사용한다고 결과 객체가 자동으로 불변이 되는 것은 왜 아닐까?', 1, 1, 'MEDIUM', '결과가 [[불변 객체]]가 되려면 변경 메서드를 제한하고 내부의 가변 참조도 외부에 그대로 노출하지 않아야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '빌더는 객체를 만드는 방법을 정리하는 도구다. 만들어진 뒤 값을 바꿀 수 있는지는 결과 클래스의 필드, 변경 메서드, 컬렉션 복사 정책이 결정한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '흔한 오해', 'TEXT', '최종 필드만 사용해도 내부에 든 가변 리스트를 그대로 반환하면 호출자가 내용을 바꿀 수 있다. 생성 방식과 변경 가능성은 따로 검토해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '불변 객체', '생성된 뒤 외부에서 관찰 가능한 상태가 바뀌지 않도록 설계한 객체');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '생성 시점 검증', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '필수값과 선택값', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '불변 객체', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '불변식', '객체가 유효한 상태로 존재하는 동안 항상 만족해야 하는 조건');

-- STEP 3 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '온라인 주문 객체의 setter가 모두 this를 반환해 order.item(...).address(...).coupon(...)처럼 이어서 호출할 수 있다. 이 문법만 갖추면 생성 과정이 분리되고 유효한 완성 상태도 보장되므로 GoF 빌더를 올바르게 적용했다고 볼 수 있다.', NULL, '호출 문법의 모양과 객체 생성 책임이 실제로 분리됐는지를 따로 살펴보세요.', 'X', '메서드를 이어 쓰는 [[플루언트 인터페이스]]는 호출을 읽기 좋게 만드는 문법이다.\n그 문법만으로 조립 중 상태와 완성된 객체가 분리되거나 검증되는 것은 아니다.\n빌더인지 판단하려면 생성 절차와 최종 생성 책임을 살펴봐야 한다.', '주문 객체 자체의 setter가 this를 반환하면서 언제든 필수 주소를 지울 수 있다면 호출은 유창해 보여도 유효한 완성 상태를 보호하지 못한다.', '메서드 체이닝과 빌더는 함께 쓰이는 경우가 많지만 같은 개념은 아니다. 반환 형식보다 조립 책임이 어디에 있고 언제 완성되는지가 핵심이다.', 3, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '빌더에서 디렉터 역할은 언제 유용할까?', 1, 1, 'MEDIUM', '같은 조립 순서를 여러 표현에 반복 적용해야 할 때 [[디렉터]]가 단계의 순서를 맡으면 재사용하기 쉽다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '디렉터는 어떤 단계를 어떤 순서로 호출할지를 알고, 실제 부품을 만드는 일은 빌더에 맡긴다. 같은 절차로 서로 다른 결과 표현을 만들 때 구분이 선명해진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '호출자가 이미 조립 순서를 간단히 표현할 수 있다면 별도 디렉터 클래스는 필요하지 않을 수 있다. GoF 설명에 등장한다고 모든 구현에 강제되는 역할은 아니다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '디렉터', '빌더의 조립 단계를 정해진 순서로 지시하는 협력 객체');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '메서드 체이닝', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '생성 책임', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '디렉터', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '플루언트 인터페이스', '메서드 호출을 자연스럽게 이어 쓸 수 있도록 설계한 인터페이스');

-- STEP 3 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '알림 정책 객체는 수신자와 제목은 필수이고, 재시도 횟수·조용한 시간대·대체 채널은 선택이다. 조용한 시간대를 지정하면 대체 채널도 반드시 있어야 하며, 완성된 정책은 이후 바뀌지 않아야 한다. 가장 적절한 생성 방식은 무엇인가?', NULL, '완성 전의 임시 입력을 외부에 노출하지 않으면서 여러 값 사이의 규칙을 한곳에서 검사할 방법을 찾아보세요.', NULL, '이 상황은 선택값이 많고 값 사이의 규칙도 함께 검사해야 한다.\n[[단계적 생성]]으로 입력을 모은 뒤 마지막에 검증하면 호출과 규칙을 분리할 수 있다.\n검증을 통과한 불변 객체만 반환하는 빌더가 요구에 잘 맞는다.', '호출자는 recipient와 title을 먼저 넣고 필요한 옵션만 추가한다. build는 조용한 시간대와 대체 채널의 조합을 검사한 뒤 방어적으로 복사한 정책을 반환한다.', '공개 setter는 완성 뒤에도 유효하지 않은 상태를 만들 수 있고, 모든 조합의 생성자를 늘어놓으면 호출 뜻을 알아보기 어렵다. 전역 싱글턴은 개별 정책의 생성 문제를 해결하지 못한다.', 3, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '빈 객체를 만든 뒤 호출자가 원하는 순서로 공개 setter를 호출하게 한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '선택값의 모든 조합마다 서로 다른 생성자를 추가한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '빌더가 입력을 모으고 build에서 조합을 검증한 뒤 불변 정책 객체를 반환한다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '정책 하나를 싱글턴으로 두고 모든 알림이 같은 값을 수정하게 한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '선택값이 거의 없는 객체에는 어떤 생성 방식이 더 단순할 수 있을까?', 1, 1, 'EASY', '인자 수가 적고 의미가 분명하면 이름으로 의도를 드러내는 [[정적 팩토리]]나 생성자가 더 간결할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '빌더는 별도 타입과 메서드를 유지해야 한다. 필드 두세 개를 한 번에 안전하게 받을 수 있다면 더 작은 생성 API가 이해하기 쉽다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '선택 기준', 'TEXT', '매개변수 수뿐 아니라 선택 조합, 검증 규칙, 같은 조립 절차의 반복 여부를 함께 보고 결정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '정적 팩토리', '이름 있는 정적 메서드로 객체 생성을 제공하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '교차 필드 검증', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '방어적 복사', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '생성 API 선택', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '단계적 생성', '필요한 값을 여러 단계에서 모은 뒤 최종 객체를 만드는 방식');

-- STEP 3 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '한 서버가 EmailBuilder 인스턴스 하나를 모든 요청에서 공유한다. 첫 번째 요청에서 추가한 수신자가 지워지지 않아 두 번째 사용자의 이메일에도 포함되는 문제가 생겼다. 가장 적절한 개선은 무엇인가?', NULL, '조립 중인 가변 값의 수명과 서로 독립이어야 하는 결과 객체의 수명을 비교해 보세요.', NULL, '공유 빌더에 이전 입력이 남으면 다음 생성에 섞이는 [[상태 누수]]가 발생한다.\n서로 독립인 결과마다 새 빌더를 사용하면 조립 중 상태의 범위를 좁힐 수 있다.\n완성된 이메일도 내부 목록을 복사해 이후 빌더 변경과 분리해야 한다.', '요청을 받을 때마다 새 EmailBuilder를 만들고 build가 수신자 목록의 복사본을 넘기면, 다른 요청의 주소가 섞이지 않는다.', '공유 객체를 싱글턴으로 강화하거나 호출자에게 매번 초기화를 맡기면 같은 실수가 다시 생기기 쉽다. 문제는 빌더의 가변 상태가 요청 경계를 넘어 살아 있는 데 있다.', 3, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 이메일 생성마다 새 빌더를 사용하고, build가 수신자 목록을 복사해 결과에 넣는다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '공유 빌더를 싱글턴으로 등록해 인스턴스가 하나임을 더 확실히 한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '애플리케이션 전체를 복제한 뒤 복제본마다 같은 빌더를 사용한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 호출자가 이전 수신자를 기억해 직접 하나씩 삭제하도록 문서화한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '가변 빌더를 꼭 재사용해야 한다면 어떤 계약이 필요할까?', 1, 1, 'HARD', '재사용 전 상태를 빠짐없이 지우는 [[초기화 규약]]과 동시 접근을 막는 소유 범위가 명확해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '초기화 대상이 늘어날 때 하나라도 빠지면 과거 입력이 섞인다. 재사용 이익이 작다면 요청마다 새 빌더를 만드는 편이 더 안전하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '동시성', 'TEXT', '상태를 초기화해도 여러 스레드가 같은 빌더를 동시에 수정하면 값이 뒤섞일 수 있다. 한 작업만 소유하도록 범위를 제한해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '초기화 규약', '객체를 다시 쓰기 전에 이전 상태를 어떤 값으로 되돌릴지 정한 약속');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '객체 수명', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '가변 상태 격리', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '방어적 복사', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '상태 누수', '이전 작업의 값이 의도하지 않게 다음 작업에 남아 영향을 주는 현상');

-- STEP 3 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'ServerConfig에 선택값이 추가될 때마다 ServerConfig(host), ServerConfig(host, port), ServerConfig(host, port, tls)처럼 더 긴 생성자가 이어져 호출 뜻을 알기 어려워졌다. 이를 ___ 문제라고 부른다.', NULL, '선택값이 늘면서 매개변수 수가 다른 생성자들이 층층이 추가되는 모습을 떠올려 보세요.', NULL, '[[점층적 생성자]] 문제는 선택값 조합이 늘수록 생성자 수나 인자 수가 커지는 상황이다.\n호출 위치에서는 같은 타입의 인자가 무엇을 뜻하는지 알아보기 어려워진다.\n빌더는 이름 있는 단계로 값을 모아 이 문제를 줄일 수 있다.', 'new ServerConfig(host, port, true, 3, false)처럼 불리언과 숫자가 이어지면 각 값의 뜻을 선언부 없이 파악하기 어렵다.', '이 문제는 객체를 하나만 생성하는지나 복제하는지에 관한 것이 아니다. 선택값이 늘면서 생성자 호출이 길고 모호해지는 구조를 가리킨다.', 3, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '점층적 생성자');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'telescoping constructor');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '언어가 명명된 인자를 지원하면 빌더가 항상 불필요해질까?', 1, 1, 'MEDIUM', '[[명명된 인자]]는 호출 가독성을 높이지만 단계적 조립, 교차 검증, 여러 표현 생성까지 대신하지는 않는다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '인자 이름이 보이면 긴 호출의 의미는 분명해진다. 그러나 값이 여러 단계에서 모이거나 완성 전에 복잡한 규칙을 검사해야 한다면 별도 조립 객체가 여전히 유용하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '선택 기준', 'TEXT', '문법 기능으로 가독성 문제만 해결되는지, 생성 절차와 검증 책임까지 분리해야 하는지를 구분한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '명명된 인자', '호출할 때 매개변수 이름과 값을 함께 적는 언어 기능');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '생성자 가독성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '선택 매개변수', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '명명된 인자', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '점층적 생성자', '선택값을 지원하려고 매개변수가 점점 늘어나는 생성자를 여러 개 두는 방식');

-- STEP 4. 프로토타입과 복사 의미
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (4, '프로토타입과 복사 의미', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '프로토타입은 이미 준비된 객체를 본보기로 삼아 새 객체를 만든다. 복제 속도만 볼 것이 아니라 어떤 상태를 공유하고 어떤 상태를 새로 가져야 하는지 정해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '생성 방법을 원본 객체에 맡긴다', '객체를 처음부터 구성하는 비용이 크거나 구체 클래스를 직접 알기 어려우면, 준비된 원본에 복제를 요청해 새 객체를 만들 수 있다. 사용하는 쪽은 복제 가능한 계약에 의존하고 구체적인 생성 절차를 반복하지 않는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '설정이 끝난 차트 복제', '축, 글꼴, 범례, 색상 규칙을 설정한 차트 원본을 준비해 두고 보고서마다 복제한 뒤 제목과 데이터만 바꿀 수 있다. 매번 같은 설정을 다시 적용하는 비용과 실수를 줄일 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '복사의 경계를 먼저 정한다', '얕은 복사는 내부 객체를 원본과 공유할 수 있고, 깊은 복사는 비용이 크며 공유해야 할 값까지 떼어 놓을 수 있다. 데이터베이스 연결, 열린 파일, 고유 식별자처럼 복사 자체가 자연스럽지 않은 값은 새로 만들거나 복제 대상에서 제외해야 한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 4 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '대시보드가 축·색상·범례 설정을 끝낸 차트 원본을 하나 보관하고, 새 보고서를 만들 때 이를 복제한 뒤 제목과 데이터만 바꾼다. 반복되는 초기화가 비싸다면 프로토타입의 적절한 활용이다.', NULL, '새 객체마다 같은 초기화 절차를 반복하는 비용과 이미 준비된 본보기를 재사용하는 비용을 비교해 보세요.', 'O', '[[프로토타입]]은 준비된 객체를 복제해 새 객체 생성의 출발점으로 삼는다.\n복잡한 공통 설정을 매번 다시 적용하지 않아도 되는 상황에 유용하다.\n복제 뒤 보고서마다 달라야 하는 제목과 데이터는 독립적으로 바꿔야 한다.', '회사 공통 차트 스타일을 가진 원본을 복제하면 각 팀은 같은 모양을 유지하면서 자신의 데이터만 넣을 수 있다.', '프로토타입은 단순히 객체 수를 줄이는 캐시가 아니다. 이미 구성된 상태를 출발점으로 새 객체를 효율적으로 만드는 데 초점이 있다.', 4, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '복제된 차트에 새 식별자를 부여해야 하는 이유는 무엇일까?', 1, 1, 'MEDIUM', '내용의 출발점은 같아도 서로 다른 개체라면 [[객체 동일성]]을 구분할 새 식별자가 필요하다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '원본의 데이터 값을 복사하는 것과 시스템에서 같은 개체로 취급하는 것은 다른 문제다. 식별자까지 그대로 복사하면 저장이나 갱신에서 원본과 충돌할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '실무 주의', 'TEXT', '생성 시각, 버전, 소유자처럼 새 개체마다 달라야 하는 메타데이터도 복제 정책에서 따로 정해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '객체 동일성', '값이 같더라도 두 객체가 시스템에서 같은 개체인지 구분하는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '복제 기반 생성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '초기화 비용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '객체 동일성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '프로토타입', '기존 객체를 본보기로 복제해 새 객체를 만드는 생성 패턴');

-- STEP 4 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '문서 객체를 얕게 복사했으므로 복사본의 태그 목록에 항목을 추가해도 원본 문서의 태그 목록에는 절대 영향을 주지 않는다.', NULL, '바깥 객체만 새로 만들어졌을 때 그 안의 가변 목록 참조가 누구에게 속하는지 살펴보세요.', 'X', '[[얕은 복사]]는 바깥 객체를 새로 만들어도 내부 참조를 원본과 공유할 수 있다.\n공유된 태그 목록을 복사본에서 바꾸면 원본에서도 같은 변경이 보일 수 있다.\n독립성이 필요하다면 해당 가변 객체를 별도로 복사해야 한다.', '원본과 복사본의 tags 필드가 같은 리스트를 가리키면 복사본에서 tags.add를 호출한 결과가 둘 모두에 나타난다.', '복사본이라는 말이 내부의 모든 객체까지 새로 생겼다는 뜻은 아니다. 어느 깊이까지 새로 만들었는지에 따라 공유 여부가 달라진다.', 4, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '내부 객체가 불변이라면 얕은 복사가 안전할 수 있는 이유는 무엇일까?', 1, 1, 'MEDIUM', '공유된 객체를 어느 쪽에서도 바꿀 수 없다면 [[공유 참조]]가 상태 간섭을 만들지 않기 때문이다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '바뀌지 않는 값은 여러 객체가 함께 가리켜도 한 복사본의 수정이 다른 복사본에 퍼질 일이 없다. 불필요한 중복도 줄일 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '확인할 점', 'TEXT', '불변이라는 약속이 실제 타입과 외부 노출 방식에서도 지켜지는지 확인해야 한다. 읽기 전용 화면만 제공한다고 내부 변경까지 막힌 것은 아니다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '공유 참조', '둘 이상의 객체가 같은 내부 객체를 가리키는 관계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '가변 객체 공유', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '참조 복사', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '복제 독립성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '얕은 복사', '바깥 객체는 새로 만들지만 내부 객체의 참조는 원본과 공유할 수 있는 복사');

-- STEP 4 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '워크플로 편집기는 검증이 끝난 표준 승인 절차를 바탕으로 부서별 절차를 만든다. 표준 절차의 파일을 읽고 노드 연결을 검증하는 비용이 크며, 각 부서는 복사 후 승인자와 기한을 독립적으로 수정해야 한다. 가장 적절한 생성 방식은 무엇인가?', NULL, '비싼 준비 작업은 재사용하되 이후 각 결과가 서로 독립적으로 바뀌어야 한다는 두 조건을 함께 살펴보세요.', NULL, '준비 비용이 큰 표준 절차를 복제하면 파일 해석과 공통 검증을 반복하지 않아도 된다.\n승인자와 기한처럼 부서마다 바뀔 값은 분리한다는 [[복제 정책]]이 필요하다.\n원본과 각 복사본의 가변 노드가 서로 영향을 주지 않게 해야 한다.', '표준 승인 그래프를 메모리에 준비한 뒤 복제할 때 새 워크플로 ID를 발급하고 노드 목록도 부서별로 분리할 수 있다.', '모든 부서가 하나의 싱글턴 절차를 수정하면 서로의 설정이 섞인다. 매번 파일 해석과 검증을 반복하거나 부서마다 서브클래스를 만드는 방식도 생성 비용과 독립 수정 요구를 함께 해결하지 못한다.', 4, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '검증된 표준 절차를 원본으로 준비하고 가변 노드까지 분리해 복제한 뒤 부서별 값을 설정한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 부서가 승인자와 기한까지 공유하는 하나의 싱글턴 절차를 함께 수정한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '부서별 절차를 만들 때마다 같은 표준 파일을 다시 읽고 전체 연결을 처음부터 검증한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '표준 절차와 구조가 같아도 부서마다 새로운 워크플로 서브클래스를 정의한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '프로토타입을 팩토리 안에서 관리하면 어떤 장점이 있을까?', 1, 1, 'MEDIUM', '이름이나 종류로 원본을 찾는 [[프로토타입 레지스트리]]를 두면 호출자가 구체 클래스를 몰라도 복제를 요청할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '레지스트리는 사용 가능한 원본들을 보관하고 키에 맞는 원본을 찾아 복제한다. 새 종류를 등록하는 코드와 사용하는 코드를 분리할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '원본이 실행 중에 바뀔 수 있다면 누가 언제 갱신하는지와 동시 접근 규칙까지 정해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '프로토타입 레지스트리', '복제에 사용할 원본 객체를 이름이나 종류별로 보관하는 저장소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '초기화 비용 절감', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '원본 객체 등록', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '개체별 상태', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '복제 정책', '복제할 때 어떤 값은 공유하고 어떤 값은 새로 만들지 정한 규칙');

-- STEP 4 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '작업 객체에는 재사용 가능한 파싱 규칙, 자동 생성된 작업 ID, 현재 열려 있는 파일 핸들이 들어 있다. 복제 자체는 외부 입출력 없이 끝내고 파일은 작업을 시작할 때 연결할 수 있다면, 가장 안전한 복제 정책은 무엇인가?', NULL, '복제할 값과 새 개체의 식별자, 복제 시점에는 연결하지 않을 운영체제 자원을 나눠 보세요.', NULL, '파싱 규칙은 값으로 복사하거나 안전하게 공유하고 작업 ID는 새로 발급한다.\n열린 파일 핸들은 [[복제 제외]]하여 복사본을 미연결 상태로 두는 편이 안전하다.\n파일이 필요해지는 실행 단계에서 명시적으로 [[재획득]]해야 소유권과 실패를 분명히 다룰 수 있다.', 'clone()은 새 작업 ID와 fileHandle=null인 복사본을 만들고, start()가 현재 권한으로 파일을 다시 열어 그 복사본만의 핸들을 갖게 할 수 있다.', '파일 핸들을 공유하거나 깊게 복사해도 독립된 운영체제 자원이 생기지 않는다. 복제 도중 자동으로 파일을 다시 여는 방식도 입출력과 실패를 clone() 안에 숨기므로, 복제에서는 제외하고 필요할 때 명시적으로 연결하는 편이 안전하다.', 4, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 필드의 메모리 값을 그대로 복사해 같은 작업 ID와 파일 핸들을 공유한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '파싱 규칙은 복사하거나 안전하게 공유하고 새 작업 ID를 발급하되, 파일 핸들은 제외해 미연결 상태로 두고 필요할 때 명시적으로 다시 연다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '복제하는 순간 같은 파일을 자동으로 다시 열고, 열기에 실패하면 복제 전체를 항상 실패시킨다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '프로토타입을 사용하면 복제 방식이 자동 결정되므로 별도 정책을 두지 않는다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '미연결 상태의 복사본은 파일을 언제 다시 열어야 할까?', 1, 1, 'HARD', '실제로 작업을 시작하는 단계에서 [[자원 획득]]을 명시하고, 열기 실패를 호출자에게 돌려주는 [[실패 계약]]을 함께 정의해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'clone()은 메모리 상태를 만드는 일에 집중하고 파일 열기는 start()나 open() 같은 별도 단계에서 수행한다. 그러면 호출자가 입출력 발생 시점과 실패 가능성을 알 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '수명 관리', 'TEXT', '다시 얻은 핸들은 복사본 하나가 소유하고, 작업 종료나 실패 때 그 복사본이 닫도록 책임을 정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '자원 획득', '파일처럼 외부 시스템이 관리하는 자원을 사용할 수 있도록 새 연결을 얻는 일');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '실패 계약', '자원을 얻지 못했을 때 오류를 누구에게 어떤 방식으로 알릴지 정한 약속');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '자원 소유권', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '식별자 재발급', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '명시적 자원 재획득', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '복제 제외', '원본의 특정 상태를 복사본에 옮기지 않고 비어 있는 상태로 두는 정책');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '재획득', '복사하지 않은 외부 자원을 필요한 시점에 새 소유권으로 다시 얻는 일');

-- STEP 4 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '문서를 복제한 뒤 복사본의 문단을 고쳐도 원본이 바뀌지 않아야 한다. 문서 객체뿐 아니라 내부의 가변 문단 객체까지 새로 만드는 방식을 ___라고 한다.', NULL, '바깥 객체뿐 아니라 그 안에서 바뀔 수 있는 객체들도 새 소유자를 갖는 복사 범위를 생각해 보세요.', NULL, '[[깊은 복사]]는 중첩된 가변 객체까지 새로 만들어 원본과의 상태 공유를 끊는다.\n복사본의 내부 값을 바꿔도 원본에 영향을 주지 않아야 할 때 필요하다.\n다만 큰 그래프를 복제하면 시간과 메모리 비용이 커질 수 있다.', '문서와 그 안의 편집 가능한 문단 목록을 모두 새로 만들면 복사본의 문단 수정이 원본에 반영되지 않는다.', '바깥 객체만 새로 만들고 내부 참조를 공유하는 방식으로는 가변 중첩 객체의 독립성을 얻을 수 없다. 어느 값까지 분리할지 명시해야 한다.', 4, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '깊은 복사');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'deep copy');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '큰 데이터를 즉시 모두 복제하지 않고도 수정 간섭을 줄이는 방법은 무엇일까?', 1, 1, 'HARD', '처음에는 데이터를 공유하다가 변경이 일어날 때만 복사하는 [[쓰기 시 복사]]를 사용할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '읽기만 하는 동안에는 같은 데이터를 공유해 복제 비용을 아낀다. 어느 한쪽이 수정하려 할 때 그 부분을 분리한 뒤 변경한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '공유 여부와 변경 시점을 추적하는 구현이 필요하므로 작은 객체에는 오히려 복잡할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '쓰기 시 복사', '데이터를 읽는 동안 공유하고 수정하는 순간에만 별도 복사본을 만드는 기법');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '중첩 객체 복제', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '복사 비용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태 독립성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '깊은 복사', '필요한 중첩 객체까지 새로 만들어 원본과 독립시키는 복사 방식');

-- STEP 5. 어댑터와 인터페이스 변환
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (5, '어댑터와 인터페이스 변환', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '어댑터는 클라이언트가 기대하는 인터페이스와 이미 존재하는 객체의 인터페이스 사이를 연결한다. 호출 모양뿐 아니라 값의 단위와 오류 의미도 올바르게 옮겨야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '바깥 계약을 유지한 채 기존 기능을 쓴다', '클라이언트는 자신이 아는 대상 인터페이스만 호출하고, 어댑터는 그 요청을 기존 객체가 이해하는 형태로 바꾼다. 기존 객체나 여러 클라이언트를 직접 수정하기 어려울 때 변경 지점을 어댑터 한곳에 모을 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '외부 결제 SDK 연결', '내부 서비스는 USD 금액 객체와 승인·거절·검토 필요 결과를 사용하지만 외부 SDK는 같은 통화의 센트 정수와 공급자별 상태 코드를 쓸 수 있다. 어댑터가 호출, 단위, 결과를 내부 계약에 맞게 변환하면 업무 코드는 공급자 세부 형식을 몰라도 된다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '이름만 바꾸면 끝나지 않는다', '온도 단위, 시간대, 오류 재시도 가능성처럼 뜻이 다른 값을 단순히 필드 이름만 바꾸면 조용한 데이터 오류가 생긴다. 어댑터는 불가능한 의미 변환을 숨기지 말고 검증하거나 명시적인 실패로 돌려줘야 한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 5 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '내부 코드는 WeatherProvider.current(city)를 사용하지만 수정할 수 없는 기존 라이브러리는 LegacyWeather.fetch(locationCode)만 제공한다. 두 호출과 응답 형식을 변환하는 객체를 두어 내부 계약을 유지하는 것은 어댑터의 적절한 활용이다.', NULL, '사용 코드가 기대하는 호출 계약을 유지하면서 기존 객체를 감쌀 수 있는지 살펴보세요.', 'O', '어댑터는 클라이언트가 기대하는 [[대상 인터페이스]]와 기존 객체 사이를 연결한다.\n도시 이름을 위치 코드로 바꾸고 응답 형식을 되돌리는 책임을 한곳에 모을 수 있다.\n내부 코드는 기존 라이브러리의 구체적인 호출 방법을 알 필요가 없다.', 'LegacyWeatherAdapter가 current를 구현하고 내부에서 fetch를 호출하면 다른 날씨 공급자로 바뀌어도 서비스의 호출 형태는 유지할 수 있다.', '기존 라이브러리와 모든 호출자를 동시에 수정할 수 없는 상황에서 두 계약을 이어 주는 경계 객체가 필요하다. 단순 위임뿐 아니라 입력과 출력 변환도 어댑터의 책임이 될 수 있다.', 5, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '어댑터를 테스트할 때 변환 경계를 따로 확인해야 하는 이유는 무엇일까?', 1, 1, 'MEDIUM', '내부와 외부의 [[계약 경계]]에서 필드·단위·오류가 빠짐없이 대응되는지 집중적으로 검증할 수 있기 때문이다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '업무 서비스 테스트만으로는 공급자별 코드나 단위 변환의 잘못을 찾기 어렵다. 어댑터 입력과 외부 호출, 외부 응답과 내부 결과를 각각 짝지어 검사한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '테스트 사례', 'TEXT', '정상 응답뿐 아니라 알 수 없는 상태 코드, 누락 필드, 범위를 벗어난 값도 내부에서 어떻게 보일지 확인해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '계약 경계', '서로 다른 두 시스템의 입력·출력 규칙이 만나는 지점');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '레거시 연동', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '계약 변환', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '변경 격리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '대상 인터페이스', '클라이언트가 사용하기로 약속한 인터페이스');

-- STEP 5 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '외부 센서는 화씨 온도를 보내고 내부 시스템은 섭씨를 사용한다. 어댑터가 필드 이름 temperatureF만 temperatureC로 바꾸면 값의 의미도 자동으로 맞으므로 별도 계산은 필요 없다.', NULL, '두 필드의 이름뿐 아니라 같은 숫자가 나타내는 물리량의 단위가 같은지 확인해 보세요.', 'X', '인터페이스 이름을 맞추는 것만으로 값의 뜻까지 같아지지는 않는다.\n화씨 값을 섭씨로 쓰려면 단위 계산이라는 [[의미 변환]]이 필요하다.\n변환을 생략하면 호출은 성공해도 잘못된 데이터가 시스템에 들어간다.', '센서가 68을 보냈을 때 이를 섭씨 68도로 저장하지 않고 변환해 섭씨 20도로 전달해야 한다.', '어댑터는 컴파일 오류만 없애는 도구가 아니다. 서로 다른 계약의 값과 실패가 실제로 같은 뜻이 되도록 변환해야 한다.', 5, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '외부 값이 내부에서 표현할 수 없는 경우 어댑터는 어떻게 해야 할까?', 1, 1, 'MEDIUM', '임의의 기본값으로 숨기기보다 검증된 [[명시적 실패]]로 반환해 호출자가 처리하게 해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '뜻을 보존할 수 없는 값을 정상값처럼 통과시키면 오류가 늦게 발견된다. 내부 계약에 맞는 오류나 결과 타입으로 변환해 손실을 드러내는 편이 안전하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '예시', 'TEXT', '외부 상태 코드의 의미를 알 수 없다면 성공으로 간주하지 말고 알 수 없는 공급자 응답으로 분류할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '명시적 실패', '변환할 수 없는 상황을 숨기지 않고 오류나 실패 결과로 드러내는 처리');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '단위 변환', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '조용한 데이터 오류', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '계약 검증', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '의미 변환', '형식뿐 아니라 값이 나타내는 뜻까지 대상 계약에 맞게 바꾸는 작업');

-- STEP 5 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '서비스 전체는 PaymentGateway의 charge(USD 금액 객체) 결과로 승인·거절·검토 필요를 사용한다. 새 결제사 SDK는 같은 통화의 센트 정수를 받는 pay(cents)를 호출하고 APPROVED·DECLINED·REVIEW 상태를 반환한다. 기존 서비스 코드를 가장 적게 바꾸면서 안전하게 연동하는 방법은 무엇인가?', NULL, '공급자별 호출과 상태를 내부 서비스가 이미 아는 계약으로 모을 경계를 찾아보세요.', NULL, '외부 SDK는 내부 계약과 다른 호출·단위·상태를 가진 [[어댑티]]다.\n어댑터가 USD 금액 객체를 센트 정수로 바꾸면 환전 없이 같은 통화의 표현만 변환한다.\n공급자 상태도 대응되는 내부 승인·거절·검토 필요 결과로 명시적으로 옮겨야 한다.', 'VendorPaymentAdapter가 12.34달러를 1234센트로 바꾸고, 공급자의 REVIEW를 내부의 검토 필요 결과로 반환할 수 있다.', '모든 서비스가 공급자 SDK를 직접 호출하면 외부 형식이 코드 곳곳에 퍼진다. 상속 관계가 없는 SDK를 억지로 상속하거나 상태를 무조건 승인으로 바꾸는 방식도 안전하지 않다.', 5, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 서비스가 새 SDK를 직접 호출하도록 바꾸고 공급자 상태 코드를 각자 해석한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'PaymentGateway를 구현한 어댑터에서 USD 금액 객체를 센트 정수로 바꾸고 상태를 대응되는 내부 결과로 변환한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '상속 관계가 없어도 새 SDK를 PaymentGateway의 서브클래스로 강제 변환한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '대응하기 어려운 REVIEW 상태는 언제나 승인으로 바꿔 정상 흐름을 유지한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '외부 오류를 내부 오류로 바꿀 때 어떤 정보를 보존해야 할까?', 1, 1, 'HARD', '재시도 가능성·사용자 조치·원인 추적에 필요한 정보를 내부의 [[오류 계약]]으로 보존해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '공급자 오류 이름을 그대로 퍼뜨릴 필요는 없지만, 일시 장애와 영구 거절을 같은 오류로 만들면 올바른 대응을 할 수 없다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '보안 주의', 'TEXT', '추적용 공급자 코드와 민감한 결제 정보는 구분해야 한다. 내부 로그와 사용자 응답에 노출할 범위를 따로 정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '오류 계약', '호출 실패의 종류와 호출자가 취할 수 있는 대응을 표현하는 약속');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '외부 SDK 격리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태 코드 매핑', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '오류 변환', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '어댑티', '어댑터가 감싸서 대상 계약에 연결하는 기존 객체');

-- STEP 5 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '수정할 수 없는 LegacyPrinter SDK를 새 Printer 인터페이스로 연결해야 한다. 앱에는 필요한 레거시 인쇄 동작만 나타낸 LegacyPrintPort 계약이 있고, 운영용 SDK 래퍼와 테스트용 가짜 구현이 이 계약을 따른다. 가장 적절한 구조는 무엇인가?', NULL, '어댑터가 특정 SDK 클래스가 아니라 교체 가능한 작은 계약을 필드로 받을 때의 효과를 살펴보세요.', NULL, '[[객체 어댑터]]는 교체 가능한 레거시 인쇄 계약을 필드로 보유하고 새 Printer 호출을 위임한다.\n구체 SDK가 아닌 [[공통 계약]]을 생성자로 받으면 운영 래퍼와 테스트 대역을 같은 자리에 넣을 수 있다.\n호출자는 레거시 메서드 모양을 몰라도 새 Printer 인터페이스만 사용한다.', 'PrinterAdapter가 LegacyPrintPort를 생성자로 받고 print 요청을 port.legacyPrint 호출로 바꾼다. 운영에서는 LegacyPrinterSdkPort를, 테스트에서는 FakeLegacyPrintPort를 주입할 수 있다.', '어댑터가 LegacyPrinter 구체 타입을 직접 받으면 그 타입을 대신할 수 없는 가짜 구현이나 다른 SDK 래퍼를 주입하기 어렵다. 정적 전역 객체나 직접 호출도 교체 지점을 없애므로 작은 공통 계약에 의존하는 편이 요구에 맞는다.', 5, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'PrinterAdapter가 LegacyPrintPort를 생성자로 받아 운영용 SDK 래퍼나 가짜 구현에 호출을 위임한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 호출자가 Printer를 제거하고 LegacyPrinter의 메서드를 직접 호출한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'PrinterAdapter가 LegacyPrinter 구체 타입을 정적 전역 변수로 고정하고 테스트에서도 그대로 사용한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '프린터 종류마다 서비스 전체를 복사해 별도 애플리케이션으로 운영한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '어댑터가 LegacyPrinter 구체 타입 대신 LegacyPrintPort를 받는 이유는 무엇일까?', 1, 1, 'MEDIUM', '앱이 소유한 [[주입 가능한 계약]]에 의존하면 특정 SDK에 대한 [[구체 타입 결합]]을 줄이고 협력 객체를 바꿀 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '운영 래퍼와 가짜 구현이 같은 작은 계약을 따르면 어댑터 코드를 바꾸지 않고 생성 시점에 협력 객체를 선택할 수 있다. 레거시 SDK를 감싸는 코드는 앱의 나머지 영역으로 퍼지지 않는다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '계약 크기', 'TEXT', '레거시 SDK의 모든 기능을 그대로 옮기기보다 PrinterAdapter에 필요한 인쇄 동작만 계약에 넣어야 변경 범위가 작다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '주입 가능한 계약', '여러 구현을 생성 시점이나 설정에 따라 바꿔 넣을 수 있도록 정의한 공통 인터페이스');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '구체 타입 결합', '추상 계약이 아니라 특정 클래스의 생성법과 메서드에 직접 의존하는 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '공통 레거시 계약', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '의존성 주입', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '테스트 대역', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '객체 어댑터', '기존 기능을 제공하는 협력 객체를 포함하고 위임해 대상 인터페이스를 제공하는 어댑터');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '공통 계약', '운영 래퍼와 테스트 대역이 같은 방식으로 호출될 수 있도록 앱이 정의한 작은 인터페이스');

-- STEP 5 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'PrinterAdapter는 클라이언트가 기대하는 Printer를 구현하고, 호출 방식이 다른 기존 LegacyPrinter를 내부에서 감싼다. 이때 LegacyPrinter의 역할을 ___라고 한다.', NULL, '변환을 수행하는 객체가 아니라 변환 대상이 되는 기존 협력 객체의 역할을 떠올려 보세요.', NULL, '[[어댑티]]는 이미 유용한 기능을 갖고 있지만 클라이언트가 원하는 계약과 호출 방식이 다른 객체다.\n어댑터는 대상 인터페이스의 요청을 어댑티가 이해하는 형태로 바꾼다.\n두 역할을 구분하면 변환 책임과 실제 기능 책임이 선명해진다.', 'LegacyPrinter가 어댑티라면 PrinterAdapter는 print 요청을 legacyPrint 호출로 바꿔 전달한다.', '클라이언트가 직접 사용하는 계약이나 변환을 수행하는 래퍼가 아니라, 래퍼 안에서 실제 기존 기능을 제공하는 객체를 묻고 있다.', 5, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '어댑티');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'adaptee');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '어댑터와 퍼사드는 모두 중간 객체인데 무엇이 다를까?', 1, 1, 'MEDIUM', '어댑터는 계약을 맞추고, [[퍼사드]]는 복잡한 하위 시스템에 더 단순한 진입점을 제공하는 데 초점이 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '어댑터는 기존 기능을 클라이언트가 이미 기대하는 인터페이스에 맞춘다. 퍼사드는 여러 구성요소를 사용하기 쉬운 상위 작업으로 묶는다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '한 객체가 두 역할을 함께 수행할 수는 있지만, 이름보다 어떤 문제를 해결하려는지로 판단해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '퍼사드', '복잡한 하위 시스템에 단순한 상위 인터페이스를 제공하는 구조 패턴');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '대상 인터페이스', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '변환 책임', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '퍼사드 비교', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '어댑티', '어댑터가 감싸 변환 대상으로 삼는 기존 객체');

-- STEP 6. 브리지와 독립적인 변화 축
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (6, '브리지와 독립적인 변화 축', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '브리지는 서로 다른 두 변화 축을 하나의 상속 계층에 섞지 않고 연결한다. 추상화는 사용자가 보는 기능을, 구현자는 실제 수행 방식을 맡아 각각 확장될 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '두 축을 각각 확장한다', '기능 종류와 실행 방식이 모두 늘어나면 두 조합마다 서브클래스를 만들기 쉽다. 브리지는 한쪽 객체가 다른 쪽 인터페이스를 보유하게 해 기능 계층과 구현 계층을 따로 확장한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '알림 종류와 전송 채널', '긴급 알림과 일반 알림이라는 기능 축, 이메일과 문자라는 전송 축이 있다고 하자. 알림 객체가 전송자 인터페이스를 보유하면 새 알림 종류와 새 채널을 서로의 서브클래스 조합 없이 추가할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '변화 축이 실제로 있는지 확인한다', '브리지는 클래스와 인터페이스를 늘리는 비용이 있다. 한쪽 구현이 하나로 고정되어 있거나 함께 바뀌어야만 하는 두 책임을 억지로 나누면 탐색과 이해만 어려워질 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 6 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '긴급·일반 같은 알림 종류 계층과 이메일·문자 같은 전송 구현 계층이 각각 계속 늘어난다. Alert가 Sender 계약에 전송을 맡겨 새 알림 종류는 알림 계층에만, 새 채널은 전송 계층에만 추가하게 한 것은 브리지의 적절한 활용이다.', NULL, '한쪽 계층에 새 종류를 추가할 때 다른 쪽 조합 클래스까지 함께 만들어야 하는지 살펴보세요.', 'O', '브리지는 알림 종류와 전송 방식이라는 두 [[독립적 변화]]를 별도 계층으로 나눈다.\nAlert 계층은 사용자에게 보일 알림 기능을 확장하고 Sender 계층은 실제 전송 방법을 확장한다.\n서로 계약으로 연결되므로 어느 한쪽을 추가해도 다른 쪽의 조합 클래스를 새로 만들 필요가 없다.', 'ScheduledAlert를 추가해 기존 EmailSender·SmsSender와 조합하고, PushSender를 추가해 기존 UrgentAlert·NormalAlert와 조합할 수 있다.', '두 축을 한 상속 트리에 넣으면 새 알림마다 채널별 하위 클래스를, 새 채널마다 알림별 하위 클래스를 만들어야 한다. 각각 다른 이유로 늘어나는 계층을 분리하는 것이 이 상황의 핵심이다.', 6, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '브리지의 실제 수행 역할은 운영체제나 장치처럼 낮은 수준에만 사용할 수 있을까?', 1, 1, 'MEDIUM', '아니며 [[실행 역할]]은 기능 계층이 맡길 수 있는 안정된 작업 계약이면 도메인 서비스나 전송 방식에도 사용할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '실제 수행 방식은 반드시 하드웨어 코드를 뜻하지 않는다. 알림 전송, 렌더링, 저장 방식처럼 기능 계층과 별개로 바뀌는 역할을 나타낼 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '설계 기준', 'TEXT', '두 계층이 정말 서로 다른 이유로 변하고 조합될 필요가 있는지를 먼저 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '실행 역할', '기능 계층이 필요로 하는 실제 작업을 제공하는 브리지의 협력 인터페이스');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '변화 축 분리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '조합 가능한 구현', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상속 계층 축소', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '독립적 변화', '한쪽을 수정하거나 확장해도 다른 쪽 계층의 변경을 강제하지 않는 성질');

-- STEP 6 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '도형 종류와 렌더러가 각각 독립적으로 늘어날 것을 예상해 설계 단계부터 두 계층을 분리하는 것은 브리지의 적용 대상이 아니다.', NULL, '서로 다른 두 변화 축을 미리 분리하는 일이 브리지의 목적에 맞는지 생각해 보세요.', 'X', '브리지와 어댑터는 위임 구조가 비슷해도 주된 [[설계 의도]]가 다르다.\n브리지는 두 변화 축을 독립적으로 발전시키려는 구조에 초점을 둔다.\n어댑터는 서로 다른 기존 계약을 클라이언트가 쓸 수 있게 맞추는 데 초점을 둔다.', '렌더링 방식과 도형 종류를 처음부터 나누는 것은 브리지에 가깝고, 기존 그래픽 라이브러리를 현재 Renderer 계약에 맞추는 것은 어댑터에 가깝다.', '브리지는 기존 코드가 완성된 뒤에만 쓰는 패턴이 아니다. 도형과 렌더러처럼 두 계층이 독립적으로 늘어날 필요가 보이면 설계 단계부터 분리할 수 있다.', 6, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '같은 객체가 브리지와 어댑터 역할을 함께 할 수도 있을까?', 1, 1, 'HARD', '가능하며 패턴 이름은 코드 모양보다 현재 문맥의 [[주된 책임]]으로 판단해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '구현 계층을 분리한 객체가 내부에서 기존 라이브러리 호출도 변환할 수 있다. 이때 하나의 구조가 변화 축 분리와 계약 변환을 동시에 수행한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '검토 방법', 'TEXT', '어떤 변경을 국소화하려고 이 객체를 두었는지, 제거하면 어느 의존성이 다시 퍼지는지를 확인하면 이름보다 의도가 선명해진다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '주된 책임', '객체가 여러 일을 할 때 설계상 가장 중심이 되는 역할');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '브리지와 어댑터 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '패턴의 의도', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '구조적 유사성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '설계 의도', '구조를 도입해 해결하려는 핵심 문제와 변화 방향');

-- STEP 6 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '그래픽 도구에 원·사각형·텍스트가 있고, 각각 화면·PDF·프린터로 렌더링해야 한다. 도형과 출력 방식은 서로 독립적으로 계속 추가될 예정이다. 가장 적절한 구조는 무엇인가?', NULL, '두 분류의 모든 조합을 클래스로 만들 때의 증가량과 한쪽 객체가 다른 쪽 계약을 보유할 때의 증가량을 비교해 보세요.', NULL, '도형은 사용자가 다루는 [[기능 계층]]이고 출력 방식은 실제 렌더링을 맡는 실행 계층이다.\n도형이 Renderer를 보유하면 두 계층을 각각 추가하면서 필요한 조합을 만들 수 있다.\n모든 도형과 출력 방식의 조합마다 서브클래스를 만들 필요가 없다.', 'Circle 하나가 ScreenRenderer나 PdfRenderer와 조합될 수 있고, 새 SvgRenderer를 추가해도 기존 도형 클래스를 복제하지 않는다.', '조합별 클래스를 만들면 도형 수와 출력 방식 수를 곱한 만큼 계층이 커진다. 싱글턴이나 프로토타입은 두 변화 축의 결합을 해결하지 않는다.', 6, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'ScreenCircle·PdfCircle처럼 모든 도형과 출력 방식의 조합마다 서브클래스를 만든다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '도형 계층이 Renderer 인터페이스를 보유하고 렌더링을 위임하도록 두 계층을 분리한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'Renderer 하나를 싱글턴으로 고정해 실행 중에는 출력 방식을 바꾸지 못하게 한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '도형 객체를 복제하면 출력 방식도 자동으로 분리되므로 프로토타입만 사용한다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '브리지에서 기능 계층이 실행 계층의 모든 세부 기능을 그대로 노출해야 할까?', 1, 1, 'MEDIUM', '아니며 기능 계층은 사용자에게 필요한 [[상위 연산]]을 제공하고 실행 계층의 낮은 수준 연산을 조합할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '기능 계층은 단순 전달자일 필요가 없다. 도형의 draw 같은 의미 있는 작업을 정의하고 실행 계층의 선·면 그리기 연산을 사용해 완성할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '캡슐화', 'TEXT', '낮은 수준 세부 동작을 그대로 공개하면 사용자 코드가 구현 계층에 다시 결합될 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '상위 연산', '사용자 관점의 목적을 표현하고 여러 낮은 수준 동작을 조합하는 기능');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '렌더링 계층', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '조합 폭증', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '추상화와 구현', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '기능 계층', '사용자가 다루는 기능을 표현하고 실제 수행 방식을 다른 계층에 맡기는 역할');

-- STEP 6 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '사내 도구는 영수증 한 종류를 회사가 정한 PDF 엔진 하나로만 출력하며, 다른 형식이나 엔진을 추가할 계획도 없다. 브리지 도입 여부에 대한 판단으로 가장 적절한 것은 무엇인가?', NULL, '현재와 예상되는 변경이 몇 축인지, 새 인터페이스와 위임 계층의 유지 비용을 감수할 이유가 있는지 살펴보세요.', NULL, '변화 축이 실제로 하나뿐이면 브리지의 두 계층이 이익 없이 복잡도만 늘릴 수 있다.\n이 경우 직접적인 구현을 유지하는 편이 [[과잉 설계]]를 피하고 읽기 쉽다.\n새 요구가 생겼을 때 분리해도 되는지 변경 비용을 함께 판단하면 된다.', 'ReceiptPdfExporter 하나로 요구를 분명히 표현할 수 있다면 기능 계층과 실행 계층을 미리 나눌 필요가 없다.', '패턴은 미래의 모든 가능성을 미리 추상화하는 목록이 아니다. 서로 독립적으로 바뀌는 두 축이 확인될 때 추가 구조의 비용이 정당화된다.', 6, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '두 변화 축이 없으므로 우선 직접 구현하고 실제 독립 변화가 생길 때 분리를 검토한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'GoF 패턴 수를 늘리기 위해 출력 종류와 엔진 인터페이스를 반드시 따로 만든다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'PDF 엔진을 싱글턴으로 바꾸면 두 변화 축이 자동으로 생긴다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '영수증을 프로토타입으로 복제하면 출력 구현 계층이 자동으로 분리된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '나중에 브리지로 분리하기 쉽게 지금 할 수 있는 작은 준비는 무엇일까?', 1, 1, 'MEDIUM', '출력 세부 동작을 한 모듈에 모으고 호출자가 그 구현에 넓게 의존하지 않도록 [[변경 지점]]을 좁힐 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '추상 계층을 미리 만들지 않아도 외부 엔진 호출을 한곳에 모으면 이후 인터페이스를 추출하기 쉽다. 단순성과 변경 가능성을 함께 확보하는 방법이다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '아직 없는 요구를 자세히 추측해 API를 만들면 실제 변화 방향과 어긋날 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '변경 지점', '요구가 바뀔 때 함께 수정해야 하는 코드가 모여 있는 위치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '불필요한 선행 추상화 피하기', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '추상화 비용', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '점진적 설계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '과잉 설계', '현재 문제보다 지나치게 많은 구조를 도입해 이해와 유지 비용을 키우는 설계');

-- STEP 6 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'Alert가 Sender 인터페이스를 필드로 보유하고 실제 전송을 맡겨 알림 종류와 채널 계층을 분리했다. 이처럼 객체를 포함해 기능을 조립하는 방식을 ___이라고 한다.', NULL, '두 계층을 하나의 상속 계보로 묶지 않고 한 객체가 다른 객체를 보유하는 관계를 떠올려 보세요.', NULL, '[[합성]]은 한 객체가 다른 객체를 포함하고 그 동작을 이용해 기능을 구성하는 방식이다.\n브리지는 합성으로 추상화와 구현자의 상속 계층을 서로 분리한다.\n실행 시 구현자를 바꾸거나 여러 추상화와 조합하기도 쉬워진다.', 'Alert가 Sender를 필드로 가지고 send 작업을 맡기면 Alert가 EmailSender의 서브클래스일 필요가 없다.', '상속은 부모와 자식의 고정된 타입 관계를 만든다. 문제는 한 객체가 다른 객체를 보유하고 위임해 기능을 조립하는 관계를 묻고 있다.', 6, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '합성');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '객체 합성');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'composition');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '합성을 사용해도 두 계층이 다시 강하게 결합될 수 있는 경우는 언제일까?', 1, 1, 'HARD', '추상화가 특정 구현 클래스의 전용 기능을 직접 호출하면 [[구체 구현 의존]]이 생겨 교체가 어려워진다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '필드 타입만 인터페이스여도 다운캐스팅하거나 구현별 조건문을 사용하면 분리 효과가 사라진다. 필요한 연산을 안정된 구현자 계약으로 표현해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '검토 질문', 'TEXT', '새 구현을 추가할 때 추상화 코드를 수정해야 하는지 확인하면 결합이 새고 있는지 찾기 쉽다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '구체 구현 의존', '추상 계약이 아니라 특정 구현 클래스의 세부 기능에 직접 묶인 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상속보다 합성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '런타임 교체', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '구현자 위임', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '합성', '객체를 포함하고 그 동작을 사용해 더 큰 기능을 구성하는 방식');

-- STEP 7. 컴포지트와 부분-전체 계층
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (7, '컴포지트와 부분-전체 계층', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '컴포지트는 하나의 객체와 객체 묶음을 같은 계약으로 다루는 부분-전체 구조다. 재귀 계산은 단순해지지만 자식 관리 권한과 순환 구조는 별도로 통제해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '리프와 컨테이너에 같은 연산을 보낸다', '공통 컴포넌트는 크기 계산이나 렌더링처럼 둘 모두 수행할 수 있는 연산을 정의한다. 리프는 실제 작업을 수행하고, 컴포지트는 자식들에게 같은 연산을 요청한 뒤 결과를 모은다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '파일과 디렉터리의 크기', '파일은 자신의 크기를 반환하고 디렉터리는 자식 파일과 하위 디렉터리의 크기를 더한다. 사용하는 쪽은 대상이 파일인지 디렉터리인지 매번 분기하지 않고 같은 size 연산을 호출할 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '모든 연산이 모두에게 자연스럽지는 않다', '자식 추가 연산을 공통 계약에 넣으면 사용법은 통일되지만 리프에는 의미가 없다. 반대로 컨테이너에만 두면 안전하지만 호출자가 타입 차이를 알아야 할 수 있다. 부모를 자식으로 다시 넣는 순환도 패턴이 자동으로 막아 주지 않는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 7 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '파일은 자신의 크기를 반환하고 디렉터리는 자식들의 크기를 합산하지만 둘 다 Node.size()로 호출할 수 있게 했다. 단일 객체와 객체 묶음을 같은 방식으로 다루려는 컴포지트의 적절한 활용이다.', NULL, '호출자가 대상의 종류를 매번 확인하지 않고 같은 연산을 요청할 수 있는지 살펴보세요.', 'O', '컴포지트는 단일 객체와 객체 묶음을 하나의 [[부분-전체 계층]]으로 표현한다.\n파일은 직접 크기를 반환하고 디렉터리는 자식에게 같은 연산을 재귀적으로 요청한다.\n호출자는 파일과 디렉터리를 공통 Node로 다룰 수 있다.', '루트 디렉터리에 size를 호출하면 하위 디렉터리도 같은 방식으로 자식 크기를 모아 전체 값을 계산한다.', '여기서 핵심은 파일과 디렉터리의 구현이 같다는 뜻이 아니다. 내부 동작은 달라도 사용하는 쪽이 공통 연산으로 부분과 전체를 다룰 수 있다는 점이다.', 7, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '컴포지트의 재귀 호출은 어떤 조건에서 끝나야 할까?', 1, 1, 'MEDIUM', '더 내려갈 자식이 없는 [[종료 조건]]에 도달해야 하며 일반적으로 리프가 그 역할을 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '컴포지트는 자식에게 같은 연산을 계속 위임한다. 자식이 없는 객체가 직접 값을 반환해야 호출이 위로 돌아오며 결과를 합칠 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '순환 참조가 있으면 자식이 없는 지점에 도달하지 못할 수 있으므로 구조를 만들 때 검증이 필요하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '종료 조건', '재귀 호출을 더 진행하지 않고 결과를 반환하는 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '재귀 구조', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '공통 연산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '트리 집계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '부분-전체 계층', '개별 요소와 요소들의 묶음이 같은 구조 안에 반복되어 나타나는 관계');

-- STEP 7 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '파일과 디렉터리의 공통 Node 인터페이스에 addChild를 넣고 File에서는 예외를 던지게 했다. 모든 Node가 같은 메서드를 가지므로 File에 자식을 추가하는 잘못된 사용은 컴포지트 패턴이 자동으로 막아 준다.', NULL, '호출 방법을 통일하는 것과 각 객체에 의미 없는 연산을 타입 수준에서 막는 것이 같은지 구분해 보세요.', 'X', '공통 계약에 자식 관리 연산을 두는 [[투명성]] 설계는 모든 객체를 같은 방식으로 호출하게 한다.\n하지만 리프의 addChild가 의미 없으므로 실행 중 오류나 무시 동작이 생길 수 있다.\n패턴 자체가 잘못된 호출을 자동으로 막아 주지는 않는다.', 'File.addChild가 예외를 던지게 만들 수 있지만 호출자는 컴파일 시점에는 파일에도 이 메서드를 호출할 수 있다.', '인터페이스가 같다는 것은 호출 가능하다는 뜻이지 모든 구현에서 연산이 자연스럽다는 뜻은 아니다. 편리한 일관성과 잘못된 호출 방지 사이에서 계약을 선택해야 한다.', 7, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '자식 관리 연산을 컴포지트에만 두는 설계의 장단점은 무엇일까?', 1, 1, 'HARD', '리프의 무의미한 호출을 막는 [[안전성]]은 높아지지만 호출자가 컨테이너 타입을 구분해야 할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '자식을 가질 수 있는 타입만 add와 remove를 제공하면 잘못된 사용을 타입으로 제한할 수 있다. 대신 모든 컴포넌트를 완전히 같은 방식으로 조작하기는 어려워진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '선택 기준', 'TEXT', '읽기 연산은 공통으로 두고 구조 변경 연산만 컨테이너에 제한하는 식으로 목적에 맞게 나눌 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '안전성', '의미 없는 연산을 가능한 한 이른 시점에 막는 설계 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '투명한 컴포지트', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '안전한 컴포지트', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '인터페이스 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '투명성', '리프와 컴포지트를 같은 인터페이스로 구분 없이 다룰 수 있는 성질');

-- STEP 7 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '관리 화면의 메뉴는 클릭 가능한 메뉴 항목과, 메뉴 항목 또는 다른 메뉴 그룹을 자식으로 담는 그룹으로 구성된다. 권한에 따라 전체 트리를 숨기거나 표시해야 한다. 가장 적절한 설계는 무엇인가?', NULL, '말단 항목과 중첩된 그룹에 같은 표시 연산을 보내고 결과를 재귀적으로 모을 수 있는 구조를 찾아보세요.', NULL, '메뉴 항목과 메뉴 그룹을 공통 [[컴포넌트]]로 다루면 중첩 구조를 자연스럽게 표현할 수 있다.\n그룹은 자식들의 표시 여부를 재귀적으로 계산하고 항목은 자신의 권한을 검사한다.\n호출자는 각 깊이의 타입을 일일이 분기하지 않아도 된다.', 'MenuGroup.visibleFor(user)가 자식의 같은 연산을 호출하면 여러 단계로 중첩된 관리자 메뉴도 한 번의 요청으로 계산할 수 있다.', '모든 메뉴를 평평한 싱글턴에 넣거나 깊이별 클래스를 따로 만들면 중첩 구조와 공통 연산을 표현하기 어렵다. 단순 어댑터도 부분-전체 관계를 해결하지 않는다.', 7, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '메뉴 항목과 그룹이 공통 인터페이스를 구현하고 그룹이 자식들에게 같은 연산을 위임한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 메뉴를 하나의 싱글턴 목록에 평평하게 저장하고 중첩 관계는 제거한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '메뉴 깊이마다 MenuLevel1·MenuLevel2처럼 별도 클래스를 계속 추가한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '메뉴 그룹의 인터페이스 이름만 항목과 같게 바꾸는 어댑터를 하나 둔다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '컴포지트에서 부모 참조를 자식이 꼭 가져야 할까?', 1, 1, 'MEDIUM', '필수는 아니며 위로 이동이나 삭제가 필요할 때 [[부모 참조]]의 편의와 결합·일관성 비용을 비교해 선택한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '자식에서 부모를 찾아야 하는 기능이 없다면 아래 방향 참조만으로 충분하다. 부모를 보유하면 이동은 쉽지만 양쪽 관계를 항상 함께 갱신해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '자식의 부모와 부모의 자식 목록이 서로 다르면 트리가 깨진다. 관계 변경 메서드를 한곳에 모아 두 방향을 함께 관리해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '부모 참조', '트리의 자식 객체가 자신을 포함한 상위 객체를 가리키는 참조');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '메뉴 트리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '권한 집계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '재귀적 위임', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '컴포넌트', '리프와 컴포지트가 함께 구현해 공통 연산을 제공하는 계약');

-- STEP 7 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '디렉터리 A가 B를 자식으로 가지고 있는데 B의 자식으로 다시 A를 추가했다. 이후 전체 크기를 재귀적으로 계산하자 호출이 끝나지 않았다. 가장 적절한 개선은 무엇인가?', NULL, '트리라고 가정한 연산이 끝나려면 구조를 추가할 때 어떤 경로를 금지해야 하는지 살펴보세요.', NULL, 'A와 B가 서로를 자식으로 가지면 [[순환 참조]] 때문에 재귀 호출이 다시 같은 객체로 돌아온다.\n트리 구조가 요구된다면 자식 추가 시 자신이나 조상을 넣지 못하게 검증해야 한다.\n일반 그래프를 허용한다면 방문한 객체를 기록하는 순회 정책도 필요하다.', 'B에 A를 추가하기 전에 A가 B의 조상인지 확인해 거부하면 size 호출은 리프에서 종료될 수 있다.', '재귀 깊이만 크게 늘리거나 예외를 무시하면 구조 오류가 남는다. 컴포지트가 트리인지 일반 그래프인지 계약을 정하고 그에 맞는 생성·순회 규칙을 둬야 한다.', 7, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '재귀 호출 제한만 매우 크게 늘려 언젠가 계산이 끝나기를 기다린다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '트리 계약이라면 자식 추가 시 자신과 조상을 넣지 못하게 검증한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, 'A와 B의 size 결과를 항상 0으로 만들어 재귀 호출을 피한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 디렉터리를 싱글턴으로 바꾸면 부모와 자식 관계가 자동으로 정리된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '일반 그래프를 순회할 때 방문 집합은 어떤 역할을 할까?', 1, 1, 'HARD', '이미 처리한 객체의 [[방문 표시]]를 남겨 같은 노드를 반복 방문하거나 순환에 빠지는 일을 막는다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '노드를 처리하기 전에 식별자를 집합에 기록하고, 다시 만난 노드는 건너뛴다. 순환이 있어도 탐색을 끝낼 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '같은 값의 서로 다른 객체를 구분해야 한다면 값 자체보다 안정된 객체 식별자를 기록해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '방문 표시', '순회 중 이미 처리한 노드를 기록해 중복 처리와 순환을 피하는 정보');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '트리 불변식', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '그래프 순회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '재귀 종료', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '순환 참조', '자식 관계를 따라가다 다시 앞서 만난 객체로 돌아오는 구조');

-- STEP 7 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '파일 트리에서 Directory는 자식의 크기를 합산하지만 File은 자식을 가지지 않고 자신의 크기를 직접 반환한다. 이때 File과 같은 말단 객체를 ___라고 한다.', NULL, '자식을 담아 결과를 모으는 역할과 더 내려가지 않고 작업을 끝내는 역할을 구분해 보세요.', NULL, '[[리프]]는 컴포지트 계층의 말단에서 공통 연산을 직접 수행하는 객체다.\n리프는 자식을 순회하지 않고 자신의 값이나 결과를 반환한다.\n컴포지트는 여러 리프와 다른 컴포지트를 자식으로 담아 결과를 모은다.', '파일 트리에서는 파일이 리프이고 디렉터리는 자식을 담는 컴포지트가 될 수 있다.', '자식을 보관하고 같은 연산을 다시 위임하는 컨테이너가 아니라, 재귀 호출이 끝나는 말단 역할을 묻고 있다.', 7, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '리프');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'leaf');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '리프와 컴포지트가 같은 인터페이스를 구현해도 내부 동작은 왜 달라도 될까?', 1, 1, 'MEDIUM', '공통 계약은 결과의 의미를 정하고 각 타입은 그 계약을 지키는 서로 다른 [[구현 방식]]을 가질 수 있기 때문이다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '파일의 size는 저장된 값을 반환하고 디렉터리의 size는 자식 값을 합산한다. 계산 과정은 달라도 호출자에게 제공하는 의미는 같다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '다형성', 'TEXT', '호출자는 구체 타입을 검사하지 않고 공통 연산을 요청하며, 실제 객체가 자신에게 맞는 동작을 선택한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '구현 방식', '같은 계약을 만족하기 위해 각 타입이 내부에서 사용하는 구체적인 처리 방법');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '리프 객체', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '재귀 종료점', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '다형성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '리프', '컴포지트 구조에서 자식을 갖지 않고 공통 연산을 직접 수행하는 말단 객체');

-- STEP 8. 데코레이터 패턴 — 객체를 감싸 기능을 조합하기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (8, '데코레이터 패턴 — 객체를 감싸 기능을 조합하기', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '데코레이터는 기존 객체를 같은 인터페이스의 객체로 감싸 기능을 덧붙이는 구조 패턴이다. 필요한 기능을 실행 중 조합할 수 있지만, 감싸는 순서가 동작에 영향을 줄 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '같은 인터페이스로 감싸기', '원본 객체와 데코레이터가 같은 인터페이스를 구현하면 사용하는 쪽은 둘을 같은 방식으로 호출할 수 있다. 데코레이터는 요청 전후에 자기 기능을 수행하고 원본 또는 다음 데코레이터로 요청을 넘긴다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '상속 대신 조합하기', '상속으로 기능 조합마다 새 클래스를 만들면 조합 수가 늘수록 클래스도 빠르게 많아진다. 데코레이터는 작은 책임을 객체로 나누고 필요한 것만 중첩해 조합한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '메시지 전송 기능 확장', '기본 메시지 전송 객체를 로깅, 압축, 암호화 데코레이터로 감싸면 호출 코드는 같은 send 인터페이스를 쓰면서 환경에 필요한 기능만 선택할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '프록시와 의도로 구분하기', '두 패턴 모두 객체를 감싸고 같은 인터페이스를 제공할 수 있다. 데코레이터의 중심 의도는 기능 추가와 조합이고, 프록시의 중심 의도는 접근 제어, 지연 생성, 원격 객체 대리 등이다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 8 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '외부 결제 SDK의 PaymentClient 소스는 수정할 수 없다. 팀이 같은 pay() 계약을 구현한 LoggingPaymentClient로 SDK 객체를 감쌌다. 이 구조에서도 호출 로그를 추가하려면 결국 원본 SDK 소스를 수정해야 한다.', NULL, '결제 코드는 같은 pay 호출을 유지한 채 바깥 객체가 호출 전후 작업을 맡을 수 있는지 추적해 보세요.', 'X', 'LoggingPaymentClient는 pay() 호출을 받은 뒤 로그를 남기고 내부 PaymentClient로 요청을 전달할 수 있다.\n이처럼 객체 [[합성]]을 쓰면 수정할 수 없는 SDK에도 바깥에서 책임을 덧붙일 수 있다.\n따라서 로그 추가를 위해 원본 SDK 소스를 반드시 수정해야 한다는 주장은 잘못이다.', 'CheckoutService는 PaymentClient만 바라보므로 SDK 객체 대신 LoggingPaymentClient를 주입해도 pay() 호출 코드는 바뀌지 않는다.', '기능 추가를 원본 클래스 편집이나 상속으로만 해결해야 한다고 본 경우다. 같은 계약의 래퍼가 부가 작업을 수행한 뒤 원본에 요청을 넘길 수 있다.', 8, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'CheckoutService가 SDK 객체와 LoggingPaymentClient를 같은 PaymentClient로 받게 하면 어떤 변화가 쉬워지는가?', 1, 1, 'MEDIUM', 'CheckoutService를 고치지 않고 원본과 로그가 붙은 객체를 바꿔 넣는 [[투명한 교체]]가 쉬워진다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'CheckoutService가 구체 SDK 클래스가 아니라 PaymentClient 계약에 의존하면 어떤 구현이 들어와도 pay() 호출 방식을 유지할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '실무 효과', 'TEXT', '운영에서는 로깅과 측정을 붙인 구성을 주입하고 테스트에서는 가짜 결제 객체를 넣어 주문 흐름만 확인할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '투명한 교체', '사용하는 코드의 호출 방식을 바꾸지 않고 같은 인터페이스의 다른 객체로 바꾸는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '객체 합성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '개방-폐쇄 원칙', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '공통 인터페이스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '합성', '객체가 다른 객체를 포함하거나 참조해 기능을 조립하는 방식');

-- STEP 8 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '파일 업로드 팀이 A 구성에서는 원본 데이터를 압축한 뒤 암호화하고, B 구성에서는 암호화한 뒤 압축하도록 래퍼를 연결했다. 두 구성은 결과 바이트와 압축률이 항상 같다.', NULL, '두 번째 처리 객체가 받는 입력이 원본인지 이미 변환된 데이터인지 순서대로 적어 보세요.', 'X', '압축 객체와 암호화 객체는 앞 단계가 만든 바이트를 다음 입력으로 사용한다.\n래퍼의 [[호출 순서]]가 바뀌면 암호화된 데이터를 압축할지, 압축된 데이터를 암호화할지가 달라진다.\n따라서 두 구성의 결과와 압축률이 항상 같다는 주장은 성립하지 않는다.', '반복이 많은 원본은 먼저 압축하면 크기가 줄 수 있지만, 무작위처럼 보이는 암호문은 같은 효과로 압축되기 어렵다.', '두 기능이 각각 정상 동작한다는 사실만 보고 조합 순서의 영향을 놓친 경우다. 각 래퍼의 출력이 바로 다음 래퍼의 입력이므로 순서도 동작의 일부다.', 8, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '업로드 서버마다 압축과 암호화 순서가 달라지는 사고를 막으려면 조립 코드를 어떻게 관리해야 하는가?', 1, 1, 'MEDIUM', '허용하는 [[중첩 순서]]를 구성 코드 한곳에 고정하고 실제 바이트 입출력으로 대표 조합을 테스트해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '각 서버가 제각각 래퍼를 만들면 같은 설정 이름으로도 다른 바이트를 만들 수 있다. 조립 책임을 팩터리나 설정 모듈 한곳에 모아야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '테스트', 'TEXT', '압축 후 암호화한 파일이 복호화 후 압축 해제로 원본과 같아지는지와 예상 크기 범위를 함께 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '중첩 순서', '여러 데코레이터가 원본 객체를 안쪽부터 바깥쪽까지 감싸는 순서');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '호출 체인', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '기능 조합 순서', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '횡단 관심사', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '호출 순서', '여러 객체가 요청을 처리하고 다음 객체로 넘기는 실제 실행 순서');

-- STEP 8 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '알림 서비스에 로깅, 재시도, 메시지 압축을 고객별로 다르게 조합해야 한다. 기존 전송 객체와 호출 코드를 최대한 유지하려면 어떤 설계가 데코레이터 패턴의 의도에 가장 잘 맞는가?', NULL, '선택 기능을 작은 객체로 나누고 모두 같은 전송 요청을 받을 수 있는 구조인지 비교해 보세요.', NULL, '각 부가 기능을 같은 전송 인터페이스의 데코레이터로 만들면 필요한 기능만 중첩할 수 있다.\n이 방식은 실행 조건에 맞춘 [[동적 조합]]을 지원하면서 기본 전송 객체를 그대로 둔다.\n기능 조합마다 하위 클래스를 만들거나 하나의 거대한 조건문에 모으는 방식보다 변경 범위가 작다.', '기본 전송 객체를 압축 데코레이터로 감싸고 그 바깥을 재시도 데코레이터로 감싸는 식으로 고객 설정을 구성할 수 있다.', '상속 조합이나 큰 조건문도 당장은 동작하지만 기능이 늘 때 조합 수와 수정 범위가 커진다. 데코레이터의 핵심은 같은 인터페이스의 작은 기능 객체를 선택해 연결하는 것이다.', 8, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 기능을 기본 전송 클래스 안의 하나의 긴 조건문에 추가한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 기능을 같은 전송 인터페이스의 객체로 만들고 필요한 순서대로 기본 전송 객체를 감싼다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '가능한 기능 조합마다 전송 클래스의 하위 클래스를 하나씩 만든다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '전송 객체를 전역 단일 인스턴스로 만들면 기능 조합 문제도 함께 해결된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '기능 조합마다 상속 클래스를 만들 때 어떤 유지보수 문제가 커지는가?', 1, 1, 'MEDIUM', '기능 수가 늘수록 가능한 조합별 하위 클래스가 증가하는 [[클래스 폭증]]이 생길 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '로깅 여부, 압축 여부, 재시도 여부만 조합해도 필요한 하위 클래스 수가 빠르게 늘 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '비교', 'TEXT', '객체 조합은 독립된 기능 객체를 재사용하므로 모든 조합을 미리 클래스 형태로 선언할 필요가 없다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '클래스 폭증', '기능 조합을 상속으로 표현하면서 비슷한 하위 클래스 수가 빠르게 늘어나는 문제');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '런타임 구성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상속보다 합성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '설정 기반 조립', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '동적 조합', '실행 시점의 조건에 따라 객체 기능을 선택하고 연결하는 방식');

-- STEP 8 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '알림 서비스가 요청을 처리할 때마다 이미 RetrySender로 감싼 객체를 다시 RetrySender로 감싼다. 일시 오류 한 번에 안쪽과 바깥쪽이 각각 최대 3회 시도해 전송 호출이 예상보다 크게 늘었다. 데코레이터 구조를 유지하면서 가장 적절한 개선은 무엇인가?', NULL, '실패가 각 래퍼를 통과할 때 내부 전송 호출 횟수가 어떻게 불어나는지 계산해 보세요.', NULL, '같은 재시도 래퍼를 겹치면 바깥 재시도마다 안쪽 재시도가 다시 실행되어 호출 수가 곱처럼 늘 수 있다.\n구성 경계에서 [[중복 장식]]을 막고 의도한 재시도 정책을 한 번만 적용해야 한다.\n데코레이터는 조합이 유연한 만큼 어떤 기능을 몇 번 붙였는지 명시적으로 관리해야 한다.', '최대 3회 시도하는 RetrySender를 두 겹으로 두면 구현 방식에 따라 기본 전송이 최대 9번 호출될 수 있다.', '타임아웃을 늘리거나 재시도 횟수를 더 키우면 중복된 호출 체인을 숨길 뿐이다. 조립 지점을 한곳으로 모으고 같은 정책의 중복 적용을 검증해야 한다.', 8, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 RetrySender가 실패를 무시하고 성공으로 반환하게 해 바깥 래퍼가 재시도하지 못하게 한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '기본 Sender 안에도 같은 재시도 코드를 복사하고 기존 래퍼는 그대로 둔다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '구성 경계에서 재시도 래퍼를 한 번만 조립하고 같은 종류의 중복 적용을 검사한다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '중첩 횟수는 유지한 채 전체 타임아웃과 최대 재시도 횟수를 더 크게 늘린다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'RetrySender와 LoggingSender를 함께 쓸 때 전송 시도마다 로그를 남기려면 두 래퍼를 어떤 순서로 조립해야 하는가?', 1, 1, 'MEDIUM', 'RetrySender가 LoggingSender를 감싸 각 재시도가 로깅을 지나가게 하는 [[관찰 경계]]를 만들어야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'RetrySender가 바깥에 있으면 실패할 때마다 안쪽 LoggingSender를 다시 호출하므로 각 시도를 기록할 수 있다. 반대로 LoggingSender가 바깥이면 전체 요청 한 번만 기록할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '판단 기준', 'TEXT', '운영자가 시도별 기록과 요청 전체 기록 중 무엇을 원하는지 먼저 정하고 성공, 실패, 재시도 경로의 로그 개수를 테스트한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '관찰 경계', '로깅이나 측정 래퍼가 호출 체인의 어느 범위를 한 번의 작업으로 바라보는지 정하는 위치');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '데코레이터 중복 적용', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '재시도 증폭', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '래핑 순서', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '중복 장식', '같은 종류의 데코레이터가 한 호출 체인에 의도치 않게 여러 번 적용된 상태');

-- STEP 8 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '알림 서비스는 기본 Sender를 그대로 두고 고객 설정에 따라 같은 send() 계약의 LoggingSender와 RetrySender를 필요한 순서로 겹쳐 붙인다. 이 구조 패턴을 ___이라고 한다.', NULL, '기본 전송 객체의 코드는 그대로 두고 같은 호출 계약의 바깥 객체로 선택 기능을 조립하는 방식을 떠올려 보세요.', NULL, '[[데코레이터 패턴]]은 원본과 같은 계약의 객체로 원본을 감싸 선택 기능을 더한다.\nLoggingSender는 내부 호출 전후에 기록하고 RetrySender는 실패한 내부 호출을 다시 시도할 수 있다.\n고객별로 필요한 기능만 고르고 순서까지 조립해야 하는 상황에 잘 맞는다.', '일반 고객은 LoggingSender만 쓰고 중요 고객은 RetrySender가 LoggingSender를 감싼 구성을 사용할 수 있다.', '기본 Sender에 모든 고객별 조건을 넣는 큰 분기와 혼동한 경우다. 같은 send() 계약의 객체를 연결해 기능을 선택적으로 더하는 점이 핵심이다.', 8, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '데코레이터 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Decorator Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Decorator');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'RetrySender가 LoggingSender를 감싼 알림 구성에서 send() 한 번이 실패 후 성공하면 호출 흐름을 어떻게 추적하는가?', 1, 1, 'HARD', '가장 바깥 RetrySender에서 시작해 재시도마다 LoggingSender와 기본 Sender로 내려가는 [[호출 체인]]을 순서대로 그리면 된다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '첫 시도가 실패하면 RetrySender가 다시 안쪽을 호출한다. 따라서 LoggingSender가 안쪽에 있으면 첫 시도와 두 번째 시도를 각각 기록한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '점검 방법', 'TEXT', '각 래퍼의 진입, 내부 호출, 성공, 예외 지점을 적으면 로그 개수와 기본 전송 호출 횟수를 예상할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '호출 체인', '여러 래퍼 객체가 요청을 안쪽으로 전달하고 결과를 바깥쪽으로 반환하는 연결 흐름');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '고객별 기능 조합', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '재귀적 합성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '호출 체인 추적', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '데코레이터 패턴', '같은 인터페이스의 객체로 원본을 감싸 기능을 동적으로 덧붙이는 구조 패턴');

-- STEP 9. 퍼사드와 프록시 패턴 — 단순화와 대리의 의도 구분
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (9, '퍼사드와 프록시 패턴 — 단순화와 대리의 의도 구분', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '퍼사드는 여러 하위 시스템을 사용하기 쉬운 진입점으로 묶고, 프록시는 실제 객체와 같은 인터페이스로 요청을 대신 받는다. 둘은 포장 모양이 아니라 단순화와 접근 관리라는 중심 의도로 구분한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '퍼사드는 사용 절차를 단순하게 만든다', '퍼사드는 여러 객체를 올바른 순서로 호출해야 하는 복잡성을 한곳에 모은다. 사용하는 쪽은 하위 시스템의 세부 협력 관계를 몰라도 자주 쓰는 작업을 하나의 고수준 메서드로 요청할 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '프록시는 실제 객체를 대신한다', '프록시는 실제 객체와 같은 인터페이스를 제공하고 요청을 받을지, 언제 실제 객체를 만들지, 원격 호출로 어떻게 전달할지 등을 관리한다. 클라이언트는 대체로 실제 객체를 부르는 것과 같은 방식으로 사용한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '주문 완료와 원격 이미지', '주문 서비스가 결제, 재고, 배송 호출을 하나로 묶으면 퍼사드의 사례가 된다. 화면에 보일 때만 원격 이미지를 불러오는 대리 객체는 지연 생성을 맡는 프록시의 사례가 된다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '래퍼라는 모양만으로 판단하지 않기', '퍼사드는 하위 시스템과 다른 단순한 인터페이스를 만들 수 있고, 프록시는 실제 객체와 같은 인터페이스를 유지하는 경우가 많다. 데코레이터까지 구조가 비슷할 수 있으므로 단순화, 대리, 기능 추가 중 무엇이 목적인지 확인해야 한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 9 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '주문 화면은 CheckoutFacade.completeOrder()만 호출하고, 내부에서 결제 승인·재고 예약·배송 접수가 이어진다. 퍼사드를 제대로 적용하려면 completeOrder()가 세 하위 서비스의 메서드 이름과 매개변수를 모두 똑같이 노출해야 한다.', NULL, '주문 화면이 세 서비스의 세부 호출 순서를 몰라도 되게 하려면 바깥 창구가 어떤 수준의 요청을 받아야 하는지 생각해 보세요.', 'X', 'CheckoutFacade는 주문 완료라는 업무 요청을 받아 여러 서비스를 알맞은 순서로 호출한다.\n퍼사드의 계약은 [[하위 시스템]]의 개별 메서드 모양과 같을 필요가 없다.\n세부 인터페이스를 그대로 복제하기보다 화면에 필요한 고수준 작업을 제공하는 것이 목적이다.', 'completeOrder(orderId)는 내부에서 authorize, reserve, requestShipping을 호출하되 화면에는 그 순서와 매개변수 변환을 숨길 수 있다.', '퍼사드를 하위 서비스 메서드의 단순 복사본으로 본 경우다. 사용하는 쪽의 업무 흐름에 맞춘 더 간단한 계약을 새로 제공할 수 있다.', 9, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '운영 도구가 배송 접수만 다시 실행해야 할 때도 반드시 completeOrder()만 사용하게 해야 하는가?', 1, 1, 'MEDIUM', '아니며, 일반 주문 흐름은 퍼사드로 묶고 제한된 운영 기능에는 배송 서비스 직접 접근을 허용하는 [[단순화 경계]]를 정할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '퍼사드는 하위 서비스를 없애는 장벽이 아니라 일반 사용자가 알아야 할 호출 절차를 줄이는 기본 진입점이다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '설계 기준', 'TEXT', '재실행 권한과 사용 범위를 통제한 운영 도구는 세부 서비스를 직접 쓸 수 있고, 일반 화면은 안정된 고수준 흐름을 사용하게 할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '단순화 경계', '일반적인 사용에는 간단한 진입점을 제공하고 세부 기능 접근은 필요에 따라 남기는 설계 범위');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '고수준 인터페이스', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '서브시스템 캡슐화', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '의존성 축소', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '하위 시스템', '하나의 큰 기능을 함께 수행하는 여러 내부 구성 요소의 집합');

-- STEP 9 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '대용량 계약서 화면은 Document.open() 계약을 구현한 SecureLazyDocument를 먼저 둔다. 이 객체가 사용자 권한을 확인한 뒤 허용된 첫 open()에서만 원격 계약서 객체를 만들고 요청을 넘기는 것은 프록시 패턴의 활용이다.', NULL, '화면과 원격 계약서 사이의 객체가 접근 허용 여부와 실제 생성 시점을 대신 결정하는지 살펴보세요.', 'O', 'SecureLazyDocument는 실제 계약서 객체 앞에서 open() 요청을 먼저 받는 [[대리 객체]]다.\n같은 계약을 유지하면서 권한을 검사하고 큰 원격 객체의 생성을 필요한 순간까지 늦춘다.\n허용된 요청만 실제 객체로 전달하므로 제시된 설계는 프록시의 의도에 맞는다.', '목록에서는 제목만 보여 주고 사용자가 계약서를 열 때 권한 확인과 원격 다운로드를 수행하면 불필요한 자원 사용을 줄일 수 있다.', '중간 객체가 화면 기능을 새로 꾸미는 것이 아니라 실제 계약서 접근을 대신 관리한다는 점을 놓친 경우다. 권한 검사와 지연 생성은 대표적인 대리 목적이다.', 9, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '계약서 화면이 SecureLazyDocument와 실제 원격 Document를 모두 open()으로 호출하게 하면 어떤 교체가 쉬워지는가?', 1, 1, 'MEDIUM', '화면 코드를 바꾸지 않고 권한 검사와 지연 생성을 맡는 객체를 끼우거나 빼는 [[대체 투명성]]을 얻는다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '두 객체가 Document 계약을 따르면 화면은 권한 검사와 다운로드가 어디서 일어나는지 몰라도 open()만 호출할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '같은 호출 모양이어도 첫 open()은 권한 실패나 다운로드 지연을 겪을 수 있으므로 로딩 상태와 오류 계약은 화면에 분명히 알려야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '대체 투명성', '사용하는 코드의 호출 형태를 유지한 채 실제 객체를 대신하는 객체로 바꿀 수 있는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '보호 프록시', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '가상 프록시', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '원격 프록시', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '대리 객체', '실제 객체 대신 요청을 받아 필요한 처리를 한 뒤 실제 객체로 전달하는 객체');

-- STEP 9 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '결제, 재고, 배송, 알림이라는 기존 하위 서비스들을 주문 완료 때 정해진 순서로 호출해야 한다. 호출하는 화면이 이 복잡한 하위 시스템의 세부 절차를 몰라도 되게 하려면 어떤 설계가 가장 적절한가?', NULL, '여러 하위 기능의 협력 순서를 한곳에 모아 사용하는 쪽에는 업무 단위의 간단한 요청만 보여 주는 방식을 찾으세요.', NULL, '[[퍼사드]]는 여러 하위 서비스의 호출 순서를 하나의 고수준 작업으로 묶는다.\n화면은 주문 완료라는 단순한 요청만 보내고 내부 협력 절차는 퍼사드가 조정할 수 있다.\n이 방식은 여러 화면에 같은 세부 호출 순서가 흩어지는 문제를 줄인다.', 'CheckoutFacade.completeOrder가 결제, 재고, 배송 서비스를 차례로 호출하고 결과를 하나로 정리해 반환할 수 있다.', '각 화면이 직접 모든 서비스를 호출하면 순서와 실패 처리가 중복된다. 단일 인스턴스나 하위 클래스 추가는 여러 서비스의 사용 절차를 단순화하는 문제를 직접 해결하지 못한다.', 9, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '주문 완료라는 고수준 메서드를 제공하는 퍼사드가 내부 서비스들을 순서대로 호출한다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 화면이 결제, 재고, 배송, 알림 서비스를 각각 직접 호출한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 하위 서비스를 싱글턴으로 만들면 호출 순서도 자동으로 보장된다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '화면 종류마다 주문 서비스의 하위 클래스를 새로 만든다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '퍼사드가 커져 모든 업무 규칙을 떠맡는 문제를 피하려면 어떻게 해야 하는가?', 1, 1, 'HARD', '퍼사드는 호출 흐름을 묶는 [[조정 책임]]에 집중하고 핵심 업무 규칙은 각 도메인 서비스에 남겨야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '퍼사드가 계산, 검증, 저장 규칙까지 모두 소유하면 변경 이유가 너무 많아지고 테스트 범위도 커진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '역할 분리', 'TEXT', '퍼사드는 여러 기능을 연결하는 순서를 표현하고 각 서비스는 자기 분야의 규칙과 상태를 책임지는 편이 낫다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '조정 책임', '여러 구성 요소를 어떤 순서와 조건으로 호출할지 연결하는 책임');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '오케스트레이션', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '응용 서비스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '관심사 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '퍼사드', '복잡한 하위 시스템을 더 단순한 고수준 인터페이스로 제공하는 객체');

-- STEP 9 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '상품 목록의 고해상도 이미지는 크기가 커서 실제로 화면에 보이는 항목만 원격 저장소에서 읽고 싶다. 기존 이미지 인터페이스를 유지하면서 이 요구를 구현하는 방식으로 가장 적절한 것은?', NULL, '사용자가 같은 표시 요청을 보내되, 중간 객체가 실제 원격 자원을 만드는 시점을 늦출 수 있는지 확인해 보세요.', NULL, '가상 프록시는 실제 객체와 같은 인터페이스로 요청을 받다가 필요할 때 실제 객체를 만든다.\n화면에 보이는 순간 이미지를 불러오는 [[지연 로딩]]은 불필요한 네트워크와 메모리 사용을 줄일 수 있다.\n다만 동시 요청과 실패 처리 정책은 프록시 구현에서 별도로 정해야 한다.', '이미지 자리에는 크기 정보만 가진 프록시를 먼저 두고 display가 처음 호출될 때 원격 파일을 내려받아 실제 이미지 객체에 위임할 수 있다.', '퍼사드는 여러 하위 기능을 단순한 창구로 묶는 데 초점이 있고, 데코레이터는 기능 추가가 중심이다. 여기서는 실제 이미지 생성 시점을 대신 관리하는 것이 핵심이다.', 9, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 이미지를 프로그램 시작 시 미리 내려받는다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '이미지 표시 기능을 여러 하위 시스템 호출로 묶는 퍼사드만 추가한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '이미지마다 압축 기능을 추가하는 데코레이터만 적용한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '같은 이미지 인터페이스의 가상 프록시가 첫 표시 요청 때 실제 이미지를 불러온다.', 1, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '여러 스레드가 같은 가상 프록시를 동시에 처음 호출하면 무엇을 주의해야 하는가?', 1, 1, 'HARD', '실제 객체를 여러 번 만들거나 원격 요청을 중복 전송하지 않도록 [[중복 생성 방지]]가 필요하다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '두 호출이 모두 아직 객체가 없다고 확인하면 각각 생성 작업을 시작할 수 있다. 생성 상태를 안전하게 공유하고 실패 뒤 재시도 규칙도 정해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '프록시 패턴을 사용했다는 사실만으로 스레드 안전성이나 단 한 번의 원격 호출이 자동 보장되지는 않는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '중복 생성 방지', '동시에 들어온 초기 요청이 같은 실제 객체나 자원을 여러 번 만들지 않게 조정하는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '가상 프록시', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '지연 초기화', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '동시 초기화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '지연 로딩', '데이터나 객체가 실제로 필요해지는 시점까지 읽기 또는 생성을 미루는 방식');

-- STEP 9 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '배포 화면에서 deployRelease() 한 번으로 검증·빌드·업로드를 순서대로 수행하게 만든 첫 구조는 ___이고, 큰 보고서와 같은 open() 계약을 제공하면서 권한 확인 뒤 첫 열기에만 다운로드하는 둘째 구조는 ___이다.', NULL, '여러 작업 절차를 한 진입점으로 묶는 역할과 실제 자원 호출 여부를 중간에서 관리하는 역할을 나누어 보세요.', NULL, '첫 빈칸의 [[퍼사드 패턴]]은 검증·빌드·업로드라는 하위 절차를 deployRelease()로 단순화한다.\n둘째 빈칸의 [[프록시 패턴]]은 보고서 대신 open()을 받아 권한과 실제 다운로드 시점을 관리한다.\n하나는 복잡한 사용 절차를 줄이고 다른 하나는 실제 객체 접근을 대신한다.', 'ReleaseFacade는 배포 도구들을 묶고, LazyReport는 같은 Report 계약으로 큰 파일의 생성을 늦출 수 있다.', '두 객체가 내부 호출을 숨긴다는 겉모양만 보고 역할을 바꿔 쓴 경우다. 배포 절차 단순화와 보고서 접근 대리를 각각 확인해야 한다.', 9, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '퍼사드 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Facade Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Facade');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 2, '프록시 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 2, 'Proxy Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 2, 'Proxy');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '배포 창구와 보고서 대리 객체가 모두 내부 객체에 요청을 넘겨도 서로 다른 패턴으로 부르는 기준은 무엇인가?', 1, 1, 'MEDIUM', '클래스 모양보다 단순화, 접근 관리, 기능 추가 중 무엇을 이루려는지 나타내는 [[설계 의도]]로 구분해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '내부 위임이라는 구현 모양이 비슷해도 배포 호출 복잡성을 줄이는 문제와 실제 보고서 접근을 관리하는 문제는 다르다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '질문 방법', 'TEXT', '이 객체가 없을 때 사용자가 여러 배포 단계를 직접 알아야 하는지, 큰 보고서를 너무 일찍 만들거나 권한 없이 여는지가 핵심인지 묻는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '설계 의도', '구조를 선택해 해결하려는 중심 문제와 기대 효과');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '구조 패턴 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '인터페이스 단순화', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '객체 대리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '퍼사드 패턴', '복잡한 하위 시스템을 단순한 고수준 인터페이스로 제공하는 구조 패턴');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '프록시 패턴', '실제 객체와 같은 인터페이스로 요청을 대신 받아 접근을 관리하는 구조 패턴');

-- STEP 10. 이터레이터 패턴 — 컬렉션 내부를 숨기고 순회하기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (10, '이터레이터 패턴 — 컬렉션 내부를 숨기고 순회하기', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '이터레이터는 컬렉션 내부 표현을 드러내지 않고 원소를 순서대로 방문하는 방법을 제공한다. 순회 위치를 별도 객체가 가지므로 같은 컬렉션에 서로 다른 순회 방식과 독립된 진행 상태를 둘 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '저장 방식과 방문 방식 분리', '배열, 연결 리스트, 트리는 원소를 저장하는 구조가 다르다. 컬렉션이 이터레이터를 제공하면 사용하는 코드는 내부 노드나 인덱스 구조를 몰라도 다음 원소를 요청할 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '순회 상태는 이터레이터가 가진다', '현재 위치, 다음 원소 존재 여부, 방문 순서 같은 상태를 이터레이터에 두면 한 컬렉션에서 여러 순회를 독립적으로 진행할 수 있다. 컬렉션 자체에 현재 위치 하나만 두는 방식보다 재사용성이 높다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '트리를 서로 다른 순서로 읽기', '같은 트리도 깊이 우선과 너비 우선 이터레이터를 각각 제공할 수 있다. 사용하는 코드는 공통된 다음 원소 요청만 사용하고 스택이나 큐 같은 내부 구현은 알 필요가 없다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '순회 중 변경은 계약을 확인한다', '순회하는 동안 컬렉션을 추가하거나 삭제했을 때 허용 여부와 결과는 구현 계약에 달려 있다. 모든 이터레이터가 스레드 안전하거나 변경을 즉시 감지한다고 단정하면 안 된다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 10 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'CSV 내보내기 코드는 연결 목록형 ProductCatalog가 준 순회 객체의 hasNext()와 next()만 호출한다. 그래도 내보내기 코드가 다음 상품을 찾으려면 Catalog 내부 노드의 next 링크를 직접 따라가야 한다.', NULL, '현재 노드와 다음 노드를 찾는 책임이 내보내기 코드와 순회 객체 중 어디에 있는지 확인해 보세요.', 'X', 'ProductCatalog의 순회 객체가 현재 노드와 다음 링크를 따라가는 책임을 맡는다.\nCSV 내보내기 코드는 hasNext()와 next() 뒤에 [[캡슐화]]된 연결 구조를 알 필요가 없다.\n따라서 내보내기 코드가 노드 링크를 직접 따라가야 한다는 주장은 잘못이다.', 'Catalog 저장 방식이 연결 목록에서 트리로 바뀌어도 새 순회 객체가 같은 두 동작을 제공하면 CSV 반복문은 유지될 수 있다.', '컬렉션을 사용하는 쪽이 저장 구조까지 제어한다고 본 경우다. 다음 원소를 찾는 규칙을 순회 객체에 두면 호출 코드는 상품 처리에만 집중할 수 있다.', 10, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'ProductCatalog 저장 방식이 연결 목록에서 트리로 바뀌어도 CSV 내보내기 반복문을 유지하려면 무엇이 중요한가?', 1, 1, 'MEDIUM', 'CSV 코드가 노드 구조가 아니라 hasNext()와 next()라는 공통 순회 계약에 의존하는 [[표현 독립성]]이 중요하다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'CSV 코드가 next 링크를 직접 다루면 트리 전환 때 내보내기 로직도 고쳐야 한다. 저장 세부를 순회 객체 안에 두면 변경 범위가 작아진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '실무 예시', 'TEXT', '새 트리 순회 구현만 추가하고 CSV 코드는 같은 반복문을 쓰는지 통합 테스트로 확인할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '표현 독립성', '사용하는 코드가 내부 저장 방식의 변경에 직접 영향받지 않는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '정보 은닉', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '컬렉션 추상화', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '순회 책임 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '캡슐화', '내부 데이터 구조와 구현 세부를 감추고 필요한 동작만 외부에 제공하는 것');

-- STEP 10 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '상품 비교 화면은 같은 ProductCatalog에서 바깥 반복용 순회 객체와 안쪽 반복용 순회 객체를 각각 만들었다. 바깥쪽 next()를 한 번 호출하면 같은 컬렉션에서 나왔으므로 안쪽 객체의 현재 위치도 반드시 함께 이동한다.', NULL, '두 반복문이 각자 현재 상품 위치를 보관하는지, 컬렉션에 위치가 하나만 있는지 구분해 보세요.', 'X', '각 순회 객체는 보통 자신이 어디까지 방문했는지 따로 저장한다.\n바깥 객체와 안쪽 객체가 독립된 [[순회 상태]]를 가지면 한쪽 next()가 다른 쪽 위치를 바꾸지 않는다.\n따라서 같은 ProductCatalog에서 만들었다는 이유로 두 위치가 반드시 함께 이동하지는 않는다.', '바깥 반복이 세 번째 상품을 가리킬 때도 새로 만든 안쪽 반복은 첫 번째 상품부터 비교를 시작할 수 있다.', 'ProductCatalog 자체에 현재 위치가 하나만 있다고 가정한 경우다. 별도 순회 객체를 만드는 구조에서는 각 객체가 자기 진행 위치를 관리할 수 있다.', 10, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '상품 두 개씩 짝지어 비교하는 중첩 반복에서 각 순회 객체가 위치를 가지면 어떤 이점이 있는가?', 1, 1, 'MEDIUM', '화면이 진행을 직접 제어하는 [[외부 반복자]]를 두 개 두어 바깥 상품마다 안쪽 비교를 처음부터 독립적으로 수행할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '바깥 순회의 위치를 유지한 채 안쪽 순회를 새로 시작할 수 있어 모든 상품 쌍을 비교하는 흐름을 만들 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '비교', 'TEXT', '위치를 Catalog 하나에만 두면 안쪽 순회가 바깥 진행을 덮어쓸 수 있다. 위치를 분리하면 두 반복의 생명주기를 각각 관리할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '외부 반복자', '클라이언트가 다음 원소 요청과 중단 시점을 직접 제어하는 순회 객체');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '순회 커서', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '중첩 반복', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '외부 반복', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '순회 상태', '현재 방문 위치와 다음에 방문할 원소 등 반복 진행에 필요한 정보');

-- STEP 10 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '보고서 생성기가 배열 목록과 트리 구조의 항목을 같은 출력 로직으로 차례로 읽어야 한다. 보고서 코드가 각 자료구조의 내부 구현을 조건문으로 구분하지 않게 하려면 어떤 설계가 가장 적절한가?', NULL, '컬렉션마다 내부 탐색은 맡기되 사용하는 쪽에는 다음 항목을 얻는 동일한 계약을 제공하는 방식을 찾으세요.', NULL, '각 컬렉션이 공통된 다음 원소 동작을 제공하는 이터레이터를 만들면 보고서 코드는 자료구조를 구분하지 않아도 된다.\n[[반복 인터페이스]] 뒤에서 배열 인덱스나 트리 탐색 상태를 각 구현이 관리한다.\n새 컬렉션이 추가되어도 보고서의 출력 로직을 고칠 필요가 줄어든다.', 'ListIterator는 인덱스를 이동하고 TreeIterator는 내부 스택을 사용하더라도 보고서 생성기는 hasNext와 next만 호출할 수 있다.', '보고서 코드가 컬렉션 타입을 검사하거나 내부 노드를 직접 다루면 저장 구조 변경이 출력 로직까지 전파된다. 방문 규칙을 각 이터레이터 구현에 맡기는 것이 핵심이다.', 10, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '보고서 생성기가 컬렉션의 실제 타입을 검사해 배열과 트리용 순회 코드를 직접 실행한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 컬렉션이 공통 순회 인터페이스의 이터레이터를 제공하고 보고서 생성기는 그 인터페이스만 사용한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 컬렉션을 전역 싱글턴으로 만들고 내부 노드를 보고서에 공개한다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '자료구조가 추가될 때마다 보고서 생성기의 상위 클래스를 새로 만든다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '같은 트리에 깊이 우선과 너비 우선 방문을 모두 제공하려면 어떻게 구성할 수 있는가?', 1, 1, 'HARD', '같은 컬렉션이 서로 다른 [[순회 방식]]을 캡슐화한 이터레이터 구현을 각각 제공할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '깊이 우선 구현은 스택을, 너비 우선 구현은 큐를 사용할 수 있지만 클라이언트가 보는 다음 원소 계약은 같게 유지할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '선택 기준', 'TEXT', '계층 구조 출력, 최단 단계 탐색처럼 작업 목적에 맞는 방문 순서를 선택하되 컬렉션의 노드 구조는 외부에 노출하지 않는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '순회 방식', '컬렉션의 원소를 어떤 순서와 규칙으로 방문할지 정한 방법');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '다형적 순회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '깊이 우선 탐색', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '너비 우선 탐색', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '반복 인터페이스', '컬렉션 종류와 무관하게 다음 원소 확인과 이동을 제공하는 공통 계약');

-- STEP 10 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '컬렉션을 순회하는 도중 조건에 맞는 원소를 삭제해야 한다. 구현 문서가 일반 컬렉션의 직접 변경을 허용하지 않는다면 가장 안전한 접근은 무엇인가?', NULL, '순회 중 구조 변경을 임의로 수행하기보다 해당 구현이 공식적으로 허용하는 변경 경로와 시점을 확인하세요.', NULL, '순회 중 구조 변경의 허용 범위는 이터레이터와 컬렉션의 계약에 따라 다르다.\n공식 삭제 연산을 쓰거나 순회가 끝난 뒤 변경하는 것이 [[순회 계약]]을 지키는 방법이다.\n직접 변경하면 원소 누락, 중복 방문, 예외처럼 구현별 문제가 생길 수 있다.', '이터레이터가 remove를 지원하면 그 연산을 사용하고, 지원하지 않으면 삭제 대상을 모아 순회 종료 뒤 컬렉션에서 제거할 수 있다.', '모든 이터레이터가 변경을 안전하게 흡수하거나 자동 복사본을 만든다고 가정하면 안 된다. 구현이 보장하는 방법을 사용해야 결과를 예측할 수 있다.', 10, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '순회 방식과 무관하게 컬렉션을 직접 수정해도 항상 현재 위치가 자동 보정된다고 가정한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '변경 감지가 모든 언어와 컬렉션에서 같은 예외로 보장된다고 가정한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '이터레이터가 제공하는 지원 연산을 사용하거나 삭제 대상을 모아 순회가 끝난 뒤 반영한다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 원소를 건너뛰지 않도록 현재 위치를 임의로 하나씩 되돌린다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'fail-fast 이터레이터가 동시 변경을 완벽하게 막아 준다고 볼 수 없는 이유는 무엇인가?', 1, 1, 'HARD', '[[fail-fast]]는 잘못된 변경을 빠르게 드러내려는 탐지 동작이지 동기화나 데이터 정합성을 보장하는 장치가 아니기 때문이다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '변경 감지는 구현이 확인하는 시점에 동작하며 모든 경쟁 상황을 빠짐없이 검출한다는 계약이 아닐 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '여러 스레드가 컬렉션을 공유한다면 별도의 동기화, 불변 스냅샷, 동시성 컬렉션 등 명시적인 안전 전략이 필요하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, 'fail-fast', '허용되지 않은 구조 변경을 발견했을 때 가능한 한 빨리 실패를 알리는 반복 동작');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '동시 수정', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '스냅샷 순회', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '변경 안전성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '순회 계약', '반복 중 허용되는 연산과 원소 방문 결과를 정한 이터레이터의 사용 규칙');

-- STEP 10 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '감사 로그 내보내기 코드는 AuditLogStore가 준 객체의 hasNext()와 next()만 호출한다. 그 객체는 데이터베이스 페이지 위치를 기억하고 필요할 때 다음 페이지를 읽지만 내보내기 코드는 저장 구조를 모른다. 이 행동 패턴을 ___이라고 한다.', NULL, '현재 페이지와 다음 항목을 찾는 책임을 내보내기 반복문 밖의 별도 객체가 맡는 구조를 떠올려 보세요.', NULL, '[[이터레이터 패턴]]은 감사 로그의 저장 방식과 항목을 방문하는 흐름을 분리한다.\n별도 객체가 페이지 위치와 다음 항목 조회를 맡으므로 내보내기 코드는 데이터베이스 구조를 몰라도 된다.\n전체 로그를 한꺼번에 메모리에 올리지 않고 필요한 페이지부터 읽는 구현도 가능하다.', '같은 내보내기 반복문에 데이터베이스용 순회 객체나 보관 파일용 순회 객체를 제공할 수 있다.', '페이지 번호를 내보내기 코드가 직접 계산하는 방식과 혼동한 경우다. 방문 위치와 이동 규칙을 별도 객체에 감추는 점이 핵심이다.', 10, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '이터레이터 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '반복자 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Iterator Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Iterator');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '감사 로그가 수천만 건일 때 다음 데이터베이스 페이지를 필요한 순간에만 읽으면 어떤 이점이 있는가?', 1, 1, 'HARD', '내보내기가 중단되거나 일부만 필요할 때 [[지연 순회]]로 읽은 페이지까지만 처리해 메모리와 데이터베이스 부하를 줄일 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '다음 페이지가 필요해질 때 조회하면 전체 로그 목록을 먼저 만들 필요가 없고 앞부분 처리에서 실패하면 뒤 페이지 조회도 피할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '내보내는 동안 새 로그가 추가될 수 있으므로 시작 시점 스냅샷인지 최신 데이터를 계속 보는지 계약을 분명히 해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '지연 순회', '원소를 미리 모두 만들지 않고 다음 값이 필요할 때 계산하거나 읽는 순회 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '페이지 단위 조회', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '지연 계산', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '스냅샷 일관성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '이터레이터 패턴', '컬렉션 내부 표현을 숨긴 채 원소를 순서대로 방문하는 객체를 제공하는 행동 패턴');

-- STEP 11. 전략 패턴 — 알고리즘을 교체 가능한 객체로 분리하기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (11, '전략 패턴 — 알고리즘을 교체 가능한 객체로 분리하기', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '전략 패턴은 같은 목적을 이루는 여러 알고리즘을 공통 인터페이스의 객체로 분리하고, 컨텍스트가 외부에서 제공된 객체에 일을 맡긴다. 알고리즘을 교체하기 쉬워지지만 선택지가 적고 고정적이면 단순한 조건문이 더 나을 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '변하는 알고리즘을 객체로 분리하기', '할인 계산, 배송비 계산, 압축처럼 목적은 같지만 규칙이 다른 코드를 각각의 전략 객체에 둔다. 컨텍스트는 공통 인터페이스만 알고 구체 알고리즘은 외부에서 전달받는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '선택과 실행의 책임 나누기', '어떤 전략을 사용할지는 설정, 사용자 등급, 요청 특성 같은 정책에 따라 선택할 수 있다. 선택한 뒤 실제 계산은 전략 객체가 맡으므로 컨텍스트의 큰 조건문을 줄일 수 있다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '요청마다 압축 방식 고르기', '파일 종류와 클라이언트 지원 형식에 따라 gzip, brotli, 무압축 전략 중 하나를 선택하고 응답 처리기는 공통 compress 요청만 호출할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '패턴 자체가 좋은 알고리즘을 고르지는 않는다', '전략 패턴은 알고리즘을 교체 가능하게 만들 뿐 가장 빠르거나 정확한 전략을 자동 선택하지 않는다. 선택 기준, 실패 처리, 성능 측정은 별도로 설계해야 한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 11 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'OrderService는 ShippingFeePolicy를 주입받아 calculate(order)를 호출한다. 일반 배송과 해외 배송의 계산식은 각 구현이 맡고 OrderService는 선택된 구현에 계산을 넘긴다. 이는 전략 패턴에 맞는 설계다.', NULL, '주문 흐름을 맡은 객체가 배송별 계산식을 직접 가지는지, 공통 계약의 다른 객체에 맡기는지 확인해 보세요.', 'O', '일반 배송과 해외 배송 규칙은 ShippingFeePolicy의 서로 다른 구현으로 분리되어 있다.\nOrderService는 선택된 구현에 계산을 [[위임]]하므로 구체 요금식을 알 필요가 없다.\n공통 계약으로 교체 가능한 알고리즘을 실행하는 이 구조는 전략 패턴의 의도에 맞는다.', '테스트에서는 고정 배송비를 반환하는 FakeShippingFeePolicy를 주입해 주문 합계 계산만 확인할 수 있다.', 'OrderService가 모든 배송 분기를 직접 가져야 한다고 본 경우다. 변하는 계산 규칙을 별도 객체로 분리하고 공통 calculate 호출로 맡기는 것이 핵심이다.', 11, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'OrderService가 ShippingFeePolicy 구현을 직접 new 하지 않고 외부에서 받으면 어떤 이점이 있는가?', 1, 1, 'MEDIUM', 'OrderService와 구체 배송 규칙의 [[결합도]]가 낮아져 운영 설정 변경과 테스트용 구현 교체가 쉬워진다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'OrderService 안에 해외·새벽 배송 구현의 생성 코드가 있으면 새 규칙을 추가할 때 주문 흐름까지 수정할 가능성이 커진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '테스트', 'TEXT', '고정 결과를 반환하는 가짜 정책을 주입하면 지역 조회나 복잡한 요금식과 분리해 주문 합계 흐름만 검증할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '결합도', '한 구성 요소가 다른 구체 구성 요소의 변경에 얼마나 강하게 의존하는지를 나타내는 정도');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '의존성 주입', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '다형성', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '알고리즘 캡슐화', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '위임', '객체가 맡은 작업의 일부를 다른 객체의 메서드 호출로 넘기는 것');

-- STEP 11 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '길찾기 서비스의 FastestRoute와 LowTollRoute는 모두 RoutePolicy.find(origin, destination)를 구현한다. 같은 인터페이스를 사용하므로 두 구현의 응답 시간, 메모리 사용량, 통행료 결과까지 항상 동일하다.', NULL, '같은 호출 형태와 반환 계약이 내부 탐색 방식과 비용 기준까지 같게 만드는지 구분해 보세요.', 'X', '두 길찾기 구현은 find() 호출과 경로 반환 계약만 공유하고 서로 다른 기준으로 탐색한다.\n[[교환 가능성]]은 공통 계약 아래 바꿔 쓸 수 있다는 뜻이지 시간, 메모리, 통행료가 같다는 뜻이 아니다.\n운영 입력에서 각 정책의 속도와 비용 결과를 따로 측정해 선택해야 한다.', 'FastestRoute는 유료도로를 써서 빨리 도착할 수 있고 LowTollRoute는 탐색 시간이 더 들더라도 통행료가 낮은 경로를 고를 수 있다.', '같은 RoutePolicy라는 사실을 내부 목표와 실행 특성까지 같다는 의미로 넓힌 경우다. 구현마다 최적화 기준과 자원 비용이 다를 수 있다.', 11, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'FastestRoute와 LowTollRoute 중 기본 정책을 정할 때 운영 데이터에서 무엇을 함께 측정해야 하는가?', 1, 1, 'MEDIUM', '실제 출발지 분포에서 응답 지연, 자원 사용량, 도착 시간과 통행료 같은 [[비기능 요구사항]]을 함께 측정해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '도심의 짧은 경로에서 빠른 구현이 전국 장거리 요청에서도 빠르다고 단정할 수 없고 사용자의 비용 선호도도 다르다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '운영 적용', 'TEXT', '대표 출발지와 시간대별로 벤치마크하고 시간 제한, 메모리 한도, 최대 허용 통행료를 반영해 선택 규칙을 정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '비기능 요구사항', '기능 결과 외에 성능, 안정성, 자원 사용량처럼 시스템이 만족해야 하는 품질 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '알고리즘의 장단점', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '벤치마크', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '계약과 구현', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '교환 가능성', '공통 계약을 지키는 구현을 사용하는 코드의 변경 없이 서로 바꿀 수 있는 성질');

-- STEP 11 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '쇼핑몰 배송비가 일반, 새벽, 해외 배송마다 다르고 지역과 주문 시점에 따라 실행 중 하나를 선택해야 한다. 규칙 추가가 주문 서비스의 큰 조건문으로 이어지지 않게 하려면 어떤 설계가 가장 적절한가?', NULL, '배송비 계산이라는 공통 목적은 유지하면서 각 계산 규칙과 선택 결과를 별도 객체로 교체할 수 있는지 살펴보세요.', NULL, '배송 방식마다 공통 계산 인터페이스를 구현한 [[전략 객체]]를 두는 구성이 적절하다.\n주문 서비스는 선택된 객체에 배송비 계산을 맡기고 세부 공식은 알지 않는다.\n새 배송 규칙은 새 전략 구현과 선택 규칙의 변경으로 제한할 수 있다.', '지역이 해외이면 InternationalShippingStrategy를 선택하고 주문 서비스는 calculateFee 호출 결과만 사용한다.', '모든 공식을 주문 서비스에 추가하면 규칙이 늘 때 조건문과 변경 이유가 함께 커진다. 싱글턴이나 퍼사드는 여러 알고리즘을 교체 가능하게 만드는 문제를 직접 해결하지 않는다.', 11, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '배송 방식별 계산 객체가 공통 인터페이스를 구현하고 주문 서비스는 선택된 객체에 계산을 맡긴다.', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 배송 공식과 지역 조건을 주문 서비스의 하나의 조건문에 계속 추가한다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '배송비 계산 객체를 싱글턴으로 만들면 서로 다른 계산 규칙도 자동 분리된다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '결제와 재고 서비스를 퍼사드로 묶으면 배송 알고리즘 선택도 자동으로 해결된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '구체 배송 전략을 고르는 책임은 어디에 두는 것이 좋은가?', 1, 1, 'HARD', '선택 기준이 업무 규칙이면 별도 [[전략 선택기]]나 조립 계층에 두어 주문 서비스와 계산 전략의 책임을 나눌 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '컨텍스트가 모든 선택 조건까지 알면 알고리즘 구현은 분리되어도 큰 조건문이 다른 위치에 그대로 남을 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '설계 기준', 'TEXT', '선택 조건이 단순한 설정인지 복잡한 업무 정책인지에 따라 구성 코드, 팩토리, 전용 선택 객체 중 알맞은 위치를 고른다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '전략 선택기', '입력과 업무 조건을 평가해 사용할 구체 알고리즘 객체를 결정하는 구성 요소');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '정책 객체', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '팩토리와 전략의 결합', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '조건문 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전략 객체', '공통 인터페이스를 구현하며 하나의 구체 알고리즘이나 정책을 수행하는 객체');

-- STEP 11 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '내부 관리 도구의 할인 규칙은 회원이면 5퍼센트 할인하고 아니면 할인하지 않는 두 경우뿐이며, 규칙이 늘어날 계획도 없다. 가장 적절한 설계 판단은 무엇인가?', NULL, '분리할 알고리즘의 수와 변경 가능성이 새로운 인터페이스와 클래스가 만드는 비용보다 큰지 비교해 보세요.', NULL, '경우가 둘뿐이고 규칙이 작고 안정적이라면 짧은 조건문이 의도를 더 직접 보여 줄 수 있다.\n이 상황에서 전략 클래스들을 먼저 만드는 것은 [[과잉 설계]]가 될 수 있다.\n패턴은 변경 가능성과 조합 필요성이 추가 구조의 비용을 정당화할 때 선택한다.', '회원 여부를 확인하는 짧은 할인 함수 하나로 충분하다면 인터페이스, 구현 두 개, 선택 객체까지 만들 이유가 작다.', '전략 패턴이 좋은 구조라는 이유만으로 모든 분기를 객체로 바꿀 필요는 없다. 규칙이 늘거나 독립적으로 시험·교체해야 할 때 리팩터링해도 늦지 않다.', 11, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '두 경우도 반드시 별도 전략 클래스와 선택기로 나누어야 하며 조건문은 항상 제거한다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '현재는 작은 조건문으로 명확하게 구현하고 규칙이 늘거나 교체 요구가 생기면 전략 객체 분리를 검토한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '할인 계산기를 싱글턴으로 만들면 규칙 수와 변경 가능성을 검토할 필요가 없다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '회원 여부가 바뀔 때마다 옵서버에게 알리면 할인 계산 구조도 자동으로 단순해진다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '단순 조건문을 전략 객체들로 분리할 시점은 어떤 변화에서 드러나는가?', 1, 1, 'MEDIUM', '규칙 종류가 계속 늘거나 실행 중 교체, 독립 테스트, 재사용 요구가 반복되는 [[변경 신호]]가 나타날 때 검토할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '조건 분기가 여러 서비스에 복사되고 한 규칙 수정이 여러 파일을 건드리기 시작하면 알고리즘을 별도 객체로 모을 이점이 커진다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '판단 기준', 'TEXT', '현재 복잡도뿐 아니라 예상되는 변경 방향과 팀이 감당할 클래스 수, 테스트 편의성을 함께 비교한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '변경 신호', '현재 구조가 반복 수정과 중복을 만들고 있어 책임 분리가 필요함을 보여 주는 징후');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '단순성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '리팩터링 시점', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '패턴 적용 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '과잉 설계', '현재 문제 규모에 비해 불필요하게 많은 추상화와 구조를 도입해 이해와 변경 비용을 높이는 설계');

-- STEP 11 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'CheckoutService는 판매 채널이 고른 FeePolicy 객체를 주입받아 calculate(cart)를 호출하고, 모바일·제휴몰 수수료 계산식의 내부 내용은 모른다. 이 행동 패턴을 ___이라고 한다.', NULL, '결제 흐름은 유지한 채 채널별 계산 방법을 공통 계약의 객체로 바꿔 넣는 구조를 떠올려 보세요.', NULL, '[[전략 패턴]]은 모바일·제휴몰 수수료 알고리즘을 FeePolicy의 서로 바꿀 수 있는 구현으로 분리한다.\nCheckoutService는 외부에서 받은 객체에 calculate()를 맡겨 구체 계산식과 분리된다.\n채널 규칙이 추가되거나 요청별로 선택될 때 결제 흐름의 큰 조건문을 줄일 수 있다.', '채널 선택기가 MobileFeePolicy나 PartnerFeePolicy를 고르고 CheckoutService에는 FeePolicy 하나만 전달할 수 있다.', 'CheckoutService가 채널 이름을 검사해 모든 계산식을 직접 실행하는 구조와 혼동한 경우다. 알고리즘을 독립된 객체로 만들고 외부에서 선택해 맡기는 점이 핵심이다.', 11, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '전략 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Strategy Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Strategy');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '웹 요청마다 회원 등급과 판매 채널에 맞는 FeePolicy가 달라진다면 선택 책임과 객체 수명주기를 어디에 두는 편이 좋은가?', 1, 1, 'HARD', '컨트롤러나 팩터리 같은 [[조립 계층]]이 요청 정보로 구현을 선택해 주입하고, 내부 상태 유무에 맞춰 공유 또는 요청 단위 수명을 정한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'CheckoutService가 채널 분기와 생성 책임까지 가지면 수수료 규칙이 바뀔 때 결제 흐름도 함께 수정된다. 바깥 조립 계층이 선택하면 CheckoutService는 계산 위임에 집중한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '수명주기', 'TEXT', '상태가 없는 불변 구현은 안전하게 공유할 수 있다. 요청별 중간값을 필드에 저장하는 구현은 공유하지 말고 요청 데이터를 매개변수로 넘기거나 요청 단위로 생성한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '조립 계층', '실행에 필요한 구체 구현을 선택하고 연결해 사용하는 객체에 전달하는 바깥 구성 영역');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '전략 선택 책임', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '알고리즘 교체', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '객체 수명주기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전략 패턴', '교체 가능한 알고리즘을 객체로 캡슐화하고 컨텍스트가 선택해 사용하는 행동 패턴');

-- STEP 12. 옵서버 패턴 — 상태 변화를 여러 구독자에게 알리기
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (12, '옵서버 패턴 — 상태 변화를 여러 구독자에게 알리기', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '옵서버 패턴은 한 객체의 상태 변화나 사건을 등록된 여러 객체에 알리는 행동 패턴이다. 발행자는 구체 구독자를 몰라도 되지만 실행 방식, 순서, 실패 처리, 중복 방지는 별도의 전달 계약으로 정해야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '발행자와 구독자 분리', '발행자는 구독 인터페이스와 등록 목록만 알고 사건이 생기면 알림을 보낸다. 구독자는 각자 알림, 통계, 화면 갱신 같은 반응을 수행하므로 새 반응을 추가할 때 발행자 수정 범위를 줄일 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '등록과 통지의 생명주기', '구독자는 관심 있는 동안 등록하고 더 이상 필요하지 않으면 해제한다. 발행자는 현재 등록된 대상을 기준으로 알리므로 등록 시점과 해제 시점, 중복 등록 처리 규칙을 정해야 한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '주문 완료 뒤 여러 후속 작업', '주문 상태가 완료되면 이메일 발송, 포인트 적립, 분석 기록이 각각 반응할 수 있다. 주문 객체가 각 구체 서비스를 직접 알기보다 완료 사건을 발행하고 구독자가 처리하게 구성할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '전달 품질은 자동 보장이 아니다', '옵서버는 구독과 통지 관계를 설명할 뿐 알림이 비동기인지, 어떤 순서인지, 실패 시 재시도하는지, 정확히 한 번 처리되는지를 정하지 않는다. 이런 요구는 실행기, 메시지 저장소, 재시도와 멱등 처리 같은 추가 설계가 필요하다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 12 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'Order가 OrderCompletedSubscriber 목록에 주문 완료 사건을 알리고 EmailSubscriber와 AnalyticsSubscriber가 같은 계약을 구현한다. 이때 Order는 각 구독자의 내부 발송·분석 코드를 몰라도 새 구독자에게 알림을 보낼 수 있다.', NULL, '주문 객체가 이메일과 분석의 구체 메서드가 아니라 하나의 통지 계약과 등록 목록만 사용해도 되는지 확인해 보세요.', 'O', 'Order는 공통 OrderCompletedSubscriber 계약으로 등록된 대상에 사건을 전달한다.\n이 [[느슨한 결합]] 덕분에 이메일 발송과 분석 기록의 내부 구현을 알 필요가 없다.\n따라서 같은 계약의 새 구독자를 등록해 반응을 확장할 수 있다는 설명은 타당하다.', 'PointSubscriber를 새로 구현해 등록해도 Order의 주문 완료 처리에는 포인트 적립 코드를 직접 추가하지 않을 수 있다.', 'Order가 EmailService.send와 Analytics.record를 각각 직접 호출해야 한다고 본 경우다. 공통 구독 계약을 쓰면 구체 반응을 Order 밖으로 분리할 수 있다.', 12, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, 'PointSubscriber를 추가할 때 Order의 완료 처리 코드를 고치지 않아도 되는 구조는 어떤 원칙과 연결되는가?', 1, 1, 'MEDIUM', 'Order의 발행 로직은 유지하고 새 구독 구현으로 반응을 확장하는 [[개방-폐쇄 원칙]]과 연결된다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'Order가 공통 계약만 사용하면 PointSubscriber를 등록하는 방식으로 후속 기능을 추가할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', 'OrderCompleted 사건의 필드나 구독 계약이 자주 바뀌면 이메일, 분석, 포인트 구현이 모두 영향을 받으므로 계약 자체도 안정적으로 설계해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '개방-폐쇄 원칙', '기능 확장에는 열려 있고 기존 코드 수정에는 닫히도록 설계하자는 원칙');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '발행-구독', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '의존성 역전', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '이벤트 통지', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '느슨한 결합', '구성 요소가 상대의 구체 구현보다 작은 공통 계약에 의존해 변경 영향이 적은 상태');

-- STEP 12 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'CheckoutEventPublisher에 처리 시간이 최대 5초인 EmailSubscriber와 AnalyticsSubscriber가 등록됐다. 옵서버 패턴을 적용했다는 사실만으로 AnalyticsSubscriber는 이메일 처리와 무관하게 즉시 별도 스레드에서 실행되고 모든 구독은 정확히 한 번 처리된다.', NULL, '구독 관계를 만드는 패턴이 실행 스레드와 느린 호출 대기, 실패 뒤 재호출 횟수까지 함께 정하는지 나누어 보세요.', 'X', '옵서버 패턴은 Publisher와 Subscriber의 등록·통지 관계를 정의한다.\n별도 스레드 실행, 느린 구독자 격리, 재시도 횟수 같은 [[전달 보장]]은 패턴만으로 생기지 않는다.\n구현에 따라 EmailSubscriber가 끝날 때까지 뒤 구독자가 기다리거나 예외 때문에 호출되지 않을 수도 있다.', '발행자가 for문에서 update()를 직접 호출하면 한 구독자의 5초 지연이 다음 구독자의 시작도 5초 늦출 수 있다.', '구독 관계를 비동기 메시지 시스템의 실행 보장과 동일시한 경우다. 스레드, 타임아웃, 예외 처리, 재시도는 구현과 운영 정책으로 따로 정해야 한다.', 12, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '동기 통지로 구현할 때 EmailSubscriber가 오래 걸리거나 예외를 던져도 뒤의 AnalyticsSubscriber를 계속 처리하려면 무엇을 정해야 하는가?', 1, 1, 'HARD', '구독자별 타임아웃과 예외 처리로 실패를 기록한 뒤 계속할지, 별도 실행 큐로 분리할지 정하는 [[구독자 격리]] 정책이 필요하다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '동기 반복문에서 예외를 그대로 전파하면 첫 실패가 전체 통지를 멈출 수 있다. 예외를 구독자 단위로 잡고 계속할지 즉시 중단할지 업무 요구로 결정해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '구현 선택', 'TEXT', '독립 실행기나 작업 큐를 쓰면 느린 구독자가 발행자와 다른 구독자를 막는 시간을 줄일 수 있다. 다만 완료 순서와 오류 관찰 방식은 달라지므로 함께 정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '구독자 격리', '한 구독자의 지연이나 실패가 발행자와 다른 구독자의 실행을 무조건 막지 않도록 경계를 두는 설계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '동기 통지', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '느린 구독자', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '예외 전파 정책', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전달 보장', '메시지의 순서, 누락, 중복, 재시도 등에 대해 시스템이 약속하는 처리 성질');

-- STEP 12 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '주문 상태가 완료되면 이메일 발송, 포인트 적립, 분석 기록이 각각 반응해야 하며 주문 객체가 이 세 서비스의 구체 구현을 직접 알고 싶지 않다. 가장 적절한 설계는 무엇인가?', NULL, '상태 변화를 알리는 쪽은 공통 계약만 알고, 서로 다른 후속 작업은 독립적으로 등록되어 반응할 수 있는지 살펴보세요.', NULL, '주문 완료 사건을 발행하고 각 후속 작업을 독립된 [[구독자]]로 등록하는 구성이 적절하다.\n주문 객체는 공통 통지 계약만 사용하고 이메일, 포인트, 분석의 세부 동작을 몰라도 된다.\n새 후속 작업도 새로운 구독 구현을 추가해 연결할 수 있다.', 'Order가 completed 사건을 알리면 EmailObserver, PointObserver, AnalyticsObserver가 각자의 처리 메서드를 실행할 수 있다.', '주문 객체가 모든 서비스를 직접 호출하면 후속 기능이 추가될 때마다 주문 코드가 바뀐다. 싱글턴이나 팩토리는 여러 반응을 상태 변화에 연결하는 문제를 직접 해결하지 않는다.', 12, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '주문 객체 안에 이메일, 포인트, 분석 코드를 모두 복사해 넣는다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '주문 완료 사건을 발행하고 각 후속 작업 객체를 공통 구독 인터페이스로 등록한다.', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 후속 서비스를 하나의 싱글턴 객체로 합치면 구독 관계가 자동 생성된다.', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '주문 종류마다 세 후속 서비스의 하위 클래스를 새로 만든다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '동기 통지에서 한 구독자의 예외가 뒤 구독자의 실행까지 막지 않게 하려면 무엇을 고려해야 하는가?', 1, 1, 'HARD', '구독자별 예외를 분리해 기록하고 계속 진행할지 중단할지 정하는 [[오류 격리]] 정책이 필요하다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '단순 반복문에서 예외를 그대로 전파하면 앞 구독자의 실패 때문에 뒤 구독자가 호출되지 않을 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '장단점', 'TEXT', '실패를 격리하면 다른 작업은 계속할 수 있지만 전체 성공 여부와 재시도 대상을 별도로 추적해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '오류 격리', '한 처리기의 실패가 다른 독립 처리기의 실행까지 불필요하게 중단시키지 않도록 경계를 두는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '도메인 이벤트', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '구독자 등록', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '후속 작업 분리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '구독자', '특정 사건이나 상태 변화를 통지받도록 등록하고 자기 반응을 수행하는 객체');

-- STEP 12 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '결제 완료 사건은 서버 재시작 뒤에도 유실되면 안 되고 재전송될 수 있으며, 포인트 적립은 중복 실행되어도 한 번만 반영되어야 한다. 가장 적절한 판단은 무엇인가?', NULL, '구독 관계를 만드는 것만으로 프로세스 실패와 같은 사건의 중복을 견딜 수 있는지, 별도 품질 계약이 필요한지 생각해 보세요.', NULL, '옵서버 패턴만으로 사건 저장과 재전송, 단 한 번의 업무 반영이 보장되지는 않는다.\n영속 전달 경로와 재시도 정책을 두고 소비자는 [[멱등성]]을 갖도록 설계해야 한다.\n같은 사건이 다시 와도 포인트가 중복 적립되지 않게 사건 식별자 등을 확인할 수 있다.', '처리한 결제 사건 ID를 기록하고 같은 ID가 다시 도착하면 적립을 반복하지 않는 방식으로 중복 영향을 막을 수 있다.', '옵서버를 등록하거나 비동기 스레드로 바꾸는 것만으로 메시지 유실과 중복 반영이 해결되지는 않는다. 저장, 재시도, 중복 검사의 책임을 명시해야 한다.', 12, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '옵서버 인터페이스를 구현하면 재시작 뒤 복구와 정확히 한 번 처리가 자동으로 보장된다.', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 구독자를 같은 스레드에서 호출하면 사건 유실과 중복이 자동으로 사라진다.', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '사건을 영속적으로 저장해 재전송할 수 있게 하고 소비자는 같은 사건을 다시 처리해도 결과가 중복되지 않게 만든다.', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '구독자 호출 순서를 고정하면 서버 종료 중 발생한 사건도 별도 저장 없이 복구된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '소비자가 같은 사건을 이미 처리했는지 어떻게 구분할 수 있는가?', 1, 1, 'HARD', '사건마다 고유한 [[이벤트 식별자]]를 두고 처리 기록이나 업무 데이터의 고유 제약과 대조할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '재시도된 메시지가 같은 식별자를 가지면 소비자는 이전 처리 성공 여부를 확인해 중복 부작용을 피할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '식별자 확인과 실제 업무 변경이 따로 커밋되면 틈이 생길 수 있으므로 가능한 한 하나의 트랜잭션 경계에서 처리한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '이벤트 식별자', '같은 사건의 재전송과 서로 다른 사건을 구분하기 위해 부여하는 고유 값');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '최소 한 번 전달', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '트랜잭션 아웃박스', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '중복 이벤트 처리', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '멱등성', '같은 요청이나 사건을 여러 번 처리해도 최종 결과가 한 번 처리한 것과 같게 유지되는 성질');

-- STEP 12 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', 'StockItem은 재고 수량이 바뀌면 등록된 PriceView, ReorderService, AnalyticsTracker에 공통 update(stockChanged)를 보내고 각 객체는 독립적으로 반응한다. 이 행동 패턴을 ___이라고 한다.', NULL, '재고 변화를 알리는 객체와 같은 통지 계약으로 등록된 여러 반응 객체의 관계를 떠올려 보세요.', NULL, '[[옵서버 패턴]]은 StockItem의 변화를 등록된 여러 구독자에게 알리게 한다.\nStockItem은 공통 update 계약에 의존하고 화면, 재주문, 분석 객체는 자기 반응을 독립적으로 구현한다.\n새 반응을 등록하기 쉽지만 호출 시점, 순서, 실패 처리는 별도 정책으로 정해야 한다.', '재고가 임계값 아래로 내려가면 화면은 수량을 갱신하고 ReorderService는 발주 필요 여부를 따로 판단할 수 있다.', 'StockItem이 세 구현의 구체 메서드를 직접 호출하는 구조와 혼동한 경우다. 하나의 변화에 여러 대상이 등록되어 같은 계약으로 통지를 받는 관계가 핵심이다.', 12, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '옵서버 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '관찰자 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Observer Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Observer');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '상품 상세 화면이 닫혔는데도 StockItem이 PriceView를 계속 등록 목록에 보관하면 어떤 문제가 생길 수 있는가?', 1, 1, 'MEDIUM', '닫힌 PriceView가 참조 목록에 남지 않도록 적절한 시점에 [[구독 해제]]하지 않으면 메모리 누수나 불필요한 화면 호출이 생길 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'StockItem의 등록 목록이 PriceView를 계속 참조하면 화면을 닫아도 객체가 회수되지 않고 재고 변경 때마다 update가 호출될 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '생명주기 관리', 'TEXT', '화면이 열릴 때 등록했다면 닫힐 때 해제하거나 자동 해제 토큰처럼 프레임워크가 제공하는 생명주기 도구를 사용할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '구독 해제', '더 이상 알림이 필요하지 않은 객체를 발행자의 등록 목록에서 제거하는 작업');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '행동 패턴', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '이벤트 기반 설계', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '구독 생명주기', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '옵서버 패턴', '한 객체의 변화를 등록된 여러 객체에 알려 독립적으로 반응하게 하는 행동 패턴');

-- STEP 13. 커맨드와 요청 객체화
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (13, '커맨드와 요청 객체화', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '커맨드 패턴은 실행 요청과 필요한 정보를 객체 하나로 묶어, 요청을 보내는 쪽과 실제 작업을 수행하는 쪽을 분리한다. 요청 객체는 큐·로그·재시도에 활용할 수 있지만 실행 취소와 중복 실행 방지는 별도 정보와 정책이 있어야 한다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '요청을 객체로 다루기', '호출자는 구체적인 업무 메서드를 직접 부르는 대신 공통 실행 메서드를 가진 커맨드를 넘긴다. 커맨드는 실제 작업을 수행할 수신자와 필요한 인자를 알고 있어, 호출자가 수신자의 세부 API에 덜 의존하게 한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '백그라운드 작업 큐', '보고서 생성 요청을 커맨드로 만들면 웹 요청이 끝난 뒤에도 큐에서 꺼내 실행할 수 있다. 실행에 필요한 사용자 식별자와 보고서 범위를 요청 객체에 담고, 작업자는 공통 방식으로 실행한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '실행 취소는 자동 기능이 아니다', '커맨드로 감쌌다는 사실만으로 작업을 되돌릴 수 있는 것은 아니다. 이전 상태, 반대 연산, 보상 작업 중 무엇이 필요한지 설계하고, 이미 외부로 나간 결제나 메시지는 단순 복원이 가능한지도 따져야 한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '재시도와 중복 실행', '큐는 같은 요청을 다시 전달할 수 있으므로 커맨드 재실행이 안전한지 확인해야 한다. 결제처럼 중복 부작용이 큰 작업은 멱등성 키나 처리 기록을 수신자 쪽 계약에 포함해야 한다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 13 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '알림 발송 API의 컨트롤러가 SendNotificationCommand를 만들어 실행기에 넘긴다. 실행기는 execute만 호출하고 실제 이메일·푸시 발송 방법은 각 커맨드가 연결한 서비스가 담당한다. 이 구조는 실행기를 구체적인 발송 방법에서 분리하는 데 도움이 된다.', NULL, '실행 버튼 역할의 객체가 실제 작업 대상과 구체적인 호출 방법을 모두 알아야 하는지 살펴보세요.', 'O', '[[커맨드 객체]]는 실행 요청과 그 요청에 필요한 정보를 하나로 묶는다.\n호출자는 공통 실행 메서드만 알고, 실제 작업은 [[수신자]]가 수행한다.\n따라서 요청을 보내는 시점과 구체적인 수행 방법을 분리하기 쉬워진다.', '컨트롤러는 commandExecutor.execute(command)만 호출하고, SendEmailCommand나 SendPushCommand가 각 발송 서비스를 호출하도록 구성할 수 있다.', '실행기가 이메일 서비스와 푸시 서비스의 모든 메서드를 직접 알게 만들면 새로운 발송 방식이 추가될 때 실행기도 함께 바뀐다. 커맨드는 이 구체적인 연결을 요청 객체 안으로 옮긴다.', 13, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '한 실행기가 서로 다른 종류의 알림 커맨드를 같은 방식으로 실행할 수 있는 이유는 무엇인가?', 1, 1, 'MEDIUM', '모든 커맨드가 [[공통 인터페이스]]를 따르므로 실행기는 구체 타입 대신 [[다형성]]을 이용해 같은 실행 메서드를 호출할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '실행기는 커맨드 내부의 이메일·푸시 처리법을 알지 않고 약속된 메서드만 호출한다. 새 커맨드가 같은 약속을 지키면 실행기를 수정하지 않고 추가할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '실무 사용처', 'TEXT', '버튼, 예약 실행기, 작업 큐가 같은 커맨드 계약을 공유하면 요청의 출처가 달라도 동일한 실행 경로를 사용할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '공통 인터페이스', '서로 다른 구현이 동일하게 제공하기로 약속한 메서드 집합');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '다형성', '구체 타입이 달라도 같은 인터페이스를 통해 각 구현의 동작을 호출하는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '호출자와 수신자의 분리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '요청 객체화', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '다형적 실행', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '커맨드 객체', '실행할 요청과 필요한 정보를 담고 공통 실행 동작을 제공하는 객체');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '수신자', '커맨드가 위임한 실제 업무 동작을 수행하는 객체');

-- STEP 13 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '문서 편집기가 줄 삭제 기능을 DeleteLineCommand로 감쌌다. 커맨드 패턴을 사용했다는 사실만으로, 삭제 전 내용을 따로 보관하지 않아도 undo를 호출하면 원래 문서가 자동으로 복원된다.', NULL, '작업을 되돌리려면 삭제 전에 어떤 정보가 필요하고 누가 그 정보를 보관해야 하는지 따져 보세요.', 'X', '커맨드 패턴은 [[실행 취소]] 기능을 자동으로 만들어 주지 않는다.\n삭제를 되돌리려면 삭제 위치와 내용 같은 [[이전 상태]]나 반대 연산을 보관해야 한다.\n외부 부작용은 단순 복원 대신 별도의 보상 작업이 필요할 수도 있다.', 'DeleteLineCommand.execute()가 삭제한 문자열과 위치를 저장하고 undo()가 그 위치에 문자열을 다시 넣도록 직접 구현할 수 있다.', '요청을 객체로 만드는 것과 요청을 역으로 실행할 수 있는 것은 별개의 능력이다. 되돌리는 데 필요한 데이터와 실패 처리 정책이 없다면 undo 메서드만 추가해도 원래 상태를 알 수 없다.', 13, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '이미 승인된 외부 결제를 되돌릴 때 문서 편집의 undo와 같은 방식만으로 충분하지 않은 이유는 무엇인가?', 1, 1, 'HARD', '외부 결제는 과거를 지우는 대신 취소나 환불 같은 [[보상 작업]]을 실행해야 하며, 재요청에도 결과가 중복되지 않도록 [[멱등성]]을 고려해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '외부 시스템에 전달된 결과는 애플리케이션 메모리를 이전 값으로 바꾸는 것만으로 사라지지 않는다. 결제 시스템이 제공하는 반대 업무를 새 요청으로 수행해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '취소 요청도 네트워크 오류로 다시 전달될 수 있으므로 같은 취소가 여러 번 적용되지 않는 계약이 필요하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '보상 작업', '이미 발생한 외부 부작용을 업무적으로 상쇄하기 위해 수행하는 별도 작업');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '멱등성', '같은 요청을 여러 번 실행해도 한 번 실행한 것과 같은 최종 결과를 내는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '실행 취소 계약', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태 스냅샷', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '보상 트랜잭션', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '실행 취소', '이미 수행한 작업의 효과를 되돌리거나 상쇄하는 기능');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '이전 상태', '작업을 수행하기 전 복원 대상이 되는 데이터 상태');

-- STEP 13 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '보고서 API는 사용자의 요청을 즉시 접수하되 실제 생성은 야간 작업자가 수행해야 한다. 요청은 저장됐다가 서버가 재시작된 뒤에도 실행될 수 있고, 실패하면 다시 시도할 수 있어야 한다. 가장 적절한 설계는 무엇인가?', NULL, '호출 시점과 다른 시간이나 프로세스에서 실행하려면 어떤 정보를 데이터처럼 보관할 수 있어야 하는지 생각해 보세요.', NULL, '요청을 객체로 저장하면 호출과 실행 사이의 [[지연 실행]]을 지원할 수 있다.\n다른 프로세스가 읽을 수 있도록 필요한 정보는 [[직렬화]] 가능한 형태여야 한다.\n작업자는 구체 요청 종류와 무관하게 공통 실행 계약으로 큐를 처리할 수 있다.', 'GenerateReportCommand에 사용자 ID와 조회 기간을 담아 JSON으로 작업 큐에 저장하고, 작업자가 이를 복원해 execute()를 호출할 수 있다.', '호출 스택이나 컨트롤러 객체를 밤까지 유지하는 방식은 재시작과 재시도에 약하다. 상태나 옵서버는 요청 자체를 저장 가능한 실행 단위로 만드는 목적과 다르다.', 13, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '컨트롤러의 호출 스택을 야간까지 유지하고 같은 메서드가 계속 기다리게 한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '생성 요청과 필요한 인자를 커맨드로 만들고 영속 작업 큐에 저장한다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '보고서 생성 알고리즘을 현재 상태 객체로 바꾸고 큐에는 상태 이름만 저장한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '보고서 요청이 올 때마다 모든 옵서버에게 알리고 실행 완료로 간주한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '오래 대기할 커맨드에는 사용자 객체 전체와 사용자 ID 중 무엇을 담을지 어떻게 판단해야 하는가?', 1, 1, 'HARD', '실행 시점의 최신 정보가 필요하면 [[식별자]]를 저장해 다시 조회하고, 요청 당시 값을 고정해야 하면 필요한 값의 [[스냅샷]]을 저장한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '도메인 객체 전체를 그대로 저장하면 직렬화 형식과 데이터 변화에 강하게 묶일 수 있다. 반대로 ID만 저장하면 나중에 조회한 값이 요청 당시와 달라질 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '판단 기준', 'TEXT', '보고서가 접수 당시 조건을 재현해야 하는지, 실행 당시 최신 조건을 반영해야 하는지를 업무 규칙으로 먼저 정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '식별자', '나중에 대상을 다시 조회할 수 있게 구분하는 안정적인 값');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '스냅샷', '특정 시점의 필요한 데이터 값을 고정해 저장한 복사본');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '작업 큐', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '지연 실행', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '직렬화 경계', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '지연 실행', '요청을 받은 시점과 실제 작업을 수행하는 시점을 분리하는 방식');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '직렬화', '객체의 필요한 상태를 저장하거나 전송할 수 있는 데이터 형태로 바꾸는 과정');

-- STEP 13 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '결제 승인 커맨드를 처리한 작업자가 응답을 보내기 전에 종료되어 같은 커맨드가 다시 전달될 수 있다. 중복 결제를 막기 위한 설계로 가장 적절한 것은 무엇인가?', NULL, '같은 실행 요청이 두 번 도착했을 때 수신자가 첫 처리 여부를 어떻게 구별할지 살펴보세요.', NULL, '작업 큐의 [[재시도]]는 같은 커맨드를 두 번 실행할 가능성을 만든다.\n결제 제공자까지 [[멱등성]] 키를 전달해 같은 키의 중복 승인을 억제해야 한다.\n로컬 처리 기록과 외부 결제 결과가 어긋날 때를 위한 조회·조정 절차도 필요하다.', 'order-42:payment 같은 안정적인 키를 결제 API에도 보내고, 같은 키가 다시 오면 제공자가 첫 승인 결과를 돌려주도록 구성할 수 있다.', '커맨드 객체 안의 메모리 플래그는 작업자 재시작이나 다른 인스턴스의 재처리를 막지 못한다. 로컬 완료 기록만으로도 외부 결제 성공과 기록 저장 사이의 실패 틈을 완전히 없앨 수 없다.', 13, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '커맨드마다 메모리의 executed 불리언만 두고 서버가 재시작되면 초기화한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '안정적인 멱등성 키를 결제 요청에도 전달하고 같은 키의 재요청에는 기존 처리 결과를 사용한다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '두 번째 실행이 감지되면 첫 결제를 undo가 자동 복원할 것이라 가정한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '실행할 때마다 서로 다른 결제 전략을 무작위로 선택한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '멱등성 키의 처리 기록을 커맨드 실행과 따로 저장하면 어떤 경계 문제가 생길 수 있는가?', 1, 1, 'HARD', '업무 처리는 성공했지만 기록이 실패하는 틈이 생기면 다시 실행될 수 있으므로, 가능한 범위에서 두 변경을 같은 [[원자적 경계]]로 묶어야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '결제와 처리 기록 사이에 실패 지점이 있으면 시스템은 실제 결제 여부와 기록 상태가 어긋날 수 있다. 외부 결제처럼 하나의 DB 트랜잭션으로 묶을 수 없으면 조회·조정·보상 정책이 추가로 필요하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '실무 점검', 'TEXT', '키의 [[보존 기간]]은 메시지가 다시 도착할 수 있는 기간과 업무상 중복 허용 범위를 고려해 정한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '원자적 경계', '관련 변경이 함께 성공하거나 함께 실패하도록 다루는 처리 범위');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '보존 기간', '중복 판단을 위해 처리 기록을 유지하는 시간 범위');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, 'at-least-once 전달', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '멱등한 수신자', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '중복 부작용 방지', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '재시도', '실패하거나 결과가 불확실한 작업을 다시 실행하는 처리');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '멱등성', '같은 요청을 반복해도 한 번 처리한 것과 같은 최종 결과를 내는 성질');

-- STEP 13 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '관리자 화면의 버튼, 예약 실행기, 테스트 코드가 모두 같은 배치 실행 요청을 객체로 전달하고 공통 execute 동작으로 실행한다. 이처럼 요청을 객체로 캡슐화해 호출자와 수행자를 분리하는 설계는 ___이다.', NULL, '실행 요청을 독립된 값처럼 다루고 요청을 만든 쪽과 수행하는 쪽을 분리하는 설계 의도를 떠올려 보세요.', NULL, '[[커맨드 패턴]]은 실행 요청을 메서드 호출이 아니라 객체로 표현한다.\n버튼이나 예약 실행기 같은 [[호출자]]는 공통 실행 계약에만 의존한다.\n요청을 저장·전달·기록할 수 있지만 작은 작업까지 모두 감싸면 구조가 복잡해질 수 있다.', 'RunBatchCommand가 execute() 안에서 batchService.run(batchId)를 호출하게 하면 화면과 스케줄러가 같은 요청 객체를 사용할 수 있다.', '전략은 같은 목적의 알고리즘을 교체하고, 옵서버는 변경을 여러 구독자에게 알린다. 여기서는 실행 요청 자체를 값처럼 다루는 것이 핵심이다.', 13, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '커맨드 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Command Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'Command');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '단순한 서비스 메서드 한 번을 호출하는 코드에도 항상 커맨드를 도입하면 어떤 비용이 생기는가?', 1, 1, 'MEDIUM', '저장·큐·취소 같은 필요가 없다면 커맨드 도입은 [[객체 수 증가]]와 [[간접 계층]]만 늘려 흐름을 읽기 어렵게 할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '패턴은 미래 가능성만으로 적용하기보다 현재 필요한 변화 지점과 운영 요구가 있는지 보고 선택한다. 직접 호출로 충분한 작은 기능은 단순하게 두는 편이 낫다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '도입 신호', 'TEXT', '요청을 나중에 실행하거나 기록·재시도·취소해야 할 때는 추가 구조의 이점이 분명해진다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '객체 수 증가', '작은 동작마다 별도 클래스를 만들면서 관리 대상이 많아지는 비용');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '간접 계층', '호출자와 실제 동작 사이에 추가되는 중간 추상화 단계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '요청 캡슐화', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '호출자와 수신자', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '패턴 도입 비용', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '커맨드 패턴', '요청을 객체로 캡슐화해 호출과 실행을 분리하는 행위 패턴');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '호출자', '커맨드의 공통 실행 동작을 요청하지만 실제 수행 세부사항은 모르는 객체');

-- STEP 14. 상태 패턴과 상태 전이
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (14, '상태 패턴과 상태 전이', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '상태 패턴은 객체의 현재 상태를 별도 객체로 표현하고 행동을 그 상태에 위임한다. 상태 전이는 도메인 사건과 규칙에 따라 일어나며, 외부 요구로 알고리즘을 고르는 전략 패턴과 선택 주체가 다르다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '상태가 행동을 결정한다', '주문이 결제 대기인지 배송 중인지에 따라 취소와 배송 요청의 의미가 달라진다. 컨텍스트가 현재 상태 객체에 행동을 위임하면 큰 조건문 대신 각 상태가 허용 동작과 반응을 설명할 수 있다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '전략과 선택 주체가 다르다', '전략은 보통 호출자나 설정이 같은 목적의 알고리즘을 선택한다. 상태는 객체의 생명주기 안에서 사건과 전이 규칙에 따라 현재 구현이 바뀌며, 클라이언트가 매 호출마다 원하는 상태를 임의로 고르는 구조가 아니다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '문서 승인 흐름', '초안은 수정과 검수 요청을 허용하고, 검수 중에는 승인이나 반려를 처리하며, 게시된 문서는 일반 수정을 막을 수 있다. 각 상태가 같은 메서드에 다르게 반응하고 유효한 다음 상태를 정한다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '전이 위치도 계약이다', '상태 객체가 다음 상태를 선택할 수도 있고 컨텍스트가 전이를 관리할 수도 있다. 어느 쪽이든 전이 규칙을 흩어 놓거나 외부 코드가 상태를 자유롭게 바꾸게 하면 유효하지 않은 전이와 테스트 누락이 생기기 쉽다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 14 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '주문 객체가 결제대기·결제완료·배송중 상태 객체 중 하나를 현재 상태로 가지고, cancel과 ship 요청을 그 객체에 위임한다. 이 구조는 상태별 행동을 하나의 큰 조건문에서 분리하는 데 도움이 된다.', NULL, '같은 요청이 들어와도 주문의 생명주기 단계에 따라 책임을 맡는 객체가 달라지는지 살펴보세요.', 'O', '[[상태 객체]]는 특정 생명주기 단계에서 허용되는 행동과 반응을 담당한다.\n주문 [[컨텍스트]]는 현재 상태를 보관하고 같은 요청을 그 상태에 위임한다.\n상태별 규칙이 분리되어 새로운 상태를 추가할 때 거대한 조건문을 직접 늘리지 않아도 된다.', 'Order.cancel()이 currentState.cancel(this)를 호출하면 PaidState와 ShippedState가 각자 취소 가능 여부와 후속 행동을 구현할 수 있다.', '상태별 분기를 주문의 모든 메서드에 반복하면 규칙이 여러 곳에 흩어진다. 상태 객체로 책임을 옮기면 한 생명주기의 행동을 한곳에서 살펴보기 쉬워진다.', 14, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '상태 패턴으로 바꿔도 새로운 상태 추가가 기존 코드에 영향을 줄 수 있는 경우는 언제인가?', 1, 1, 'MEDIUM', '모든 상태를 열거하는 화면·저장 형식·전이 표가 새 상태를 알아야 한다면 [[확장 지점]] 밖의 코드도 함께 바뀔 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '행동 분기를 상태 객체로 옮겨도 시스템 전체가 자동으로 변경에 닫히는 것은 아니다. 상태 이름을 저장하거나 외부 API로 노출한다면 호환성과 마이그레이션도 검토해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '검수 기준', 'TEXT', '새 상태가 추가될 때 수정되는 곳을 찾아 [[조건 분기]]가 다른 계층에 다시 퍼져 있지 않은지 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '확장 지점', '새 구현이나 동작을 기존 구조에 연결하도록 의도적으로 마련한 위치');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '조건 분기', '값이나 상태를 검사해 실행 경로를 나누는 로직');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태별 책임 분리', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '컨텍스트 위임', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '조건문 분산 방지', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '상태 객체', '특정 상태에서의 행동과 전이 규칙을 표현하는 객체');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '컨텍스트', '현재 상태를 보관하고 외부 요청을 상태 객체에 위임하는 본체 객체');

-- STEP 14 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '배송비 계산 전략과 주문 상태는 모두 교체 가능한 객체이므로 선택 주체도 같다. 두 경우 모두 객체 내부의 상태 전이가 다음 구현을 정하고 외부 설정이나 호출자는 선택에 관여하지 않는다.', NULL, '계산 방법을 고르는 주체와 생명주기 사건 뒤 다음 행동을 정하는 주체를 나누어 보세요.', 'X', '[[전략 패턴]]은 보통 호출자나 설정이 목적에 맞는 알고리즘을 선택한다.\n[[상태 패턴]]은 현재 상태와 사건에 따른 전이가 다음 행동을 결정한다.\n클래스 모양이 비슷해도 무엇이 교체를 주도하는지가 두 패턴의 중요한 구분점이다.', '결제 수단별 수수료 계산기는 사용자가 전략을 고를 수 있지만, 배송 완료 뒤 주문이 완료 상태로 가는 것은 주문의 전이 규칙이 정한다.', '두 패턴 모두 합성과 위임을 사용할 수 있어 구조만 보면 비슷하다. 그러나 전략은 선택 가능한 계산법이고 상태는 객체가 지나가는 생명주기의 현재 단계를 표현한다.', 14, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '클래스 다이어그램이 비슷한 두 패턴을 코드 리뷰에서 어떻게 구분할 수 있는가?', 1, 1, 'HARD', '누가 구현을 바꾸는지라는 [[선택 주체]]와, 교체 목적이 계산법 선택인지 생명주기 표현인지라는 [[설계 의도]]를 확인한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '인터페이스와 구현 클래스 개수만으로 패턴 이름을 정하면 의도를 놓친다. 생성 지점, 교체 시점, 전이를 일으키는 사건을 함께 추적해야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '리뷰 질문', 'TEXT', '클라이언트가 매번 구현을 선택하는가, 아니면 현재 객체가 업무 사건을 받아 자연스럽게 다음 단계로 이동하는가를 묻는다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '선택 주체', '여러 구현 중 실제 사용할 대상을 결정하는 객체나 규칙');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '설계 의도', '구조를 도입해 해결하려는 주된 변화와 문제');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '전략과 상태 비교', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '선택 주체', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '패턴의 의도', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전략 패턴', '같은 목적을 가진 여러 알고리즘을 교체 가능하게 캡슐화하는 패턴');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '상태 패턴', '객체의 현재 상태를 객체로 표현해 상태에 따라 행동을 바꾸는 패턴');

-- STEP 14 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '문서 서비스에는 초안·검수중·게시됨 단계가 있다. 초안은 수정할 수 있고, 검수중은 승인 또는 반려할 수 있으며, 게시됨은 일반 수정을 거부해야 한다. 단계가 늘면서 각 메서드의 조건문이 반복되고 있다. 가장 적절한 개선은 무엇인가?', NULL, '같은 요청의 허용 여부가 현재 생명주기 단계에 따라 달라질 때 그 규칙을 어디에 모을지 생각해 보세요.', NULL, '문서의 현재 단계를 별도 [[상태 클래스]]로 나누면 단계별 행동을 함께 모을 수 있다.\n문서는 요청을 현재 상태에 [[위임]]하고 상태는 허용되지 않은 동작을 명확히 거부한다.\n상태 전이는 승인·반려 같은 업무 사건과 연결해 테스트 가능한 규칙으로 둔다.', 'Document.approve()가 state.approve(this)를 호출하고 ReviewingState만 PublishedState로의 전이를 허용하도록 구현할 수 있다.', '상태 문자열 비교를 모든 서비스와 컨트롤러에 복사하면 새 단계가 추가될 때 수정 범위가 넓어진다. 전략을 외부에서 임의 선택하게 하는 것도 문서의 유효한 생명주기 규칙을 표현하지 못한다.', 14, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 컨트롤러가 상태 문자열을 검사하고 허용 목록을 별도로 유지한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '단계별 상태 클래스로 행동을 분리하고 문서가 현재 상태에 요청을 위임한다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '호출자가 매 요청마다 원하는 문서 상태를 전략처럼 직접 주입한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 상태에서 수정과 승인을 허용한 뒤 로그에서 잘못된 호출을 찾는다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '게시 상태를 DB에 문자열로 저장할 때 새 상태를 추가하면 무엇을 함께 검토해야 하는가?', 1, 1, 'MEDIUM', '기존 행을 새 코드가 읽을 수 있는지와 구버전 코드가 새 값을 만났을 때의 [[호환성]]을 확인해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '상태 클래스만 추가해도 저장 값, API 응답, 검색 조건은 자동으로 갱신되지 않는다. 배포 중 서로 다른 버전이 함께 실행될 수 있다면 알 수 없는 상태를 다루는 정책도 필요하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '데이터 점검', 'TEXT', '기존 데이터를 새 상태로 옮겨야 한다면 [[데이터 마이그레이션]]과 롤백 경로를 설계한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '호환성', '서로 다른 버전의 코드와 데이터가 함께 동작할 수 있는 성질');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '데이터 마이그레이션', '기존 저장 데이터를 새 구조나 규칙에 맞게 변환하는 작업');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '문서 워크플로', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태별 허용 동작', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '행동 위임', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '상태 클래스', '특정 상태에서 허용되는 행동과 반응을 구현한 클래스');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '위임', '현재 객체가 해야 할 작업을 다른 책임 객체에 맡기는 것');

-- STEP 14 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '연결 객체는 연결끊김·연결중·연결됨 상태를 가지며 성공, 실패, 시간 초과 사건으로 이동한다. 상태 전이 책임을 배치하는 원칙으로 가장 적절한 것은 무엇인가?', NULL, '특정 구현 위치보다 유효한 이동 규칙이 한눈에 드러나고 일관되게 검사되는지를 기준으로 보세요.', NULL, '상태 패턴은 전이를 반드시 한 가지 클래스에만 두라고 강제하지 않는다.\n중요한 것은 [[전이 정책]]을 일관된 위치에 두고 [[유효한 전이]]만 허용하는 계약이다.\n외부 코드가 상태 필드를 자유롭게 바꾸게 하면 생명주기 불변식을 지키기 어렵다.', 'ConnectingState가 성공 사건을 받아 context.transitionTo(ConnectedState)를 요청하거나, 컨텍스트의 전이 표가 같은 규칙을 관리할 수 있다.', '모든 전이를 상태 객체나 컨텍스트 중 한쪽에만 둬야 한다는 보편 규칙은 없다. 반대로 아무 호출자나 상태를 교체하게 하면 연결되지 않은 객체가 곧바로 연결됨이 되는 잘못된 이동도 막기 어렵다.', 14, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '모든 상태 객체가 어떤 검증도 없이 원하는 다음 상태를 직접 대입하게 한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '외부 호출자가 현재 상태 필드를 언제든 원하는 값으로 바꿀 수 있게 공개한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '컨텍스트나 상태 객체 중 선택한 위치에서 전이 규칙을 일관되게 관리하고 유효성을 검사한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '상태 전이를 없애고 매 요청마다 무작위 구현을 선택한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '두 요청이 동시에 같은 객체의 상태를 바꾸려 할 때 상태 패턴만으로 안전성이 보장되는가?', 1, 1, 'HARD', '상태 패턴은 행동 구조를 정리할 뿐 [[동시성]]을 자동으로 제어하지 않으므로 잠금이나 [[낙관적 잠금]] 같은 별도 정책이 필요하다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '두 실행 흐름이 같은 이전 상태를 보고 각각 다른 전이를 저장하면 한 변경이 사라지거나 허용되지 않은 순서가 생길 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '실무 점검', 'TEXT', 'DB 버전 값, 조건부 갱신, 트랜잭션 경계를 사용해 누가 먼저 상태를 바꿨는지 검출할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '동시성', '여러 실행 흐름이 같은 시간대에 공유 상태를 읽고 바꾸는 상황');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '낙관적 잠금', '버전 비교 등으로 충돌을 감지하고 실패한 갱신을 다시 처리하는 동시성 제어 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태 전이 소유권', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '생명주기 불변식', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '유효하지 않은 전이', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전이 정책', '어떤 사건에서 어느 상태로 이동할 수 있는지 정한 규칙');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '유효한 전이', '현재 상태와 업무 규칙이 허용하는 다음 상태로의 이동');

-- STEP 14 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '구독 객체가 체험중·활성·연체·해지 상태 객체에 renew와 cancel 행동을 위임하고, 결제 성공이나 연체 사건에 따라 현재 구현을 바꾼다. 이 설계는 ___이다.', NULL, '외부가 계산법을 고르는 상황이 아니라 객체의 생명주기 단계가 행동을 바꾸는 상황에 초점을 맞추세요.', NULL, '[[상태 패턴]]은 현재 생명주기 단계를 객체로 표현해 행동을 위임한다.\n결제 성공이나 연체 같은 [[도메인 사건]]이 상태 전이의 계기가 된다.\n상태 클래스는 행동을 정리하지만 저장·동시성·잘못된 전이 방지는 별도 계약으로 설계해야 한다.', 'Subscription.renew()가 currentState.renew(this)를 호출하면 ActiveState와 CanceledState가 같은 요청에 서로 다른 반응을 제공할 수 있다.', '전략 패턴이라면 호출자나 설정이 원하는 갱신 알고리즘을 고르는 상황에 가깝다. 여기서는 구독 자체의 현재 단계와 업무 사건이 다음 행동을 결정한다.', 14, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '상태 패턴');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'State Pattern');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'State');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '배송비 계산 방식을 사용자가 선택하고 객체 생명주기와 무관하게 바꿀 수 있다면 어떤 패턴이 더 적절한가?', 1, 1, 'MEDIUM', '외부 요구에 따라 같은 목적의 계산법을 교체하는 상황이므로 [[전략 패턴]]이 더 자연스럽다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '일반 배송과 빠른 배송은 생명주기의 앞뒤 단계가 아니라 같은 계산 목적을 수행하는 선택지다. 호출자나 설정이 사용할 구현을 정할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '비교', 'TEXT', '상태는 내부 사건에 따른 변화를, 전략은 외부에서 선택 가능한 [[알고리즘 교체]]를 중심으로 본다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '전략 패턴', '같은 목적의 여러 알고리즘을 캡슐화해 필요에 따라 선택하는 패턴');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '알고리즘 교체', '동일한 목적을 수행하는 계산 절차의 구현을 다른 구현으로 바꾸는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상태 기반 행동', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '도메인 사건', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '전략 패턴과의 구분', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '상태 패턴', '현재 상태를 객체로 표현하고 상태에 따라 행동을 바꾸는 행위 패턴');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '도메인 사건', '업무 안에서 상태 변화나 후속 행동을 일으키는 의미 있는 사건');

-- STEP 15. 템플릿 메서드와 확장 훅
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (15, '템플릿 메서드와 확장 훅', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '템플릿 메서드는 전체 처리 순서를 상위 클래스에 두고 일부 단계를 하위 클래스가 구현하거나 선택적으로 확장하게 한다. 공통 흐름과 불변 순서를 지키기 쉽지만 변화 축이 많으면 상속 계층과 결합이 커질 수 있다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '전체 순서는 상위 클래스가 소유한다', '가져오기, 검증, 변환, 저장처럼 모든 구현이 지켜야 할 순서를 템플릿 메서드에 둔다. 하위 클래스는 파일 형식에 따라 달라지는 읽기나 변환 단계만 구현한다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '필수 단계와 선택적 훅', '반드시 구현해야 하는 단계는 추상 연산으로 두고, 필요할 때만 덧붙이는 단계는 기본 동작이 있는 훅으로 둘 수 있다. 훅이 너무 많으면 실제 실행 흐름을 추적하기 어려워진다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '여러 형식의 가져오기 작업', 'CSV와 JSON 가져오기가 모두 파일 열기, 파싱, 검증, 저장, 정리 순서를 따른다면 상위 클래스가 수명주기를 관리하고 각 형식이 파싱 단계만 바꾸게 할 수 있다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '상속의 변화 비용', '상위 클래스의 호출 순서와 보호된 상태는 하위 클래스의 계약이 된다. 출력 형식, 저장소, 알림처럼 독립적인 변화 축을 상속으로 모두 조합하면 하위 클래스가 폭증하므로 합성이나 전략이 더 나을 수 있다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 15 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '가져오기 프레임워크의 BaseImporter.run이 파일 열기→파싱→변환→검증→저장→파일 닫기 순서를 정하고, CSVImporter와 JsonImporter는 파싱과 변환 단계만 구현한다. 이 구조는 공통 처리 순서를 한곳에서 유지하는 데 도움이 된다.', NULL, '전체 흐름의 순서를 누가 소유하고 형식별 차이가 어느 단계에 한정되는지 확인해 보세요.', 'O', '[[템플릿 메서드]]는 여러 구현이 공유할 [[알고리즘 골격]]과 실행 순서를 정의한다.\n하위 클래스는 형식마다 달라지는 일부 단계만 구현하거나 재정의한다.\n공통 자원 정리와 검증 순서를 상위 클래스가 관리해 중복과 순서 누락을 줄일 수 있다.', 'run()이 open(), parse(), transform(), validate(), save(), close()를 차례로 호출하고 parse()와 transform()만 하위 클래스가 구현하도록 만들 수 있다.', '각 가져오기 클래스가 전체 순서를 복사하면 닫기나 검증 단계가 빠지거나 수정 내용이 서로 달라질 수 있다. 공통 흐름을 상위 클래스가 소유하는 것이 이 구조의 핵심이다.', 15, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '하위 클래스가 저장 전에 검증 단계를 건너뛰지 못하게 하려면 무엇을 보호해야 하는가?', 1, 1, 'MEDIUM', '상위 클래스가 [[불변 순서]]를 소유하고 하위 클래스에는 허용된 단계만 [[재정의]]할 수 있게 해야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '하위 클래스가 전체 run 흐름을 바꿀 수 있으면 검증 뒤 저장이라는 핵심 계약도 깨질 수 있다. 언어가 지원한다면 전체 흐름의 변경을 제한하고 단계별 확장점만 노출한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '테스트 기준', 'TEXT', '모든 구현에서 검증 실패 시 저장이 호출되지 않고 자원 정리가 수행되는지 공통 계약 테스트로 확인할 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '불변 순서', '구체 구현이 달라도 반드시 지켜야 하는 단계의 실행 순서');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '재정의', '하위 클래스가 상위 클래스에서 제공한 동작을 자신의 구현으로 바꾸는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '알고리즘 골격', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '공통 수명주기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '불변 순서', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '템플릿 메서드', '전체 알고리즘 순서를 정의하고 일부 단계를 하위 클래스에 맡기는 메서드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '알고리즘 골격', '구체 구현들이 공통으로 따라야 하는 처리 단계와 순서');

-- STEP 15 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'BaseImporter는 afterSave()에 아무 일도 하지 않는 기본 구현을 두고, 감사 로그가 필요한 하위 클래스만 이 메서드를 재정의한다. afterSave()는 모든 하위 클래스가 반드시 구현해야 하므로 이런 기본 구현은 잘못된 설계다.', NULL, '감사 로그가 필요 없는 Importer가 저장 뒤 반드시 수행해야 할 동작이 있는지 생각해 보세요.', 'X', '저장 후 감사 로그가 일부 Importer에만 필요하다면 [[훅]]을 선택적 확장점으로 둘 수 있다.\nBaseImporter의 빈 [[기본 구현]]은 로그가 필요 없는 하위 클래스에 불필요한 구현을 강제하지 않는다.\n모든 하위 클래스에 반드시 필요한 단계만 추상 연산으로 두어 구현을 강제하는 편이 명확하다.', 'CsvImporter와 JsonImporter는 afterSave()를 그대로 사용하고, AuditedCsvImporter만 이를 재정의해 파일 이름과 작업자, 저장 시각을 감사 로그에 남길 수 있다.', '이 상황에서 감사 로그는 일부 하위 클래스에만 필요한 선택 동작이다. 이를 필수 추상 단계로 만들면 로그가 필요 없는 Importer도 의미 없는 빈 메서드를 구현해야 하므로, 빈 기본 구현이 잘못됐다는 주장은 맞지 않는다.', 15, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '어떤 단계를 추상 연산으로 두고 어떤 단계를 훅으로 둘지 판단하는 기준은 무엇인가?', 1, 1, 'MEDIUM', '모든 하위 클래스가 제공해야 흐름이 성립하면 [[필수 단계]], 없어도 공통 흐름이 완성되면 [[선택 단계]]로 본다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '파싱처럼 구현이 없으면 작업 자체가 불가능한 단계는 구현을 강제하는 편이 낫다. 저장 뒤 감사 로그처럼 일부 구현만 필요한 동작은 기본 동작이 있는 확장점으로 둘 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '흔한 오해', 'TEXT', '선택할 수 있다는 이유로 중요한 검증이나 권한 확인까지 비어 있는 기본 동작으로 두면 하위 클래스가 실수로 안전 규칙을 건너뛸 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '필수 단계', '모든 구체 구현이 제공해야 전체 처리 흐름이 성립하는 단계');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '선택 단계', '필요한 구현만 추가 동작을 제공해도 되는 확장 단계');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '선택적 감사 로그', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '추상 연산과 훅 구분', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '빈 기본 동작', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '훅', '하위 클래스가 필요할 때 템플릿 흐름 일부를 확장하도록 제공하는 선택적 메서드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '기본 구현', '하위 클래스가 재정의하지 않아도 사용할 수 있도록 상위 클래스가 제공하는 동작');

-- STEP 15 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'CSV와 JSON 상품 가져오기는 파일 열기, 파싱, 업무 검증, 저장, 파일 닫기 순서를 반드시 지켜야 한다. 형식마다 파싱 방법만 다르고, 실패해도 파일은 닫혀야 한다. 가장 적절한 설계는 무엇인가?', NULL, '공통 수명주기와 형식별 변화 지점을 분리하고 자원 정리를 누가 책임질지 기준으로 보세요.', NULL, '상위 템플릿은 열기부터 닫기까지의 공통 흐름과 자원 수명을 책임진다.\n형식별 파싱은 하위 클래스가 구현하는 [[원시 연산]]으로 분리할 수 있다.\n이 방식은 [[상속]]으로 확장되므로 하위 클래스가 상위 흐름의 계약을 이해해야 한다.', 'BaseImporter.run()이 try/finally로 close()를 보장하고 parse(stream)만 CsvImporter와 JsonImporter가 다르게 구현하도록 만들 수 있다.', '각 구현이 전체 흐름을 복사하면 실패 경로의 닫기나 검증 순서가 달라질 수 있다. 반대로 파싱 방법을 런타임마다 자유롭게 조합해야 한다면 상속보다 합성이 나을 수 있지만, 제시된 상황은 공통 수명주기가 중심이다.', 15, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 형식 클래스가 열기부터 닫기까지 전체 코드를 복사해 독립적으로 관리한다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '상위 클래스가 전체 순서와 정리를 맡고 하위 클래스가 형식별 파싱 단계만 구현한다', 1, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '파일 형식과 무관하게 하나의 파서를 사용하고 실패한 행은 모두 무시한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '하위 클래스가 저장과 닫기의 호출 순서를 자유롭게 바꾸도록 전체 흐름을 공개한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '하위 클래스의 파싱 단계가 예외를 던져도 파일을 닫게 하려면 어느 계층이 자원 수명을 관리해야 하는가?', 1, 1, 'HARD', '전체 흐름을 소유한 상위 템플릿이 [[자원 수명]]과 [[예외 안전성]]을 함께 관리해야 모든 하위 구현에 같은 보장을 적용할 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '열기와 닫기를 서로 다른 하위 구현에 맡기면 실패 경로마다 정리 여부가 달라질 수 있다. 상위 흐름이 finally나 언어의 자원 관리 구문을 사용해 정리를 보장한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '검수 기준', 'TEXT', '정상, 검증 실패, 파싱 예외 경로에서 닫기 동작이 모두 실행되는지 공통 테스트로 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '자원 수명', '파일이나 연결을 획득한 뒤 사용하고 반드시 해제하기까지의 범위');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '예외 안전성', '실행 중 예외가 발생해도 자원과 상태가 약속된 조건을 지키는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '원시 연산', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '자원 수명주기', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '예외 안전성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '원시 연산', '템플릿의 전체 흐름 안에서 하위 클래스가 구체적으로 구현하는 개별 단계');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '상속', '하위 클래스가 상위 클래스의 구조와 동작을 이어받아 확장하는 관계');

-- STEP 15 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '보고서 생성 흐름은 같지만 출력 형식 4종, 저장소 3종, 완료 알림 3종을 실행 시점마다 독립적으로 조합해야 한다. 모든 조합을 템플릿 메서드의 하위 클래스로 만들자 클래스 수가 빠르게 늘었다. 가장 적절한 개선은 무엇인가?', NULL, '서로 독립적인 변화 축을 하나의 상속 계층에서 모든 조합으로 표현할 때 필요한 클래스 수를 생각해 보세요.', NULL, '독립적인 변화 축을 상속 조합으로 표현하면 [[서브클래스 폭증]]이 생길 수 있다.\n출력·저장·알림 동작을 별도 객체로 [[합성]]하면 필요한 구현을 실행 시점에 조합할 수 있다.\n템플릿 메서드는 공통 순서가 핵심일 때 유용하지만 모든 변화에 적합한 해법은 아니다.', 'ReportJob이 OutputFormatter, ReportStore, CompletionNotifier를 생성자로 받아 run()에서 차례로 위임하도록 바꿀 수 있다.', '하위 클래스를 더 만들거나 조건문으로 조합을 숨기면 변화 축이 추가될 때 복잡도가 계속 커진다. 공통 흐름은 유지하되 독립적으로 바뀌는 행동을 객체로 분리하는 편이 낫다.', 15, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '출력·저장·알림의 모든 조합마다 새 하위 클래스를 계속 만든다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '상위 클래스의 한 메서드에 모든 조합을 조건문으로 직접 추가한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '독립적으로 바뀌는 동작을 별도 객체로 분리하고 보고서 작업이 이들을 합성한다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '출력 형식을 하나만 남기고 저장과 알림 요구를 제거한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '템플릿 메서드와 전략을 함께 사용할 수도 있는가?', 1, 1, 'MEDIUM', '상위 템플릿이 공통 순서를 유지하면서 일부 단계는 [[위임]]을 통해 교체 가능한 [[전략 객체]]에 맡길 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '패턴은 서로 배타적인 이름표가 아니다. 변하지 않는 전체 흐름은 상위 클래스에 두고, 실행 시점마다 바뀌는 계산이나 저장 방식만 객체로 주입할 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '판단 기준', 'TEXT', '상속으로 고정해도 되는 변화와 런타임에 조합해야 하는 변화를 나누어 적용한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '위임', '자신이 받은 작업의 일부를 다른 책임 객체가 수행하도록 맡기는 것');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '전략 객체', '같은 목적의 교체 가능한 알고리즘을 캡슐화한 객체');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '상속과 합성', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '독립 변화 축', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '전략 패턴 조합', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '서브클래스 폭증', '여러 변화 조합을 상속으로 표현하면서 하위 클래스 수가 곱셈처럼 늘어나는 문제');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '합성', '필요한 동작을 가진 객체들을 내부에 두고 협력하게 구성하는 방식');

-- STEP 15 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '배치 처리의 전체 순서는 그대로 유지하되, 일부 하위 클래스만 저장 뒤 감사 로그를 추가할 수 있도록 기본 동작이 비어 있는 선택적 확장 메서드를 제공했다. 이 메서드는 ___이다.', NULL, '공통 흐름을 깨지 않고 필요한 구현만 추가 행동을 넣도록 마련한 선택적 지점을 떠올려 보세요.', NULL, '[[훅]]은 템플릿 흐름 안에서 선택적으로 재정의할 수 있는 메서드다.\n[[확장 지점]]을 명시적으로 제공해 하위 클래스가 전체 순서를 복사하지 않게 한다.\n훅이 많아지면 호출 관계와 상위 클래스의 숨은 계약을 이해하기 어려워질 수 있다.', 'BaseJob.afterSave()를 빈 구현으로 두고 AuditJob만 afterSave()에서 auditLogger.log(result)를 호출할 수 있다.', '반드시 구현해야 하는 추상 연산과 달리, 이 메서드는 구현하지 않아도 전체 배치가 동작한다. 선택적 확장을 위해 기본 동작을 제공한다는 조건이 구분점이다.', 15, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '훅');
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, 'hook');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '훅이 너무 많고 호출 순서가 자주 바뀌면 하위 클래스에 어떤 문제가 생길 수 있는가?', 1, 1, 'HARD', '상위 클래스의 내부 변경이 예상하지 못한 하위 클래스 동작을 깨뜨리는 [[취약한 기반 클래스]] 문제가 생길 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '하위 클래스는 문서에 드러난 메서드뿐 아니라 호출 시점과 순서에도 기대를 갖기 쉽다. 상위 구현의 작은 수정이 여러 하위 클래스의 결과를 바꿀 수 있다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '완화 방법', 'TEXT', '허용된 확장점과 호출 순서를 [[계약]]으로 문서화하고 공통 테스트를 두며, 변화 축이 많으면 합성으로 전환한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '취약한 기반 클래스', '상위 클래스의 내부 변경이 하위 클래스에 예상하지 못한 오류를 일으키는 문제');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '계약', '구현들이 서로 지켜야 하는 동작, 순서, 입력과 결과에 대한 약속');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '선택적 재정의', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '확장 지점', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '취약한 기반 클래스', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '훅', '하위 클래스가 필요할 때만 템플릿 흐름 일부를 확장하도록 제공하는 메서드');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '확장 지점', '기존 흐름을 유지하면서 추가 동작을 연결하도록 마련한 위치');

-- STEP 16. 책임 연쇄와 처리 파이프라인
INSERT INTO quiz_step (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
VALUES (16, '책임 연쇄와 처리 파이프라인', 3, @design_pattern_course_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_step_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing (quiz_step_id, summary, created_at, updated_at)
VALUES (@design_pattern_quiz_step_id, '책임 연쇄는 요청을 여러 처리자 중 누가 처리할지 호출자가 미리 알지 않아도 되도록 처리자를 연결한다. 요청을 처리한 뒤 멈출지 계속 보낼지, 아무도 처리하지 않으면 어떻게 할지는 패턴이 자동 결정하지 않는 구현 계약이다.', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_briefing_id = LAST_INSERT_ID();
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CONCEPT', '처리하거나 다음으로 넘기기', '각 처리자는 자신이 요청을 다룰 수 있는지 판단하고, 처리하거나 다음 처리자에게 전달한다. 호출자는 첫 처리자만 알면 되어 구체적인 최종 처리자와 직접 연결되지 않는다.', 1, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'EXAMPLE', '웹 요청 미들웨어', '인증, 요청 제한, 입력 검증을 순서대로 연결할 수 있다. 각 단계는 요청을 거부해 응답을 끝내거나 다음 단계로 넘길 수 있으며, 보안상 중요한 순서를 명확히 정해야 한다.', 2, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '전파 정책은 패턴 밖의 계약', '첫 처리자가 성공하면 멈추는지, 모든 처리자가 실행되는지, 오류가 나면 어디까지 돌아가는지는 시스템이 정해야 한다. 단지 next 참조를 연결했다고 해서 원하는 흐름이 보장되지는 않는다.', 3, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO quiz_step_briefing_block (briefing_id, type, heading, content, display_order, created_at, updated_at)
VALUES (@design_pattern_briefing_id, 'CAUTION', '순서와 미처리 요청', '인가보다 인증이 먼저여야 하는 것처럼 처리 순서가 결과와 안전성에 영향을 줄 수 있다. 아무 처리자도 요청을 맡지 않았을 때 기본 응답, 오류, 무시 중 무엇을 할지도 끝 처리자의 계약으로 둔다.', 4, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- STEP 16 / SLOT 1
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', '고객 문의가 일반 상담원, 결제 담당자, 관리자 처리자 순으로 전달된다. 각 처리자는 자신의 권한으로 해결할 수 있으면 처리하고, 아니면 다음 처리자에게 넘긴다. 호출자는 최종 담당자를 미리 알 필요가 없다.', NULL, '요청을 처음 받은 쪽이 최종 담당자의 구체 타입과 호출 방법을 알고 있어야 하는지 살펴보세요.', 'O', '각 [[처리자]]는 요청을 맡을 수 있는지 판단하고 처리하거나 넘긴다.\n맡지 못한 요청은 연결된 [[다음 처리자]]에게 전달된다.\n호출자는 사슬의 시작점만 알면 되어 구체적인 최종 담당자와의 결합이 줄어든다.', 'supportChain.handle(ticket)를 호출하면 BillingHandler가 결제 문의를 처리하고 다른 문의는 AdminHandler로 넘길 수 있다.', '호출자가 문의 종류마다 최종 담당자를 직접 선택하면 처리자 추가와 순서 변경 때 호출 코드도 바뀐다. 사슬은 이 라우팅 책임을 각 처리자와 연결 구조로 옮긴다.', 16, 1, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '중간 처리자는 요청을 최종적으로 누가 해결했는지 몰라도 동작할 수 있는가?', 1, 1, 'MEDIUM', '중간 처리자는 자신의 책임과 [[체인]]의 다음 대상만 알면 되므로 최종 담당자에 대한 [[결합도]]를 낮출 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '각 처리자는 자신이 다룰 수 없는 요청을 약속된 방식으로 다음 대상에 넘긴다. 새 처리자를 중간에 넣어도 앞의 호출자는 구체적인 최종 대상을 알 필요가 없다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '주의', 'TEXT', '누가 처리했는지 감사 기록이 필요하면 처리 결과에 담당자 정보를 포함하는 별도 계약을 둘 수 있다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '체인', '요청을 차례로 전달할 수 있도록 연결된 처리자들의 순서');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '결합도', '한 구성 요소가 다른 구성 요소의 구체적인 구조와 변경에 의존하는 정도');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '처리자 연결', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '요청 라우팅', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '호출자 결합도', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '처리자', '요청을 처리할지 다음 대상으로 넘길지 결정하는 객체');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '다음 처리자', '현재 처리자가 요청을 넘길 수 있도록 연결된 다음 객체');

-- STEP 16 / SLOT 2
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('OX', 'EASY', 'API 요청이 인증→요청 제한→입력 검증 처리자 순서로 흐른다. 인증 처리자가 위조된 토큰을 발견했더라도, 올바른 책임 연쇄라면 요청 제한과 입력 검증 처리자까지 반드시 실행해야 한다.', NULL, '각 처리자가 다음 처리자를 호출할 조건과 요청을 즉시 끝낼 조건을 체인의 계약에서 확인해 보세요.', 'X', '인증 실패처럼 더 진행할 이유가 없는 요청은 [[중단 조건]]에 따라 즉시 끝낼 수 있다.\n인증 성공 시에만 다음 처리자를 호출하도록 [[전파 정책]]을 정하는 것이 이 체인의 구현 계약이다.\n모든 처리자를 반드시 실행하는 것이 책임 연쇄의 올바름을 보장하지는 않는다.', 'AuthHandler가 위조 토큰을 발견하면 401 응답을 반환하고 next를 호출하지 않는다. 인증을 통과한 요청만 RateLimitHandler와 ValidationHandler로 보내 불필요한 검사와 부작용을 막는다.', '책임 연쇄는 모든 처리자의 실행을 보장하는 구조가 아니다. 이 체인에서는 인증 실패가 명시된 종료 조건이므로 뒤의 요청 제한과 입력 검증을 건너뛰는 동작이 계약에 맞다.', 16, 2, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '웹 미들웨어가 요청을 허용했지만 다음 단계를 호출하지 않으면 어떤 현상이 생길 수 있는가?', 1, 1, 'MEDIUM', '응답을 끝내지도 않고 다음으로 넘기지도 않으면 [[전파 누락]]으로 요청 처리가 멈추거나 시간 초과가 날 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '각 단계는 거부 응답을 완성하거나 다음 단계를 호출하는 경로 중 하나를 분명히 선택해야 한다. 비동기 처리에서는 반환과 예외 전달까지 일관되게 이어야 한다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '테스트 기준', 'TEXT', '허용, 거부, 예외 경로마다 최종 [[응답 완료]] 또는 다음 처리자 호출 중 기대한 결과가 발생하는지 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '전파 누락', '요청을 끝내거나 다음 단계로 넘겨야 하는 경로가 빠진 상태');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '응답 완료', '요청에 대한 결과나 오류가 호출자에게 최종적으로 전달된 상태');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '인증 실패 단락', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '전파 계약', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '보안 처리 순서', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전파 정책', '처리한 요청을 다음 처리자에게 계속 보낼지 멈출지 정한 규칙');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '중단 조건', '더 이상 다음 처리자를 호출하지 않고 흐름을 끝내는 조건');

-- STEP 16 / SLOT 3
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', 'API 요청에 인증, 요청 횟수 제한, 입력 검증을 순서대로 적용한다. 어느 단계든 실패하면 즉시 오류 응답을 보내고, 통과하면 다음 단계로 넘겨야 한다. 가장 적절한 설계는 무엇인가?', NULL, '각 단계가 자신의 조건만 검사하고 성공과 실패에 따라 다음 흐름을 선택할 수 있는지 살펴보세요.', NULL, '각 [[미들웨어]]는 한 가지 검사 책임을 맡고 성공 시 다음 단계로 요청을 넘길 수 있다.\n보안과 비용에 영향을 주는 [[처리 순서]]는 체인을 조립할 때 명시해야 한다.\n실패 시 즉시 끝내는 규칙과 예외 전달 방식도 모든 단계가 공유하는 계약이어야 한다.', 'auth.handle(request, next)가 인증 성공 때만 next()를 호출하고 실패하면 401 응답을 반환하도록 구성할 수 있다.', '검사 순서를 무작위로 바꾸거나 실패 뒤에도 업무 로직을 실행하면 보안과 자원 사용이 달라진다. 한 메서드에 모든 검사를 붙이면 단계 교체와 개별 테스트도 어려워진다.', 16, 3, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '각 검사를 독립 처리자로 만들고 정해진 순서로 연결해 실패 시 멈추고 성공 시 다음을 호출한다', 1, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '검사 순서를 요청마다 무작위로 섞고 어느 단계가 실패해도 업무 로직까지 실행한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '컨트롤러 한 메서드에 모든 검사와 응답 코드를 복사하고 다른 API에도 반복한다', 0, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '첫 검사 결과만 기록하고 나머지 검사는 실행하지 않은 채 항상 성공으로 처리한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '인증과 인가 처리자의 순서가 바뀌면 왜 문제가 될 수 있는가?', 1, 1, 'HARD', '사용자 신원을 확인하는 [[인증]]이 먼저 끝나야 그 사용자의 권한을 판단하는 [[인가]]가 의미 있는 입력을 받을 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '신원이 정해지기 전에 권한 검사를 수행하면 익명 사용자를 잘못 처리하거나 불필요한 내부 정보를 드러낼 수 있다. 체인은 처리자 집합뿐 아니라 순서도 설계의 일부다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '테스트 기준', 'TEXT', '인증 정보가 없거나 잘못된 요청에서 뒤의 인가와 업무 처리자가 호출되지 않는지 확인한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '인증', '요청을 보낸 주체가 누구인지 확인하는 과정');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '인가', '확인된 주체가 특정 동작을 수행할 권한이 있는지 판단하는 과정');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '미들웨어 체인', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '단락 응답', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '보안 처리 순서', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '미들웨어', '요청과 최종 업무 처리 사이에서 공통 검사나 변환을 수행하는 구성 요소');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '처리 순서', '연결된 처리자들이 요청을 받는 앞뒤 관계');

-- STEP 16 / SLOT 4
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '고객 지원 요청을 일반 상담, 결제 전문, 보안 사고 처리자에게 차례로 보낸다. 어느 처리자도 맡을 수 없는 요청이 조용히 사라지는 문제가 생겼다. 가장 적절한 개선은 무엇인가?', NULL, '사슬 끝까지 담당자를 찾지 못한 경우 호출자에게 어떤 결과를 보장해야 하는지 생각해 보세요.', NULL, '책임 연쇄에서는 아무도 맡지 않은 [[미처리 요청]]이 생길 수 있다.\n사슬 끝에 오류·기본 처리·별도 큐 전송 중 하나의 명시적인 [[폴백]]을 둬야 한다.\n요청을 무시하는 정책이라도 관측과 감사 요구를 검토한 뒤 의도적으로 선택해야 한다.', '마지막 UnhandledTicketHandler가 담당 불가 결과를 반환하고 요청 ID와 분류 정보를 별도 검토 큐에 기록하도록 만들 수 있다.', '첫 처리자에게 모든 책임을 몰거나 요청을 무조건 성공 처리하면 전문 처리자의 장점과 오류 가시성을 잃는다. 순서를 무작위로 바꾸는 것도 사슬 끝의 미처리 계약을 해결하지 못한다.', 16, 4, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '처리자가 없으면 성공 응답만 보내고 요청 내용과 결과를 버린다', 0, 1);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '첫 처리자가 모든 종류의 요청을 강제로 처리하도록 전문 처리자를 제거한다', 0, 2);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '사슬 끝에 담당 불가 오류나 별도 검토 큐 전송 같은 명시적 기본 처리를 둔다', 1, 3);
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order)
VALUES (@design_pattern_quiz_id, '요청마다 처리자 순서를 무작위로 섞어 언젠가 처리되기를 기대한다', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '처리자 연결이 실수로 원형이 되면 무엇이 필요할 수 있는가?', 1, 1, 'HARD', '같은 요청이 끝없이 돌지 않도록 조립 시 [[순환 체인]]을 금지하거나 방문 횟수 제한으로 [[종료 보장]]을 둬야 한다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', 'A가 B를, B가 다시 A를 다음 처리자로 가리키면 아무도 처리하지 않는 요청이 계속 전달될 수 있다. 일반적인 선형 체인이라면 구성 시점에 순환을 검출하는 편이 단순하다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '운영 영향', 'TEXT', '무한 전달은 스택, CPU, 로그를 소모하고 실제 장애 원인을 가릴 수 있으므로 최대 전달 횟수와 추적 ID도 도움이 된다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '순환 체인', '다음 처리자 연결을 따라가면 이전 처리자로 다시 돌아오는 잘못된 연결');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '종료 보장', '모든 요청 처리 흐름이 유한한 단계 안에 끝나도록 하는 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '미처리 요청', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '기본 처리자', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '관측 가능성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '미처리 요청', '체인의 어느 처리자도 책임지지 않은 요청');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '폴백', '주 처리 경로가 결과를 만들지 못했을 때 적용하는 명시적인 기본 처리');

-- STEP 16 / SLOT 5
INSERT INTO quiz (type, difficulty, question_text, code_snippet, hint, correct_answer, explanation_summary, explanation_example, wrong_answer_explanation, step_order, slot_order, quiz_step_id, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '요청 제한 처리자는 한도를 넘으면 즉시 응답하고, 입력 검증 처리자는 성공하면 업무 처리자로 넘긴다. 이처럼 각 단계가 처리 뒤 다음 단계로 계속 보낼지 끝낼지를 정하는 규칙은 ___이다.', NULL, '요청이 어디까지 이동하고 어느 조건에서 멈추는지를 모든 단계가 공유해야 하는 규칙을 떠올려 보세요.', NULL, '[[전파 정책]]은 처리 뒤 요청을 다음 대상으로 넘길지 멈출지 정한다.\n이 정책은 패턴 이름만으로 결정되지 않는 명시적인 [[구현 계약]]이다.\n성공·거부·예외·미처리 경로마다 최종 결과와 다음 호출 여부를 정의해야 한다.', 'HandlerResult에 CONTINUE, HANDLED, FAILED를 두고 체인 실행기가 결과에 따라 다음 호출 또는 종료를 결정할 수 있다.', '처리자 목록만 정하면 요청의 이동 방식까지 자동으로 정해지는 것은 아니다. 한 처리자가 성공한 뒤에도 감사 단계를 실행할지 즉시 끝낼지는 시스템 요구에 따라 달라진다.', 16, 5, @design_pattern_quiz_step_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @design_pattern_quiz_id = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword)
VALUES (@design_pattern_quiz_id, 1, '전파 정책');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
VALUES (@design_pattern_quiz_id, '모든 단계를 반드시 한 번씩 실행해야 하는 처리에서도 책임 연쇄가 항상 가장 적절한가?', 1, 1, 'HARD', '모든 단계 실행과 고정 순서가 핵심이면 선택적으로 넘기는 연쇄보다 명시적인 [[파이프라인]]이 그 [[보장]]을 더 잘 드러낼 수 있다.');
SET @design_pattern_follow_up_id = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '해설', 'TEXT', '책임 연쇄는 누가 처리할지 유연하게 찾거나 중간에 끝내는 상황에 잘 맞는다. 모든 변환 단계를 반드시 거쳐야 한다면 실행기가 전체 단계를 순서대로 호출하는 구조가 읽기 쉽다.', 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order)
VALUES (@design_pattern_follow_up_id, '판단 기준', 'TEXT', '처리자 중 하나를 찾는 흐름인지, 여러 단계가 결과를 차례로 가공하는 흐름인지 먼저 구분한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '파이프라인', '정해진 여러 처리 단계를 순서대로 통과하며 결과를 만드는 구조');
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
VALUES (@design_pattern_follow_up_id, '보장', '구현이 모든 정상·실패 경로에서 지키기로 한 동작 조건');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '전파 정책', 1);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '구현 계약', 2);
INSERT INTO quiz_derived_concept (quiz_id, name, display_order)
VALUES (@design_pattern_quiz_id, '책임 연쇄와 파이프라인', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '전파 정책', '처리 뒤 요청을 다음 처리자에게 넘길지 현재 단계에서 끝낼지 정한 규칙');
INSERT INTO quiz_keyword (quiz_id, keyword, description)
VALUES (@design_pattern_quiz_id, '구현 계약', '처리자와 체인 실행기가 성공·실패·전달 상황에서 지키기로 한 동작 약속');

DROP TEMPORARY TABLE design_pattern_seed_guard;

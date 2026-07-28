-- 디자인 패턴 커리큘럼 2스텝(10문제) — #26 생성 파이프라인으로 만들고 사람이 검수한 콘텐츠.
-- 로컬에서 생성 → 검수 → 이 마이그레이션으로 prod에 반영(팀 결정: 로컬 검수 후 SQL 이관 방식).
-- id는 전부 auto-increment로 새로 채번한다(로컬 id와 무관) — LAST_INSERT_ID()로 자식 테이블을 연결한다.
-- 이 파일은 로컬 DB의 실제 저장값에서 스크립트로 생성했다(수기 전사 아님) — 내용을 임의로 고치지 않는다.
-- 이 마이그레이션은 V20260728170100__add_course_to_quiz_step.sql보다 먼저 적용돼야 한다 —
-- 그 마이그레이션이 step_order 13 이상을 '디자인 패턴' 코스로 자동 배정하는 로직이 이 스텝들의 존재를 전제한다.

-- ===================== STEP 13: 생성 패턴 개요와 싱글턴(스레드 안전성 포함) =====================
INSERT INTO quiz_step (step_order, topic, estimated_minutes, created_at, updated_at)
VALUES (13, '생성 패턴 개요와 싱글턴(스레드 안전성 포함)', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- ===================== STEP 14: 팩토리 메서드와 추상 팩토리 =====================
INSERT INTO quiz_step (step_order, topic, estimated_minutes, created_at, updated_at)
VALUES (14, '팩토리 메서드와 추상 팩토리', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- Step13 Slot1 (OX) [local id=64]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '생성 패턴은 객체 생성 과정을 캡슐화하여, 어떤 구체 클래스의 인스턴스를 만들지 결정하는 책임을 분리하는 데 도움을 준다. 이 설명은 옳을까?', NULL, 'O',
        '생성 패턴은 객체를 어떻게 만들고 조합할지에 초점을 둔다.\n구체 클래스 선택과 생성 절차를 숨겨 [[캡슐화]]를 높이는 데 도움이 된다.\n따라서 제시된 설명은 참이다.', '예를 들어 클라이언트가 직접 new로 여러 구현체를 고르기보다 팩토리 메서드 같은 방식을 쓰면 생성 책임을 한곳에 모을 수 있다.', '이 문장을 거짓으로 판단했다면 생성 패턴의 목적을 구조 변경이나 알고리즘 교체와 혼동했을 가능성이 크다. 생성 패턴은 객체 생성 책임을 정리하고 의존 대상을 덜 노출해 변경 영향을 줄이는 데 쓰인다.',
        13, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '생성 패턴과 구조 패턴은 무엇이 가장 다를까?', 1, 1, 'MEDIUM', '생성 패턴은 [[인스턴스화]] 방식에, 구조 패턴은 객체와 클래스의 조합 방식에 더 직접적으로 초점을 둔다.'),
  (@qid, '생성 패턴을 쓰면 항상 코드가 더 단순해질까?', 0, 2, 'EASY', '아니며, [[추상화]] 계층이 늘어나면 작은 프로그램에서는 오히려 복잡해 보일 수 있다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '인스턴스화는 객체를 실제로 만들어 내는 과정이고, 구조 패턴은 이미 존재하는 객체나 클래스를 어떻게 연결해 더 큰 구조를 만들지 다룬다.', 1),
  (@fq, '비교', 'TEXT', '예를 들어 싱글턴, 팩토리 메서드, 추상 팩토리는 생성 패턴이고, 어댑터, 데코레이터, 퍼사드는 구조 패턴에 속한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '인스턴스화', '클래스로부터 실제 객체를 생성하는 과정');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '추상화는 변경 지점을 분리하는 장점이 있지만, 요구사항이 단순한 경우에는 클래스 수와 간접 호출이 늘어 과한 설계가 될 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '추상화', '핵심 개념만 드러내고 세부 구현을 감추는 것');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '팩토리 메서드', 1),
  (@qid, '추상 팩토리', 2),
  (@qid, '빌더', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '캡슐화', '데이터나 구현 세부를 외부에서 직접 보지 못하게 감추고 필요한 인터페이스만 제공하는 것');

-- Step13 Slot2 (OX) [local id=65]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '싱글턴 패턴에서 정적 필드에 인스턴스를 저장해 두었다고 해서, 멀티스레드 환경에서도 항상 자동으로 스레드 안전성이 보장되는 것은 아니다. 이 설명은 옳을까?', NULL, 'O',
        '정적 필드 하나만 둔다고 해서 [[스레드 안전성]]이 자동으로 생기지는 않는다.\n초기화 시점과 접근 방식에 따라 경쟁 상태가 생길 수 있다.\n따라서 제시된 설명은 참이다.', '지연 초기화된 싱글턴을 여러 스레드가 동시에 처음 호출하면, 적절한 동기화 없이 둘 이상의 객체가 만들어질 수 있다.', '이 문장을 거짓으로 판단했다면 정적 필드와 단일 인스턴스 개념만 보고 동시성 문제를 놓친 것이다. 멀티스레드에서는 생성 시점이 겹칠 수 있으므로 동기화 전략이나 언어 차원의 안전한 초기화 규칙을 확인해야 한다.',
        13, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '싱글턴의 스레드 안전성을 확보하는 대표적인 방법에는 무엇이 있을까?', 1, 1, 'MEDIUM', '대표적으로 eager initialization, synchronized 접근, double-checked locking, 그리고 [[정적 초기화]]에 의존하는 방식이 있다.'),
  (@qid, '싱글턴이 항상 좋은 선택은 아닌 이유는 무엇일까?', 0, 2, 'MEDIUM', '전역 상태처럼 사용되기 쉬워 [[결합도]]를 높이고 테스트를 어렵게 만들 수 있기 때문이다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '정적 초기화는 클래스 로딩 시점의 초기화 규칙을 활용해 비교적 단순하게 안전성을 얻는 방법이다.', 1),
  (@fq, '비교', 'TEXT', '항상 미리 만드는 방식은 단순하지만 불필요한 생성이 있을 수 있고, synchronized는 이해하기 쉽지만 호출 비용이 늘 수 있으며, double-checked locking은 구현을 더 주의해서 해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '정적 초기화', '클래스가 로드되거나 초기화될 때 정적 필드를 설정하는 방식');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '결합도는 한 모듈이 다른 모듈에 얼마나 강하게 의존하는지를 뜻하며, 싱글턴 남용은 숨은 의존성을 늘릴 수 있다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '결합도', '모듈 사이의 의존 정도');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '동기화', 1),
  (@qid, '지연 초기화', 2),
  (@qid, '클래스 로딩', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '스레드 안전성', '여러 스레드가 동시에 접근해도 올바르게 동작하는 성질');

-- Step13 Slot3 (MULTIPLE_CHOICE) [local id=66]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 생성 패턴에 해당하지 않는 것은 무엇인가?', NULL, NULL,
        '[[데코레이터]]는 객체에 기능을 동적으로 덧붙이는 구조 패턴이다.\n싱글턴, 빌더, 추상 팩토리는 대표적인 생성 패턴이다.\n따라서 정답은 데코레이터이다.', '예를 들어 빌더는 복잡한 객체를 단계적으로 만들고, 추상 팩토리는 관련 있는 객체군을 생성한다. 반면 데코레이터는 이미 있는 객체를 감싸 기능을 확장한다.', '오답을 골랐다면 생성 패턴과 구조 패턴의 구분을 다시 볼 필요가 있다. 생성 패턴은 객체를 만드는 방법을, 구조 패턴은 객체를 조합하고 확장하는 방법을 다룬다.',
        13, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '싱글턴', 0, 1),
  (@qid, '빌더', 0, 2),
  (@qid, '데코레이터', 1, 3),
  (@qid, '추상 팩토리', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '빌더 패턴은 어떤 상황에서 특히 유용할까?', 1, 1, 'MEDIUM', '생성자 매개변수가 많거나 선택 항목이 많아 객체 생성 절차를 분리해야 할 때 [[빌더]]가 특히 유용하다.'),
  (@qid, '데코레이터와 상속 기반 확장의 차이는 무엇일까?', 0, 2, 'HARD', '데코레이터는 [[합성]]을 이용해 실행 중에도 기능을 조합할 수 있다는 점이 상속보다 유연하다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '빌더는 복잡한 객체를 단계적으로 조립하게 해 주며, 생성자 오버로딩이 과도해지는 문제를 줄이는 데 도움이 된다.', 1),
  (@fq, '실무 사용처', 'TEXT', '설정 객체, HTTP 요청 객체, 불변 객체처럼 필드가 많고 조합이 다양한 경우에 자주 쓰인다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '빌더', '복잡한 객체 생성을 단계별로 구성하는 생성 패턴');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '합성은 객체 안에 다른 객체를 포함해 기능을 위임하는 방식이며, 상속보다 조합의 자유도가 높다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '합성', '객체를 포함하고 위임하여 기능을 재사용하는 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '구조 패턴', 1),
  (@qid, '객체 조합', 2),
  (@qid, '불변 객체', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '데코레이터', '기존 객체를 감싸 기능을 동적으로 추가하는 구조 패턴');

-- Step13 Slot4 (MULTIPLE_CHOICE) [local id=67]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 멀티스레드 환경에서 싱글턴의 지연 초기화 구현에 대해 가장 적절한 설명은 무엇인가?', 'class Singleton {\n    private static Singleton instance;\n\n    static Singleton getInstance() {\n        if (instance == null) {\n            instance = new Singleton();\n        }\n        return instance;\n    }\n}', NULL,
        '제시된 코드는 동기화가 없어 여러 스레드가 동시에 null 검사를 통과할 수 있다.\n그 결과 둘 이상의 인스턴스가 생성되는 [[경쟁 상태]]가 발생할 수 있다.\n따라서 스레드 안전한 구현이라고 볼 수 없다.', '예를 들어 스레드 A와 B가 거의 동시에 getInstance를 호출하면 둘 다 instance가 null이라고 보고 각각 new Singleton()을 실행할 수 있다.', '스레드 안전하다고 답했다면 null 검사 한 번만으로 충분하다고 본 것이다. 하지만 멀티스레드에서는 검사와 생성 사이가 원자적으로 묶여 있지 않으면 경쟁 상태가 생긴다.',
        13, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, 'null 검사가 있으므로 항상 스레드 안전하다.', 0, 1),
  (@qid, '동기화가 없으므로 동시에 호출되면 둘 이상의 인스턴스가 생성될 수 있다.', 1, 2),
  (@qid, '정적 메서드이므로 JVM이 자동으로 한 스레드만 실행하게 만든다.', 0, 3),
  (@qid, '생성자가 private이면 멀티스레드 문제는 자동으로 해결된다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, 'double-checked locking은 왜 단순한 if 검사보다 더 복잡하게 보일까?', 1, 1, 'HARD', '검사 횟수를 줄이면서도 안전한 초기화를 노리기 때문에 [[메모리 가시성]] 같은 동시성 규칙까지 고려해야 하기 때문이다.'),
  (@qid, 'private 생성자는 무엇을 보장하고 무엇은 보장하지 않을까?', 0, 2, 'MEDIUM', 'private 생성자는 외부 직접 생성을 막지만, [[동시성]] 문제 해결까지 보장하지는 않는다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '메모리 가시성은 한 스레드의 쓰기 결과가 다른 스레드에 언제 보이는지에 관한 성질이며, 이를 보장하지 않으면 부분적으로 초기화된 객체를 관찰하는 문제가 생길 수 있다.', 1),
  (@fq, '흔한 오해', 'TEXT', 'if를 두 번 검사한다고 해서 자동으로 안전해지는 것은 아니며, 언어와 메모리 모델이 요구하는 조건을 함께 만족해야 한다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '메모리 가시성', '한 스레드의 메모리 변경이 다른 스레드에서 관측되는 성질');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '동시성은 여러 실행 흐름이 동시에 자원에 접근하는 상황을 다루며, 생성자 접근 제한과는 별개의 문제다.', 1);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '동시성', '여러 작업이 겹쳐 실행되며 자원을 공유할 수 있는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, 'double-checked locking', 1),
  (@qid, 'volatile', 2),
  (@qid, '원자성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '경쟁 상태', '여러 실행 흐름의 접근 순서에 따라 결과가 달라지는 문제');

-- Step13 Slot5 (KEYWORD_BLANK) [local id=68]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '싱글턴의 지연 초기화에서 성능과 안전성을 함께 고려할 때 자주 언급되는 기법은 ___이며, 올바른 구현에서는 메모리 재배치와 가시성 문제를 함께 고려해야 한다.', NULL, NULL,
        '빈칸의 정답은 [[double-checked locking]]이다.\n이 기법은 불필요한 동기화 비용을 줄이려는 목적에서 사용된다.\n다만 올바른 동시성 보장 조건을 함께 만족해야 안전하다.', '예를 들어 첫 번째 검사에서 이미 생성된 인스턴스를 빠르게 반환하고, 아직 없을 때만 동기화 구역에 들어가 다시 검사하는 방식이 널리 알려져 있다.', '다른 용어를 넣었다면 지연 초기화와 성능 최적화를 함께 다루는 대표 기법을 혼동한 것이다. 단순 synchronized 방식은 가능하지만, 문제에서 묻는 것은 검사 두 번으로 불필요한 잠금 진입을 줄이려는 기법이다.',
        13, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, 'double-checked locking');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, 'double-checked locking이 모든 언어에서 같은 방식으로 안전하다고 말할 수 있을까?', 1, 1, 'HARD', '아니며, 언어의 [[메모리 모델]]과 초기화 규칙에 따라 안전한 구현 조건이 달라질 수 있다.'),
  (@qid, '싱글턴 대신 의존성 주입을 쓰는 것이 더 나은 경우는 언제일까?', 0, 2, 'MEDIUM', '전역 접근보다 [[의존성 주입]]으로 생성과 사용을 분리해야 테스트와 교체가 쉬운 경우가 많다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '메모리 모델은 읽기·쓰기의 순서와 가시성에 대한 규칙을 정의하므로, 같은 형태의 코드라도 언어마다 안전성 판단 기준이 다를 수 있다.', 1),
  (@fq, '비교', 'TEXT', '어떤 환경에서는 클래스 초기화 규칙을 활용한 방식이 더 단순하고 안전하게 권장되며, 어떤 환경에서는 명시적 동기화나 언어 제공 기능을 쓰는 편이 낫다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '메모리 모델', '프로그램의 메모리 읽기·쓰기 순서와 가시성 규칙을 정의하는 모델');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 2);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '의존성 주입은 필요한 객체를 외부에서 전달받게 해 결합을 낮추고, 모의 객체로 대체하기 쉽게 만든다.', 1),
  (@fq, '실무 사용처', 'TEXT', '서비스 객체, 저장소, 로거처럼 구현 교체나 테스트 격리가 중요한 구성요소에서 특히 유용하다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '의존성 주입', '객체가 필요한 의존 객체를 스스로 만들지 않고 외부에서 전달받는 설계 방식');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '지연 초기화', 1),
  (@qid, '성능 최적화', 2),
  (@qid, '메모리 재배치', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, 'double-checked locking', '지연 초기화된 싱글턴에서 동기화 비용을 줄이기 위해 두 번 검사하는 기법');

-- Step14 Slot1 (OX) [local id=69]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '팩토리 메서드 패턴은 객체 생성을 위한 인터페이스를 정의하고, 어떤 구체 클래스를 생성할지는 서브클래스가 결정하도록 위임하는 패턴이다.', NULL, 'O',
        '[[팩토리 메서드]]는 생성 책임을 상위 타입에서 선언하고 하위 타입이 구체 생성을 정하게 한다.\n이 패턴은 클라이언트가 [[구체 클래스]]에 직접 의존하는 정도를 줄이는 데 도움이 된다.\n생성 로직을 확장할 때 기존 사용 코드를 덜 바꾸게 해 준다.', '예를 들어 대화상자 프레임워크에서 버튼 생성 메서드를 상위 클래스가 선언하고, WindowsDialog는 WindowsButton을, WebDialog는 HTMLButton을 반환하도록 만들 수 있다.', '틀렸다면 팩토리 메서드를 단순한 정적 생성 함수로만 이해했을 가능성이 크다. 핵심은 생성 메서드의 선언과 실제 생성 결정을 분리해 서브클래스가 어떤 제품을 만들지 선택하게 하는 점이다.',
        14, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '팩토리 메서드가 템플릿 메서드와 함께 자주 설명되는 이유는 무엇인가?', 1, 1, 'MEDIUM', '상위 클래스가 작업의 큰 흐름을 정의하고, 그 흐름 중 객체 생성 지점을 [[훅]]처럼 서브클래스에 맡길 수 있기 때문이다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '템플릿 메서드는 알고리즘의 골격을 상위 클래스에 두고 일부 단계를 하위 클래스가 바꾸게 한다. 이때 생성 단계가 팩토리 메서드가 되면 생성 대상만 바꾸면서 전체 흐름은 유지할 수 있다.', 1),
  (@fq, '비교', 'TEXT', '[[템플릿 메서드]]는 절차의 구조를 재사용하는 데 초점이 있고, 팩토리 메서드는 생성 책임의 분리에 초점이 있다. 둘은 서로 대체 관계라기보다 함께 쓰이기 쉽다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '훅', '상위 알고리즘의 특정 지점을 하위 클래스가 재정의하도록 열어 둔 확장 지점'),
  (@fq, '템플릿 메서드', '상위 클래스가 알고리즘의 골격을 정의하고 일부 단계를 하위 클래스가 구현하게 하는 패턴');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '템플릿 메서드', 1),
  (@qid, '의존성 역전', 2),
  (@qid, '다형성 기반 확장', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '팩토리 메서드', '객체 생성 인터페이스를 정의하고 구체 생성은 서브클래스가 결정하게 하는 생성 패턴'),
  (@qid, '구체 클래스', '인터페이스나 추상 클래스가 아닌 실제 인스턴스화 가능한 구현 클래스');

-- Step14 Slot2 (OX) [local id=70]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('OX', 'EASY', '추상 팩토리 패턴은 서로 관련되거나 함께 사용되는 객체들의 집합을 생성하기 위한 인터페이스를 제공하며, 클라이언트는 개별 제품의 구체 클래스를 몰라도 된다.', NULL, 'O',
        '[[추상 팩토리]]는 관련된 제품군을 일관된 방식으로 생성하게 해 준다.\n클라이언트는 제품 생성 인터페이스에 의존하므로 [[제품군]]의 구체 구현을 직접 알 필요가 없다.\n같은 테마나 플랫폼에 맞는 객체 조합을 바꿔 끼우기 쉽다.', '예를 들어 GUI 라이브러리에서 Mac용 버튼과 체크박스, Windows용 버튼과 체크박스를 각각 하나의 팩토리로 묶어 제공하면 같은 플랫폼끼리 호환되는 위젯을 함께 만들 수 있다.', '틀렸다면 추상 팩토리를 단일 객체만 만드는 패턴으로 오해했을 수 있다. 이 패턴의 핵심은 관련 있는 여러 객체를 한 묶음으로 생성해 조합의 일관성을 유지하는 데 있다.',
        14, 2, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '추상 팩토리에서 새 제품 종류를 추가하는 것과 새 제품군을 추가하는 것 중 무엇이 더 어려운가?', 1, 1, 'MEDIUM', '보통 새 [[제품 종류]]를 추가하는 쪽이 더 어렵다, 모든 팩토리 인터페이스와 구현체를 함께 수정해야 하기 때문이다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '새 제품군을 추가할 때는 기존 인터페이스를 구현하는 새 팩토리 하나와 그에 대응하는 제품 구현들을 추가하면 되는 경우가 많다. 반면 새 제품 종류를 넣으면 추상 팩토리 인터페이스에 생성 메서드를 추가하고 기존 모든 구체 팩토리를 수정해야 한다.', 1),
  (@fq, '흔한 오해', 'TEXT', '[[구체 팩토리]]를 하나 더 만드는 일은 비교적 국소적 변경이지만, 제품 종류 추가는 인터페이스 자체의 변경이라 파급 범위가 커진다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '제품 종류', '버튼, 체크박스처럼 제품군 안에서 구분되는 개별 제품 카테고리'),
  (@fq, '구체 팩토리', '추상 팩토리 인터페이스를 구현하여 실제 제품 객체들을 생성하는 클래스');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '제품군 일관성', 1),
  (@qid, '인터페이스 기반 설계', 2),
  (@qid, '플랫폼 독립적 생성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '추상 팩토리', '관련된 객체들의 집합을 생성하는 인터페이스를 제공하는 생성 패턴'),
  (@qid, '제품군', '서로 관련되어 함께 사용되는 제품 객체들의 묶음');

-- Step14 Slot3 (MULTIPLE_CHOICE) [local id=71]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 중 팩토리 메서드와 추상 팩토리의 차이를 가장 정확히 설명한 것은 무엇인가?', NULL, NULL,
        '[[팩토리 메서드]]는 보통 하나의 생성 지점을 서브클래싱으로 확장하는 데 초점이 있다.\n[[추상 팩토리]]는 관련된 여러 제품을 조합으로 생성하는 인터페이스를 제공한다.\n둘 다 생성 캡슐화를 다루지만 확장 방식과 적용 범위가 다르다.', '예를 들어 문서 편집기에서 개별 문서 객체 생성만 바꾸려면 팩토리 메서드가 적합할 수 있고, 운영체제별 버튼·메뉴·스크롤바를 함께 바꾸려면 추상 팩토리가 더 잘 맞는다.', '오답을 골랐다면 두 패턴을 모두 단순히 객체 생성 숨기기로만 본 경우가 많다. 실제로는 팩토리 메서드는 상속을 통한 단일 생성 지점의 변형에, 추상 팩토리는 관련 객체 집합의 일관된 생성에 더 가깝다.',
        14, 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '팩토리 메서드는 보통 서브클래스가 생성할 구체 제품을 정하고, 추상 팩토리는 관련된 여러 제품을 생성하는 인터페이스를 제공한다.', 1, 1),
  (@qid, '팩토리 메서드는 항상 여러 제품군을 동시에 생성하고, 추상 팩토리는 항상 단일 객체만 생성한다.', 0, 2),
  (@qid, '팩토리 메서드는 상속을 사용할 수 없고, 추상 팩토리는 반드시 상속만 사용해야 한다.', 0, 3),
  (@qid, '두 패턴은 이름만 다를 뿐 구조와 목적이 완전히 동일하다.', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '추상 팩토리를 구현할 때 내부적으로 팩토리 메서드를 함께 사용할 수 있는가?', 1, 1, 'MEDIUM', '가능하다, [[추상 팩토리]]의 각 생성 연산을 구체 팩토리 내부의 [[팩토리 메서드]] 형태로 구현할 수 있다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '패턴은 배타적이지 않다. 추상 팩토리는 외부에 제품군 생성 인터페이스를 제공하고, 각 구체 팩토리는 개별 제품 생성 로직을 별도 메서드로 나누어 관리할 수 있다.', 1),
  (@fq, '실무 사용처', 'TEXT', 'UI 툴킷이나 데이터 저장소 드라이버 계층처럼 제품군은 유지하되 제품별 생성 절차가 복잡한 경우 이런 조합이 자연스럽다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '추상 팩토리', '관련된 객체 집합을 생성하는 인터페이스를 제공하는 패턴'),
  (@fq, '팩토리 메서드', '구체 생성 결정을 하위 구현에 맡기는 생성 메서드 패턴');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '상속 대 합성', 1),
  (@qid, '생성 책임 분리', 2),
  (@qid, '패턴 조합', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '팩토리 메서드', '서브클래스가 구체 생성 대상을 결정하도록 하는 생성 패턴'),
  (@qid, '추상 팩토리', '관련된 여러 제품을 생성하는 인터페이스를 제공하는 생성 패턴');

-- Step14 Slot4 (MULTIPLE_CHOICE) [local id=72]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('MULTIPLE_CHOICE', 'MEDIUM', '다음 상황에 가장 적합한 패턴을 고르시오. 애플리케이션이 Windows 테마와 macOS 테마를 지원해야 하며, 각 테마마다 버튼·체크박스·스크롤바가 서로 일관된 모양과 동작을 가져야 한다.', NULL, NULL,
        '이 상황의 핵심은 관련된 위젯들을 한 번에 같은 계열로 맞추는 [[일관성]]이다.\n서로 연관된 여러 객체를 묶어 생성해야 하므로 [[추상 팩토리]]가 적합하다.\n개별 위젯 하나만 바꾸는 문제가 아니라 제품군 전체를 교체하는 문제다.', 'WindowsWidgetFactory는 WindowsButton, WindowsCheckbox, WindowsScrollbar를 만들고, MacWidgetFactory는 대응되는 Mac 제품들을 만든다. 클라이언트는 현재 팩토리만 바꾸면 전체 테마를 교체할 수 있다.', '팩토리 메서드를 선택했다면 개별 생성 지점의 확장과 제품군 전체의 교체를 구분하지 못했을 수 있다. 여기서는 버튼만이 아니라 체크박스와 스크롤바까지 같은 계열로 맞춰야 하므로 제품군 단위 생성이 중요하다.',
        14, 4, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_choice (quiz_id, content, is_correct, display_order) VALUES
  (@qid, '싱글턴', 0, 1),
  (@qid, '빌더', 0, 2),
  (@qid, '추상 팩토리', 1, 3),
  (@qid, '프로토타입', 0, 4);
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '이 상황에서 추상 팩토리를 쓰면 클라이언트 코드의 어떤 의존성이 줄어드는가?', 1, 1, 'EASY', '클라이언트는 개별 위젯의 [[구체 클래스]] 대신 팩토리와 제품 [[인터페이스]]에 주로 의존하게 된다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '버튼, 체크박스, 스크롤바를 직접 new 하지 않고 팩토리 메서드를 통해 받으면 운영체제별 구현 이름을 코드 곳곳에 적지 않아도 된다. 그래서 테마 변경 시 수정 범위가 줄어든다.', 1),
  (@fq, '비교', 'TEXT', '직접 생성 방식은 플랫폼별 클래스 이름이 클라이언트에 퍼지기 쉽고, 추상 팩토리 방식은 생성 지식을 팩토리 계층으로 모은다.', 2);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '구체 클래스', '실제로 인스턴스화되는 구체 구현 클래스'),
  (@fq, '인터페이스', '클라이언트가 의존하는 추상적 계약');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '제품군 교체', 1),
  (@qid, '테마 시스템 설계', 2),
  (@qid, '의존성 감소', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '일관성', '함께 사용되는 객체들이 같은 규칙과 계열을 유지하는 성질'),
  (@qid, '추상 팩토리', '관련 객체 집합을 생성하는 인터페이스를 제공하는 패턴');

-- Step14 Slot5 (KEYWORD_BLANK) [local id=73]
INSERT INTO quiz (type, difficulty, question_text, code_snippet, correct_answer,
                   explanation_summary, explanation_example, wrong_answer_explanation,
                   step_order, slot_order, created_at, updated_at)
VALUES ('KEYWORD_BLANK', 'HARD', '팩토리 메서드는 생성할 객체의 실제 타입 결정을 서브클래스에 맡기는 반면, 추상 팩토리는 서로 관련된 여러 객체를 하나의 ___ 단위로 생성하는 데 초점을 둔다.', NULL, NULL,
        '팩토리 메서드와 추상 팩토리의 큰 차이는 생성 범위에 있다.\n추상 팩토리는 관련 객체들을 [[제품군]]으로 묶어 일관되게 생성한다.\n따라서 여러 객체 사이의 호환성과 조합을 유지해야 할 때 유리하다.', '예를 들어 데이터베이스 접근 계층에서 MySQL용 연결 객체와 명령 객체, PostgreSQL용 연결 객체와 명령 객체를 각각 한 세트로 제공하는 경우를 생각할 수 있다.', '빈칸을 단일 객체나 클래스라고 적었다면 추상 팩토리의 초점을 너무 좁게 본 것이다. 추상 팩토리는 관련된 여러 제품을 함께 다루며, 핵심은 같은 계열의 객체 묶음을 일관되게 만드는 데 있다.',
        14, 5, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_answer_keyword (quiz_id, slot_order, keyword) VALUES
  (@qid, 1, '제품군');
INSERT INTO quiz_follow_up_question (quiz_id, content, is_primary, display_order, difficulty, one_line_answer) VALUES
  (@qid, '추상 팩토리에서 제품군 내부의 객체들이 서로 호환된다는 보장은 왜 중요한가?', 1, 1, 'HARD', '같은 [[제품군]] 안의 객체들이 함께 동작하도록 설계되어야 조합 오류를 줄이고 [[호환성]]을 유지할 수 있기 때문이다.');
SET @fq = (SELECT id FROM quiz_follow_up_question WHERE quiz_id = @qid AND display_order = 1);
INSERT INTO quiz_follow_up_block (follow_up_question_id, label, type, content, display_order) VALUES
  (@fq, '해설', 'TEXT', '버튼은 Windows 스타일인데 스크롤바는 macOS 스타일인 식의 혼합은 시각적 문제뿐 아니라 동작 규약 차이도 만들 수 있다. 추상 팩토리는 같은 계열의 객체를 함께 제공해 이런 불일치를 줄인다.', 1),
  (@fq, '실무 사용처', 'TEXT', '플러그인 시스템, 데이터베이스 드라이버 계층, 크로스플랫폼 UI처럼 여러 구현 계열이 공존하는 환경에서 특히 중요하다.', 2),
  (@fq, '흔한 오해', 'TEXT', '추상 팩토리는 단지 생성 코드를 숨기는 도구가 아니라, 관련 객체들의 조합 규칙을 한곳에 모아 관리하는 설계 수단이기도 하다.', 3);
INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description) VALUES
  (@fq, '제품군', '서로 관련되어 함께 사용되는 객체들의 묶음'),
  (@fq, '호환성', '함께 사용되는 구성요소들이 충돌 없이 맞물려 동작하는 성질');
INSERT INTO quiz_derived_concept (quiz_id, name, display_order) VALUES
  (@qid, '객체 조합 규칙', 1),
  (@qid, '패턴 선택 기준', 2),
  (@qid, '관련 객체 집합 생성', 3);
INSERT INTO quiz_keyword (quiz_id, keyword, description) VALUES
  (@qid, '제품군', '서로 관련된 여러 제품 객체의 묶음');

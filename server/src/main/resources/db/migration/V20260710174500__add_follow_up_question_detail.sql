-- 꼬리질문 화면(S4 곁가지)이 그리는 콘텐츠를 꼬리질문 자신이 갖는다.
-- 꼬리질문은 "이어서 풀 문제"로 라우팅되지 않는다 — 풀이·채점 없는 읽기 전용 설명 화면이다(#108).
-- 기존 120건에는 상세가 없으므로 두 컬럼은 NULL을 허용한다. 값 채우기는 생성 파이프라인(#26)의 몫이다.
ALTER TABLE quiz_follow_up_question
    ADD COLUMN difficulty      VARCHAR(10) NULL,
    ADD COLUMN one_line_answer VARCHAR(500) NULL;

-- 두 컬럼은 "상세가 있으면 함께, 없으면 함께 없다"가 불변식이다(hasDetail()이 이걸 전제한다).
-- 애플리케이션의 attachDetail()은 이를 지키지만, 생성 파이프라인(#26)이 raw SQL로 백필할 때
-- 한쪽만 채우면 상세가 있다고 판정된 꼬리질문의 난이도가 null로 내려간다. DB에서 막는다.
ALTER TABLE quiz_follow_up_question
    ADD CONSTRAINT ck_quiz_follow_up_question_detail
        CHECK ((difficulty IS NULL) = (one_line_answer IS NULL));

-- "상세 정리" — 항목 수와 라벨이 꼬리질문마다 달라 고정 컬럼이 아닌 순서 있는 블록 배열로 둔다.
CREATE TABLE quiz_follow_up_block
(
    id                    BIGINT      NOT NULL AUTO_INCREMENT,
    follow_up_question_id BIGINT      NOT NULL,
    label                 VARCHAR(50) NOT NULL,
    type                  VARCHAR(20) NOT NULL,
    content               TEXT        NOT NULL,
    display_order         INT         NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_follow_up_block_question
        FOREIGN KEY (follow_up_question_id) REFERENCES quiz_follow_up_question (id) ON DELETE CASCADE
);

-- 꼬리질문 전용 키워드 툴팁 사전. quiz_keyword(부모 문제 사전)와 분리하는 이유는
-- 꼬리질문이 부모 문제에 없던 개념을 끌어오기 때문이다(예: 스택 문제의 꼬리질문에 등장하는 FIFO).
CREATE TABLE quiz_follow_up_keyword
(
    id                    BIGINT        NOT NULL AUTO_INCREMENT,
    follow_up_question_id BIGINT        NOT NULL,
    keyword               VARCHAR(200)  NOT NULL,
    description           VARCHAR(1000) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quiz_follow_up_keyword_question
        FOREIGN KEY (follow_up_question_id) REFERENCES quiz_follow_up_question (id) ON DELETE CASCADE
);

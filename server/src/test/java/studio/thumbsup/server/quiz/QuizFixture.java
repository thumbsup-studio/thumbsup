package studio.thumbsup.server.quiz;

import java.util.List;

/** 퀴즈 테스트 픽스처 — feature 소유. 영속화 전 완전한 aggregate를 만들어 반환한다. */
public final class QuizFixture {

    public static Quiz oxQuiz() {
        Quiz quiz = Quiz.create(
                QuizType.OX,
                QuizDifficulty.EASY,
                "TCP는 연결 지향 프로토콜이다.",
                null,
                "TCP는 3-way handshake로 연결을 맺는 연결 지향 프로토콜이다.",
                null,
                "UDP와 헷갈리기 쉽다 — UDP는 비연결형이라 handshake가 없다.");
        quiz.assignCorrectAnswer("O");
        quiz.addFollowUpQuestion("UDP와 TCP의 핵심 차이는 무엇인가요?", true, 1);
        quiz.addDerivedConcept("3-way handshake", 1);
        quiz.addKeyword("연결 지향", "통신 전에 연결을 먼저 수립하는 방식");
        return quiz;
    }

    public static Quiz oxQuiz2() {
        Quiz quiz = Quiz.create(
                QuizType.OX,
                QuizDifficulty.EASY,
                "UDP는 신뢰성을 보장한다.",
                null,
                "UDP는 신뢰성을 보장하지 않는 비연결형 프로토콜이다.",
                null,
                "TCP와 헷갈리기 쉽다 — 신뢰성 보장은 TCP의 특징이다.");
        quiz.assignCorrectAnswer("X");
        quiz.addFollowUpQuestion("UDP는 어떤 상황에 적합한가요?", true, 1);
        quiz.addDerivedConcept("비연결형 프로토콜", 1);
        quiz.addKeyword("신뢰성", "데이터 전달을 보장하는 성질");
        return quiz;
    }

    public static Quiz multipleChoiceQuiz() {
        Quiz quiz = Quiz.create(
                QuizType.MULTIPLE_CHOICE,
                QuizDifficulty.MEDIUM,
                "다음 코드의 시간복잡도는?",
                "for (int i = 0; i < n; i++) { for (int j = 0; j < n; j++) { ... } }",
                "이중 반복문이 각각 n번 실행되므로 O(n^2)이다.",
                "정렬되지 않은 배열에서 버블 정렬이 이 패턴의 대표적인 예시다.",
                "O(n)으로 착각하기 쉽다 — 바깥 반복문만 보고 안쪽 반복문을 놓치지 않도록 주의.");
        quiz.addChoice("O(n)", false, 1);
        quiz.addChoice("O(n log n)", false, 2);
        quiz.addChoice("O(n^2)", true, 3);
        quiz.addChoice("O(2^n)", false, 4);
        quiz.addFollowUpQuestion("이중 반복문을 O(n log n)으로 개선하려면?", true, 1);
        quiz.addDerivedConcept("빅오 표기법", 1);
        quiz.addKeyword("시간복잡도", "입력 크기에 따라 연산 횟수가 증가하는 정도");
        return quiz;
    }

    public static Quiz multipleChoiceQuiz2() {
        Quiz quiz = Quiz.create(
                QuizType.MULTIPLE_CHOICE,
                QuizDifficulty.MEDIUM,
                "프로세스와 스레드의 차이로 옳은 것은?",
                null,
                "프로세스는 독립된 메모리 공간을, 스레드는 프로세스 내 메모리를 공유한다.",
                "멀티스레드 웹 서버가 스레드 간 메모리 공유의 대표적인 예시다.",
                "스레드도 독립된 메모리를 갖는다고 착각하기 쉽다 — 스택만 별도이고 힙은 공유한다.");
        quiz.addChoice("프로세스는 메모리를 공유하고 스레드는 독립적이다", false, 1);
        quiz.addChoice("스레드는 프로세스 내 메모리를 공유한다", true, 2);
        quiz.addChoice("둘 다 완전히 독립된 메모리를 가진다", false, 3);
        quiz.addChoice("차이가 없다", false, 4);
        quiz.addFollowUpQuestion("스레드 간 메모리 공유가 왜 위험할 수 있나요?", true, 1);
        quiz.addDerivedConcept("컨텍스트 스위칭", 1);
        quiz.addKeyword("스레드", "프로세스 내에서 실행되는 작업 단위");
        return quiz;
    }

    public static Quiz keywordBlankQuiz() {
        Quiz quiz = Quiz.create(
                QuizType.KEYWORD_BLANK,
                QuizDifficulty.HARD,
                "스택은 ___ 방식으로 데이터를 관리하는 자료구조다.",
                "push(1); push(2); pop(); // 결과: ?",
                "스택은 LIFO(Last In First Out) 방식으로 마지막에 넣은 데이터가 먼저 나온다.",
                "함수 호출 스택, 브라우저 뒤로가기 기능이 대표적인 활용 예시다.",
                "큐(FIFO)와 헷갈리기 쉽다 — 큐는 먼저 넣은 데이터가 먼저 나온다.");
        quiz.addAnswerKeyword(1, "LIFO");
        quiz.addFollowUpQuestion("큐(Queue)와 스택의 차이는 무엇인가요?", true, 1);
        quiz.addDerivedConcept("LIFO", 1);
        quiz.addKeyword("스택", "한쪽 끝에서만 데이터를 넣고 뺄 수 있는 자료구조");
        return quiz;
    }

    /**
     * 해설 조회(#43)용 — 본문에 {@code [[키워드]]} 마커가 저작돼 있다.
     *
     * <p>실제 생성물의 두 가지 특성을 재현한다: (1) 키워드 '비연결형'은 해설 본문이 아니라 오답 해설에만
     * 등장한다. (2) 대표 꼬리질문이 저작 순서상 뒤에 있어, 응답에서 앞으로 끌어올려야 한다.
     */
    public static Quiz annotatedExplanationQuiz() {
        Quiz quiz = Quiz.create(
                QuizType.OX,
                QuizDifficulty.EASY,
                "TCP는 연결 지향 프로토콜이다.",
                null,
                "TCP는 [[연결 지향]] 프로토콜이다.\n연결은 [[3-way handshake]]로 맺어진다.",
                "웹 브라우저도 접속 전에 [[3-way handshake]]를 거친다.",
                "UDP는 [[비연결형]]이라 handshake가 없다.");
        quiz.assignCorrectAnswer("O");
        quiz.addFollowUpQuestion("보조 질문입니다.", false, 2);
        quiz.addFollowUpQuestion("대표 질문입니다.", true, 1);
        quiz.addKeyword("연결 지향", "통신 전에 연결을 먼저 수립하는 방식");
        quiz.addKeyword("3-way handshake", "세 단계로 패킷을 주고받아 연결을 맺는 절차");
        quiz.addKeyword("비연결형", "연결을 수립하지 않고 곧바로 전송하는 방식");
        return quiz;
    }

    /** 한 스텝(5문제: 하2·중2·상1)을 slot_order 1~5로 조립한다. */
    public static List<Quiz> step(int stepOrder) {
        Quiz first = oxQuiz();
        Quiz second = oxQuiz2();
        Quiz third = multipleChoiceQuiz();
        Quiz fourth = multipleChoiceQuiz2();
        Quiz fifth = keywordBlankQuiz();

        first.assignPosition(stepOrder, 1);
        second.assignPosition(stepOrder, 2);
        third.assignPosition(stepOrder, 3);
        fourth.assignPosition(stepOrder, 4);
        fifth.assignPosition(stepOrder, 5);

        return List.of(first, second, third, fourth, fifth);
    }

    private QuizFixture() {}
}

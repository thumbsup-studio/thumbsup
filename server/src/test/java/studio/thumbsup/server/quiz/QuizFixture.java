package studio.thumbsup.server.quiz;

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

    private QuizFixture() {}
}

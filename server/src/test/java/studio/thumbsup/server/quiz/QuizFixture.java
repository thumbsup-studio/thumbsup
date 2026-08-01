package studio.thumbsup.server.quiz;

import java.util.List;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.quiz.course.Course;

/** 퀴즈 테스트 픽스처 — feature 소유. 영속화 전 완전한 aggregate를 만들어 반환한다. */
public final class QuizFixture {

    public static Course course(Long id) {
        Course course = Course.create("CS 기초", "CS");
        ReflectionTestUtils.setField(course, "id", id);
        return course;
    }

    public static Quiz oxQuiz() {
        Quiz quiz = Quiz.create(
                QuizType.OX,
                QuizDifficulty.EASY,
                "TCP는 연결 지향 프로토콜이다.",
                null,
                "TCP는 3-way handshake로 연결을 맺는 연결 지향 프로토콜이다.",
                null,
                "UDP와 헷갈리기 쉽다 — UDP는 비연결형이라 handshake가 없다.");
        quiz.assignHint("연결을 시작하기 전에 통신 상대와 준비 절차를 거치는지 떠올려 보세요.");
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
        quiz.assignHint("전송 전에 연결을 맺고 손실된 데이터를 다시 보내는 절차가 있는지 살펴보세요.");
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
        quiz.assignHint("각 반복문이 입력 크기에 따라 몇 번씩 실행되는지 곱해서 생각해 보세요.");
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
        quiz.assignHint("실행 단위들이 주소 공간을 각각 소유하는지 함께 사용하는지 구분해 보세요.");
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
        quiz.assignHint("가장 최근에 들어온 데이터가 언제 꺼내지는지 순서를 따라가 보세요.");
        quiz.addAnswerKeyword(1, "LIFO");
        quiz.addFollowUpQuestion("큐(Queue)와 스택의 차이는 무엇인가요?", true, 1);
        quiz.addDerivedConcept("LIFO", 1);
        quiz.addKeyword("스택", "한쪽 끝에서만 데이터를 넣고 뺄 수 있는 자료구조");
        return quiz;
    }

    /**
     * 해설 조회(#43)용 — 본문에 {@code [[키워드]]} 마커가 저작돼 있다.
     *
     * <p>실제 생성물의 세 가지 특성을 재현한다: (1) 키워드 '비연결형'은 해설 본문이 아니라 오답 해설에만
     * 등장한다. (2) 대표 꼬리질문이 저작 순서상 뒤에 있어, 응답에서 앞으로 끌어올려야 한다.
     * (3) 상세가 아직 저작되지 않은 꼬리질문이 섞여 있어, 응답에서 걸러져야 한다(#108).
     */
    public static Quiz annotatedExplanationQuiz() {
        Quiz quiz = Quiz.create(
                QuizType.OX,
                QuizDifficulty.EASY,
                "TCP는 연결 지향 프로토콜이다.",
                null,
                "TCP는 [[연결 지향]] 프로토콜이다.\n연결은 [[3-way handshake]]로 맺어진다.",
                "웹 브라우저도 접속 전에 3-way handshake를 거친다.",
                "UDP는 [[비연결형]]이라 handshake가 없다.");
        quiz.assignHint("통신을 시작하기 전에 연결 설정 절차를 수행하는지 떠올려 보세요.");
        quiz.assignCorrectAnswer("O");
        withDetail(quiz.addFollowUpQuestion("보조 질문입니다.", false, 2), 20L);
        withDetail(quiz.addFollowUpQuestion("대표 질문입니다.", true, 1), 10L);
        quiz.addFollowUpQuestion("상세가 없는 질문입니다.", false, 3);
        quiz.addKeyword("연결 지향", "통신 전에 연결을 먼저 수립하는 방식");
        quiz.addKeyword("3-way handshake", "세 단계로 패킷을 주고받아 연결을 맺는 절차");
        quiz.addKeyword("비연결형", "연결을 수립하지 않고 곧바로 전송하는 방식");
        return quiz;
    }

    /**
     * 상세 콘텐츠가 저작된 꼬리질문 — 꼬리질문 상세 조회(#108)용.
     *
     * <p>출처 문제를 스텝 내 3번 슬롯에 두어 응답의 {@code sourceQuizNumber}가 3이 되게 한다
     * ("3번 문제에서 이어짐"). 키워드 '해시셋'은 한 줄 답이 아니라 블록에만 등장한다.
     */
    public static QuizFollowUpQuestion detailedFollowUpQuestion(Long followUpQuestionId, Long sourceQuizId) {
        Quiz quiz = oxQuiz();
        ReflectionTestUtils.setField(quiz, "id", sourceQuizId);
        quiz.assignPosition(1, 3);

        QuizFollowUpQuestion followUpQuestion = quiz.addFollowUpQuestion("정렬되어 있지 않은 배열이라면 어떻게 찾아야 할까?", true, 2);
        ReflectionTestUtils.setField(followUpQuestion, "id", followUpQuestionId);

        followUpQuestion.attachDetail(QuizDifficulty.MEDIUM, "정렬이 안 됐다면 이진 탐색은 못 써요. [[선형 탐색]]이 기본입니다.");
        followUpQuestion.addKeyword("선형 탐색", "앞에서부터 하나씩 확인하는 탐색 방법");
        followUpQuestion.addKeyword("해시셋", "값의 존재 여부를 평균 O(1)에 확인하는 자료구조");
        followUpQuestion.addBlock("해설", FollowUpBlockType.TEXT, "선형 탐색은 정렬 여부와 무관하게 O(n)이다.", 1);
        followUpQuestion.addBlock("실무 사용처", FollowUpBlockType.TEXT, "반복 조회라면 [[해시셋]]으로 미리 인덱싱한다.", 2);
        return followUpQuestion;
    }

    /** 상세가 아직 저작되지 않은 꼬리질문 — 생성 파이프라인(#26) 백필 전의 실제 데이터 상태. */
    public static QuizFollowUpQuestion followUpQuestionWithoutDetail(Long followUpQuestionId) {
        Quiz quiz = oxQuiz();
        ReflectionTestUtils.setField(quiz, "id", 1L);
        QuizFollowUpQuestion followUpQuestion = quiz.addFollowUpQuestion("아직 준비되지 않은 질문입니다.", true, 2);
        ReflectionTestUtils.setField(followUpQuestion, "id", followUpQuestionId);
        return followUpQuestion;
    }

    private static void withDetail(QuizFollowUpQuestion followUpQuestion, Long id) {
        ReflectionTestUtils.setField(followUpQuestion, "id", id);
        followUpQuestion.attachDetail(QuizDifficulty.EASY, "한 줄 답입니다.");
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

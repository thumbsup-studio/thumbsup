package studio.thumbsup.server.quiz.generation;

import studio.thumbsup.server.quiz.QuizType;

/**
 * 저작 브리지에 보낼 프롬프트를 조립한다 — 요구 스키마는 {@link GeneratedQuizSet}과 1:1로 맞춰져 있다.
 * 난이도·유형 매핑은 세션 설계(#19)를 그대로 따른다: 하(EASY)=OX, 중(MEDIUM)=사지선다, 상(HARD)=키워드 빈칸.
 */
public final class QuizGenerationPromptBuilder {

    public static final String SYSTEM_PROMPT = """
            너는 컴퓨터공학 전공 교재 수준의 정확성을 가진 CS 강사이며, 학습자의 이해도를 확인하는 퀴즈를 만든다.

            - 사실 기반으로만 작성한다. 확실하지 않은 내용, 검증되지 않은 수치·통계, 존재하지 않는 개념이나
              용어를 지어내지 않는다. 확신이 없으면 더 널리 알려진 확실한 소재로 대체한다.
            - 사용자가 제시한 JSON 스키마를 한 글자도 벗어나지 않고 정확히 지킨다. 스키마에 없는 필드를
              추가하거나, 요구된 필드를 누락하거나, 타입(문자열/배열/불리언 등)을 다르게 쓰지 않는다.
            - 응답은 오직 유효한 JSON 객체 하나뿐이어야 한다. 인사말, 설명 문장, 주석, 마크다운 코드펜스
              (```)는 절대 포함하지 않는다.
            """;

    private static final String SCHEMA = """
            {
              "quizzes": [
                {
                  "type": "OX | MULTIPLE_CHOICE | KEYWORD_BLANK",
                  "difficulty": "EASY | MEDIUM | HARD",
                  "questionText": "문제 본문",
                  "hint": "정답을 직접 말하지 않고 판단 단서를 제공하는 200자 이내의 개행 없는 한 문장",
                  "codeSnippet": "실제 코드 또는 실행 흐름이 명확한 의사코드(필요하지 않으면 null)",
                  "explanationSummary": "핵심 3줄 요약 해설 — 해설 3개 컬럼 전체의 keywords 마커 정책 적용",
                  "explanationExample": "실무 적용/코드 예시(없으면 null) — 해설 3개 컬럼 전체의 keywords 마커 정책 적용",
                  "wrongAnswerExplanation": "오답 해설(왜 틀렸는지) — 해설 3개 컬럼 전체의 keywords 마커 정책 적용",
                  "correctAnswer": "OX 전용 정답 \\"O\\" 또는 \\"X\\"(그 외 유형은 null)",
                  "choices": [{"content": "선택지 내용", "isCorrect": true}],
                  "answerKeywords": [["빈칸1 정답", "빈칸1과 같은 뜻의 동의어(있으면)"], ["빈칸2 정답"]],
                  "followUpQuestions": [
                    {
                      "content": "꼬리질문 본문 — 마커를 넣지 않는 평문",
                      "isPrimary": true,
                      "difficulty": "EASY | MEDIUM | HARD — 이 꼬리질문 자체의 난이도",
                      "oneLineAnswer": "한 줄 답 — 꼬리질문 전체 keywords 마커 정책의 최우선 영역",
                      "blocks": [
                        {"label": "해설", "content": "블록 본문 — 꼬리질문 전체 keywords 마커 정책 적용"}
                      ],
                      "keywords": [{"keyword": "이 꼬리질문의 어려운 용어", "description": "그 용어의 설명"}]
                    }
                  ],
                  "derivedConcepts": ["관련 파생 개념 이름"],
                  "keywords": [{"keyword": "지문 속 어려운 용어", "description": "그 용어의 설명"}]
                }
              ]
            }
            """;

    private static final String COMMON_REQUIREMENTS = """
            모든 문제 공통 요구사항:
            - hint: 정답을 제출하기 전에 사용자가 직접 요청해 보는 단서다. 200자 이내의 개행 없는 한 문장으로 쓰고,
              정답 자체가 아니라 정답 개념의 배경 원리·판단 조건·구분 기준을 설명한다. "정답은", "답은",
              "N번 선택지", "O/X"처럼 답을 직접 지시하는 표현과 [[키워드]] 마커를 절대 넣지 마라.
              유형별로 다음을 추가로 지켜라.
              · OX: 참·거짓·옳다·틀리다·맞다·아니다 같은 판단 결론을 말하지 않고, 판정할 조건이나 예외만 설명한다.
              · MULTIPLE_CHOICE: 선택지 라벨이나 정답 선택지 문구를 말하지 않고, 선택지를 가를 개념적 기준만 설명한다.
              · KEYWORD_BLANK: 정답 키워드와 동의어를 쓰지 않고, 그 개념의 정의·역할·문맥만 설명한다.
            - codeSnippet: 실제 코드나 실행 흐름이 명확한 의사코드가 문제 풀이에 필요할 때만 작성한다.
              코드/의사코드가 아니면 codeSnippet은 반드시 null로 두고, 자연어 상황 설명·표·조건 목록은 questionText에 작성한다.
              변수명에 리터럴 입력값만 대입해 나열한 데이터도 코드가 아니므로 questionText에 문장으로 작성한다.
            - explanationSummary: 정확히 개행(\\n) 3줄로 된 핵심 요약. 줄 끝 공백·빈 줄 없이 정확히 3줄이어야 한다.
            - wrongAnswerExplanation: 이 문제를 틀렸을 때 보여줄, 왜 틀렸는지 설명하는 해설
            - followUpQuestions: 1개 이상, 그중 정확히 1개는 isPrimary=true. 각 꼬리질문은 아래 "꼬리질문 상세"를
              빠짐없이 갖춰야 한다
            - derivedConcepts: 1개 이상
            - keywords: 지문 속에서 학습자가 어려워할 만한 용어 1개 이상과 그 설명

            꼬리질문 상세 (followUpQuestions의 각 원소):
            - 꼬리질문 화면은 읽기 전용이다 — 학습자가 다시 풀거나 채점받지 않고 읽기만 한다. 그러니 방금 푼
              문제에서 한 걸음 더 들어가는 질문을 쓰고, 그 답과 정리를 같은 원소 안에 함께 담아라.
            - content: 질문 본문. 여기엔 마커를 넣지 마라 — 서버가 평문 그대로 내려준다.
            - difficulty: 이 꼬리질문 자체의 난이도. 부모 문제의 난이도와 무관하다(HARD 문제의 꼬리질문이 EASY일 수 있다).
            - oneLineAnswer: 질문에 답하는 한 문장. 500자 이내.
            - blocks: 상세 정리. 첫 블록의 label은 반드시 "해설"이다. 그 뒤로는 문제 성격에 맞는 블록을 필요한 만큼
              덧붙여라(예: "실무 사용처", "흔한 오해", "비교"). label은 50자 이내.
            - keywords: 이 꼬리질문 전용 용어 사전. 부모 문제의 keywords와 별개이며, 부모 지문에 없던 용어를
              새로 등록해도 된다. 1개 이상.
            """;

    private static final String MARKER_RULES = """
            키워드 하이라이트 마커:
            - 마커를 넣는 곳은 두 묶음뿐이고, 묶음마다 사전이 다르다.
              (1) 해설 3개 컬럼(explanationSummary·explanationExample·wrongAnswerExplanation) — 그 문제의 keywords를 사전으로 쓴다.
              (2) 각 꼬리질문의 oneLineAnswer와 blocks의 content — 그 꼬리질문의 keywords를 사전으로 쓴다.
                  부모 문제의 keywords가 아니다.
            - questionText·codeSnippet·followUpQuestions의 content에는 절대 넣지 마라.
            - 사전에 등록한 각 용어는 아래 영역 우선순위로 선택한 한 위치의 첫 등장만 [[용어]]로 감싸라.
              예: "[[프로세스]]는 실행 중인 프로그램이다."
            - 마커 안 문자열은 keyword 값과 공백·대소문자까지 정확히 일치해야 한다.
              조사(은/는/이/가/을/를 등)는 마커 밖에 둔다. 올바름: [[프로세스]]는 / 잘못됨: [[프로세스는]]
            - 문제 keywords의 각 용어는 해설 3개 컬럼 전체에서 정확히 한 번만 마킹한다.
              같은 용어가 여러 컬럼에 등장하면 explanationSummary → explanationExample → wrongAnswerExplanation 우선순위로
              한 곳만 골라 마킹하고, 나머지 컬럼의 같은 용어는 마커 없는 평문으로 둔다.
            - 꼬리질문 keywords의 각 용어는 oneLineAnswer와 모든 blocks의 content 전체에서 정확히 한 번만 마킹한다.
              같은 용어가 여러 영역에 등장하면 oneLineAnswer → blocks 배열 순서(displayOrder 오름차순) 우선순위로
              한 곳만 골라 마킹하고, 나머지 영역의 같은 용어는 마커 없는 평문으로 둔다.
            - 마커를 중첩하거나 겹치게 쓰지 마라 (예: [[가상 [[메모리]]]] 금지).
            - 커버리지: 문제의 keywords는 해설 3개 컬럼 중 최소 한 곳에, 꼬리질문의 keywords는 그 꼬리질문의
              oneLineAnswer나 blocks의 content 중 최소 한 곳에 자연스러운 문장으로 등장하고 마킹돼야 한다.
              본문에 자연스럽게 넣을 수 없는 용어는 keywords 목록에 아예 넣지 마라.
            """;

    /**
     * 유형마다 "쉽다/어렵다"의 의미가 다르므로(OX는 헷갈림 정도, 사지선다는 오답 매력도, 키워드 빈칸은
     * 용어 전문성) 유형별로 따로 지시한다 — 슬롯 순서(하2·중2·상1) 자체를 바꾸는 게 아니라, 그 슬롯
     * 안에서 다루는 콘텐츠의 깊이만 이 지시로 조절한다.
     */
    private static final String CONTENT_LEVEL_BASIC = """
            콘텐츠 난이도: 입문자 수준으로 맞춰라. 문제 유형·슬롯 순서(하2·중2·상1)는 그대로 유지하되,
            유형별로 다음과 같이 개념의 깊이를 낮춰라.
            - OX: 가장 널리 알려진 기본 사실을 판정하게 하고, 헷갈리기 쉬운 예외 조건·경계 사례는 피해라.
            - 사지선다: 오답 선택지도 명백히 틀린 것 위주로 구성해, 정답과 지나치게 비슷한 근접 개념으로
              헷갈리게 하지 마라.
            - 키워드 빈칸: 교재 도입부에 나올 법한 가장 기본적인 핵심 용어로 빈칸을 구성해라.
            """;

    private static final String CONTENT_LEVEL_ADVANCED = """
            콘텐츠 난이도: 심화 수준으로 맞춰라. 문제 유형·슬롯 순서(하2·중2·상1)는 그대로 유지하되,
            유형별로 다음과 같이 개념의 깊이를 높여라.
            - OX: 단순 정의가 아니라 실무자도 자주 오해하는 경계 사례·예외 조건·미묘한 차이를 판정하게 해라.
            - 사지선다: 오답 선택지도 정답과 근접한 개념으로 구성해, 단순 소거법이 아니라 정확한 이해가
              있어야 풀리게 해라.
            - 키워드 빈칸: 실무·심화 문헌에서 쓰이는 전문 용어나 세부 메커니즘을 가리키는 용어로 빈칸을
              구성해라.
            """;

    private QuizGenerationPromptBuilder() {}

    /** 저작 파이프라인(#174)의 {@code AuthoringPromptFactory}가 콘텐츠 난이도 힌트 없이 재사용한다. */
    public static String build(String courseTopic) {
        return build(courseTopic, QuizPreset.BASIC_5);
    }

    public static String build(String courseTopic, QuizPreset preset) {
        return build(courseTopic, preset, GenerationLevel.STANDARD);
    }

    /**
     * {@code level}은 슬롯 구성(하2·중2·상1)이 정하는 문제 "형식" 난이도와 별개로, 그 안에서 다루는
     * 콘텐츠 깊이를 조절한다. STANDARD는 별도 힌트를 넣지 않는다(기존 동작과 동일 — 모델 판단에 맡긴다).
     */
    static String build(String courseTopic, GenerationLevel level) {
        return build(courseTopic, QuizPreset.BASIC_5, level);
    }

    private static String build(String courseTopic, QuizPreset preset, GenerationLevel level) {
        return """
                "%s" 주제로 학습 퀴즈 %d문제를 한 세트로 생성해줘. 오직 아래 JSON 스키마와 정확히 일치하는
                JSON 객체 하나만 출력하고, 그 외 설명·마크다운 코드펜스는 절대 포함하지 마.

                %s
                %s%s
                %s
                JSON 스키마:
                %s
                """.formatted(
                        courseTopic,
                        preset.quizCount(),
                        slotComposition(preset),
                        contentLevelHint(level),
                        COMMON_REQUIREMENTS,
                        MARKER_RULES,
                        SCHEMA);
    }

    private static String slotComposition(QuizPreset preset) {
        StringBuilder composition = new StringBuilder("난이도 구성(정확히 이 순서·개수를 지켜야 함):\n");
        for (int index = 0; index < preset.slots().size(); index++) {
            QuizPreset.Slot slot = preset.slots().get(index);
            composition
                    .append("%d. %s(%s) — ".formatted(index + 1, slot.difficulty(), slot.type()))
                    .append(slotDescription(slot.type()))
                    .append('\n');
        }
        return composition.toString();
    }

    private static String slotDescription(QuizType type) {
        if (type == QuizType.OX) {
            return "참/거짓 판정 문제. choices와 answerKeywords는 null, correctAnswer는 \"O\" 또는 \"X\".";
        }
        if (type == QuizType.MULTIPLE_CHOICE) {
            return "4지선다, choices 배열에 정확히 4개, 그중 정답 1개만 isCorrect=true. correctAnswer와 answerKeywords는 null.";
        }
        return """
                빈칸 채우기. questionText에 빈칸(___)을 포함하고, answerKeywords는 "빈칸 개수만큼의 배열"이어야 한다 —
                배열 원소 하나가 빈칸 하나다. 빈칸이 1개면 answerKeywords도 원소 1개짜리 배열이다. 절대로 같은 뜻의
                다른 표현(동의어·약어/전체 이름 등)을 별도 빈칸으로 쪼개서 배열 길이를 늘리지 마라 — 동의어는 그
                빈칸에 해당하는 원소 안에 함께 나열한다. choices와 correctAnswer는 null.
                """;
    }

    // if-else 사용 이유: enum switch 표현식은 컴파일러가 안전장치로 java.lang.MatchException 생성 코드를
    // 바이트코드에 삽입하는데, ArchUnit이 이를 "표준 예외 직접 생성"으로 오탐지한다(QuizService#grade와 동일 이유).
    private static String contentLevelHint(GenerationLevel level) {
        if (level == GenerationLevel.BASIC) {
            return CONTENT_LEVEL_BASIC;
        }
        if (level == GenerationLevel.ADVANCED) {
            return CONTENT_LEVEL_ADVANCED;
        }
        return "";
    }
}

package studio.thumbsup.server.quiz.generation;

/**
 * 엘리스 모델에 보낼 프롬프트를 조립한다 — 요구 스키마는 {@link GeneratedQuizSet}과 1:1로 맞춰져 있다.
 * 난이도·유형 매핑은 세션 설계(#19)를 그대로 따른다: 하(EASY)=OX, 중(MEDIUM)=사지선다, 상(HARD)=키워드 빈칸.
 */
public final class QuizGenerationPromptBuilder {

    private static final String SCHEMA = """
            {
              "quizzes": [
                {
                  "type": "OX | MULTIPLE_CHOICE | KEYWORD_BLANK",
                  "difficulty": "EASY | MEDIUM | HARD",
                  "questionText": "문제 본문",
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

    private static final String SLOT_COMPOSITION = """
            난이도 구성(정확히 이 순서·개수를 지켜야 함):
            1. EASY(OX) — 참/거짓 판정 문제. choices와 answerKeywords는 null, correctAnswer는 "O" 또는 "X".
            2. EASY(OX) — 위와 같은 유형, 다른 소재.
            3. MEDIUM(MULTIPLE_CHOICE) — 4지선다, choices 배열에 정확히 4개, 그중 정답 1개만 isCorrect=true.
               correctAnswer와 answerKeywords는 null.
            4. MEDIUM(MULTIPLE_CHOICE) — 위와 같은 유형, 다른 소재.
            5. HARD(KEYWORD_BLANK) — 빈칸 채우기. questionText에 빈칸(___)을 포함하고, answerKeywords는
               "빈칸 개수만큼의 배열"이어야 한다 — 배열 원소 하나가 빈칸 하나다. 빈칸이 1개면 answerKeywords도
               원소 1개짜리 배열이다. 절대로 같은 뜻의 다른 표현(동의어·약어/전체 이름 등)을 별도 빈칸으로
               쪼개서 배열 길이를 늘리지 마라 — 동의어는 그 빈칸에 해당하는 원소 안에 함께 나열한다.
               예: 빈칸 1개, 정답이 "PCB"와 "Process Control Block" 둘 다 인정되면
               answerKeywords = [["PCB", "Process Control Block"]] (배열 길이 1, 안쪽에 동의어 2개).
               choices와 correctAnswer는 null.
            """;

    private static final String COMMON_REQUIREMENTS = """
            모든 문제 공통 요구사항:
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

    private QuizGenerationPromptBuilder() {}

    public static String build(String courseTopic) {
        return """
                "%s" 주제로 학습 퀴즈 5문제를 한 세트로 생성해줘. 오직 아래 JSON 스키마와 정확히 일치하는
                JSON 객체 하나만 출력하고, 그 외 설명·마크다운 코드펜스는 절대 포함하지 마.

                %s
                %s
                %s
                JSON 스키마:
                %s
                """.formatted(courseTopic, SLOT_COMPOSITION, COMMON_REQUIREMENTS, MARKER_RULES, SCHEMA);
    }
}

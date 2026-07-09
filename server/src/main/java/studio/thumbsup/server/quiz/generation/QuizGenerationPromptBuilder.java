package studio.thumbsup.server.quiz.generation;

/**
 * 엘리스 모델에 보낼 프롬프트를 조립한다 — 요구 스키마는 {@link GeneratedQuizSet}과 1:1로 맞춰져 있다.
 * 난이도·유형 매핑은 세션 설계(#19)를 그대로 따른다: 하(EASY)=OX, 중(MEDIUM)=사지선다, 상(HARD)=키워드 빈칸.
 */
final class QuizGenerationPromptBuilder {

    private static final String SCHEMA = """
            {
              "quizzes": [
                {
                  "type": "OX | MULTIPLE_CHOICE | KEYWORD_BLANK",
                  "difficulty": "EASY | MEDIUM | HARD",
                  "questionText": "문제 본문",
                  "codeSnippet": "코드 지문(없으면 null)",
                  "explanationSummary": "핵심 3줄 요약 해설 — keywords 용어 첫 등장에 [[용어]] 마커",
                  "explanationExample": "실무 적용/코드 예시(없으면 null) — keywords 용어 첫 등장에 [[용어]] 마커",
                  "wrongAnswerExplanation": "오답 해설(왜 틀렸는지) — keywords 용어 첫 등장에 [[용어]] 마커",
                  "correctAnswer": "OX 전용 정답 \\"O\\" 또는 \\"X\\"(그 외 유형은 null)",
                  "choices": [{"content": "선택지 내용", "isCorrect": true}],
                  "answerKeywords": [["빈칸1 정답", "빈칸1과 같은 뜻의 동의어(있으면)"], ["빈칸2 정답"]],
                  "followUpQuestions": [{"content": "꼬리질문", "isPrimary": true}],
                  "derivedConcepts": ["관련 파생 개념 이름"],
                  "keywords": [{"keyword": "지문 속 어려운 용어", "description": "그 용어의 설명"}]
                }
              ]
            }
            """;

    private QuizGenerationPromptBuilder() {}

    static String build(String courseTopic) {
        return """
                "%s" 주제로 학습 퀴즈 5문제를 한 세트로 생성해줘. 오직 아래 JSON 스키마와 정확히 일치하는
                JSON 객체 하나만 출력하고, 그 외 설명·마크다운 코드펜스는 절대 포함하지 마.

                난이도 구성(정확히 이 순서·개수를 지켜야 함):
                1. EASY(OX) — 참/거짓 판정 문제. choices와 answerKeywords는 null, correctAnswer는 "O" 또는 "X".
                2. EASY(OX) — 위와 같은 유형, 다른 소재.
                3. MEDIUM(MULTIPLE_CHOICE) — 4지선다, choices 배열에 정확히 4개, 그중 정답 1개만 isCorrect=true.
                   correctAnswer와 answerKeywords는 null.
                4. MEDIUM(MULTIPLE_CHOICE) — 위와 같은 유형, 다른 소재. 가능하면 코드 지문(codeSnippet) 포함.
                5. HARD(KEYWORD_BLANK) — 빈칸 채우기. questionText에 빈칸(___)을 포함하고, answerKeywords는
                   "빈칸 개수만큼의 배열"이어야 한다 — 배열 원소 하나가 빈칸 하나다. 빈칸이 1개면 answerKeywords도
                   원소 1개짜리 배열이다. 절대로 같은 뜻의 다른 표현(동의어·약어/전체 이름 등)을 별도 빈칸으로
                   쪼개서 배열 길이를 늘리지 마라 — 동의어는 그 빈칸에 해당하는 원소 안에 함께 나열한다.
                   예: 빈칸 1개, 정답이 "PCB"와 "Process Control Block" 둘 다 인정되면
                   answerKeywords = [["PCB", "Process Control Block"]] (배열 길이 1, 안쪽에 동의어 2개).
                   choices와 correctAnswer는 null.

                모든 문제 공통 요구사항:
                - explanationSummary: 정확히 개행(\\n) 3줄로 된 핵심 요약. 줄 끝 공백·빈 줄 없이 정확히 3줄이어야 한다.
                - wrongAnswerExplanation: 이 문제를 틀렸을 때 보여줄, 왜 틀렸는지 설명하는 해설
                - followUpQuestions: 1개 이상, 그중 정확히 1개는 isPrimary=true
                - derivedConcepts: 1개 이상
                - keywords: 지문 속에서 학습자가 어려워할 만한 용어 1개 이상과 그 설명

                키워드 하이라이트 마커 (explanationSummary·explanationExample·wrongAnswerExplanation 전용 —
                questionText·codeSnippet에는 절대 넣지 마라):
                - keywords에 등록한 각 용어가 처음 등장하는 위치를 [[용어]]로 감싸라.
                  예: "[[프로세스]]는 실행 중인 프로그램이다."
                - 마커 안 문자열은 keywords[].keyword 값과 공백·대소문자까지 정확히 일치해야 한다.
                  조사(은/는/이/가/을/를 등)는 마커 밖에 둔다. 올바름: [[프로세스]]는 / 잘못됨: [[프로세스는]]
                - 같은 용어를 한 컬럼 안에서 두 번 이상 마킹하지 마라 — 첫 등장 1회만 마킹한다.
                - 마커를 중첩하거나 겹치게 쓰지 마라 (예: [[가상 [[메모리]]]] 금지).
                - keywords에 등록한 용어는 반드시 이 3개 컬럼 중 최소 한 곳에 자연스러운 문장으로 등장하고
                  마킹돼야 한다. 본문에 자연스럽게 넣을 수 없는 용어는 keywords 목록에 아예 넣지 마라.

                JSON 스키마:
                %s
                """.formatted(courseTopic, SCHEMA);
    }
}

package studio.thumbsup.server.quiz.generation;

/**
 * 생성될 문제의 콘텐츠 난이도 힌트 — 슬롯 구성(하2·중2·상1, {@link QuizGenerationPromptBuilder})이
 * 정하는 "문제 유형·형식" 난이도와는 별개다. 같은 OX 슬롯이라도 이 값에 따라 다루는 개념의 깊이가 달라진다.
 */
enum GenerationLevel {
    BASIC,
    STANDARD,
    ADVANCED
}

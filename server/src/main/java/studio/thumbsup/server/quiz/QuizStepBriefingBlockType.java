package studio.thumbsup.server.quiz;

/** 문제 풀이 전 개념 브리핑의 블록 성격. 앱은 이 값으로 강조 표현만 달리하고 콘텐츠 순서는 displayOrder를 따른다. */
public enum QuizStepBriefingBlockType {
    CONCEPT,
    EXAMPLE,
    CAUTION
}

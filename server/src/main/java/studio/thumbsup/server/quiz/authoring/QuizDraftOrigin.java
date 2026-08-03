package studio.thumbsup.server.quiz.authoring;

/** draft가 생겨난 경로 — 새 문제·기존 문제 개선·뼈대 스텝 채움인지. */
public enum QuizDraftOrigin {
    NEW,
    IMPROVE,
    OUTLINE_STEP
}

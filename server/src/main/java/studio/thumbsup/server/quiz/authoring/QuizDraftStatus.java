package studio.thumbsup.server.quiz.authoring;

/** draft의 승인 상태 — DRAFT는 검수 대기·개선 중, APPROVED는 승격 완료. */
public enum QuizDraftStatus {
    DRAFT,
    APPROVED
}

package studio.thumbsup.server.quiz.authoring;

/** 생성 잡의 종류 — 새 문제 생성인지, 기존 draft에 대한 검수/개선인지. */
public enum GenerationJobKind {
    GENERATE,
    REVIEW
}

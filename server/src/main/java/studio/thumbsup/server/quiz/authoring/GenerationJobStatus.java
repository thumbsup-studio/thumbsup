package studio.thumbsup.server.quiz.authoring;

/** 생성 잡의 진행 상태 — QUEUED에서 시작해 RUNNING을 거쳐 SUCCEEDED/FAILED로 종결된다. */
public enum GenerationJobStatus {
    QUEUED,
    RUNNING,
    SUCCEEDED,
    FAILED
}

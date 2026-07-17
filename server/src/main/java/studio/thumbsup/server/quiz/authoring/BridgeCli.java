package studio.thumbsup.server.quiz.authoring;

/** 잡을 실행한 로컬 브리지의 CLI 종류 — 결과 제출 시 어떤 도구가 생성했는지 기록한다. */
public enum BridgeCli {
    CLAUDE,
    CODEX,
    GEMINI
}

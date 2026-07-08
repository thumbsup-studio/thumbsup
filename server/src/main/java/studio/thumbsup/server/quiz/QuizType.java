package studio.thumbsup.server.quiz;

/** 문제 유형 — 난이도와 1:1로 매핑된다 (EASY-OX / MEDIUM-MULTIPLE_CHOICE / HARD-KEYWORD_BLANK, #19). */
public enum QuizType {
    OX,
    MULTIPLE_CHOICE,
    KEYWORD_BLANK
}

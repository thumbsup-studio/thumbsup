package studio.thumbsup.server.quiz.dto;

import java.util.List;

/**
 * 재도전 힌트 — 오답이고 중·상 난이도일 때만 채워진다(정답·EASY·OX는 {@code null}). 정답을 흘리지 않고
 * 재도전에 단서만 준다: 사지선다는 오답 하나를 소거하고, 빈칸은 슬롯별 첫 글자와 글자수를 준다.
 * 유형에 따라 둘 중 하나만 채워진다 — 사지선다면 {@code eliminatedChoiceId}, 빈칸이면 {@code blankHints}.
 */
public record RetryHint(Long eliminatedChoiceId, List<BlankHint> blankHints) {

    /** 빈칸 하나에 대한 힌트. {@code answerLength}는 공백을 제외한 글자 수다(정답 매칭이 띄어쓰기를 무시하므로, #183). */
    public record BlankHint(int slotOrder, String revealedPrefix, int answerLength) {}
}

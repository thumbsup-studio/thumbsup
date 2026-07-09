package studio.thumbsup.server.quiz.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

/**
 * 정답 제출 — 문제 유형에 따라 의미가 다르다.
 * OX: {@code ["O"]} / 사지선다: {@code ["<선택지 id>"]} / 키워드 빈칸: 슬롯 순서대로 키워드 목록.
 */
public record AnswerSubmitRequest(
        @NotEmpty(message = "답을 제출해야 합니다.") List<@NotBlank String> answers) {}

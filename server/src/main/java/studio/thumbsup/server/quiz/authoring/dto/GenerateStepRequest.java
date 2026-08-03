package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotNull;
import studio.thumbsup.server.quiz.generation.QuizPreset;

public record GenerateStepRequest(
        @NotNull(message = "프리셋은 필수입니다.") QuizPreset preset) {}

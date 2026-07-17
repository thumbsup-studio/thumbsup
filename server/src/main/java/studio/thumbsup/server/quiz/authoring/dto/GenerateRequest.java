package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record GenerateRequest(
        @NotBlank(message = "주제는 필수입니다.") @Size(max = 100, message = "100자 이하여야 합니다.")
        String topic) {}

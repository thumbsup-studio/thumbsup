package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateOutlineStepRequest(
        @NotBlank(message = "주제는 필수입니다.") @Size(max = 200, message = "200자 이하여야 합니다.")
        String topic) {}

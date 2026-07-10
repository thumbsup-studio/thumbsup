package studio.thumbsup.server.feedback.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record FeedbackCreateRequest(
        @NotBlank(message = "내용은 필수입니다.") @Size(max = 1000, message = "1000자 이하여야 합니다.")
        String content) {}

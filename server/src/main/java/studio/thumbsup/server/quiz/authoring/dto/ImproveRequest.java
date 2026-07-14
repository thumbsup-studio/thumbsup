package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ImproveRequest(
        @NotBlank(message = "개선 지시는 필수입니다.") @Size(max = 2000, message = "2000자 이하여야 합니다.")
        String instruction) {}

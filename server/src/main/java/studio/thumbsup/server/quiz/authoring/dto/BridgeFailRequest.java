package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;

public record BridgeFailRequest(
        @NotBlank(message = "error는 필수입니다.") String error) {}

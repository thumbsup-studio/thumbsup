package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import studio.thumbsup.server.quiz.authoring.BridgeCli;

public record BridgeResultRequest(
        @NotNull(message = "cli는 필수입니다.") BridgeCli cli,
        @NotBlank(message = "resultJson은 필수입니다.") String resultJson) {}

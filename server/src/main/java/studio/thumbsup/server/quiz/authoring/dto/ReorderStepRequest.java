package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;

public record ReorderStepRequest(
        @NotBlank(message = "방향은 필수입니다.") String direction) {}

package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateOutlineRequest(
        @NotBlank(message = "제목은 필수입니다.") @Size(max = 200, message = "200자 이하여야 합니다.")
        String title,

        @NotBlank(message = "분류는 필수입니다.") @Size(max = 50, message = "50자 이하여야 합니다.")
        String category,

        @NotBlank(message = "목차는 필수입니다.") @Size(max = 20000, message = "20000자 이하여야 합니다.")
        String toc) {}

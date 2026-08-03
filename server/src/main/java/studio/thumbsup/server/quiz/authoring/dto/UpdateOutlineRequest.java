package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.Size;

public record UpdateOutlineRequest(
        @Size(min = 1, max = 200, message = "제목은 1~200자여야 합니다.")
        String title,

        @Size(min = 1, max = 50, message = "분류는 1~50자여야 합니다.")
        String category) {}

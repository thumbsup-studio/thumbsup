package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.Size;

/** feedback은 선택 — 브리지 없이 "다시 검수만" 요청할 수도 있다(#174). */
public record ReviewRequest(
        @Size(max = 2000, message = "2000자 이하여야 합니다.") String feedback) {}

package studio.thumbsup.server.quiz.authoring.dto;

import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record BridgeLogsRequest(
        @NotEmpty(message = "로그 라인은 최소 1개 이상이어야 합니다.") List<String> lines) {}

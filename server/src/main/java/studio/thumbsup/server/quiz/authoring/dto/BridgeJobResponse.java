package studio.thumbsup.server.quiz.authoring.dto;

import com.fasterxml.jackson.databind.JsonNode;
import studio.thumbsup.server.quiz.authoring.GenerationJob;

/** {@code outputSchema}는 서비스가 kind별 {@code AuthoringOutputSchemas} 상수를 미리 파싱해 넘긴다. */
public record BridgeJobResponse(Long jobId, String kind, String prompt, JsonNode outputSchema) {

    public static BridgeJobResponse from(GenerationJob job, JsonNode outputSchema) {
        return new BridgeJobResponse(job.getId(), job.getKind().name(), job.getPrompt(), outputSchema);
    }
}

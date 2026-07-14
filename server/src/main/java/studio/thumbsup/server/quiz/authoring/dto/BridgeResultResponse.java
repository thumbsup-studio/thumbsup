package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.authoring.GenerationJob;

public record BridgeResultResponse(Long jobId, String status, String error) {

    public static BridgeResultResponse from(GenerationJob job) {
        return new BridgeResultResponse(job.getId(), job.getStatus().name(), job.getError());
    }
}

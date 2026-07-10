package studio.thumbsup.server.feedback.dto;

import studio.thumbsup.server.feedback.Feedback;

/** POST /api/v1/feedbacks 전용 응답 DTO — 다른 API와 공유하지 않는다. */
public record FeedbackCreateResponse(Long id) {

    public static FeedbackCreateResponse from(Feedback feedback) {
        return new FeedbackCreateResponse(feedback.getId());
    }
}

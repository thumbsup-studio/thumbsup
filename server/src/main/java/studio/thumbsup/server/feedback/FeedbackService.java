package studio.thumbsup.server.feedback;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.feedback.dto.FeedbackCreateRequest;
import studio.thumbsup.server.feedback.dto.FeedbackCreateResponse;

@Service
public class FeedbackService {

    private final FeedbackRepository feedbackRepository;

    public FeedbackService(FeedbackRepository feedbackRepository) {
        this.feedbackRepository = feedbackRepository;
    }

    @Transactional
    public FeedbackCreateResponse create(Long userId, FeedbackCreateRequest request) {
        Feedback feedback = feedbackRepository.save(Feedback.create(userId, request.content()));
        return FeedbackCreateResponse.from(feedback);
    }
}

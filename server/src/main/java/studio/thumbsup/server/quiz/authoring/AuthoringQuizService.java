package studio.thumbsup.server.quiz.authoring;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringQuizListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringQuizSummaryResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringStepResponse;

/**
 * 대시보드의 라이브 문제 목록 조회(#174 T7) — 저작 대상(개선할 문제)을 스텝별로 훑어보는 용도라
 * draft/잡과 무관한 별도 서비스로 둔다. 문제 수가 작아 페이지네이션은 의도적으로 두지 않는다(YAGNI).
 */
@Service
@Transactional(readOnly = true)
public class AuthoringQuizService {

    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;

    public AuthoringQuizService(QuizRepository quizRepository, QuizStepRepository quizStepRepository) {
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
    }

    public AuthoringQuizListResponse listQuizzes() {
        Map<Integer, String> topicByStepOrder = quizStepRepository.findAll().stream()
                .collect(Collectors.toMap(QuizStep::getStepOrder, QuizStep::getTopic));

        // stepOrder→slotOrder로 먼저 정렬해두면 groupingBy(LinkedHashMap)가 그 순서를 그대로 보존한다.
        Map<Integer, List<Quiz>> quizzesByStep = quizRepository.findAll().stream()
                .filter(quiz -> quiz.getStepOrder() > 0) // 0은 "스텝 밖" placeholder 샘플의 sentinel
                .sorted(Comparator.comparingInt(Quiz::getStepOrder).thenComparingInt(Quiz::getSlotOrder))
                .collect(Collectors.groupingBy(Quiz::getStepOrder, LinkedHashMap::new, Collectors.toList()));

        List<AuthoringStepResponse> steps = quizzesByStep.entrySet().stream()
                .map(entry -> toStepResponse(entry.getKey(), entry.getValue(), topicByStepOrder))
                .toList();
        return new AuthoringQuizListResponse(steps);
    }

    private AuthoringStepResponse toStepResponse(
            int stepOrder, List<Quiz> quizzes, Map<Integer, String> topicByStepOrder) {
        String topic = Optional.ofNullable(topicByStepOrder.get(stepOrder)).orElse(null);
        List<AuthoringQuizSummaryResponse> summaries =
                quizzes.stream().map(AuthoringQuizSummaryResponse::from).toList();
        return new AuthoringStepResponse(stepOrder, topic, summaries);
    }
}

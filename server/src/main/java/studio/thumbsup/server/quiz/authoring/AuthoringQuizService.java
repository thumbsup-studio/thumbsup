package studio.thumbsup.server.quiz.authoring;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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
        // #292: 이 조회는 코스 전체를 훑으므로(스텝 단위가 아니라) step_order는 코스마다 겹칠 수 있어
        // 그룹 키로 쓸 수 없다 — 전역 유일한 quizStepId(PK)로 묶는다.
        Map<Long, QuizStep> stepById =
                quizStepRepository.findAll().stream().collect(Collectors.toMap(QuizStep::getId, s -> s));

        Map<Long, List<Quiz>> quizzesByStepId = quizRepository.findAll().stream()
                .filter(quiz -> quiz.getStepOrder() > 0) // 0은 "스텝 밖" placeholder 샘플의 sentinel
                .sorted(Comparator.comparing((Quiz quiz) ->
                                stepById.get(quiz.getQuizStepId()).getCourseId())
                        .thenComparingInt(Quiz::getStepOrder)
                        .thenComparingInt(Quiz::getSlotOrder))
                .collect(Collectors.groupingBy(Quiz::getQuizStepId, LinkedHashMap::new, Collectors.toList()));

        List<AuthoringStepResponse> steps = quizzesByStepId.entrySet().stream()
                .map(entry -> toStepResponse(stepById.get(entry.getKey()), entry.getValue()))
                .toList();
        return new AuthoringQuizListResponse(steps);
    }

    private AuthoringStepResponse toStepResponse(QuizStep step, List<Quiz> quizzes) {
        List<AuthoringQuizSummaryResponse> summaries =
                quizzes.stream().map(AuthoringQuizSummaryResponse::from).toList();
        return new AuthoringStepResponse(step.getStepOrder(), step.getTopic(), summaries);
    }
}

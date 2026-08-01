package studio.thumbsup.server.quiz;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;
import studio.thumbsup.server.quiz.dto.QuizHintResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;
import studio.thumbsup.server.quiz.dto.QuizStepHistoryResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * 쓰기 메서드를 추가하면 반드시 그 메서드에 {@code @Transactional}로 오버라이드한다.
 */
@Service
@Transactional(readOnly = true)
public class QuizService {

    /**
     * 빈칸 정답 비교 전에 지울 공백 — "시스템 콜"과 "시스템콜"을 같은 답으로 본다.
     * 한글 IME는 전각 공백(U+3000)을 입력할 수 있어 ASCII 공백만 보는 기본 {@code \s} 대신
     * 유니코드 공백까지 포함하도록 {@link Pattern#UNICODE_CHARACTER_CLASS}를 켠다.
     */
    private static final Pattern BLANK_ANSWER_WHITESPACE = Pattern.compile("\\s+", Pattern.UNICODE_CHARACTER_CLASS);

    private final QuizRepository quizRepository;
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizAttemptRepository quizAttemptRepository;
    private final QuizProgressRepository quizProgressRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    public QuizService(
            QuizRepository quizRepository,
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizAttemptRepository quizAttemptRepository,
            QuizProgressRepository quizProgressRepository,
            ApplicationEventPublisher eventPublisher,
            Clock clock) {
        this.quizRepository = quizRepository;
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizAttemptRepository = quizAttemptRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    /**
     * 유저의 현재 진행 스텝에서, 아직 시도하지 않은 문제 중 출제 순서가 가장 빠른 것을 반환한다.
     * 오답이어도 같은 문제를 다시 내려주지 않고 다음 문제로 선형 진행한다(#58) — 즉시 재도전을 강제하지 않는다.
     * 틀린 문제의 복습은 이 흐름과 별개로, 저장된 풀이 이력(QuizAttempt)을 활용하는 향후 기능의 몫이다.
     *
     * <p>{@code courseId}가 null이면 기본 코스({@link CourseRepository#findFirstByOrderByIdAsc})를 쓴다 —
     * 코스 선택 UI가 아직 없는 앱이 courseId 없이 호출해도 기존과 동일하게 동작한다.
     */
    public QuizNextResponse getNextQuiz(Long userId, Long courseId) {
        Long resolvedCourseId = resolveCourseId(courseId);
        int stepOrder = quizProgressRepository
                .findByUserIdAndCourseId(userId, resolvedCourseId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElseGet(() -> initialStepOrder(resolvedCourseId));

        // stepOrder는 코스 무관 전역 순번이라, 코스를 완주해 커서가 그 코스의 마지막 스텝을 넘으면
        // 다음 코스의 stepOrder를 그대로 가리키게 된다. 여기서 막지 않으면 완주 응답 대신 다른 코스의
        // 문제를 그대로 내려주게 된다.
        int maxStepOrder = quizStepRepository
                .findMaxStepOrderByCourseId(resolvedCourseId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        if (stepOrder > maxStepOrder) {
            throw new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED);
        }

        List<Quiz> stepQuizzes = quizRepository.findByStepOrderOrderBySlotOrderAsc(stepOrder);
        if (stepQuizzes.isEmpty()) {
            throw new BusinessException(QuizErrorType.QUIZ_NOT_FOUND);
        }

        Set<Long> attemptedQuizIds = quizAttemptRepository.findByUserIdAndQuiz_StepOrder(userId, stepOrder).stream()
                .map(attempt -> attempt.getQuiz().getId())
                .collect(Collectors.toSet());

        Quiz next = stepQuizzes.stream()
                .filter(quiz -> !attemptedQuizIds.contains(quiz.getId()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED));

        return QuizNextResponse.from(next);
    }

    /**
     * 유저가 완료한 스텝(현재 진행 스텝보다 이전) 목록을 스텝번호 오름차순으로 반환한다 — 히스토리 화면(#10).
     * 진행 기록이 없으면(1스텝도 완료 전) 빈 목록을 반환한다. courseId 기본값은 {@link #getNextQuiz}와 동일.
     */
    public QuizStepHistoryResponse getCompletedSteps(Long userId, Long courseId) {
        Long resolvedCourseId = resolveCourseId(courseId);
        int startStepOrder = initialStepOrder(resolvedCourseId);
        int currentStepOrder = quizProgressRepository
                .findByUserIdAndCourseId(userId, resolvedCourseId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(startStepOrder);
        List<QuizStep> completedSteps =
                quizStepRepository.findByStepOrderBetweenOrderByStepOrderAsc(startStepOrder, currentStepOrder - 1);
        return QuizStepHistoryResponse.from(completedSteps);
    }

    /**
     * 완료한 스텝의 문제를 슬롯 지정으로 다시 조회한다(#151, 히스토리 재풀이). 시도 이력을 보지 않고
     * 항상 그 슬롯의 문제를 그대로 반환한다 — {@link #getNextQuiz}와 달리 "미시도만"이 아니다.
     * 접근 제어는 {@link #submitAnswer}와 동일하게 현재 진행 스텝 이하만 허용한다. courseId는 클라이언트가
     * 보내지 않는다 — stepOrder가 속한 코스를 서버가 직접 찾아 그 코스의 진행 상태와 대조한다(위조 불가).
     */
    public QuizNextResponse getStepQuiz(Long userId, int stepOrder, int slotOrder) {
        Long courseId = courseIdForStep(stepOrder);
        validateAccessible(userId, courseId, stepOrder);
        Quiz quiz = quizRepository
                .findByStepOrderAndSlotOrder(stepOrder, slotOrder)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        return QuizNextResponse.from(quiz);
    }

    /**
     * 정답 제출 전 사용자가 직접 요청한 한 문장 힌트를 반환한다(#193). 조회만 수행하므로 풀이 이력·진행도·
     * 오답 재도전 상태에는 아무 영향이 없다. 접근 범위는 답 제출과 동일하게 현재 진행 스텝 이하로 제한한다.
     */
    public QuizHintResponse getHint(Long userId, Long quizId) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        Long courseId = courseIdForStep(quiz.getStepOrder());
        validateAccessible(userId, courseId, quiz.getStepOrder());
        if (quiz.getHint() == null || quiz.getHint().isBlank()) {
            throw new BusinessException(QuizErrorType.QUIZ_HINT_NOT_AVAILABLE);
        }
        return QuizHintResponse.from(quiz);
    }

    /**
     * 문제 하나의 해설을 조회한다 — 해설 화면(S4)이 그리는 콘텐츠 전부를 한 번에 내려준다.
     *
     * <p>해설은 quizId만으로 정해지는 정적 콘텐츠라 채점 결과에 의존하지 않는다. 그래서 정답 제출(#42)이
     * 쓴 풀이 이력을 읽지 않으며, 새로고침·딥링크·복습처럼 채점 없이 해설만 필요한 흐름에서도 그대로 쓰인다.
     *
     * <p>courseTitle은 이 quiz가 실제로 속한 스텝의 코스에서 가져온다 — 예전엔 항상 "기본 코스"를 가져와서
     * 디자인패턴 문제 해설에도 "OS"라고 잘못 표시되는 버그가 있었다.
     */
    public QuizExplanationResponse getExplanation(Long quizId) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));

        QuizStep step = quizStepRepository
                .findByStepOrder(quiz.getStepOrder())
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        String courseTitle = courseRepository
                .findById(step.getCourseId())
                .map(Course::getTitle)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        long totalCount = quizRepository.countByStepOrder(quiz.getStepOrder());

        return QuizExplanationResponse.from(quiz, totalCount, courseTitle, step.getTopic());
    }

    /**
     * 제출한 답을 채점하고 풀이 이력을 남긴다. 재시도를 허용하므로 이력은 매번 새로 쌓인다.
     * 이 시도로 현재 스텝의 모든 문제를 한 번씩 풀었다면(정답 여부 무관) 다음 스텝으로 진행 상태를 갱신한다.
     *
     * <p>격리 수준을 READ_COMMITTED로 낮춘 이유는 {@link #advanceProgressIfStepCompleted}에서 설명한다.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public AnswerSubmitResponse submitAnswer(Long userId, Long quizId, AnswerSubmitRequest request) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        Long courseId = courseIdForStep(quiz.getStepOrder());
        validateAccessible(userId, courseId, quiz.getStepOrder());

        boolean isCorrect = grade(quiz, request.answers());
        quizAttemptRepository.save(QuizAttempt.create(quiz, userId, isCorrect));
        advanceProgressIfStepCompleted(userId, courseId, quiz.getStepOrder());

        return new AnswerSubmitResponse(isCorrect, RetryHintBuilder.build(quiz, request.answers(), isCorrect));
    }

    /** stepOrder가 속한 코스 id — quiz.step_order로부터 역으로 찾는다. 존재하지 않는 스텝이면 QUIZ_NOT_FOUND. */
    private Long courseIdForStep(int stepOrder) {
        return quizStepRepository
                .findByStepOrder(stepOrder)
                .map(QuizStep::getCourseId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
    }

    /** courseId가 지정돼 있으면 그대로, 없으면 기본 코스(가장 먼저 생성된 코스)를 쓴다. */
    private Long resolveCourseId(Long courseId) {
        if (courseId != null) {
            return courseId;
        }
        return courseRepository
                .findFirstByOrderByIdAsc()
                .map(Course::getId)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }

    /** 그 코스의 시작 스텝 — stepOrder가 코스 무관 전역 순번이라 코스마다 1이 아닐 수 있다. */
    private int initialStepOrder(Long courseId) {
        return quizStepRepository
                .findMinStepOrderByCourseId(courseId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
    }

    /**
     * 유저의 그 코스 진행 스텝보다 미래인 스텝의 문제는 제출할 수 없다 — {@code /next}를 거치지 않고
     * quizId를 추측해 앞선 스텝을 건너뛰는 것을 막는다. 현재 스텝과 과거 스텝은 허용한다(복습 여지).
     */
    private void validateAccessible(Long userId, Long courseId, int stepOrder) {
        int currentStepOrder = quizProgressRepository
                .findByUserIdAndCourseId(userId, courseId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElseGet(() -> initialStepOrder(courseId));
        if (stepOrder > currentStepOrder) {
            throw new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE);
        }
    }

    // if-else 사용 이유: enum switch 표현식은 컴파일러가 안전장치로 java.lang.MatchException 생성 코드를
    // 바이트코드에 삽입하는데, ArchUnit이 이를 "표준 예외 직접 생성"으로 오탐지한다(docs/error-implementation.md
    // 한계와 동일한 정적분석 한계).
    private boolean grade(Quiz quiz, List<String> answers) {
        if (quiz.getType() == QuizType.OX) {
            return gradeOx(quiz, answers);
        }
        if (quiz.getType() == QuizType.MULTIPLE_CHOICE) {
            return gradeMultipleChoice(quiz, answers);
        }
        return gradeKeywordBlank(quiz, answers);
    }

    private boolean gradeOx(Quiz quiz, List<String> answers) {
        return answers.get(0).equalsIgnoreCase(quiz.getCorrectAnswer());
    }

    private boolean gradeMultipleChoice(Quiz quiz, List<String> answers) {
        Long submittedChoiceId = parseChoiceId(answers.get(0));
        if (submittedChoiceId == null) {
            return false;
        }
        return quiz.getChoices().stream()
                .filter(choice -> choice.getId().equals(submittedChoiceId))
                .findFirst()
                .map(QuizChoice::isCorrect)
                .orElse(false);
    }

    private Long parseChoiceId(String rawChoiceId) {
        try {
            return Long.valueOf(rawChoiceId);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 빈칸 하나에 동의어가 여러 개 등록될 수 있다(같은 slotOrder를 여러 행이 공유) — 그중 하나만 맞아도
     * 그 빈칸은 정답으로 인정한다. slotOrder는 실제 빈칸 개수와 일치해야 하므로, 답 개수는 "고유 slotOrder 개수"와
     * 비교한다(등록된 키워드 행 개수가 아님).
     *
     * <p>비교는 대소문자와 공백을 무시한다. "시스템 콜"·"문맥 전환"처럼 띄어쓰기가 들어간 정답이 많은데
     * 붙여 쓰는 표기도 똑같이 통용되므로, 표기 차이로 오답 처리되지 않도록 양쪽에서 공백을 모두 지우고 비교한다.
     */
    private boolean gradeKeywordBlank(Quiz quiz, List<String> answers) {
        Map<Integer, List<String>> synonymsBySlot = quiz.getAnswerKeywords().stream()
                .collect(Collectors.groupingBy(
                        QuizAnswerKeyword::getSlotOrder,
                        Collectors.mapping(QuizAnswerKeyword::getKeyword, Collectors.toList())));
        List<Integer> slotOrders = synonymsBySlot.keySet().stream().sorted().toList();
        if (answers.size() != slotOrders.size()) {
            return false;
        }
        for (int i = 0; i < answers.size(); i++) {
            List<String> synonyms = synonymsBySlot.get(slotOrders.get(i));
            String submitted = normalizeBlankAnswer(answers.get(i));
            boolean matched = synonyms.stream()
                    .anyMatch(keyword -> normalizeBlankAnswer(keyword).equalsIgnoreCase(submitted));
            if (!matched) {
                return false;
            }
        }
        return true;
    }

    static String normalizeBlankAnswer(String raw) {
        return BLANK_ANSWER_WHITESPACE.matcher(raw).replaceAll("");
    }

    /**
     * 이 유저가 스텝의 모든 문제를 한 번씩 시도했는지 확인하고, 그렇다면 다음 스텝으로 진행시킨다.
     *
     * <p>같은 유저가 같은 스텝의 마지막 문제 두 개를 동시에 제출하면, 서로 상대방의 커밋을 못 본 채
     * 둘 다 "아직 미완료"로 판단해 진행이 영영 갱신되지 않는 레이스가 생길 수 있다. 이를 막기 위해
     * 진행 상태 행을 유저·코스 단위로 비관적 락({@link QuizProgressRepository#findByUserIdAndCourseIdForUpdate})으로
     * 잠가 이 구간을 직렬화한다 — 먼저 온 요청이 커밋할 때까지 나중 요청은 대기했다가, 커밋 후의
     * 최신 시도 이력을 다시 읽는다. 격리 수준을 READ_COMMITTED로 낮춘 이유도 이것과 짝을 이룬다 —
     * 기본 REPEATABLE READ에서는 트랜잭션 최초 조회 시점의 스냅샷이 고정되어, 락을 기다렸다 얻은
     * 뒤에도 그 사이 다른 트랜잭션이 커밋한 시도 이력을 못 볼 수 있다.
     *
     * <p>스트릭·포인트 갱신은 {@code QuizStepCompletedEvent}를 publish해 {@code user} 도메인에
     * 위임한다 — 이 트랜잭션이 커밋된 뒤 별도 트랜잭션으로 처리되어(AFTER_COMMIT), 스트릭 갱신이
     * 실패해도 방금 저장한 퀴즈 풀이·진행 상태는 롤백되지 않는다.
     */
    private void advanceProgressIfStepCompleted(Long userId, Long courseId, int stepOrder) {
        QuizProgress progress = lockOrCreateProgress(userId, courseId);

        List<Long> stepQuizIds = quizRepository.findIdsByStepOrder(stepOrder);
        Set<Long> attemptedQuizIds = quizAttemptRepository.findByUserIdAndQuiz_StepOrder(userId, stepOrder).stream()
                .map(attempt -> attempt.getQuiz().getId())
                .collect(Collectors.toSet());
        boolean stepCompleted = stepQuizIds.stream().allMatch(attemptedQuizIds::contains);
        if (!stepCompleted) {
            return;
        }

        if (progress.getCurrentStepOrder() == stepOrder) {
            progress.advanceToNextStep();
            quizProgressRepository.save(progress);
            // 스트릭 갱신(user 도메인, AFTER_COMMIT)과 지식 그래프 학습 기록(#233, quiz.concept.
            // LearnedConceptRecorder, 평범한 동기 @EventListener)이 같은 이벤트를 각자 필요한 만큼만
            // 구독한다 — 두 관심사 모두 "스텝을 처음 완료했다"는 같은 사실 하나일 뿐이다.
            eventPublisher.publishEvent(
                    new QuizStepCompletedEvent(userId, LocalDate.now(clock.withZone(TimeZones.KST)), stepOrder));
        }
    }

    /**
     * 진행 상태 행을 락을 건 채로 가져온다. 없으면 새로 만든다 — 유저가 처음으로 스텝을 완료하는
     * 순간 두 요청이 동시에 "행이 없다"를 보고 둘 다 생성을 시도할 수 있으므로, 유니크 제약 위반은
     * 상대가 먼저 만든 행을 락으로 다시 읽어 해소한다.
     */
    private QuizProgress lockOrCreateProgress(Long userId, Long courseId) {
        Optional<QuizProgress> existing = quizProgressRepository.findByUserIdAndCourseIdForUpdate(userId, courseId);
        if (existing.isPresent()) {
            return existing.get();
        }
        try {
            return quizProgressRepository.saveAndFlush(
                    QuizProgress.create(userId, courseId, initialStepOrder(courseId)));
        } catch (DataIntegrityViolationException e) {
            return quizProgressRepository
                    .findByUserIdAndCourseIdForUpdate(userId, courseId)
                    .orElseThrow();
        }
    }
}

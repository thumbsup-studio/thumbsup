package studio.thumbsup.server.quiz;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;
import studio.thumbsup.server.quiz.dto.QuizStepHistoryResponse;
import studio.thumbsup.server.quiz.dto.RetryHint;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * 쓰기 메서드를 추가하면 반드시 그 메서드에 {@code @Transactional}로 오버라이드한다.
 */
@Service
@Transactional(readOnly = true)
public class QuizService {

    private static final int INITIAL_STEP_ORDER = 1;

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
    private final UserProgressService userProgressService;
    private final Clock clock;

    public QuizService(
            QuizRepository quizRepository,
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizAttemptRepository quizAttemptRepository,
            QuizProgressRepository quizProgressRepository,
            UserProgressService userProgressService,
            Clock clock) {
        this.quizRepository = quizRepository;
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizAttemptRepository = quizAttemptRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.userProgressService = userProgressService;
        this.clock = clock;
    }

    /**
     * 유저의 현재 진행 스텝에서, 아직 시도하지 않은 문제 중 출제 순서가 가장 빠른 것을 반환한다.
     * 오답이어도 같은 문제를 다시 내려주지 않고 다음 문제로 선형 진행한다(#58) — 즉시 재도전을 강제하지 않는다.
     * 틀린 문제의 복습은 이 흐름과 별개로, 저장된 풀이 이력(QuizAttempt)을 활용하는 향후 기능의 몫이다.
     */
    public QuizNextResponse getNextQuiz(Long userId) {
        int stepOrder = quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);

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
     * 진행 기록이 없으면(1스텝도 완료 전) 빈 목록을 반환한다.
     */
    public QuizStepHistoryResponse getCompletedSteps(Long userId) {
        int currentStepOrder = quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);
        List<QuizStep> completedSteps =
                quizStepRepository.findByStepOrderBetweenOrderByStepOrderAsc(INITIAL_STEP_ORDER, currentStepOrder - 1);
        return QuizStepHistoryResponse.from(completedSteps);
    }

    /**
     * 완료한 스텝의 문제를 슬롯 지정으로 다시 조회한다(#151, 히스토리 재풀이). 시도 이력을 보지 않고
     * 항상 그 슬롯의 문제를 그대로 반환한다 — {@link #getNextQuiz}와 달리 "미시도만"이 아니다.
     * 접근 제어는 {@link #submitAnswer}와 동일하게 현재 진행 스텝 이하만 허용한다.
     */
    public QuizNextResponse getStepQuiz(Long userId, int stepOrder, int slotOrder) {
        validateAccessible(userId, stepOrder);
        Quiz quiz = quizRepository
                .findByStepOrderAndSlotOrder(stepOrder, slotOrder)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        return QuizNextResponse.from(quiz);
    }

    /**
     * 문제 하나의 해설을 조회한다 — 해설 화면(S4)이 그리는 콘텐츠 전부를 한 번에 내려준다.
     *
     * <p>해설은 quizId만으로 정해지는 정적 콘텐츠라 채점 결과에 의존하지 않는다. 그래서 정답 제출(#42)이
     * 쓴 풀이 이력을 읽지 않으며, 새로고침·딥링크·복습처럼 채점 없이 해설만 필요한 흐름에서도 그대로 쓰인다.
     */
    public QuizExplanationResponse getExplanation(Long quizId) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));

        String courseTitle = courseRepository
                .findFirstByOrderByIdAsc()
                .map(Course::getTitle)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        String unitTitle = quizStepRepository
                .findByStepOrder(quiz.getStepOrder())
                .map(QuizStep::getTopic)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        long totalCount = quizRepository.countByStepOrder(quiz.getStepOrder());

        return QuizExplanationResponse.from(quiz, totalCount, courseTitle, unitTitle);
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
        validateAccessible(userId, quiz);

        boolean isCorrect = grade(quiz, request.answers());
        quizAttemptRepository.save(QuizAttempt.create(quiz, userId, isCorrect));
        advanceProgressIfStepCompleted(userId, quiz.getStepOrder());

        return new AnswerSubmitResponse(isCorrect, buildRetryHint(quiz, request.answers(), isCorrect));
    }

    /**
     * 재도전 힌트를 만든다 — 오답이고 중·상 난이도일 때만. 정답을 흘리지 않도록 부분 힌트만 준다:
     * 사지선다는 오답 하나를 소거하고, 빈칸은 슬롯별 첫 글자·글자수를 준다. 그 외에는 {@code null}이다.
     * OX는 힌트로 줄 형태가 없어 유형으로도 막는다 — 현재 데이터에서 OX는 항상 EASY지만 코드가 그 결합을 가정하지 않는다.
     */
    private RetryHint buildRetryHint(Quiz quiz, List<String> answers, boolean isCorrect) {
        if (isCorrect || quiz.getDifficulty() == QuizDifficulty.EASY || quiz.getType() == QuizType.OX) {
            return null;
        }
        if (quiz.getType() == QuizType.MULTIPLE_CHOICE) {
            return buildMultipleChoiceHint(quiz, answers);
        }
        return buildKeywordBlankHint(quiz);
    }

    /**
     * 사용자가 방금 고른 오답을 지우는 건 이미 아는 사실이라 힌트가 되지 않으므로, 오답 중 사용자가 고르지 않은
     * 것을 소거한다. 4지선다면 오답 3개 중 최소 2개가 후보라 항상 하나는 나온다. 표시 순서(displayOrder) 기준
     * 첫 번째를 골라 결정적으로 만든다 — 컬렉션의 {@code @OrderBy}에 기대지 않고 여기서 명시적으로 정렬한다.
     * 제출값이 파싱되지 않아 사용자 선택을 특정할 수 없으면 오답 중 첫 번째를 소거한다.
     */
    private RetryHint buildMultipleChoiceHint(Quiz quiz, List<String> answers) {
        Long submittedChoiceId = parseChoiceId(answers.get(0));
        Long eliminatedChoiceId = quiz.getChoices().stream()
                .filter(choice -> !choice.isCorrect())
                .filter(choice -> !Objects.equals(choice.getId(), submittedChoiceId))
                .min(Comparator.comparingInt(QuizChoice::getDisplayOrder))
                .map(QuizChoice::getId)
                .orElse(null);
        if (eliminatedChoiceId == null) {
            return null;
        }
        return new RetryHint(eliminatedChoiceId, null);
    }

    /**
     * 슬롯마다 첫 키워드의 첫 글자와 공백 제외 글자수를 준다. "첫 키워드"는 그 슬롯에 등록된 순서(엔티티 id
     * 오름차순) 기준 첫 번째다 — 시드에서 한글 표기가 먼저, 영문 동의어가 뒤에 와서 자연스럽게 한글이 힌트가 된다.
     * 글자수는 정답 매칭이 띄어쓰기를 무시하므로(#183) 공백을 제외해 센다. 목록은 {@code slotOrder} 오름차순으로
     * 내려준다. 키워드가 등록되지 않은 문제는 힌트 없이({@code null}) 넘어간다.
     */
    private RetryHint buildKeywordBlankHint(Quiz quiz) {
        Map<Integer, List<QuizAnswerKeyword>> keywordsBySlot =
                quiz.getAnswerKeywords().stream().collect(Collectors.groupingBy(QuizAnswerKeyword::getSlotOrder));
        if (keywordsBySlot.isEmpty()) {
            return null;
        }
        List<RetryHint.BlankHint> blankHints = keywordsBySlot.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> toBlankHint(entry.getKey(), entry.getValue()))
                .toList();
        return new RetryHint(null, blankHints);
    }

    private RetryHint.BlankHint toBlankHint(int slotOrder, List<QuizAnswerKeyword> slotKeywords) {
        String keyword = slotKeywords.stream()
                .min(Comparator.comparing(QuizAnswerKeyword::getId))
                .map(QuizAnswerKeyword::getKeyword)
                .orElseThrow();
        String withoutWhitespace = normalizeBlankAnswer(keyword);
        return new RetryHint.BlankHint(slotOrder, withoutWhitespace.substring(0, 1), withoutWhitespace.length());
    }

    /**
     * 유저의 현재 진행 스텝보다 미래인 스텝의 문제는 제출할 수 없다 — {@code /next}를 거치지 않고
     * quizId를 추측해 앞선 스텝을 건너뛰는 것을 막는다. 현재 스텝과 과거 스텝은 허용한다(복습 여지).
     */
    private void validateAccessible(Long userId, Quiz quiz) {
        validateAccessible(userId, quiz.getStepOrder());
    }

    private void validateAccessible(Long userId, int stepOrder) {
        int currentStepOrder = quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);
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

    private static String normalizeBlankAnswer(String raw) {
        return BLANK_ANSWER_WHITESPACE.matcher(raw).replaceAll("");
    }

    /**
     * 이 유저가 스텝의 모든 문제를 한 번씩 시도했는지 확인하고, 그렇다면 다음 스텝으로 진행시킨다.
     *
     * <p>같은 유저가 같은 스텝의 마지막 문제 두 개를 동시에 제출하면, 서로 상대방의 커밋을 못 본 채
     * 둘 다 "아직 미완료"로 판단해 진행이 영영 갱신되지 않는 레이스가 생길 수 있다. 이를 막기 위해
     * 진행 상태 행을 유저 단위로 비관적 락({@link QuizProgressRepository#findByUserIdForUpdate})으로
     * 잠가 이 구간을 직렬화한다 — 먼저 온 요청이 커밋할 때까지 나중 요청은 대기했다가, 커밋 후의
     * 최신 시도 이력을 다시 읽는다. 격리 수준을 READ_COMMITTED로 낮춘 이유도 이것과 짝을 이룬다 —
     * 기본 REPEATABLE READ에서는 트랜잭션 최초 조회 시점의 스냅샷이 고정되어, 락을 기다렸다 얻은
     * 뒤에도 그 사이 다른 트랜잭션이 커밋한 시도 이력을 못 볼 수 있다.
     */
    private void advanceProgressIfStepCompleted(Long userId, int stepOrder) {
        QuizProgress progress = lockOrCreateProgress(userId);

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
            userProgressService.recordStepCompletion(userId, LocalDate.now(clock.withZone(TimeZones.KST)));
        }
    }

    /**
     * 진행 상태 행을 락을 건 채로 가져온다. 없으면 새로 만든다 — 유저가 처음으로 스텝을 완료하는
     * 순간 두 요청이 동시에 "행이 없다"를 보고 둘 다 생성을 시도할 수 있으므로, 유니크 제약 위반은
     * 상대가 먼저 만든 행을 락으로 다시 읽어 해소한다.
     */
    private QuizProgress lockOrCreateProgress(Long userId) {
        Optional<QuizProgress> existing = quizProgressRepository.findByUserIdForUpdate(userId);
        if (existing.isPresent()) {
            return existing.get();
        }
        try {
            return quizProgressRepository.saveAndFlush(QuizProgress.create(userId));
        } catch (DataIntegrityViolationException e) {
            return quizProgressRepository.findByUserIdForUpdate(userId).orElseThrow();
        }
    }
}

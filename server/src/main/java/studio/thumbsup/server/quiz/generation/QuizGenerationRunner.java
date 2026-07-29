package studio.thumbsup.server.quiz.generation;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.LearningErrorType;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 문제 생성 파이프라인의 CLI 진입점(#26). 비용이 드는 LLM 호출이라 상시 HTTP 엔드포인트로 열지 않고,
 * {@code generate} 프로파일을 명시적으로 켰을 때만 동작한다 — 예:
 * {@code ./gradlew bootRun --args='--spring.profiles.active=local,generate --topic=운영체제 --steps=1'}
 * (스텝마다 다른 주제, 한 줄에 하나씩 적은 파일) {@code --args='--spring.profiles.active=local,generate
 * --topicsFile=/path/to/topics.txt'} — Gradle {@code --args}는 공백 기준으로 토큰을 쪼개기 때문에, 주제에
 * 공백이 들어가면 {@code --topics=a,b,c} 콤마 나열 방식은 깨진다. 여러 주제를 쓸 때는 반드시 파일 방식을 쓴다.
 * {@code --level=basic|standard|advanced}로 콘텐츠 난이도 힌트를 줄 수 있다(기본 standard — 힌트 없음).
 * {@code --courseId=<id>}로 소속 코스를 지정한다 — 생략하면 가장 먼저 생성된 코스(운영체제)로 계속 생성된다,
 * 즉 기존 사용법은 그대로 동작한다. 한 번의 실행에 포함된 모든 스텝에 동일하게 적용된다.
 * 실행 후에는 웹서버로 남지 않고 즉시 종료한다.
 */
@Component
@Profile("generate")
public class QuizGenerationRunner implements ApplicationRunner {

    private static final String DEFAULT_TOPIC = "운영체제";
    private static final int DEFAULT_STEPS = 1;
    private static final String DEFAULT_LEVEL = "standard";

    private final QuizGenerationService quizGenerationService;
    private final CourseRepository courseRepository;
    private final ApplicationContext applicationContext;

    public QuizGenerationRunner(
            QuizGenerationService quizGenerationService,
            CourseRepository courseRepository,
            ApplicationContext applicationContext) {
        this.quizGenerationService = quizGenerationService;
        this.courseRepository = courseRepository;
        this.applicationContext = applicationContext;
    }

    @Override
    public void run(ApplicationArguments args) {
        final int exitCode = runGeneration(args);
        System.exit(SpringApplication.exit(applicationContext, () -> exitCode));
    }

    private int runGeneration(ApplicationArguments args) {
        try {
            List<String> topics = resolveTopics(args);
            GenerationLevel level = resolveLevel(args);
            Long courseId = resolveCourseId(args);
            System.out.printf("문제 생성 시작 — 스텝 수: %d, 난이도: %s, 코스 id: %d%n", topics.size(), level, courseId);
            for (int i = 0; i < topics.size(); i++) {
                int stepOrder = quizGenerationService.generateStep(courseId, topics.get(i), level);
                System.out.printf("스텝 %d 생성 완료 — 주제: %s (%d/%d)%n", stepOrder, topics.get(i), i + 1, topics.size());
            }
            return 0;
        } catch (Exception e) {
            System.err.println("문제 생성 실패: " + e.getMessage());
            return 1;
        }
    }

    /** {@code --courseId} 생략 시 가장 먼저 생성된 코스(운영체제)를 쓴다 — 기존 CLI 사용법과 호환. */
    private Long resolveCourseId(ApplicationArguments args) {
        if (args.containsOption("courseId") && !args.getOptionValues("courseId").isEmpty()) {
            return Long.valueOf(args.getOptionValues("courseId").get(0));
        }
        return courseRepository
                .findFirstByOrderByIdAsc()
                .map(Course::getId)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }

    /**
     * {@code --level=basic|standard|advanced} — 대소문자 무관, 기본값 standard(콘텐츠 난이도 힌트 없음).
     * 값이 잘못되면 {@link GenerationLevel#valueOf}가 자체적으로 예외를 던지게 둔다({@code --steps}의
     * {@link Integer#parseInt}와 같은 패턴) — 표준 예외를 직접 생성하면 ArchUnit "표준_예외_생성_금지"
     * 규칙(BusinessException(ErrorType)으로만 던진다)에 걸린다. CLI 도구라 어차피 이 예외는
     * {@link #runGeneration}에서 잡아 메시지만 stderr에 출력하고 종료한다.
     */
    private GenerationLevel resolveLevel(ApplicationArguments args) {
        String raw = optionValue(args, "level", DEFAULT_LEVEL).trim().toUpperCase(Locale.ROOT);
        return GenerationLevel.valueOf(raw);
    }

    /**
     * 우선순위: {@code --topicsFile}(한 줄에 주제 하나씩, 공백 포함 주제도 안전) →
     * {@code --topics}(콤마 구분 — 주제에 공백이 없을 때만 안전) → {@code --topic}/{@code --steps}(반복).
     */
    private List<String> resolveTopics(ApplicationArguments args) throws IOException {
        if (args.containsOption("topicsFile")
                && !args.getOptionValues("topicsFile").isEmpty()) {
            Path path = Path.of(args.getOptionValues("topicsFile").get(0));
            return Files.readAllLines(path).stream()
                    .map(String::trim)
                    .filter(topic -> !topic.isEmpty())
                    .toList();
        }
        if (args.containsOption("topics") && !args.getOptionValues("topics").isEmpty()) {
            return Arrays.stream(args.getOptionValues("topics").get(0).split(","))
                    .map(String::trim)
                    .filter(topic -> !topic.isEmpty())
                    .toList();
        }
        String topic = optionValue(args, "topic", DEFAULT_TOPIC);
        int steps = Integer.parseInt(optionValue(args, "steps", String.valueOf(DEFAULT_STEPS)));
        return Collections.nCopies(steps, topic);
    }

    private String optionValue(ApplicationArguments args, String name, String defaultValue) {
        if (!args.containsOption(name) || args.getOptionValues(name).isEmpty()) {
            return defaultValue;
        }
        return args.getOptionValues(name).get(0);
    }
}

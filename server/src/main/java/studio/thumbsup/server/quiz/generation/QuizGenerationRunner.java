package studio.thumbsup.server.quiz.generation;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 문제 생성 파이프라인의 CLI 진입점(#26). 비용이 드는 LLM 호출이라 상시 HTTP 엔드포인트로 열지 않고,
 * {@code generate} 프로파일을 명시적으로 켰을 때만 동작한다 — 예:
 * {@code ./gradlew bootRun --args='--spring.profiles.active=local,generate --topic=운영체제 --steps=1'}
 * (스텝마다 다른 주제, 한 줄에 하나씩 적은 파일) {@code --args='--spring.profiles.active=local,generate
 * --topicsFile=/path/to/topics.txt'} — Gradle {@code --args}는 공백 기준으로 토큰을 쪼개기 때문에, 주제에
 * 공백이 들어가면 {@code --topics=a,b,c} 콤마 나열 방식은 깨진다. 여러 주제를 쓸 때는 반드시 파일 방식을 쓴다.
 * 실행 후에는 웹서버로 남지 않고 즉시 종료한다.
 */
@Component
@Profile("generate")
public class QuizGenerationRunner implements ApplicationRunner {

    private static final String DEFAULT_TOPIC = "운영체제";
    private static final int DEFAULT_STEPS = 1;

    private final QuizGenerationService quizGenerationService;
    private final ApplicationContext applicationContext;

    public QuizGenerationRunner(QuizGenerationService quizGenerationService, ApplicationContext applicationContext) {
        this.quizGenerationService = quizGenerationService;
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
            System.out.printf("문제 생성 시작 — 스텝 수: %d%n", topics.size());
            for (int i = 0; i < topics.size(); i++) {
                int stepOrder = quizGenerationService.generateStep(topics.get(i));
                System.out.printf("스텝 %d 생성 완료 — 주제: %s (%d/%d)%n", stepOrder, topics.get(i), i + 1, topics.size());
            }
            return 0;
        } catch (Exception e) {
            System.err.println("문제 생성 실패: " + e.getMessage());
            return 1;
        }
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

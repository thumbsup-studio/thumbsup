package studio.thumbsup.server.quiz.generation;

import java.time.Duration;
import java.util.List;
import org.springframework.boot.http.client.ClientHttpRequestFactoryBuilder;
import org.springframework.boot.http.client.ClientHttpRequestFactorySettings;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 엘리스AX ML API(OpenAI 호환 프록시) 클라이언트 — 문제 생성 용도 전용(스킬 elice-models §용도별 모델).
 * base URL·모델은 용도별로 다르므로 이 클라이언트를 다른 용도(시각 QA 등)와 공유하지 않는다.
 */
@Component
public class EliceClient {

    private static final String RESPONSE_FORMAT_JSON = "json_object";
    private static final double TEMPERATURE = 0.2; // 사실 기반 콘텐츠라 창의성보다 일관성 우선
    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);
    private static final Duration READ_TIMEOUT = Duration.ofMinutes(2); // 문제 5개 생성은 수십 초가 걸릴 수 있다

    private static final String SYSTEM_PROMPT = """
            너는 컴퓨터공학 전공 교재 수준의 정확성을 가진 CS 강사이며, 학습자의 이해도를 확인하는 퀴즈를 만든다.

            - 사실 기반으로만 작성한다. 확실하지 않은 내용, 검증되지 않은 수치·통계, 존재하지 않는 개념이나
              용어를 지어내지 않는다. 확신이 없으면 더 널리 알려진 확실한 소재로 대체한다.
            - 사용자가 제시한 JSON 스키마를 한 글자도 벗어나지 않고 정확히 지킨다. 스키마에 없는 필드를
              추가하거나, 요구된 필드를 누락하거나, 타입(문자열/배열/불리언 등)을 다르게 쓰지 않는다.
            - 응답은 오직 유효한 JSON 객체 하나뿐이어야 한다. 인사말, 설명 문장, 주석, 마크다운 코드펜스
              (```)는 절대 포함하지 않는다.
            """;

    private final RestClient restClient;
    private final EliceProperties properties;

    public EliceClient(EliceProperties properties) {
        this.properties = properties;
        ClientHttpRequestFactorySettings settings = ClientHttpRequestFactorySettings.defaults()
                .withConnectTimeout(CONNECT_TIMEOUT)
                .withReadTimeout(READ_TIMEOUT);
        ClientHttpRequestFactory requestFactory =
                ClientHttpRequestFactoryBuilder.detect().build(settings);
        this.restClient = RestClient.builder()
                .baseUrl(properties.baseUrl())
                .requestFactory(requestFactory)
                .build();
    }

    /** 프롬프트를 보내고 모델 응답 본문(텍스트)을 그대로 반환한다 — JSON 파싱은 호출자의 몫. */
    public String generate(String prompt) {
        EliceChatRequest request = new EliceChatRequest(
                properties.model(),
                List.of(
                        new EliceChatRequest.Message("system", SYSTEM_PROMPT),
                        new EliceChatRequest.Message("user", prompt)),
                TEMPERATURE,
                new EliceChatRequest.ResponseFormat(RESPONSE_FORMAT_JSON));

        EliceChatResponse response = restClient
                .post()
                .uri("/chat/completions")
                .contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + properties.apiKey())
                .body(request)
                .retrieve()
                .body(EliceChatResponse.class);

        if (response == null || response.choices() == null || response.choices().isEmpty()) {
            throw new QuizGenerationException("엘리스 API가 빈 응답을 반환했습니다.");
        }
        return response.choices().get(0).message().content();
    }
}

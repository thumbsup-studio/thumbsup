package studio.thumbsup.server.quiz.generation;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/** 엘리스AX ML API(OpenAI 호환) chat/completions 요청. */
record EliceChatRequest(
        String model,
        List<Message> messages,
        double temperature,
        @JsonProperty("response_format") ResponseFormat responseFormat) {

    record Message(String role, String content) {}

    record ResponseFormat(String type) {}
}

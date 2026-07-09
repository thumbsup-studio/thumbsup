package studio.thumbsup.server.quiz.generation;

import java.util.List;

/** 엘리스AX ML API(OpenAI 호환) chat/completions 응답 — 필요한 필드만 매핑한다. */
record EliceChatResponse(List<Choice> choices) {

    record Choice(Message message) {}

    record Message(String content) {}
}

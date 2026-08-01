package studio.thumbsup.server.quiz.history.dto;

import java.time.LocalDate;
import java.util.List;
import studio.thumbsup.server.quiz.concept.Concept;

/** 지식 그래프 조회 응답(#233) — 유저가 학습한 개념(노드)과 그 관계(엣지). */
public record HistoryGraphResponse(List<Node> nodes, List<Edge> edges) {

    public record Node(
            String id,
            String label,
            List<String> description,
            LocalDate learnedAt,
            String category,
            List<RelatedStep> relatedSteps) {

        public static Node from(
                Concept concept, List<String> description, LocalDate learnedAt, List<RelatedStep> relatedSteps) {
            return new Node(
                    concept.getId().toString(),
                    concept.getName(),
                    description,
                    learnedAt,
                    concept.getCategory(),
                    relatedSteps);
        }
    }

    public record RelatedStep(int stepOrder, String topic) {}

    public record Edge(String source, String target) {}
}

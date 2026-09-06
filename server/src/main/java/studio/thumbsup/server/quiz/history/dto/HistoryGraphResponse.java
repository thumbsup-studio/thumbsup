package studio.thumbsup.server.quiz.history.dto;

import java.time.LocalDate;
import java.util.List;
import studio.thumbsup.server.quiz.tag.Tag;

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
                Tag tag, List<String> description, LocalDate learnedAt, List<RelatedStep> relatedSteps) {
            return new Node(
                    tag.getId().toString(), tag.getName(), description, learnedAt, tag.getCategory(), relatedSteps);
        }
    }

    /** stepOrder는 코스 내 상대 순번이라(#292) courseId 없이는 어느 코스의 몇 번째 스텝인지 알 수 없다. */
    public record RelatedStep(Long courseId, int stepOrder, String topic) {}

    public record Edge(String source, String target) {}
}

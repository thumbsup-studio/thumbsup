package studio.thumbsup.server.quiz.history;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.Edge;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.Node;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.RelatedStep;
import studio.thumbsup.server.quiz.tag.Tag;
import studio.thumbsup.server.quiz.tag.TagDescription;
import studio.thumbsup.server.quiz.tag.TagDescriptionRepository;
import studio.thumbsup.server.quiz.tag.TagRelation;
import studio.thumbsup.server.quiz.tag.TagRelationRepository;
import studio.thumbsup.server.quiz.tag.TagRepository;
import studio.thumbsup.server.quiz.tag.UserTag;
import studio.thumbsup.server.quiz.tag.UserTagRepository;
import studio.thumbsup.server.quiz.tag.UserTagStep;
import studio.thumbsup.server.quiz.tag.UserTagStepRepository;

/**
 * 지식 그래프 조회(#233) — 데이터 소스는 {@code user_tag}/{@code user_tag_step} 하나뿐이다.
 * 유저가 완료한 스텝을 실시간으로 조인·계산하지 않는다({@code QuizService}가 스텝 완료 시점에 이미
 * 기록해 두었기 때문) — 그래서 코스·스텝 수가 늘어나도 이 조회 비용은 유저가 학습한 태그 수에만 비례한다.
 */
@Service
@Transactional(readOnly = true)
public class HistoryService {

    private final UserTagRepository userTagRepository;
    private final UserTagStepRepository userTagStepRepository;
    private final TagRepository tagRepository;
    private final TagDescriptionRepository tagDescriptionRepository;
    private final TagRelationRepository tagRelationRepository;
    private final QuizStepRepository quizStepRepository;

    public HistoryService(
            UserTagRepository userTagRepository,
            UserTagStepRepository userTagStepRepository,
            TagRepository tagRepository,
            TagDescriptionRepository tagDescriptionRepository,
            TagRelationRepository tagRelationRepository,
            QuizStepRepository quizStepRepository) {
        this.userTagRepository = userTagRepository;
        this.userTagStepRepository = userTagStepRepository;
        this.tagRepository = tagRepository;
        this.tagDescriptionRepository = tagDescriptionRepository;
        this.tagRelationRepository = tagRelationRepository;
        this.quizStepRepository = quizStepRepository;
    }

    public HistoryGraphResponse getGraph(Long userId) {
        List<UserTag> learned = userTagRepository.findByUserId(userId);
        if (learned.isEmpty()) {
            return new HistoryGraphResponse(List.of(), List.of());
        }

        Map<Long, Instant> learnedAtByTagId =
                learned.stream().collect(Collectors.toMap(UserTag::getTagId, UserTag::getCreatedAt));
        Set<Long> tagIds = learnedAtByTagId.keySet();

        Map<Long, List<UserTagStep>> learnedStepsByTagId =
                userTagStepRepository.findByUserIdAndTagIdIn(userId, tagIds).stream()
                        .collect(Collectors.groupingBy(UserTagStep::getTagId));

        Map<Long, List<RelatedStep>> relatedStepsByTagId = relatedStepsByTagId(learnedStepsByTagId);
        Map<Long, List<String>> descriptionsByTagId = descriptionsByTagId(tagIds, learnedStepsByTagId);

        Map<Long, Tag> tagById =
                tagRepository.findAllById(tagIds).stream().collect(Collectors.toMap(Tag::getId, t -> t));

        List<Node> nodes = tagIds.stream()
                .filter(tagById::containsKey)
                .sorted()
                .map(id -> Node.from(
                        tagById.get(id),
                        descriptionsByTagId.getOrDefault(id, List.of()),
                        learnedAtByTagId.get(id).atZone(TimeZones.KST).toLocalDate(),
                        relatedStepsByTagId.getOrDefault(id, List.of())))
                .toList();

        Set<Long> nodeIds = tagById.keySet();
        List<Edge> edges = tagRelationRepository.findBySourceTagIdInAndTargetTagIdIn(nodeIds, nodeIds).stream()
                .sorted(Comparator.comparing(TagRelation::getSourceTagId).thenComparing(TagRelation::getTargetTagId))
                .map(r -> new Edge(
                        r.getSourceTagId().toString(), r.getTargetTagId().toString()))
                .toList();

        return new HistoryGraphResponse(nodes, edges);
    }

    private Map<Long, List<RelatedStep>> relatedStepsByTagId(Map<Long, List<UserTagStep>> learnedStepsByTagId) {
        Set<Long> quizStepIds = learnedStepsByTagId.values().stream()
                .flatMap(List::stream)
                .map(UserTagStep::getQuizStepId)
                .collect(Collectors.toSet());
        Map<Long, QuizStep> stepById =
                quizStepRepository.findAllById(quizStepIds).stream().collect(Collectors.toMap(QuizStep::getId, s -> s));

        return learnedStepsByTagId.entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, entry -> entry.getValue().stream()
                        // stepOrder는 코스 상대 순번이라(#292) 코스 없이 정렬하면 서로 다른 코스의 스텝이
                        // 뒤섞일 수 있다 — courseId를 우선 키로 둔다.
                        .sorted(Comparator.<UserTagStep, Long>comparing(
                                        s -> stepById.get(s.getQuizStepId()).getCourseId())
                                .thenComparing(
                                        s -> stepById.get(s.getQuizStepId()).getStepOrder()))
                        .map(s -> {
                            QuizStep step = stepById.get(s.getQuizStepId());
                            return new RelatedStep(step.getCourseId(), step.getStepOrder(), step.getTopic());
                        })
                        .toList()));
    }

    /** 유저가 실제로 완료한 스텝에 해당하는 설명 문장만 골라, 아직 안 배운 스텝의 뉘앙스가 미리 노출되지 않게 한다. */
    private Map<Long, List<String>> descriptionsByTagId(
            Set<Long> tagIds, Map<Long, List<UserTagStep>> learnedStepsByTagId) {
        Map<Long, Set<Long>> learnedQuizStepIdsByTagId = learnedStepsByTagId.entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, entry -> entry.getValue().stream()
                        .map(UserTagStep::getQuizStepId)
                        .collect(Collectors.toSet())));

        return tagDescriptionRepository.findByTagIdIn(tagIds).stream()
                .filter(d -> learnedQuizStepIdsByTagId
                        .getOrDefault(d.getTagId(), Set.of())
                        .contains(d.getQuizStepId()))
                .collect(Collectors.groupingBy(
                        TagDescription::getTagId,
                        Collectors.collectingAndThen(Collectors.toList(), list -> list.stream()
                                .sorted(Comparator.comparing(TagDescription::getQuizStepId))
                                .map(TagDescription::getContent)
                                .toList())));
    }
}

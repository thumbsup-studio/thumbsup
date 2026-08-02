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
import studio.thumbsup.server.quiz.concept.Concept;
import studio.thumbsup.server.quiz.concept.ConceptDescription;
import studio.thumbsup.server.quiz.concept.ConceptDescriptionRepository;
import studio.thumbsup.server.quiz.concept.ConceptRelation;
import studio.thumbsup.server.quiz.concept.ConceptRelationRepository;
import studio.thumbsup.server.quiz.concept.ConceptRepository;
import studio.thumbsup.server.quiz.concept.UserConcept;
import studio.thumbsup.server.quiz.concept.UserConceptRepository;
import studio.thumbsup.server.quiz.concept.UserConceptStep;
import studio.thumbsup.server.quiz.concept.UserConceptStepRepository;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.Edge;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.Node;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.RelatedStep;

/**
 * 지식 그래프 조회(#233) — 데이터 소스는 {@code user_concept}/{@code user_concept_step} 하나뿐이다.
 * 유저가 완료한 스텝을 실시간으로 조인·계산하지 않는다({@code QuizService}가 스텝 완료 시점에 이미
 * 기록해 두었기 때문) — 그래서 코스·스텝 수가 늘어나도 이 조회 비용은 유저가 학습한 개념 수에만 비례한다.
 */
@Service
@Transactional(readOnly = true)
public class HistoryService {

    private final UserConceptRepository userConceptRepository;
    private final UserConceptStepRepository userConceptStepRepository;
    private final ConceptRepository conceptRepository;
    private final ConceptDescriptionRepository conceptDescriptionRepository;
    private final ConceptRelationRepository conceptRelationRepository;
    private final QuizStepRepository quizStepRepository;

    public HistoryService(
            UserConceptRepository userConceptRepository,
            UserConceptStepRepository userConceptStepRepository,
            ConceptRepository conceptRepository,
            ConceptDescriptionRepository conceptDescriptionRepository,
            ConceptRelationRepository conceptRelationRepository,
            QuizStepRepository quizStepRepository) {
        this.userConceptRepository = userConceptRepository;
        this.userConceptStepRepository = userConceptStepRepository;
        this.conceptRepository = conceptRepository;
        this.conceptDescriptionRepository = conceptDescriptionRepository;
        this.conceptRelationRepository = conceptRelationRepository;
        this.quizStepRepository = quizStepRepository;
    }

    public HistoryGraphResponse getGraph(Long userId) {
        List<UserConcept> learned = userConceptRepository.findByUserId(userId);
        if (learned.isEmpty()) {
            return new HistoryGraphResponse(List.of(), List.of());
        }

        Map<Long, Instant> learnedAtByConceptId =
                learned.stream().collect(Collectors.toMap(UserConcept::getConceptId, UserConcept::getCreatedAt));
        Set<Long> conceptIds = learnedAtByConceptId.keySet();

        Map<Long, List<UserConceptStep>> learnedStepsByConceptId =
                userConceptStepRepository.findByUserIdAndConceptIdIn(userId, conceptIds).stream()
                        .collect(Collectors.groupingBy(UserConceptStep::getConceptId));

        Map<Long, List<RelatedStep>> relatedStepsByConceptId = relatedStepsByConceptId(learnedStepsByConceptId);
        Map<Long, List<String>> descriptionsByConceptId = descriptionsByConceptId(conceptIds, learnedStepsByConceptId);

        Map<Long, Concept> conceptById =
                conceptRepository.findAllById(conceptIds).stream().collect(Collectors.toMap(Concept::getId, c -> c));

        List<Node> nodes = conceptIds.stream()
                .filter(conceptById::containsKey)
                .sorted()
                .map(id -> Node.from(
                        conceptById.get(id),
                        descriptionsByConceptId.getOrDefault(id, List.of()),
                        learnedAtByConceptId.get(id).atZone(TimeZones.KST).toLocalDate(),
                        relatedStepsByConceptId.getOrDefault(id, List.of())))
                .toList();

        Set<Long> nodeIds = conceptById.keySet();
        List<Edge> edges =
                conceptRelationRepository.findBySourceConceptIdInAndTargetConceptIdIn(nodeIds, nodeIds).stream()
                        .sorted(Comparator.comparing(ConceptRelation::getSourceConceptId)
                                .thenComparing(ConceptRelation::getTargetConceptId))
                        .map(r -> new Edge(
                                r.getSourceConceptId().toString(),
                                r.getTargetConceptId().toString()))
                        .toList();

        return new HistoryGraphResponse(nodes, edges);
    }

    private Map<Long, List<RelatedStep>> relatedStepsByConceptId(
            Map<Long, List<UserConceptStep>> learnedStepsByConceptId) {
        Set<Integer> stepOrders = learnedStepsByConceptId.values().stream()
                .flatMap(List::stream)
                .map(UserConceptStep::getStepOrder)
                .collect(Collectors.toSet());
        Map<Integer, String> topicByStepOrder = quizStepRepository.findByStepOrderIn(stepOrders).stream()
                .collect(Collectors.toMap(QuizStep::getStepOrder, QuizStep::getTopic));

        return learnedStepsByConceptId.entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, entry -> entry.getValue().stream()
                        .sorted(Comparator.comparingInt(UserConceptStep::getStepOrder))
                        .map(s -> new RelatedStep(s.getStepOrder(), topicByStepOrder.get(s.getStepOrder())))
                        .toList()));
    }

    /** 유저가 실제로 완료한 step_order에 해당하는 설명 문장만 골라, 아직 안 배운 스텝의 뉘앙스가 미리 노출되지 않게 한다. */
    private Map<Long, List<String>> descriptionsByConceptId(
            Set<Long> conceptIds, Map<Long, List<UserConceptStep>> learnedStepsByConceptId) {
        Map<Long, Set<Integer>> learnedStepOrdersByConceptId = learnedStepsByConceptId.entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, entry -> entry.getValue().stream()
                        .map(UserConceptStep::getStepOrder)
                        .collect(Collectors.toSet())));

        return conceptDescriptionRepository.findByConceptIdIn(conceptIds).stream()
                .filter(d -> learnedStepOrdersByConceptId
                        .getOrDefault(d.getConceptId(), Set.of())
                        .contains(d.getStepOrder()))
                .collect(Collectors.groupingBy(
                        ConceptDescription::getConceptId,
                        Collectors.collectingAndThen(Collectors.toList(), list -> list.stream()
                                .sorted(Comparator.comparingInt(ConceptDescription::getStepOrder))
                                .map(ConceptDescription::getContent)
                                .toList())));
    }
}

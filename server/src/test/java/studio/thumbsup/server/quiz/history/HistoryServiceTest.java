package studio.thumbsup.server.quiz.history;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.concept.Concept;
import studio.thumbsup.server.quiz.concept.ConceptDescriptionRepository;
import studio.thumbsup.server.quiz.concept.ConceptFixture;
import studio.thumbsup.server.quiz.concept.ConceptRelationRepository;
import studio.thumbsup.server.quiz.concept.ConceptRepository;
import studio.thumbsup.server.quiz.concept.UserConceptRepository;
import studio.thumbsup.server.quiz.concept.UserConceptStepRepository;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse;

/** Service 단위 테스트 — Spring 없이 Mockito로 그래프 조립 로직만 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("지식 그래프 서비스")
class HistoryServiceTest {

    private static final Long USER_ID = 1L;

    @Mock
    private UserConceptRepository userConceptRepository;

    @Mock
    private UserConceptStepRepository userConceptStepRepository;

    @Mock
    private ConceptRepository conceptRepository;

    @Mock
    private ConceptDescriptionRepository conceptDescriptionRepository;

    @Mock
    private ConceptRelationRepository conceptRelationRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    private HistoryService historyService;

    private HistoryService service() {
        return new HistoryService(
                userConceptRepository,
                userConceptStepRepository,
                conceptRepository,
                conceptDescriptionRepository,
                conceptRelationRepository,
                quizStepRepository);
    }

    @Nested
    @DisplayName("그래프 조회")
    class GetGraph {

        @Test
        @DisplayName("학습한 개념이 없으면 빈 nodes/edges를 반환한다")
        void returns_empty_graph_when_nothing_learned() {
            historyService = service();
            given(userConceptRepository.findByUserId(USER_ID)).willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes()).isEmpty();
            assertThat(response.edges()).isEmpty();
        }

        @Test
        @DisplayName("노드는 concept 정보와 learnedAt(KST 날짜), relatedSteps, description을 포함한다")
        void assembles_node_with_concept_detail_and_related_steps() {
            historyService = service();
            Instant learnedAt = Instant.parse("2026-07-08T15:00:00Z"); // KST 2026-07-09 00:00
            given(userConceptRepository.findByUserId(USER_ID))
                    .willReturn(List.of(ConceptFixture.userConcept(USER_ID, 1L, learnedAt)));
            given(userConceptStepRepository.findByUserIdAndConceptIdIn(USER_ID, Set.of(1L)))
                    .willReturn(List.of(ConceptFixture.userConceptStep(USER_ID, 1L, 1)));
            given(quizStepRepository.findByStepOrderIn(Set.of(1)))
                    .willReturn(List.of(QuizStep.create(1, 1L, "프로세스와 스레드", 10)));
            given(conceptDescriptionRepository.findByConceptIdIn(Set.of(1L)))
                    .willReturn(List.of(ConceptFixture.conceptDescription(1L, "프로세스에 대한 설명이다.", 1)));
            Concept concept = ConceptFixture.concept(1L, "프로세스", "프로세스");
            given(conceptRepository.findAllById(Set.of(1L))).willReturn(List.of(concept));
            given(conceptRelationRepository.findBySourceConceptIdInAndTargetConceptIdIn(Set.of(1L), Set.of(1L)))
                    .willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes()).hasSize(1);
            HistoryGraphResponse.Node node = response.nodes().get(0);
            assertThat(node.id()).isEqualTo("1");
            assertThat(node.label()).isEqualTo("프로세스");
            assertThat(node.category()).isEqualTo("프로세스");
            assertThat(node.description()).containsExactly("프로세스에 대한 설명이다.");
            assertThat(node.learnedAt()).isEqualTo(LocalDate.of(2026, 7, 9)); // UTC 저장 → KST 날짜 변환
            assertThat(node.relatedSteps()).containsExactly(new HistoryGraphResponse.RelatedStep(1, "프로세스와 스레드"));
        }

        @Test
        @DisplayName("양쪽 concept이 모두 학습된 경우에만 엣지를 내려준다")
        void includes_edge_only_when_both_endpoints_are_learned_nodes() {
            historyService = service();
            given(userConceptRepository.findByUserId(USER_ID))
                    .willReturn(List.of(
                            ConceptFixture.userConcept(USER_ID, 1L, Instant.parse("2026-07-08T00:00:00Z")),
                            ConceptFixture.userConcept(USER_ID, 2L, Instant.parse("2026-07-08T00:00:00Z"))));
            given(userConceptStepRepository.findByUserIdAndConceptIdIn(USER_ID, Set.of(1L, 2L)))
                    .willReturn(List.of());
            given(quizStepRepository.findByStepOrderIn(Set.of())).willReturn(List.of());
            given(conceptDescriptionRepository.findByConceptIdIn(Set.of(1L, 2L)))
                    .willReturn(List.of());
            given(conceptRepository.findAllById(Set.of(1L, 2L)))
                    .willReturn(List.of(
                            ConceptFixture.concept(1L, "프로세스", "프로세스"), ConceptFixture.concept(2L, "스레드", "프로세스")));
            given(conceptRelationRepository.findBySourceConceptIdInAndTargetConceptIdIn(Set.of(1L, 2L), Set.of(1L, 2L)))
                    .willReturn(List.of(ConceptFixture.relation(1L, 2L)));

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.edges()).containsExactly(new HistoryGraphResponse.Edge("1", "2"));
        }

        @Test
        @DisplayName("아직 완료하지 않은 스텝의 설명 문장은 노출하지 않는다(스포일러 방지)")
        void excludes_description_facets_from_unfinished_steps() {
            historyService = service();
            Instant learnedAt = Instant.parse("2026-07-08T00:00:00Z");
            given(userConceptRepository.findByUserId(USER_ID))
                    .willReturn(List.of(ConceptFixture.userConcept(USER_ID, 22L, learnedAt)));
            given(userConceptStepRepository.findByUserIdAndConceptIdIn(USER_ID, Set.of(22L)))
                    .willReturn(List.of(ConceptFixture.userConceptStep(USER_ID, 22L, 2))); // 4번 스텝은 아직 미완료
            given(quizStepRepository.findByStepOrderIn(Set.of(2)))
                    .willReturn(List.of(QuizStep.create(2, 1L, "CPU 스케줄링", 10)));
            given(conceptDescriptionRepository.findByConceptIdIn(Set.of(22L)))
                    .willReturn(List.of(
                            ConceptFixture.conceptDescription(22L, "PCB에 상태를 저장·복원하는 작업이다.", 2),
                            ConceptFixture.conceptDescription(22L, "타임 퀀텀이 작으면 오버헤드가 된다.", 4)));
            given(conceptRepository.findAllById(Set.of(22L)))
                    .willReturn(List.of(ConceptFixture.concept(22L, "문맥 전환", "프로세스")));
            given(conceptRelationRepository.findBySourceConceptIdInAndTargetConceptIdIn(Set.of(22L), Set.of(22L)))
                    .willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes().get(0).description()).containsExactly("PCB에 상태를 저장·복원하는 작업이다.");
        }
    }
}

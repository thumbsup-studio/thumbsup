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
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse;
import studio.thumbsup.server.quiz.tag.Tag;
import studio.thumbsup.server.quiz.tag.TagDescriptionRepository;
import studio.thumbsup.server.quiz.tag.TagFixture;
import studio.thumbsup.server.quiz.tag.TagRelationRepository;
import studio.thumbsup.server.quiz.tag.TagRepository;
import studio.thumbsup.server.quiz.tag.UserTagRepository;
import studio.thumbsup.server.quiz.tag.UserTagStepRepository;

/** Service 단위 테스트 — Spring 없이 Mockito로 그래프 조립 로직만 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("지식 그래프 서비스")
class HistoryServiceTest {

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;

    @Mock
    private UserTagRepository userTagRepository;

    @Mock
    private UserTagStepRepository userTagStepRepository;

    @Mock
    private TagRepository tagRepository;

    @Mock
    private TagDescriptionRepository tagDescriptionRepository;

    @Mock
    private TagRelationRepository tagRelationRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    private HistoryService historyService;

    private HistoryService service() {
        return new HistoryService(
                userTagRepository,
                userTagStepRepository,
                tagRepository,
                tagDescriptionRepository,
                tagRelationRepository,
                quizStepRepository);
    }

    /** relatedStepsByTagId가 이 PK로 quizStepRepository.findAllById를 조회하므로(#292) id를 직접 채운다. */
    private static QuizStep stepFixture(Long id, int stepOrder, String topic) {
        QuizStep step = QuizStep.create(stepOrder, COURSE_ID, topic, 10);
        ReflectionTestUtils.setField(step, "id", id);
        return step;
    }

    @Nested
    @DisplayName("그래프 조회")
    class GetGraph {

        @Test
        @DisplayName("학습한 태그가 없으면 빈 nodes/edges를 반환한다")
        void returns_empty_graph_when_nothing_learned() {
            historyService = service();
            given(userTagRepository.findByUserId(USER_ID)).willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes()).isEmpty();
            assertThat(response.edges()).isEmpty();
        }

        @Test
        @DisplayName("노드는 태그 정보와 learnedAt(KST 날짜), relatedSteps, description을 포함한다")
        void assembles_node_with_tag_detail_and_related_steps() {
            historyService = service();
            Instant learnedAt = Instant.parse("2026-07-08T15:00:00Z"); // KST 2026-07-09 00:00
            given(userTagRepository.findByUserId(USER_ID))
                    .willReturn(List.of(TagFixture.userTag(USER_ID, 1L, learnedAt)));
            given(userTagStepRepository.findByUserIdAndTagIdIn(USER_ID, Set.of(1L)))
                    .willReturn(List.of(TagFixture.userTagStep(USER_ID, 1L, 1L)));
            given(quizStepRepository.findAllById(Set.of(1L))).willReturn(List.of(stepFixture(1L, 1, "프로세스와 스레드")));
            given(tagDescriptionRepository.findByTagIdIn(Set.of(1L)))
                    .willReturn(List.of(TagFixture.tagDescription(1L, "프로세스에 대한 설명이다.", 1L)));
            Tag tag = TagFixture.tag(1L, "프로세스", "프로세스");
            given(tagRepository.findAllById(Set.of(1L))).willReturn(List.of(tag));
            given(tagRelationRepository.findBySourceTagIdInAndTargetTagIdIn(Set.of(1L), Set.of(1L)))
                    .willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes()).hasSize(1);
            HistoryGraphResponse.Node node = response.nodes().get(0);
            assertThat(node.id()).isEqualTo("1");
            assertThat(node.label()).isEqualTo("프로세스");
            assertThat(node.category()).isEqualTo("프로세스");
            assertThat(node.description()).containsExactly("프로세스에 대한 설명이다.");
            assertThat(node.learnedAt()).isEqualTo(LocalDate.of(2026, 7, 9)); // UTC 저장 → KST 날짜 변환
            assertThat(node.relatedSteps())
                    .containsExactly(new HistoryGraphResponse.RelatedStep(COURSE_ID, 1, "프로세스와 스레드"));
        }

        @Test
        @DisplayName("양쪽 태그가 모두 학습된 경우에만 엣지를 내려준다")
        void includes_edge_only_when_both_endpoints_are_learned_nodes() {
            historyService = service();
            given(userTagRepository.findByUserId(USER_ID))
                    .willReturn(List.of(
                            TagFixture.userTag(USER_ID, 1L, Instant.parse("2026-07-08T00:00:00Z")),
                            TagFixture.userTag(USER_ID, 2L, Instant.parse("2026-07-08T00:00:00Z"))));
            given(userTagStepRepository.findByUserIdAndTagIdIn(USER_ID, Set.of(1L, 2L)))
                    .willReturn(List.of());
            given(quizStepRepository.findAllById(Set.of())).willReturn(List.of());
            given(tagDescriptionRepository.findByTagIdIn(Set.of(1L, 2L))).willReturn(List.of());
            given(tagRepository.findAllById(Set.of(1L, 2L)))
                    .willReturn(List.of(TagFixture.tag(1L, "프로세스", "프로세스"), TagFixture.tag(2L, "스레드", "프로세스")));
            given(tagRelationRepository.findBySourceTagIdInAndTargetTagIdIn(Set.of(1L, 2L), Set.of(1L, 2L)))
                    .willReturn(List.of(TagFixture.relation(1L, 2L)));

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.edges()).containsExactly(new HistoryGraphResponse.Edge("1", "2"));
        }

        @Test
        @DisplayName("아직 완료하지 않은 스텝의 설명 문장은 노출하지 않는다(스포일러 방지)")
        void excludes_description_facets_from_unfinished_steps() {
            historyService = service();
            Instant learnedAt = Instant.parse("2026-07-08T00:00:00Z");
            given(userTagRepository.findByUserId(USER_ID))
                    .willReturn(List.of(TagFixture.userTag(USER_ID, 22L, learnedAt)));
            given(userTagStepRepository.findByUserIdAndTagIdIn(USER_ID, Set.of(22L)))
                    .willReturn(List.of(TagFixture.userTagStep(USER_ID, 22L, 2L))); // 4번 스텝은 아직 미완료
            given(quizStepRepository.findAllById(Set.of(2L))).willReturn(List.of(stepFixture(2L, 2, "CPU 스케줄링")));
            given(tagDescriptionRepository.findByTagIdIn(Set.of(22L)))
                    .willReturn(List.of(
                            TagFixture.tagDescription(22L, "PCB에 상태를 저장·복원하는 작업이다.", 2L),
                            TagFixture.tagDescription(22L, "타임 퀀텀이 작으면 오버헤드가 된다.", 4L)));
            given(tagRepository.findAllById(Set.of(22L))).willReturn(List.of(TagFixture.tag(22L, "문맥 전환", "프로세스")));
            given(tagRelationRepository.findBySourceTagIdInAndTargetTagIdIn(Set.of(22L), Set.of(22L)))
                    .willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes().get(0).description()).containsExactly("PCB에 상태를 저장·복원하는 작업이다.");
        }

        @Test
        @DisplayName("퀴즈 하나에 태그가 여럿 붙어도(#324) 각 태그가 독립된 노드로 확장된다")
        void expands_multiple_tags_from_a_single_quiz_into_separate_nodes() {
            historyService = service();
            Instant learnedAt = Instant.parse("2026-07-08T00:00:00Z");
            given(userTagRepository.findByUserId(USER_ID))
                    .willReturn(List.of(
                            TagFixture.userTag(USER_ID, 1L, learnedAt),
                            TagFixture.userTag(USER_ID, 2L, learnedAt),
                            TagFixture.userTag(USER_ID, 3L, learnedAt)));
            given(userTagStepRepository.findByUserIdAndTagIdIn(USER_ID, Set.of(1L, 2L, 3L)))
                    .willReturn(List.of(
                            TagFixture.userTagStep(USER_ID, 1L, 1L),
                            TagFixture.userTagStep(USER_ID, 2L, 1L),
                            TagFixture.userTagStep(USER_ID, 3L, 1L)));
            given(quizStepRepository.findAllById(Set.of(1L))).willReturn(List.of(stepFixture(1L, 1, "프로세스와 스레드")));
            given(tagDescriptionRepository.findByTagIdIn(Set.of(1L, 2L, 3L))).willReturn(List.of());
            given(tagRepository.findAllById(Set.of(1L, 2L, 3L)))
                    .willReturn(List.of(
                            TagFixture.tag(1L, "프로세스", "프로세스"),
                            TagFixture.tag(2L, "스레드", "프로세스"),
                            TagFixture.tag(3L, "문맥 전환", "프로세스")));
            given(tagRelationRepository.findBySourceTagIdInAndTargetTagIdIn(Set.of(1L, 2L, 3L), Set.of(1L, 2L, 3L)))
                    .willReturn(List.of());

            HistoryGraphResponse response = historyService.getGraph(USER_ID);

            assertThat(response.nodes()).hasSize(3);
            assertThat(response.nodes()).allSatisfy(node -> assertThat(node.relatedSteps())
                    .containsExactly(new HistoryGraphResponse.RelatedStep(COURSE_ID, 1, "프로세스와 스레드")));
        }
    }
}

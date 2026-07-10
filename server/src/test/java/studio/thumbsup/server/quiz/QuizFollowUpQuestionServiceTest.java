package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.BDDMockito.given;

import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.FollowUpQuestionDetailResponse;

/** Service 단위 테스트 — 꼬리질문 상세 조립 규칙과 예외 분기를 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
class QuizFollowUpQuestionServiceTest {

    private static final long FOLLOW_UP_QUESTION_ID = 17L;
    private static final long SOURCE_QUIZ_ID = 3L;
    private static final long ABSENT_ID = 999L;

    @Mock
    private QuizFollowUpQuestionRepository quizFollowUpQuestionRepository;

    private QuizFollowUpQuestionService service() {
        return new QuizFollowUpQuestionService(quizFollowUpQuestionRepository);
    }

    private void givenFollowUpQuestion(QuizFollowUpQuestion followUpQuestion) {
        given(quizFollowUpQuestionRepository.findWithQuizById(FOLLOW_UP_QUESTION_ID))
                .willReturn(Optional.of(followUpQuestion));
    }

    @Nested
    @DisplayName("꼬리질문 상세 조회")
    class GetDetail {

        @Test
        @DisplayName("출처 문제 순번·난이도·질문·한 줄 답·상세 블록·키워드 사전을 함께 반환한다")
        void returns_full_detail() {
            givenFollowUpQuestion(QuizFixture.detailedFollowUpQuestion(FOLLOW_UP_QUESTION_ID, SOURCE_QUIZ_ID));

            FollowUpQuestionDetailResponse response = service().getDetail(FOLLOW_UP_QUESTION_ID);

            assertThat(response.followUpQuestionId()).isEqualTo(FOLLOW_UP_QUESTION_ID);
            assertThat(response.sourceQuizId()).isEqualTo(SOURCE_QUIZ_ID);
            assertThat(response.sourceQuizNumber()).isEqualTo(3);
            assertThat(response.difficulty()).isEqualTo(QuizDifficulty.MEDIUM);
            assertThat(response.question()).isEqualTo("정렬되어 있지 않은 배열이라면 어떻게 찾아야 할까?");
            assertThat(response.keywords())
                    .extracting(FollowUpQuestionDetailResponse.KeywordItem::keyword)
                    .containsExactly("선형 탐색", "해시셋");
        }

        @Test
        @DisplayName("한 줄 답의 마커를 제거하고 하이라이트 구간으로 번역한다")
        void translates_markers_in_one_line_answer() {
            givenFollowUpQuestion(QuizFixture.detailedFollowUpQuestion(FOLLOW_UP_QUESTION_ID, SOURCE_QUIZ_ID));

            FollowUpQuestionDetailResponse.AnnotatedText oneLineAnswer =
                    service().getDetail(FOLLOW_UP_QUESTION_ID).oneLineAnswer();

            assertThat(oneLineAnswer.text()).isEqualTo("정렬이 안 됐다면 이진 탐색은 못 써요. 선형 탐색이 기본입니다.");
            assertThat(oneLineAnswer.highlights())
                    .extracting(FollowUpQuestionDetailResponse.Highlight::keyword)
                    .containsExactly("선형 탐색");
        }

        @Test
        @DisplayName("상세 블록은 저작 순서대로, 각 본문의 마커도 하이라이트로 번역해 반환한다")
        void returns_blocks_in_authored_order_with_highlights() {
            givenFollowUpQuestion(QuizFixture.detailedFollowUpQuestion(FOLLOW_UP_QUESTION_ID, SOURCE_QUIZ_ID));

            FollowUpQuestionDetailResponse response = service().getDetail(FOLLOW_UP_QUESTION_ID);

            assertThat(response.blocks())
                    .extracting(
                            FollowUpQuestionDetailResponse.DetailBlock::label,
                            FollowUpQuestionDetailResponse.DetailBlock::type)
                    .containsExactly(tuple("해설", FollowUpBlockType.TEXT), tuple("실무 사용처", FollowUpBlockType.TEXT));
            assertThat(response.blocks().get(1).content().text()).isEqualTo("반복 조회라면 해시셋으로 미리 인덱싱한다.");
            assertThat(response.blocks().get(1).content().highlights())
                    .extracting(FollowUpQuestionDetailResponse.Highlight::keyword)
                    .containsExactly("해시셋");
        }

        @Test
        @DisplayName("하이라이트 구간은 평문에서 정확히 그 키워드를 가리킨다")
        void anchors_highlights_to_the_keyword() {
            givenFollowUpQuestion(QuizFixture.detailedFollowUpQuestion(FOLLOW_UP_QUESTION_ID, SOURCE_QUIZ_ID));

            FollowUpQuestionDetailResponse.AnnotatedText block =
                    service().getDetail(FOLLOW_UP_QUESTION_ID).blocks().get(1).content();

            FollowUpQuestionDetailResponse.Highlight highlight =
                    block.highlights().get(0);
            assertThat(block.text().substring(highlight.start(), highlight.end()))
                    .isEqualTo(highlight.keyword());
        }

        @Test
        @DisplayName("존재하지 않는 꼬리질문이면 FOLLOW_UP_QUESTION_NOT_FOUND")
        void throws_when_follow_up_question_is_absent() {
            given(quizFollowUpQuestionRepository.findWithQuizById(ABSENT_ID)).willReturn(Optional.empty());

            assertThatThrownBy(() -> service().getDetail(ABSENT_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.FOLLOW_UP_QUESTION_NOT_FOUND));
        }

        @Test
        @DisplayName("상세가 아직 저작되지 않았으면 FOLLOW_UP_DETAIL_NOT_FOUND — 없는 것과 구분한다")
        void throws_when_detail_is_not_authored_yet() {
            givenFollowUpQuestion(QuizFixture.followUpQuestionWithoutDetail(FOLLOW_UP_QUESTION_ID));

            assertThatThrownBy(() -> service().getDetail(FOLLOW_UP_QUESTION_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.FOLLOW_UP_DETAIL_NOT_FOUND));
        }
    }
}

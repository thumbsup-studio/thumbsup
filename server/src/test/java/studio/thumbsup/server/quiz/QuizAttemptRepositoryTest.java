package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

/**
 * 풀이 기록(#261) Repository 통합 테스트 — 실제 MySQL(Testcontainers)에서 커서 페이지네이션 쿼리를
 * 검증한다 (피라미드 3층). 페이지네이션 경계(hasNext 등)는 {@code QuizAttemptHistoryServiceTest}가 담당하므로
 * 여기서는 쿼리 자체(정렬·유저 필터·커서 이후 조회·컬럼 왕복)만 확인한다.
 */
@DisplayName("풀이 기록 리포지토리")
class QuizAttemptRepositoryTest extends RepositoryTestSupport {

    private final QuizRepository quizRepository;
    private final QuizAttemptRepository quizAttemptRepository;

    QuizAttemptRepositoryTest(
            @Autowired QuizRepository quizRepository, @Autowired QuizAttemptRepository quizAttemptRepository) {
        this.quizRepository = quizRepository;
        this.quizAttemptRepository = quizAttemptRepository;
    }

    @Nested
    @DisplayName("유저별 커서 페이지네이션")
    class FindPageByUser {

        @Test
        @DisplayName("id 내림차순(최신순)으로 이어진다")
        void paginates_by_id_desc_with_cursor() {
            Quiz quiz = quizRepository.save(QuizFixture.oxQuiz());
            QuizAttempt first = quizAttemptRepository.save(QuizAttempt.create(quiz, 1L, true, "O"));
            QuizAttempt second = quizAttemptRepository.save(QuizAttempt.create(quiz, 1L, false, "X"));
            QuizAttempt third = quizAttemptRepository.save(QuizAttempt.create(quiz, 1L, true, "O"));

            List<QuizAttempt> firstPage = quizAttemptRepository.findPageByUserId(1L, PageRequest.of(0, 2));
            List<QuizAttempt> nextPage = quizAttemptRepository.findPageByUserIdBeforeId(
                    1L, firstPage.get(firstPage.size() - 1).getId(), PageRequest.of(0, 2));

            assertThat(firstPage).extracting(QuizAttempt::getId).containsExactly(third.getId(), second.getId());
            assertThat(nextPage).extracting(QuizAttempt::getId).containsExactly(first.getId());
        }

        @Test
        @DisplayName("다른 유저의 시도는 섞이지 않는다")
        void does_not_mix_other_users_attempts() {
            Quiz quiz = quizRepository.save(QuizFixture.oxQuiz());
            QuizAttempt mine = quizAttemptRepository.save(QuizAttempt.create(quiz, 1L, true, "O"));
            quizAttemptRepository.save(QuizAttempt.create(quiz, 2L, true, "O"));

            List<QuizAttempt> page = quizAttemptRepository.findPageByUserId(1L, PageRequest.of(0, 10));

            assertThat(page).extracting(QuizAttempt::getId).containsExactly(mine.getId());
        }

        @Test
        @DisplayName("quiz를 함께 fetch해 지연 로딩 예외 없이 문제 내용을 읽을 수 있다")
        void fetches_quiz_eagerly() {
            Quiz quiz = quizRepository.save(QuizFixture.oxQuiz());
            quizAttemptRepository.save(QuizAttempt.create(quiz, 1L, true, "O"));

            List<QuizAttempt> page = quizAttemptRepository.findPageByUserId(1L, PageRequest.of(0, 10));

            assertThat(page.get(0).getQuiz().getQuestionText()).isEqualTo(quiz.getQuestionText());
        }
    }

    @Nested
    @DisplayName("선택한 답 저장")
    class SelectedAnswerColumn {

        @Test
        @DisplayName("저장한 값 그대로 다시 읽힌다")
        void round_trips_selected_answer() {
            Quiz quiz = quizRepository.save(QuizFixture.keywordBlankQuiz());
            QuizAttempt saved = quizAttemptRepository.saveAndFlush(QuizAttempt.create(quiz, 1L, true, "LIFO,스택"));

            QuizAttempt found = quizAttemptRepository.findById(saved.getId()).orElseThrow();

            assertThat(found.getSelectedAnswer()).isEqualTo("LIFO,스택");
        }

        @Test
        @DisplayName("이 컬럼 도입 이전처럼 null도 그대로 저장할 수 있다")
        void allows_null_selected_answer() {
            Quiz quiz = quizRepository.save(QuizFixture.oxQuiz());

            QuizAttempt saved = quizAttemptRepository.saveAndFlush(QuizAttempt.create(quiz, 1L, true));

            assertThat(quizAttemptRepository
                            .findById(saved.getId())
                            .orElseThrow()
                            .getSelectedAnswer())
                    .isNull();
        }
    }
}

package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 저작 파이프라인(quiz_draft/generation_job/quiz_draft_revision/job_log) 저장·조회·제약을 검증한다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
class AuthoringRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final QuizDraftRepository quizDraftRepository;
    private final GenerationJobRepository jobRepository;
    private final QuizDraftRevisionRepository revisionRepository;
    private final JobLogRepository jobLogRepository;
    private final DatabaseCleanUp databaseCleanUp;

    AuthoringRepositoryTest(
            @Autowired QuizDraftRepository quizDraftRepository,
            @Autowired GenerationJobRepository jobRepository,
            @Autowired QuizDraftRevisionRepository revisionRepository,
            @Autowired JobLogRepository jobLogRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.quizDraftRepository = quizDraftRepository;
        this.jobRepository = jobRepository;
        this.revisionRepository = revisionRepository;
        this.jobLogRepository = jobLogRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    // 다른 도메인의 Flyway 시드(quiz 샘플 등)와 id/unique 제약이 겹치지 않도록 각 테스트를 빈 테이블에서 시작시킨다.
    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
    }

    @Nested
    @DisplayName("QuizDraft 저장·조회")
    class QuizDraftPersistence {

        @Test
        @DisplayName("origin/status/payload를 저장한 그대로 재조회한다")
        void round_trips_origin_status_and_payload() {
            QuizDraft saved = quizDraftRepository.save(QuizDraft.createNew("운영체제", "{\"quizzes\":[]}", 1L));

            QuizDraft found = quizDraftRepository.findById(saved.getId()).orElseThrow();

            assertThat(found.getOrigin()).isEqualTo(QuizDraftOrigin.NEW);
            assertThat(found.getStatus()).isEqualTo(QuizDraftStatus.DRAFT);
            assertThat(found.getCurrentPayload()).isEqualTo("{\"quizzes\":[]}");
        }
    }

    @Nested
    @DisplayName("GenerationJob 잡 픽업")
    class GenerationJobPickup {

        @Test
        @DisplayName("pickNextQueued는 본인의 QUEUED 잡만 집는다")
        void pickNextQueued는_본인의_QUEUED_잡만_집는다() {
            GenerationJob mine = jobRepository.save(GenerationJob.createGenerate(1L, "운영체제", "P"));
            jobRepository.save(GenerationJob.createGenerate(2L, "네트워크", "P")); // 남의 잡
            GenerationJob running = GenerationJob.createGenerate(1L, "DB", "P");
            running.markRunning(Instant.parse("2026-07-14T00:00:00Z"));
            jobRepository.save(running); // 이미 RUNNING

            Optional<GenerationJob> picked = jobRepository.pickNextQueued(1L);

            assertThat(picked).isPresent();
            assertThat(picked.get().getId()).isEqualTo(mine.getId());
        }

        @Test
        @DisplayName("본인의 QUEUED 잡이 없으면 empty를 반환한다")
        void pickNextQueued는_QUEUED_잡이_없으면_empty를_반환한다() {
            GenerationJob running = GenerationJob.createGenerate(1L, "DB", "P");
            running.markRunning(Instant.parse("2026-07-14T00:00:00Z"));
            jobRepository.save(running);

            Optional<GenerationJob> picked = jobRepository.pickNextQueued(1L);

            assertThat(picked).isEmpty();
        }
    }

    @Nested
    @DisplayName("QuizDraftRevision 유니크 제약")
    class QuizDraftRevisionUniqueness {

        @Test
        @DisplayName("같은 draft에 같은 revisionNo를 두 번 저장하면 예외가 발생한다")
        void rejects_duplicate_revision_no() {
            QuizDraft draft = quizDraftRepository.save(QuizDraft.createNew("운영체제", "{}", 1L));
            GenerationJob job = jobRepository.save(GenerationJob.createGenerate(1L, "운영체제", "P"));
            revisionRepository.saveAndFlush(QuizDraftRevision.create(draft.getId(), 1, "{}", null, null, job.getId()));

            assertThatThrownBy(() -> revisionRepository.saveAndFlush(
                            QuizDraftRevision.create(draft.getId(), 1, "{}", null, null, job.getId())))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }
    }

    @Nested
    @DisplayName("JobLog 조회")
    class JobLogPersistence {

        @Test
        @DisplayName("findByJobIdAndSeqGreaterThanOrderBySeqAsc는 fromSeq 이후만 순서대로 반환한다")
        void finds_logs_after_seq_in_order() {
            GenerationJob job = jobRepository.save(GenerationJob.createGenerate(1L, "운영체제", "P"));
            jobLogRepository.save(JobLog.create(job.getId(), 1, "시작"));
            jobLogRepository.save(JobLog.create(job.getId(), 3, "완료"));
            jobLogRepository.save(JobLog.create(job.getId(), 2, "진행중"));

            List<JobLog> logs = jobLogRepository.findByJobIdAndSeqGreaterThanOrderBySeqAsc(job.getId(), 1);

            assertThat(logs).extracting(JobLog::getSeq).containsExactly(2, 3);
        }
    }
}

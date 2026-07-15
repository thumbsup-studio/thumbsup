package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.persistence.EntityManager;
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
import org.springframework.orm.ObjectOptimisticLockingFailureException;
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
    private final EntityManager entityManager;

    AuthoringRepositoryTest(
            @Autowired QuizDraftRepository quizDraftRepository,
            @Autowired GenerationJobRepository jobRepository,
            @Autowired QuizDraftRevisionRepository revisionRepository,
            @Autowired JobLogRepository jobLogRepository,
            @Autowired DatabaseCleanUp databaseCleanUp,
            @Autowired EntityManager entityManager) {
        this.quizDraftRepository = quizDraftRepository;
        this.jobRepository = jobRepository;
        this.revisionRepository = revisionRepository;
        this.jobLogRepository = jobLogRepository;
        this.databaseCleanUp = databaseCleanUp;
        this.entityManager = entityManager;
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

        @Test
        @DisplayName("findByIdForUpdate는 PESSIMISTIC_WRITE로 잠그고 동일한 draft를 반환한다(#174 I2)")
        void locks_and_returns_the_draft() {
            QuizDraft saved = quizDraftRepository.save(QuizDraft.createNew("운영체제", "{\"quizzes\":[]}", 1L));

            QuizDraft found =
                    quizDraftRepository.findByIdForUpdate(saved.getId()).orElseThrow();

            assertThat(found.getId()).isEqualTo(saved.getId());
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
    @DisplayName("GenerationJob 낙관적 락")
    class GenerationJobOptimisticLock {

        /**
         * 만료 처리(getJobWithExpiry)와 브리지 결과 제출(submitResult)이 같은 잡을 동시에 종결시키는
         * 상황(#174 I1)을 재현한다 — 먼저 읽은 뒤 detach해 둔 stale 사본으로 나중에 쓰면 그 사이
         * 다른 트랜잭션이 이미 한 번 갱신·커밋한 것으로 간주해 충돌해야 한다.
         */
        @Test
        @DisplayName("먼저 읽은 뒤 오래된 버전으로 저장하면 ObjectOptimisticLockingFailureException")
        void rejects_stale_version_write() {
            GenerationJob saved = jobRepository.saveAndFlush(GenerationJob.createGenerate(1L, "운영체제", "P"));
            Long id = saved.getId();
            entityManager.clear();

            GenerationJob staleCopy = jobRepository.findById(id).orElseThrow();
            entityManager.detach(staleCopy); // 이후 findById가 새 인스턴스를 읽도록 persistence context에서 뗀다

            GenerationJob current = jobRepository.findById(id).orElseThrow();
            current.markRunning(Instant.parse("2026-07-14T00:00:00Z"));
            jobRepository.saveAndFlush(current); // version 0 -> 1
            entityManager.clear();

            staleCopy.fail(null, "동시 만료 처리", Instant.parse("2026-07-14T00:10:00Z"));
            assertThatThrownBy(() -> jobRepository.saveAndFlush(staleCopy))
                    .isInstanceOf(ObjectOptimisticLockingFailureException.class);
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

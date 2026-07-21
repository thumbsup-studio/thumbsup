# 문제 저작 파이프라인 — 서버 구현 계획 (#174)

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 웹 대시보드가 만든 생성/검수/개선 잡을 로컬 브리지가 폴링·실행하고, 결과를 draft→approved 라이프사이클로 관리·승격하는 Spring Boot 파이프라인.

**Architecture:** 신규 패키지 `studio.thumbsup.server.quiz.authoring` (quiz 슬라이스 내부 — ArchUnit의 feature 간 의존 금지 규칙 때문에 quiz 밖에 두면 안 됨). 기존 `quiz.generation`의 검증·영속 로직을 재사용하기 위해 소규모 가시성 리팩토링 선행. 잡 큐는 MySQL 테이블 + `FOR UPDATE SKIP LOCKED`, 로그 스트림은 `SseEmitter`(인메모리 팬아웃, 단일 인스턴스 전제).

**Tech Stack:** Spring Boot(기존), JPA/Hibernate, Flyway, MySQL 8.4 Testcontainers, SseEmitter.

**Spec:** `docs/specs/2026-07-14-quiz-authoring-dashboard-design.md`

## Global Constraints

- 브랜치: `feat/174-authoring-server`, 커밋 형식 `feat(server): <한국어 요약> (#174)` — main 직접 커밋 금지.
- 스키마 변경은 **Flyway만** (`server/src/main/resources/db/migration/V{yyyyMMddHHmmss}__*.sql`, 적용된 파일 수정 금지). `ddl-auto: validate`.
- 테스트 DB는 **MySQL 8.4 Testcontainers만** (H2 금지). 기존 테스트 어노테이션 패턴을 그대로 복제.
- ArchUnit 규칙 (위반 시 빌드 실패): 필드 `@Autowired` 금지(생성자 주입), raw `RuntimeException` 금지(`BusinessException(ErrorType)` 사용 — 단 `QuizGenerationException`은 예외적 허용 기존재), `@Transactional`은 `@Service` 클래스에만, 컨트롤러는 Repository·`@Entity` 직접 의존 금지, feature 패키지 상호 의존 금지(`common..` 제외).
- 시간은 항상 주입된 `Clock` 사용 (`Instant.now()` 직접 호출 금지). 엔티티 타임스탬프는 `BaseEntity`(`@CreatedDate`/`@LastModifiedDate`).
- 응답은 항상 `ApiResponse` 엔벨로프 `{code, message, data, meta}` (HTTP 204 사용 금지 — no-data 성공은 `ApiResponse.success()`).
- 에러 코드는 `AuthoringErrorType implements ErrorType`, 코드 네이밍 `AUTHORING_{REASON}`.
- DTO의 날짜 필드는 기존 DTO(예: notice/feedback 응답)의 변환 방식을 그대로 따라 KST(+09:00) 문자열로 노출 (`docs/api-standard.md §5`).
- 완료 게이트: `cd server && ./gradlew --no-daemon spotlessApply build` (테스트+ArchUnit+Spotless+Checkstyle 포함).
- 관련 없는 파일 수정 금지. 각 태스크 완료 시 커밋.

## 공유 HTTP 계약 (브리지 #175 · 앱 #176과 동일 — 이 계약이 정본)

인증: 전부 `Authorization: Bearer <JWT access token>` (SecurityConfig의 `anyRequest().authenticated()`로 자동 적용 — PUBLIC_PATHS 추가 불필요).

```
── 대시보드용 ──
POST /api/v1/authoring/drafts/generate        {topic}        → 202 data:{jobId}
POST /api/v1/authoring/quizzes/{quizId}/improve {instruction} → 202 data:{draftId, jobId}
POST /api/v1/authoring/drafts/{draftId}/reviews {feedback?}   → 202 data:{jobId}
POST /api/v1/authoring/drafts/{draftId}/approve               → 200 data:{draftId, status:"APPROVED"}
GET  /api/v1/authoring/drafts?status=DRAFT|APPROVED           → 200 data:{drafts:[DraftSummary]}
GET  /api/v1/authoring/drafts/{draftId}                       → 200 data:DraftDetail
GET  /api/v1/authoring/quizzes                                → 200 data:{steps:[{stepOrder,topic,quizzes:[{quizId,slotOrder,type,difficulty,questionText}]}]}
GET  /api/v1/authoring/jobs/{jobId}                           → 200 data:JobStatus
GET  /api/v1/authoring/jobs/{jobId}/stream?fromSeq=N          → SSE (text/event-stream, 엔벨로프 미적용)

── 브리지용 ──
GET  /api/v1/authoring/bridge/jobs/next                       → 200 data:{jobId,kind,prompt,outputSchema} | data:null (잡 없음)
POST /api/v1/authoring/bridge/jobs/{jobId}/logs   {lines:[string]}          → 200 data:null
POST /api/v1/authoring/bridge/jobs/{jobId}/result {cli, resultJson:string}  → 200 data:{jobId,status:"SUCCEEDED"|"FAILED",error?}
POST /api/v1/authoring/bridge/jobs/{jobId}/fail   {error}                   → 200 data:null
```

DTO 필드 (앱/브리지가 이 이름 그대로 소비):
- `DraftSummary`: `{draftId, origin:"NEW"|"IMPROVE", status:"DRAFT"|"APPROVED", topic, sourceQuizId:number|null, revisionCount, updatedAt}`
- `DraftDetail`: DraftSummary + `{payload:<GeneratedQuizSet JSON 객체>, revisions:[{revisionNo, reviewSummary:string|null, reviewedBy:number|null, jobId, createdAt}], createdBy, approvedBy:number|null, approvedAt:string|null}`
- `JobStatus`: `{jobId, kind:"GENERATE"|"REVIEW", status:"QUEUED"|"RUNNING"|"SUCCEEDED"|"FAILED", draftId:number|null, error:string|null, createdAt, startedAt:string|null, finishedAt:string|null}`

SSE 이벤트 (엔벨로프 없음):
```
event: log     id: <seq>   data: {"seq":12,"line":"OX 1번 작성 중..."}
event: status              data: {"status":"SUCCEEDED","draftId":42,"error":null}   ← 터미널 상태 도달 시 1회 후 스트림 종료
```

result 페이로드 계약 (`resultJson` 문자열 내부):
- GENERATE: `{"quizzes":[ ...5개, 기존 GeneratedQuizSet 스키마... ]}`
- REVIEW:   `{"reviewSummary":"무엇을 바꿨는지", "quizzes":[ ...NEW draft면 5개, IMPROVE draft면 1개... ]}`

## 파일 맵

```
server/src/main/resources/db/migration/V20260714100000__add_authoring_tables.sql   [T1 생성]
server/src/main/java/studio/thumbsup/server/quiz/authoring/
  GenerationJob.java, GenerationJobKind.java, GenerationJobStatus.java, BridgeCli.java   [T1]
  QuizDraft.java, QuizDraftOrigin.java, QuizDraftStatus.java, QuizDraftRevision.java, JobLog.java  [T1]
  GenerationJobRepository.java, QuizDraftRepository.java, QuizDraftRevisionRepository.java, JobLogRepository.java  [T1]
  AuthoringErrorType.java, AuthoringPromptFactory.java, AuthoringOutputSchemas.java  [T3]
  QuizToGeneratedQuizMapper.java, ReviewResult.java, AuthoringDraftService.java  [T4]
  AuthoringJobService.java  [T5]
  AuthoringApprovalService.java  [T6]
  dto/ (요청·응답 record 모음)  [T7]
  AuthoringDraftController.java, AuthoringQuizController.java, AuthoringJobController.java  [T7]
  AuthoringBridgeController.java, JobLogService.java  [T8]
  JobLogStreamService.java  [T9]
server/src/main/java/studio/thumbsup/server/quiz/generation/   [T2 수정 — 가시성만]
  GeneratedQuizSet.java, QuizGenerationPromptBuilder.java, EliceClient.java, QuizPersister.java
  GeneratedQuizValidator.java [T2 신규 — QuizGenerationService에서 추출]
server/src/main/java/studio/thumbsup/server/quiz/Quiz.java   [T6 수정 — 저작용 mutator 추가]
```

---

### Task 1: Flyway 마이그레이션 + 엔티티 + 리포지토리

**Files:**
- Create: `server/src/main/resources/db/migration/V20260714100000__add_authoring_tables.sql`
- Create: `server/src/main/java/studio/thumbsup/server/quiz/authoring/` 하위 enum 5개, 엔티티 4개, 리포지토리 4개
- Test: `server/src/test/java/studio/thumbsup/server/quiz/authoring/AuthoringRepositoryTest.java`

**Interfaces (Produces):**
- `GenerationJob.createGenerate(Long assigneeUserId, String topic, String prompt)`, `GenerationJob.createReview(Long assigneeUserId, Long draftId, String feedback, String prompt)` — static factory
- `GenerationJob` mutators: `markRunning(Instant now)`, `succeed(BridgeCli cli, Instant now)`, `fail(BridgeCli cli, String error, Instant now)`, `attachDraft(Long draftId)`, `boolean isActive()`
- `QuizDraft.createNew(String topic, String payloadJson, Long createdBy)`, `QuizDraft.createImprove(String topic, Long sourceQuizId, String payloadJson, Long createdBy)` / mutators: `applyRevision(String payloadJson)`, `approve(Long userId, Instant now)`
- `QuizDraftRevision.create(Long draftId, int revisionNo, String payload, String reviewSummary, Long reviewedBy, Long jobId)`
- `JobLog.create(Long jobId, int seq, String line)`
- `GenerationJobRepository.pickNextQueued(Long userId): Optional<GenerationJob>` — `FOR UPDATE SKIP LOCKED`
- `GenerationJobRepository.findByDraftIdAndStatusIn(Long, Collection<GenerationJobStatus>)`
- `QuizDraftRepository.findByStatusOrderByUpdatedAtDesc(QuizDraftStatus)`, `existsBySourceQuizIdAndStatus(Long, QuizDraftStatus)`
- `QuizDraftRevisionRepository.findByDraftIdOrderByRevisionNoDesc(Long)`, `findTopByDraftIdOrderByRevisionNoDesc(Long)`
- `JobLogRepository.findByJobIdAndSeqGreaterThanOrderBySeqAsc(Long, int)`, `findTopByJobIdOrderBySeqDesc(Long)`

- [ ] **Step 1: 마이그레이션 SQL 작성** — 기존 최신 마이그레이션 파일 하나를 열어 타입 표기(datetime(6) 등)·문자셋 표기 스타일을 확인하고 동일하게 맞춘다:

```sql
CREATE TABLE quiz_draft (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    origin          VARCHAR(10)  NOT NULL,
    status          VARCHAR(10)  NOT NULL,
    topic           VARCHAR(255) NOT NULL,
    source_quiz_id  BIGINT       NULL,
    current_payload MEDIUMTEXT   NOT NULL,
    created_by      BIGINT       NOT NULL,
    approved_by     BIGINT       NULL,
    approved_at     DATETIME(6)  NULL,
    created_at      DATETIME(6)  NOT NULL,
    updated_at      DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    KEY idx_quiz_draft_status (status),
    KEY idx_quiz_draft_source (source_quiz_id, status),
    CONSTRAINT fk_quiz_draft_source_quiz FOREIGN KEY (source_quiz_id) REFERENCES quiz (id)
);

CREATE TABLE generation_job (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    kind             VARCHAR(10)  NOT NULL,
    status           VARCHAR(10)  NOT NULL,
    assignee_user_id BIGINT       NOT NULL,
    cli              VARCHAR(10)  NULL,
    draft_id         BIGINT       NULL,
    topic            VARCHAR(255) NULL,
    feedback         TEXT         NULL,
    prompt           MEDIUMTEXT   NOT NULL,
    error            TEXT         NULL,
    started_at       DATETIME(6)  NULL,
    finished_at      DATETIME(6)  NULL,
    created_at       DATETIME(6)  NOT NULL,
    updated_at       DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    KEY idx_generation_job_pick (status, assignee_user_id, id),
    KEY idx_generation_job_draft (draft_id, status),
    CONSTRAINT fk_generation_job_draft FOREIGN KEY (draft_id) REFERENCES quiz_draft (id)
);

CREATE TABLE quiz_draft_revision (
    id             BIGINT      NOT NULL AUTO_INCREMENT,
    draft_id       BIGINT      NOT NULL,
    revision_no    INT         NOT NULL,
    payload        MEDIUMTEXT  NOT NULL,
    review_summary TEXT        NULL,
    reviewed_by    BIGINT      NULL,
    job_id         BIGINT      NOT NULL,
    created_at     DATETIME(6) NOT NULL,
    updated_at     DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_quiz_draft_revision (draft_id, revision_no),
    CONSTRAINT fk_revision_draft FOREIGN KEY (draft_id) REFERENCES quiz_draft (id),
    CONSTRAINT fk_revision_job FOREIGN KEY (job_id) REFERENCES generation_job (id)
);

CREATE TABLE job_log (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    job_id     BIGINT      NOT NULL,
    seq        INT         NOT NULL,
    line       TEXT        NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_job_log_seq (job_id, seq),
    CONSTRAINT fk_job_log_job FOREIGN KEY (job_id) REFERENCES generation_job (id)
);
```

- [ ] **Step 2: 실패하는 리포지토리 테스트 작성** — 기존 리포지토리 통합 테스트(예: `CourseAndUserProgressRepositoryTest`)의 어노테이션·Testcontainers 구성을 그대로 복제해 `AuthoringRepositoryTest` 작성:

```java
// 케이스 1: quiz_draft 저장·재조회 (origin/status/payload 왕복)
// 케이스 2: pickNextQueued — userId A의 QUEUED 잡만 집는다 (B의 잡·RUNNING 잡은 스킵), 없으면 empty
// 케이스 3: quiz_draft_revision (draft_id, revision_no) 유니크 제약 위반 시 예외
// 케이스 4: JobLog findByJobIdAndSeqGreaterThanOrderBySeqAsc — fromSeq 이후만 순서대로
@Test
void pickNextQueued는_본인의_QUEUED_잡만_집는다() {
    GenerationJob mine = jobRepository.save(GenerationJob.createGenerate(1L, "운영체제", "P"));
    jobRepository.save(GenerationJob.createGenerate(2L, "네트워크", "P"));       // 남의 잡
    GenerationJob running = GenerationJob.createGenerate(1L, "DB", "P");
    running.markRunning(Instant.parse("2026-07-14T00:00:00Z"));
    jobRepository.save(running);                                                // 이미 RUNNING

    Optional<GenerationJob> picked = jobRepository.pickNextQueued(1L);

    assertThat(picked).isPresent();
    assertThat(picked.get().getId()).isEqualTo(mine.getId());
}
```

- [ ] **Step 3: 테스트 실행 — 컴파일 실패 확인** — `cd server && ./gradlew test --tests '*AuthoringRepositoryTest*'` → 엔티티 미존재로 FAIL.

- [ ] **Step 4: enum + 엔티티 + 리포지토리 구현** — 하우스 스타일(`@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)`, private 생성자 + static factory, `BaseEntity` 상속). 핵심 코드:

```java
// GenerationJob.java (발췌 — 필드는 마이그레이션 컬럼과 1:1)
@Entity @Table(name = "generation_job")
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GenerationJob extends BaseEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 10) private GenerationJobKind kind;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 10) private GenerationJobStatus status;
    @Column(nullable = false) private Long assigneeUserId;
    @Enumerated(EnumType.STRING) @Column(length = 10) private BridgeCli cli;
    private Long draftId;
    private String topic;
    @Column(columnDefinition = "TEXT") private String feedback;
    @Column(nullable = false, columnDefinition = "MEDIUMTEXT") private String prompt;
    @Column(columnDefinition = "TEXT") private String error;
    private Instant startedAt;
    private Instant finishedAt;

    public static GenerationJob createGenerate(Long assigneeUserId, String topic, String prompt) { ... status = QUEUED, kind = GENERATE ... }
    public static GenerationJob createReview(Long assigneeUserId, Long draftId, String feedback, String prompt) { ... }
    public void markRunning(Instant now) { this.status = GenerationJobStatus.RUNNING; this.startedAt = now; }
    public void succeed(BridgeCli cli, Instant now) { this.status = GenerationJobStatus.SUCCEEDED; this.cli = cli; this.finishedAt = now; }
    public void fail(BridgeCli cli, String error, Instant now) { this.status = GenerationJobStatus.FAILED; this.cli = cli; this.error = error; this.finishedAt = now; }
    public void attachDraft(Long draftId) { this.draftId = draftId; }
    public boolean isActive() { return status == GenerationJobStatus.QUEUED || status == GenerationJobStatus.RUNNING; }
}

// GenerationJobRepository.java
public interface GenerationJobRepository extends JpaRepository<GenerationJob, Long> {
    @Query(value = "SELECT * FROM generation_job WHERE status = 'QUEUED' AND assignee_user_id = :userId "
            + "ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED", nativeQuery = true)
    Optional<GenerationJob> pickNextQueued(@Param("userId") Long userId);

    List<GenerationJob> findByDraftIdAndStatusIn(Long draftId, Collection<GenerationJobStatus> statuses);
}
```

`QuizDraft.applyRevision(String payloadJson)`은 `currentPayload`만 교체, `approve(Long userId, Instant now)`는 `status=APPROVED; approvedBy=userId; approvedAt=now` (이미 APPROVED면 여기서 막지 않음 — 서비스 레이어가 가드).

- [ ] **Step 5: 테스트 통과 확인** — `./gradlew test --tests '*AuthoringRepositoryTest*'` → PASS. Flyway+`ddl-auto: validate`가 스키마-엔티티 정합을 함께 검증한다.

- [ ] **Step 6: 커밋** — `feat(server): 저작 파이프라인 스키마·엔티티·리포지토리 (#174)`

---

### Task 2: quiz.generation 가시성 리팩토링 (기존 테스트가 안전망)

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/quiz/generation/GeneratedQuizSet.java` — 최상위 record와 **모든 중첩 record**에 `public` 부여
- Modify: `.../generation/QuizGenerationPromptBuilder.java` — 클래스·`build(String)` public
- Modify: `.../generation/EliceClient.java` — `SYSTEM_PROMPT`를 `public static final`로
- Modify: `.../generation/QuizPersister.java` — 클래스·생성자·`persist` public + `populate` 메서드 추출
- Create: `.../generation/GeneratedQuizValidator.java` — `QuizGenerationService`의 private `parse`/`validate` 로직 이동
- Modify: `.../generation/QuizGenerationService.java` — validator에 위임
- Modify: `server/src/test/java/.../generation/QuizGenerationServiceTest.java` — 생성자 변경 반영
- Create: `server/src/test/java/.../generation/GeneratedQuizValidatorTest.java`

**Interfaces (Produces — T3~T6이 소비):**
```java
public record GeneratedQuizSet(List<GeneratedQuiz> quizzes) { public record GeneratedQuiz(...) {...} ... }  // 전 중첩 public
public final class QuizGenerationPromptBuilder { public static String build(String courseTopic); }
public class EliceClient { public static final String SYSTEM_PROMPT; }
public class QuizPersister {
    @Transactional public int persist(String courseTopic, GeneratedQuizSet generated);
    public void populate(Quiz quiz, GeneratedQuizSet.GeneratedQuiz generated);  // create/assignPosition 제외한 자식 채우기 전부
}
@Component public class GeneratedQuizValidator {
    public GeneratedQuizValidator(ObjectMapper objectMapper);
    public GeneratedQuizSet parse(String rawResponse);        // 코드펜스 제거 + 역직렬화 (기존 로직 이동)
    public void validateSet(GeneratedQuizSet set);            // 5슬롯 고정 검증 (기존 validate 이동)
    public void validateSingle(GeneratedQuizSet.GeneratedQuiz quiz, QuizType expectedType, QuizDifficulty expectedDifficulty);
}
```

- [ ] **Step 1: 실패하는 validator 테스트 작성** — `GeneratedQuizValidatorTest`: ① `parse`가 코드펜스 감싼 JSON을 벗겨 역직렬화한다(기존 `GeneratedQuizJsonFixture` 재사용, 필요 시 fixture를 public으로), ② `validateSingle`이 기대 type/difficulty 불일치 시 `QuizGenerationException`, ③ `validateSingle`이 정상 단건은 통과.
- [ ] **Step 2: 실행 — 컴파일 실패 확인** — `./gradlew test --tests '*GeneratedQuizValidatorTest*'` → FAIL.
- [ ] **Step 3: 리팩토링 구현** — 메서드 본문은 **변경 없이 이동**한다. `QuizGenerationService.validate()`의 슬롯 루프를 `validateSlot(String location, GeneratedQuiz, QuizType, QuizDifficulty)` private 메서드로 쪼개고 `validateSet`(5개+슬롯 루프)·`validateSingle`(단건)이 공유. `QuizPersister.persist` 내부의 자식 채우기 코드(assignCorrectAnswer/addChoice/addAnswerKeyword/addFollowUpQuestion+attachDetail+addBlock+addKeyword/addDerivedConcept/addKeyword)를 `populate(quiz, generated)`로 추출하고 persist가 호출.
- [ ] **Step 4: 전체 generation 테스트 그린 확인** — `./gradlew test --tests '*generation*'` → PASS (기존 테스트가 리팩토링 안전망).
- [ ] **Step 5: 커밋** — `refactor(server): 저작 파이프라인 재사용 위해 generation 가시성 정리 (#174)`

---

### Task 3: AuthoringErrorType + 프롬프트 팩토리 + 출력 스키마

**Files:**
- Create: `.../quiz/authoring/AuthoringErrorType.java`, `AuthoringPromptFactory.java`, `AuthoringOutputSchemas.java`
- Test: `server/src/test/java/.../quiz/authoring/AuthoringPromptFactoryTest.java`

**Interfaces (Produces):**
```java
public enum AuthoringErrorType implements ErrorType {
    AUTHORING_DRAFT_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 draft입니다."),
    AUTHORING_JOB_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 잡입니다."),
    AUTHORING_DRAFT_JOB_ACTIVE(HttpStatus.CONFLICT, "이 draft에 진행 중인 잡이 있습니다."),
    AUTHORING_IMPROVE_DRAFT_EXISTS(HttpStatus.CONFLICT, "이 문제에 이미 열린 개선 draft가 있습니다."),
    AUTHORING_DRAFT_ALREADY_APPROVED(HttpStatus.CONFLICT, "이미 승인된 draft입니다."),
    AUTHORING_JOB_NOT_CLAIMABLE(HttpStatus.CONFLICT, "결과를 제출할 수 있는 상태가 아닙니다.");
    // 기존 ErrorType 구현 enum(QuizErrorType 등)의 필드·생성자 패턴 복제
}
public final class AuthoringPromptFactory {
    public static String generatePrompt(String topic);
    public static String reviewPrompt(String topic, String currentPayloadJson, String feedback, List<String> siblingQuestions);
}
public final class AuthoringOutputSchemas {
    public static final String GENERATE;  // JSON Schema 문자열
    public static final String REVIEW;
}
```

- [ ] **Step 1: 실패하는 테스트 작성**:

```java
@Test void generatePrompt는_시스템프롬프트와_주제_스키마를_포함한다() {
    String prompt = AuthoringPromptFactory.generatePrompt("운영체제");
    assertThat(prompt).contains("CS 강사");           // SYSTEM_PROMPT 병합 확인
    assertThat(prompt).contains("운영체제");
}
@Test void reviewPrompt는_피드백이_있으면_반영_섹션을_포함한다() {
    String prompt = AuthoringPromptFactory.reviewPrompt("운영체제", "{\"quizzes\":[]}", "선지 3번이 모호함", List.of());
    assertThat(prompt).contains("검수자 피드백");
    assertThat(prompt).contains("선지 3번이 모호함");
    assertThat(prompt).contains("reviewSummary");
}
@Test void reviewPrompt는_피드백_없고_형제문제_있으면_해당_섹션만() { ... "검수자 피드백" 미포함, "다른 문제들" 포함 ... }
```

- [ ] **Step 2: 실행 — FAIL 확인.**
- [ ] **Step 3: 구현** — `generatePrompt` = `EliceClient.SYSTEM_PROMPT + "\n\n" + QuizGenerationPromptBuilder.build(topic)`. `reviewPrompt` 템플릿(그대로 사용):

```text
{SYSTEM_PROMPT}

너는 위 규칙을 따르는 검수자다. 아래 기존 문제를 비평하고, 개선한 수정본을 만들어라.

[주제] {topic}

[현재 문제 JSON]
{currentPayloadJson}

[검수 규칙]
- 각 문제의 type과 difficulty는 절대 변경하지 않는다. 문제 개수도 변경하지 않는다.
- 사실 오류, 모호한 표현, 빈약한 해설, 어색한 선지를 우선적으로 고친다.
- 원문이 이미 충분히 좋으면 최소 수정만 한다.

(feedback != null 이고 공백 아님일 때만)
[검수자 피드백 — 반드시 반영하라]
{feedback}

(siblingQuestions 비어있지 않을 때만)
[같은 스텝의 다른 문제들 — 아래와 개념이 중복되지 않게 하라 (읽기 전용 맥락)]
- {질문1}
- {질문2}

[출력 형식]
다음 형태의 JSON 객체 하나만 출력한다. 코드펜스·설명·인사말을 붙이지 않는다.
{"reviewSummary": "무엇을 왜 바꿨는지 3문장 이내", "quizzes": [현재 문제 JSON과 동일한 스키마의 수정본 배열]}
```

`AuthoringOutputSchemas` (CLI의 `--json-schema`/`--output-schema`에 전달할 얕은 가드 — 깊은 검증은 서버가 함):

```java
public static final String GENERATE = """
    {"type":"object","required":["quizzes"],"properties":{"quizzes":{"type":"array","minItems":5,"maxItems":5,
    "items":{"type":"object","required":["type","difficulty","questionText","explanationSummary","wrongAnswerExplanation"]}}}}""";
public static final String REVIEW = """
    {"type":"object","required":["reviewSummary","quizzes"],"properties":{"reviewSummary":{"type":"string"},
    "quizzes":{"type":"array","minItems":1,"items":{"type":"object","required":["type","difficulty","questionText"]}}}}""";
```

- [ ] **Step 4: 실행 — PASS.** / **Step 5: 커밋** — `feat(server): 저작 프롬프트 팩토리·출력 스키마 (#174)`

---

### Task 4: Draft 서비스 + 라이브 문제 → GeneratedQuiz 역매핑

**Files:**
- Create: `.../quiz/authoring/QuizToGeneratedQuizMapper.java`, `ReviewResult.java`, `AuthoringDraftService.java`
- Test: `.../quiz/authoring/QuizToGeneratedQuizMapperTest.java`, `AuthoringDraftServiceTest.java`

**Interfaces:**
- Consumes: T1 엔티티·리포지토리, T2 `GeneratedQuizSet`(public)
- Produces:
```java
public final class QuizToGeneratedQuizMapper {
    public static GeneratedQuizSet.GeneratedQuiz toGenerated(Quiz quiz);  // 엔티티 → 스키마 record 역변환
}
public record ReviewResult(String reviewSummary, List<GeneratedQuizSet.GeneratedQuiz> quizzes) {}
@Service public class AuthoringDraftService {
    @Transactional public QuizDraft createFromGenerate(GenerationJob job, GeneratedQuizSet set);     // draft 생성 + rev1
    @Transactional public QuizDraft applyReview(GenerationJob job, ReviewResult result);             // payload 갱신 + rev N+1
    @Transactional public QuizDraft createImproveDraft(Long userId, Quiz sourceQuiz, String stepTopic); // 라이브 복제 draft
    @Transactional(readOnly = true) public List<QuizDraft> list(QuizDraftStatus status);
    @Transactional(readOnly = true) public QuizDraft getOrThrow(Long draftId);                       // 없으면 AUTHORING_DRAFT_NOT_FOUND
    @Transactional(readOnly = true) public List<QuizDraftRevision> revisions(Long draftId);
}
```
- 직렬화 규약: draft `currentPayload`/revision `payload`에는 항상 `GeneratedQuizSet` 형태 JSON(`{"quizzes":[...]}`)을 `ObjectMapper.writeValueAsString`으로 저장. IMPROVE는 원소 1개.

- [ ] **Step 1: 실패하는 매퍼 테스트** — 기존 `QuizFixture`의 `oxQuiz()`/`multipleChoiceQuiz()`/`keywordBlankQuiz()`로 Quiz를 만들고 `toGenerated` 결과 검증: type/difficulty/questionText 일치, MC는 choices 4개·정답 1개 보존, KEYWORD_BLANK는 answerKeywords가 slotOrder별로 그룹핑된 `List<List<String>>`(동의어 유지), followUpQuestions의 blocks가 (label, content)로 보존.
- [ ] **Step 2: FAIL 확인** → **Step 3: 구현**:

```java
public static GeneratedQuizSet.GeneratedQuiz toGenerated(Quiz quiz) {
    List<GeneratedQuizSet.GeneratedChoice> choices = quiz.getChoices().stream()
            .map(c -> new GeneratedQuizSet.GeneratedChoice(c.getContent(), c.isCorrect())).toList();
    // slotOrder별 그룹핑 (순서 보장 위해 TreeMap)
    Map<Integer, List<String>> grouped = new TreeMap<>();
    quiz.getAnswerKeywords().forEach(k -> grouped.computeIfAbsent(k.getSlotOrder(), x -> new ArrayList<>()).add(k.getKeyword()));
    List<List<String>> answerKeywords = new ArrayList<>(grouped.values());
    List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUps = quiz.getFollowUpQuestions().stream().map(f ->
            new GeneratedQuizSet.GeneratedFollowUpQuestion(f.getContent(), f.isPrimary(), f.getDifficulty(), f.getOneLineAnswer(),
                    f.getBlocks().stream().map(b -> new GeneratedQuizSet.GeneratedFollowUpBlock(b.getLabel(), b.getContent())).toList(),
                    f.getKeywords().stream().map(k -> new GeneratedQuizSet.GeneratedKeyword(k.getKeyword(), k.getDescription())).toList()))
            .toList();
    return new GeneratedQuizSet.GeneratedQuiz(quiz.getType(), quiz.getDifficulty(), quiz.getQuestionText(), quiz.getCodeSnippet(),
            quiz.getExplanationSummary(), quiz.getExplanationExample(), quiz.getWrongAnswerExplanation(), quiz.getCorrectAnswer(),
            choices, answerKeywords, followUps,
            quiz.getDerivedConcepts().stream().map(QuizDerivedConcept::getName).toList(),
            quiz.getKeywords().stream().map(k -> new GeneratedQuizSet.GeneratedKeyword(k.getKeyword(), k.getDescription())).toList());
}
```
(getter 이름은 실제 엔티티에서 확인해 맞출 것 — 필드명은 §3 파일 맵의 엔티티에 있음.)

- [ ] **Step 4: 실패하는 서비스 테스트** — Mockito로 리포지토리 mock: ① `createFromGenerate`가 draft 저장 + revisionNo=1 저장 + `job.attachDraft` 호출, ② `applyReview`가 `currentPayload` 교체 + 기존 max revision+1로 저장(reviewSummary·reviewedBy=잡 assignee 기록), ③ `getOrThrow` 미존재 시 `BusinessException(AUTHORING_DRAFT_NOT_FOUND)`.
- [ ] **Step 5: FAIL → 구현 → PASS.** `createImproveDraft`는 `QuizToGeneratedQuizMapper.toGenerated(sourceQuiz)` 1개를 `GeneratedQuizSet`으로 감싸 직렬화해 `QuizDraft.createImprove(stepTopic, sourceQuiz.getId(), json, userId)` 저장 (revision은 검수 잡 결과가 만들므로 여기선 생성 안 함 — rev는 applyReview에서만 누적. 단 createFromGenerate는 rev1을 만든다).
- [ ] **Step 6: 커밋** — `feat(server): draft 서비스·라이브 문제 역매핑 (#174)`

---

### Task 5: 잡 큐 오케스트레이션 서비스

**Files:**
- Create: `.../quiz/authoring/AuthoringJobService.java`
- Test: `.../quiz/authoring/AuthoringJobServiceTest.java`

**Interfaces:**
- Consumes: T1~T4 전부. `QuizStepRepository`(기존, stepOrder→topic 조회), `QuizRepository`(기존).
- Produces (T7·T8 컨트롤러가 소비):
```java
@Service public class AuthoringJobService {
    @Transactional public Long enqueueGenerate(Long userId, String topic);                    // → jobId
    @Transactional public ImproveEnqueued enqueueImprove(Long userId, Long quizId, String instruction); // record ImproveEnqueued(Long draftId, Long jobId)
    @Transactional public Long enqueueReview(Long userId, Long draftId, String feedback);    // → jobId
    @Transactional public Optional<GenerationJob> claimNext(Long userId);                    // pickNext + markRunning
    @Transactional public GenerationJob submitResult(Long userId, Long jobId, BridgeCli cli, String resultJson);
    @Transactional public GenerationJob failJob(Long userId, Long jobId, String error);
    @Transactional public GenerationJob getJobWithExpiry(Long jobId); // 조회 + lazy 만료 평가 (팀원 누구나 조회 가능 — assignee 제한 없음)
}
```
- 만료 정책(lazy — 스케줄러 없음): 가드·조회 시점에 QUEUED 30분 초과 또는 RUNNING 10분 초과인 잡은 `fail(null, "시간 초과로 만료되었습니다", now)` 처리 후 진행.
- 가드: `enqueueReview`/`approve` 전에 draft가 APPROVED면 `AUTHORING_DRAFT_ALREADY_APPROVED`; 만료 평가 후에도 활성 잡 존재 시 `AUTHORING_DRAFT_JOB_ACTIVE`; `enqueueImprove`는 `existsBySourceQuizIdAndStatus(quizId, DRAFT)`면 `AUTHORING_IMPROVE_DRAFT_EXISTS`.
- `submitResult` 흐름: 잡 조회(없으면 `AUTHORING_JOB_NOT_FOUND`) → `assigneeUserId != userId`면 `CommonErrorType.FORBIDDEN` → RUNNING 아니면 `AUTHORING_JOB_NOT_CLAIMABLE` → kind 분기:
  - GENERATE: `validator.parse(resultJson)` → `validateSet` → `draftService.createFromGenerate` → `job.succeed(cli, now)`
  - REVIEW: `objectMapper.readValue(stripFences, ReviewResult.class)` → draft origin이 NEW면 `validateSet(new GeneratedQuizSet(result.quizzes()))`, IMPROVE면 크기 1 확인 + 원본 Quiz의 type/difficulty로 `validateSingle` → `draftService.applyReview` → `job.succeed`
  - `QuizGenerationException`·`JsonProcessingException` 캐치 → `job.fail(cli, 메시지, now)` — **예외를 다시 던지지 않고** FAILED 잡을 반환(브리지 입장에선 정상 응답, 실패 사유는 잡에 기록).
- 프롬프트 조립: `enqueueGenerate` → `AuthoringPromptFactory.generatePrompt(topic)`. `enqueueImprove`/`enqueueReview`(IMPROVE draft) → 원본 quiz의 stepOrder로 형제 문제 questionText 목록(자기 제외)·스텝 topic 조회 후 `reviewPrompt(...)`. `enqueueReview`(NEW draft) → 형제 없음, topic=draft.topic, payload=draft.currentPayload.

- [ ] **Step 1: 실패하는 테스트 작성** — Mockito. 최소 케이스: ① enqueueGenerate가 GENERATE 잡 저장(프롬프트에 topic 포함), ② draft에 활성 잡 있으면 enqueueReview가 `AUTHORING_DRAFT_JOB_ACTIVE`, ③ RUNNING 10분 초과 잡은 만료 후 enqueueReview 성공, ④ 개선 draft 중복 시 `AUTHORING_IMPROVE_DRAFT_EXISTS`, ⑤ submitResult GENERATE 성공 경로(validateSet·createFromGenerate·succeed 호출 검증), ⑥ submitResult에서 검증 예외 → 잡 FAILED + error 기록 + 예외 미전파, ⑦ 남의 잡 submitResult → FORBIDDEN.
- [ ] **Step 2: FAIL 확인 → Step 3: 구현 → Step 4: PASS** — Clock은 `Clock.fixed(...)` 주입.
- [ ] **Step 5: 커밋** — `feat(server): 저작 잡 큐 오케스트레이션 (#174)`

---

### Task 6: 승인 = materialize (NEW→INSERT, IMPROVE→in-place UPDATE)

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/quiz/Quiz.java` — 저작용 mutator 2개 추가
- Create: `.../quiz/authoring/AuthoringApprovalService.java`
- Test: `.../quiz/authoring/AuthoringApprovalServiceTest.java` (unit), `.../quiz/authoring/AuthoringApprovalIntegrationTest.java` (Testcontainers)

**Interfaces:**
- Produces:
```java
// Quiz.java에 추가 — 저작 개선 반영용. type/difficulty/stepOrder/slotOrder는 절대 바꾸지 않는다.
public void updateContent(String questionText, String codeSnippet, String explanationSummary,
        String explanationExample, String wrongAnswerExplanation) { ...필드 교체... }
public void resetForRepopulation() {
    this.correctAnswer = null;
    choices.clear(); answerKeywords.clear(); followUpQuestions.clear(); derivedConcepts.clear(); keywords.clear();
}
@Service public class AuthoringApprovalService {
    @Transactional public QuizDraft approve(Long userId, Long draftId);
}
```
- approve 흐름: draft 조회 → APPROVED면 `AUTHORING_DRAFT_ALREADY_APPROVED` → 활성 잡 있으면(만료 평가 후) `AUTHORING_DRAFT_JOB_ACTIVE` → `validator.parse(currentPayload)` →
  - NEW: `quizPersister.persist(draft.getTopic(), set)`
  - IMPROVE: `quizRepository.findById(sourceQuizId)` (없으면 기존 `QuizErrorType.QUIZ_NOT_FOUND`) → `quiz.updateContent(...)` → `quiz.resetForRepopulation()` → `quizPersister.populate(quiz, set.quizzes().get(0))`
  → `draft.approve(userId, clock.instant())`

- [ ] **Step 1: 실패하는 통합 테스트 작성** (핵심 리스크 = in-place UPDATE라 통합부터) — Testcontainers `@SpringBootTest`:

```java
@Test void 개선_draft_승인은_원본_quiz_id를_보존하며_내용만_교체한다() {
    // given: QuizFixture로 스텝 저장, 그중 MC 문제 하나를 createImproveDraft로 복제,
    //        payload의 questionText를 "개선된 질문"으로 바꿔 draft에 applyRevision
    // when: approvalService.approve(reviewerId, draftId)
    // then: 같은 quiz.id 조회 시 questionText == "개선된 질문",
    //        choices 4개 재구성, quiz_draft.status == APPROVED,
    //        다른 슬롯 문제들은 변경 없음
}
@Test void 신규_draft_승인은_새_스텝을_INSERT한다() { ... persist 경유, quiz_step 1행 + quiz 5행 증가 ... }
```

- [ ] **Step 2: FAIL 확인 → Step 3: mutator + 서비스 구현 → Step 4: PASS** — 유닛 테스트(가드 3종: NOT_FOUND / ALREADY_APPROVED / JOB_ACTIVE)도 추가.
- [ ] **Step 5: 커밋** — `feat(server): draft 승인·materialize (#174)`

---

### Task 7: 대시보드 REST 컨트롤러 + DTO

**Files:**
- Create: `.../quiz/authoring/dto/` — `GenerateRequest(topic @NotBlank @Size(max=100))`, `ImproveRequest(instruction @NotBlank @Size(max=2000))`, `ReviewRequest(feedback @Size(max=2000) nullable)`, `JobCreatedResponse(jobId)`, `ImproveCreatedResponse(draftId, jobId)`, `ApproveResponse(draftId, status)`, `DraftSummaryResponse`, `DraftListResponse(List<DraftSummaryResponse> drafts)`, `DraftDetailResponse`, `RevisionResponse`, `JobStatusResponse`, `AuthoringStepResponse`, `AuthoringQuizSummaryResponse`, `AuthoringQuizListResponse(List<AuthoringStepResponse> steps)` — 필드는 위 "공유 HTTP 계약" 절과 1:1 (목록은 래퍼 record로 감싸 `data:{drafts:[...]}` / `data:{steps:[...]}` 형태 유지)
- Create: `.../quiz/authoring/AuthoringDraftController.java`, `AuthoringQuizController.java`, `AuthoringJobController.java` (stream 제외 — T9)
- Create: `AuthoringDraftService`에 목록/상세 DTO 변환 보조 추가 또는 컨트롤러-서비스 사이 조립 (컨트롤러는 엔티티 직접 의존 금지 — DTO 변환은 서비스가 수행)
- Test: `.../quiz/authoring/AuthoringDraftControllerTest.java` 등 — **기존 컨트롤러 단독 MockMvc 테스트(예: `HomeControllerTest`)의 셋업(principal 주입 resolver 포함)을 그대로 복제**

**Interfaces:**
- Consumes: T4 `AuthoringDraftService`, T5 `AuthoringJobService`, T6 `AuthoringApprovalService`
- Produces: 공유 계약의 대시보드 엔드포인트 전부(스트림 제외). 잡 생성 계열은 `@ResponseStatus(HttpStatus.ACCEPTED)`.
- `DraftDetailResponse.payload`는 `JsonNode` (`objectMapper.readTree(currentPayload)`) — 클라이언트가 JSON 객체로 받는다.
- `GET /authoring/quizzes`: `QuizRepository.findAll()`을 stepOrder→slotOrder 정렬·그룹핑, `QuizStepRepository`에서 topic 매칭. 페이지네이션 없음(문제 수 작음 — 의도적 YAGNI).

- [ ] **Step 1: 실패하는 컨트롤러 계약 테스트 작성** — 최소: generate 202+jobId 반환, topic 공백 → 400 `INVALID_INPUT` + fieldErrors, drafts 목록 200 형태, approve 200. 서비스는 Mockito mock.
- [ ] **Step 2: FAIL → Step 3: 컨트롤러·DTO 구현** — 컨트롤러 예시:

```java
@RestController
@RequestMapping("/api/v1/authoring/drafts")
public class AuthoringDraftController {
    private final AuthoringJobService jobService;
    private final AuthoringDraftService draftService;
    private final AuthoringApprovalService approvalService;

    @ResponseStatus(HttpStatus.ACCEPTED)
    @PostMapping("/generate")
    public ApiResponse<JobCreatedResponse> generate(
            @AuthenticationPrincipal Long userId, @Valid @RequestBody GenerateRequest request) {
        return ApiResponse.success(new JobCreatedResponse(jobService.enqueueGenerate(userId, request.topic())));
    }
    // reviews / approve / 목록 / 상세 동일 패턴
}
```

- [ ] **Step 4: PASS → Step 5: 커밋** — `feat(server): 저작 대시보드 REST API (#174)`

---

### Task 8: 브리지 REST + 로그 서비스 + 인수 테스트

**Files:**
- Create: `.../quiz/authoring/JobLogService.java`, `AuthoringBridgeController.java`, `dto/BridgeJobResponse.java`, `dto/BridgeLogsRequest.java(lines @NotEmpty List<String>)`, `dto/BridgeResultRequest.java(cli @NotNull BridgeCli, resultJson @NotBlank)`, `dto/BridgeFailRequest.java(error @NotBlank)`, `dto/BridgeResultResponse.java(jobId, status, error)`
- Test: `.../quiz/authoring/AuthoringAcceptanceTest.java` — `@SpringBootTest` + Testcontainers + MockMvc (기존 `FollowUpQuestionAcceptanceTest` 구성 복제, JWT는 `jwtTokenProvider.createAccessToken(USER_ID)` 직접 발급)

**Interfaces:**
- Produces:
```java
@Service public class JobLogService {
    @Transactional public List<JobLog> append(Long jobId, List<String> lines);  // seq = 마지막 seq+1부터 연속 부여
    @Transactional(readOnly = true) public List<JobLog> after(Long jobId, int fromSeq);
}
```
- `GET /bridge/jobs/next`: `jobService.claimNext(userId)` → 있으면 `BridgeJobResponse(jobId, kind, prompt, outputSchema)` (outputSchema는 kind별 `AuthoringOutputSchemas` 상수를 `readTree`로 JsonNode 변환), 없으면 `ApiResponse.success(null)` — HTTP 200.
- logs: 잡 존재+본인+RUNNING 확인 후 append. result/fail: `jobService.submitResult`/`failJob` 위임.

- [ ] **Step 1: 실패하는 인수 테스트 작성** — 전체 happy path 한 개 + 가드 한 개:

```java
@Test void 생성_잡_전체_흐름() throws Exception {
    // 1) POST /authoring/drafts/generate {topic:"운영체제"} → 202, jobId 추출
    // 2) GET  /authoring/bridge/jobs/next → 200, data.jobId 일치, data.prompt에 "운영체제" 포함
    // 3) POST /authoring/bridge/jobs/{id}/logs {lines:["시작","생성 중"]} → 200
    // 4) POST /authoring/bridge/jobs/{id}/result {cli:"CLAUDE", resultJson:<GeneratedQuizJsonFixture의 유효 5문제 JSON>} → 200 data.status=SUCCEEDED
    // 5) GET  /authoring/jobs/{id} → status SUCCEEDED, draftId not null
    // 6) GET  /authoring/drafts/{draftId} → revisions 크기 1, payload.quizzes 크기 5
    // 7) POST /authoring/drafts/{draftId}/approve → 200 → quiz 테이블 5행 증가 확인
}
@Test void 남의_잡은_next로_집을_수_없다() { ... 다른 userId 토큰으로 next → data null ... }
```

- [ ] **Step 2: FAIL → Step 3: 구현 → Step 4: PASS.**
- [ ] **Step 5: 커밋** — `feat(server): 브리지 API·로그 적재·인수 테스트 (#174)`

---

### Task 9: SSE 로그 스트림

**Files:**
- Create: `.../quiz/authoring/JobLogStreamService.java`
- Modify: `AuthoringJobController.java` — `GET /jobs/{jobId}/stream` 추가
- Modify: `AuthoringBridgeController.java` — logs 성공 후 `broadcast`, result/fail 성공 후 `notifyStatus` 호출
- Test: `.../quiz/authoring/JobLogStreamTest.java` (MockMvc async)

**Interfaces:**
```java
@Component public class JobLogStreamService {
    public SseEmitter subscribe(Long jobId, Integer fromSeq);          // 리플레이 + 등록 (터미널 상태면 status 쏘고 즉시 complete)
    public void broadcast(Long jobId, List<JobLog> lines);             // event:log, id:seq
    public void notifyStatus(Long jobId, GenerationJob job);           // event:status 후 모든 emitter complete
}
```
- 구현 규칙: emitter 타임아웃 30분(`new SseEmitter(Duration.ofMinutes(30).toMillis())`), 레지스트리는 `ConcurrentHashMap<Long, CopyOnWriteArrayList<SseEmitter>>`, `onCompletion`/`onTimeout`/`onError`에서 자기 제거. `IOException` 발생 emitter는 목록에서 제거. 단일 인스턴스 전제(현 배포 구조 = EC2 컨테이너 1대) — 주석으로 명시.
- 컨트롤러: `HttpServletResponse`에 `X-Accel-Buffering: no` 헤더 설정(Nginx 프록시 버퍼링 무력화). **배포 노트(코드 아님, PR 본문에 기재)**: Nginx `location`에 `proxy_read_timeout`이 SSE 유지시간보다 짧으면 스트림이 끊긴다 — 운영 반영 시 `/api/v1/authoring/jobs/` 경로에 `proxy_read_timeout 1800s;` 권장.
- status 이벤트 데이터: `{"status":"SUCCEEDED","draftId":42,"error":null}` (ObjectMapper 직렬화).

- [ ] **Step 1: 실패하는 테스트 작성** — Testcontainers `@SpringBootTest`+MockMvc: ① 로그 3행 저장된 RUNNING 잡 스트림 구독(`fromSeq=1`) → 응답 본문에 seq 2·3의 `event:log` 라인 존재, ② SUCCEEDED 잡 구독 → `event:status` + `"SUCCEEDED"` 포함 후 종료. (`request().asyncStarted()` → `asyncDispatch` 패턴.)
- [ ] **Step 2: FAIL → Step 3: 구현 → Step 4: PASS.**
- [ ] **Step 5: 최종 게이트** — `./gradlew --no-daemon spotlessApply build` 전체 통과 확인.
- [ ] **Step 6: 커밋** — `feat(server): 잡 로그 SSE 스트림 (#174)`

---

## Self-review 체크 (플랜 작성자 완료)

- 스펙 §5~§10의 서버 책임 전부 태스크에 매핑됨 (스키마 T1, 가시성 T2, 프롬프트·스키마 T3, draft T4, 큐·가드·만료 T5, 승인 T6, REST T7~T8, SSE T9).
- 잡 만료는 스케줄러 대신 lazy 평가로 구현 (스펙 "N분 후 만료"의 구현 단순화 — @EnableScheduling 도입 회피, 의도적).
- 타입 일관성: `ReviewResult`·`GeneratedQuizSet`·DTO 필드명이 브리지/앱 플랜과 공유 계약 절에서 일치.

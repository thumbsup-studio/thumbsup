# 홈 화면 조회 API (#45) Implementation Plan

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유저 기준 스트릭·포인트·오늘의 학습 진입점을 한 번에 반환하는 `GET /api/v1/home`을 구현한다. 문제 완료 시 streak/points를 갱신하는 쓰기 로직은 범위 밖(후속 티켓) — 이번 PR은 조회만 다룬다.

**Architecture:** 새 `studio.thumbsup.server.learning` feature 패키지에 `Course`(코스) → `Unit`(화) → `UserProgress`(유저별 진행상태: 커서·스트릭·포인트) 엔티티와 `HomeController`→`HomeService`→`{Course,Unit,UserProgress}Repository` 계층을 `notice/`·`quiz/` 레퍼런스 패턴으로 구현한다. 기존 `quiz` 패키지는 무수정 — ArchUnit `피처_간_직접_의존_금지`가 feature 슬라이스 간 의존을 전면 차단하므로, `learning`은 자기 소유 테이블만 갖는다(크로스 피처 조회 자체가 필요 없도록 설계).

**Tech Stack:** Spring Boot 3(Web/Data JPA/Security), Flyway(MySQL), JUnit5 + Mockito + AssertJ + Testcontainers.

**설계 근거 전체:** `docs/specs/2026-07-09-home-query-api-design.md` (결정 기록 표 포함)

## Global Constraints

- API 베이스 경로 `/api/v1`, 모든 응답은 `ApiResponse{code,message,data,meta}` envelope (`docs/api-standard.md` §2)
- 유저 식별은 항상 `@AuthenticationPrincipal Long userId`에서 — request body/param 신뢰 금지 (IDOR 방지)
- 표준 예외 직접 생성 금지 — 항상 `BusinessException(LearningErrorType)` (ArchUnit 강제)
- 생성자 주입만, `@Transactional`은 `@Service` 클래스에만, Controller는 Repository/Entity 직접 사용 금지 (ArchUnit 강제)
- feature 패키지 간 직접 의존 금지(`common` 제외, ArchUnit 강제) — `learning`은 `quiz`/`auth`를 import하지 않는다
- JPA 엔티티를 API 응답으로 직접 반환 금지 — API별 `record` DTO + 정적 팩토리 `from()`
- 한 PR = 마이그레이션 파일 1개 원칙이나, 이번은 create+seed 2개(quiz 선례와 동일하게 분리)
- 테스트 4종(Service/Controller/Repository/Fixture) 없는 PR 금지, `./gradlew --no-daemon spotlessApply build` 통과 후 PR

---

### Task 1: Flyway 마이그레이션 + 엔티티/리포지토리

**Files:**
- Create: `server/src/main/resources/db/migration/V20260709161009__create_learning_tables.sql`
- Create: `server/src/main/resources/db/migration/V20260709161024__seed_learning_sample.sql`
- Create: `server/src/main/java/studio/thumbsup/server/learning/{Course,Unit,UserProgress}.java`
- Create: `server/src/main/java/studio/thumbsup/server/learning/{Course,Unit,UserProgress}Repository.java`

- [x] **Step 1: 마이그레이션 작성** — `course`/`unit`(FK CASCADE)/`user_progress`(FK 없음, `uk_user_progress_user_course` unique) DDL + "CS 기초" 코스·화 10개·데모 진행 2건 시드
- [x] **Step 2: 엔티티 작성** — `Course`(aggregate root, `addUnit`), `Unit`(`@ManyToOne Course`), `UserProgress`(`userId`/`courseId`는 ID값 참조)
- [x] **Step 3: 리포지토리 작성** — `findFirstByOrderByIdAsc`, `findByCourseIdAndOrderIndex`/`countByCourseId`, `findByUserId`

### Task 2: Service/Controller/DTO/ErrorType

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/learning/HomeService.java`
- Create: `server/src/main/java/studio/thumbsup/server/learning/HomeController.java`
- Create: `server/src/main/java/studio/thumbsup/server/learning/LearningErrorType.java`
- Create: `server/src/main/java/studio/thumbsup/server/learning/dto/HomeResponse.java`

- [x] **Step 1: `HomeResponse` DTO** — `streakDays`, `points`, `today{courseId,courseTitle,unitId,unitTitle,order,completedCount,totalCount,estimatedMinutes}` — 필드명은 앱 홈(`courseTitle`/`unitTitle`/`streakDays`)과 정렬
- [x] **Step 2: `LearningErrorType`** — `COURSE_NOT_FOUND(404)`
- [x] **Step 3: `HomeService.getHome(userId)`** — 진행 기록 없으면 streak 0/points 0/1화 기본 상태(에러 아님), 커서가 전체 화 수 초과 시 마지막 화로 clamp
- [x] **Step 4: `HomeController`** — `GET /api/v1/home`, `@AuthenticationPrincipal Long userId`

### Task 3: 테스트 4종 + 공용 테스트 유틸

**Files:**
- Create: `server/src/test/java/studio/thumbsup/server/learning/LearningFixture.java`
- Create: `server/src/test/java/studio/thumbsup/server/learning/HomeServiceTest.java`
- Create: `server/src/test/java/studio/thumbsup/server/learning/HomeControllerTest.java`
- Create: `server/src/test/java/studio/thumbsup/server/learning/LearningRepositoryTest.java`
- Create: `server/src/test/java/studio/thumbsup/server/common/DatabaseCleanUp.java`

- [x] **Step 1: `LearningFixture`** — 영속화 없이 `Course`(+units)/`UserProgress` 조립 (`ReflectionTestUtils`)
- [x] **Step 2: `HomeServiceTest`(Mockito)** — 저장된 진행 반환/신규 유저 기본값/커서 clamp/completedCount 계산/코스·화 없음 시 `COURSE_NOT_FOUND`
- [x] **Step 3: `HomeControllerTest`(standalone MockMvc)** — 200 envelope + 필드값 / 404 `COURSE_NOT_FOUND`
- [x] **Step 4: 공용 `DatabaseCleanUp`(`common` 테스트 패키지)** — Flyway 시드와 "첫 코스"/"특정 user_id" 절대값 테스트가 충돌해 신설. 전체 테이블 TRUNCATE + AUTO_INCREMENT 리셋, 테이블명은 `@Table(name=...)` 값을 직접 읽음(클래스명 변환은 `users`처럼 복수형 테이블에서 어긋남)
- [x] **Step 5: `LearningRepositoryTest`(`@DataJpaTest`+Testcontainers)** — `@BeforeEach`에서 `DatabaseCleanUp` 호출 후 저장·조회·unique 제약·cascade 검증

### Task 4: 검증

- [x] **Step 1:** `cd server && ./gradlew --no-daemon spotlessApply build` — 전체 그린(테스트 133개, ArchUnit·Checkstyle·Spotless 포함)
- [ ] **Step 2:** 로컬 기동 후 실제 `GET /api/v1/home` 수동 호출 확인 (커밋/PR 전 마지막 확인 항목)
- [ ] **Step 3:** `commit`/`pr` 스킬로 커밋·PR, 본문에 `Closes #45` + "응답 필드 앱 합의 필요" 명시

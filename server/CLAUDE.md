# Thumbs Up 서버 — AI 코딩 규칙 (인덱스)

서버 코드를 작성·수정하기 전에 아래 문서를 읽는다.
**규칙의 정본은 `./docs/`이며, 이 파일은 요약과 인덱스만 담는다.**

## 계약 — FE와 공유 (어기면 FE가 깨진다)

- [../docs/api-standard.md](../docs/api-standard.md) — 응답 envelope, HTTP status 정책, 네이밍, 날짜, 페이지네이션, 인증, CORS
- [../docs/error-spec.md](../docs/error-spec.md) — 에러 응답 형식, ErrorType 코드 체계, 공통 에러 카탈로그

## 서버 구현 규칙 (정본)

- [./docs/dto-and-query-patterns.md](docs/dto-and-query-patterns.md) — DTO 작성 규칙, 크로스 도메인 조회 패턴
- [./docs/error-implementation.md](docs/error-implementation.md) — ErrorType·예외·전역 핸들러 구현
- [./docs/env-guide.md](docs/env-guide.md) — 프로파일(local/prod), SSM Parameter Store, 시크릿
- [./docs/ci-requirements.md](docs/ci-requirements.md) — CI/CD 담당자 인수인계 명세 (참고)

## 핵심 규칙 요약 (근거·상세는 위 문서)

1. **표준 예외 생성 금지** — `IllegalArgumentException` 등 대신 항상 `BusinessException(ErrorType)`. ErrorType은 feature별 enum.
2. **JPA 엔티티를 API로 직접 노출 금지** — API별 `record` DTO + 정적 팩토리 `from()`. DTO 재사용 금지, MapStruct 금지.
3. **도메인 경계를 넘는 JPA 연관관계 금지** — 다른 도메인은 ID 값으로 참조, 조회는 "ID 수집 → in절 일괄 조회 → Service 조립" (N+1 금지).
4. **생성자 주입만** (필드 `@Autowired` 금지) · `@Transactional`은 Service에만 · Controller는 검증·변환·호출만.
5. **시크릿 하드코딩 금지** · `@Value`에 default 값 금지 (fail-fast).
6. 시간은 주입받은 `Clock` 사용 (`LocalDateTime.now()` 직접 호출 금지).
7. 인터페이스는 구현이 2개 이상이거나 외부 경계일 때만 (불필요한 추상화 금지).

## 패키지 구조 (기능별 — package-by-feature)

```text
studio.thumbsup.server
├─ common/            # 횡단 관심사 (여기만 여러 feature가 공유)
│  ├─ response/       # ApiResponse, CursorMeta, CursorPage
│  ├─ exception/      # ErrorType(인터페이스), CommonErrorType, BusinessException, GlobalExceptionHandler
│  ├─ security/       # JWT 필터·토큰·엔트리포인트
│  ├─ config/         # Security·Cors·Clock·Auditing·OpenApi
│  ├─ entity/         # BaseEntity(createdAt/updatedAt)
│  ├─ logging/        # RequestIdFilter
│  └─ time/           # TimeZones.KST
├─ notice/            # ★ 레퍼런스 feature — 새 API는 이걸 복제한다
│  ├─ Notice.java             (Entity, BaseEntity 상속)
│  ├─ NoticeController.java   (얇게 — 검증·호출·envelope만)
│  ├─ NoticeService.java      (@Transactional·비즈니스 로직)
│  ├─ NoticeRepository.java
│  ├─ NoticeErrorType.java    (feature별 enum)
│  └─ dto/                    (API별 record — 재사용 금지)
└─ quiz/ user/ ...    # 각 feature 동일 구조
```

- 다른 feature의 `internal`을 import하지 않는다 (ArchUnit 강제). feature 간 공유가 필요하면 `common`으로 올린다.
- 한 feature 폴더는 티켓 단위로 한 명이 소유한다 (충돌 방지).

## 새 API 만드는 절차 (notice를 복제)

1. **`notice/` 패키지를 통째로 복제**하고 도메인명으로 치환 (`Notice`→`Quiz` 등).
2. **Flyway 마이그레이션 추가** — `src/main/resources/db/migration/V{yyyyMMddHHmmss}__{설명}.sql`. 타임스탬프는 `date +%Y%m%d%H%M%S`. **적용된 파일은 절대 수정하지 않는다** (수정은 새 파일로).
3. DTO는 **API별로** 새로 만든다 (목록/상세/생성 각각). 엔티티→DTO 변환은 `record`의 정적 팩토리 `from()`.
4. 도메인 에러는 `{Domain}ErrorType`에 추가 (common 건드리지 않기).
5. 다른 도메인 데이터가 필요하면 **연관관계 대신 ID로** 참조하고 조회는 [in절 일괄 조립 패턴](docs/dto-and-query-patterns.md#2-크로스-도메인-조회-조합-패턴)을 따른다 (해당 문서에 구현 예시·`@AuthenticationPrincipal`로 유저 식별하는 IDOR 방지 예시 포함). notice는 단일 엔티티라 이 패턴이 없으니, **크로스 도메인이 필요한 첫 feature는 그 문서 예시를 정본으로 삼는다.**
6. **테스트 4종을 함께 복제** — Service(Mockito)·Controller(standalone MockMvc)·Repository(@DataJpaTest+Testcontainers)·Fixture. 테스트 없는 PR은 올리지 않는다.
7. `./gradlew build` 통과 후 PR. (빌드에 테스트·ArchUnit·Spotless·Checkstyle이 전부 포함됨 — **빌드 통과 전 PR 금지**)

> 상세 규칙의 근거는 위 `docs/` 문서들에 있다. 판단이 서지 않으면 `notice/`의 실제 코드를 그대로 따른다.

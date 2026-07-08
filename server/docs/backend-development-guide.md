# 백엔드 개발 가이드

이 문서는 AI agent와 사람이 같은 방식으로 서버 feature를 만들기 위한 작업 규칙이다.
세부 계약은 루트 `docs/`, 구현 규칙은 `server/docs/`가 정본이다.

## 1. 작업 시작 전 읽기 순서

1. `server/CLAUDE.md`
2. `docs/api-standard.md`
3. `docs/error-spec.md`
4. `server/docs/dto-and-query-patterns.md`
5. `server/docs/error-implementation.md`
6. 이 문서와 `server/docs/testing-guide.md`

AI agent는 위 문서를 읽기 전 코드 생성을 시작하지 않는다.

## 2. 기본 구조

서버는 package-by-feature 구조다.

```text
studio.thumbsup.server
├─ common/     # 횡단 관심사
├─ notice/     # 레퍼런스 feature
└─ {feature}/  # 새 API feature
```

새 API는 `notice/`를 복제한 뒤 도메인명, 경로, DTO, ErrorType, 테스트를 바꾼다.
공유가 필요하다는 이유만으로 무조건 `common`에 올리지 않는다. 두 feature 이상에서 실제로 필요할 때만 올린다.

## 3. Controller / Service / Repository

- Controller는 검증, DTO 변환, Service 호출, envelope 반환만 한다.
- Service는 트랜잭션 경계와 비즈니스 결정을 담당한다.
- Repository는 feature 패키지 안에 둔다.
- 다른 feature의 Entity를 직접 연관관계로 물지 않는다. ID로 참조하고 in절 일괄 조회 후 Service에서 조립한다.
- API DTO는 record로 만들고 API별로 분리한다. Entity를 API 응답으로 직접 노출하지 않는다.

## 4. 예외와 응답

- 표준 예외(`IllegalArgumentException` 등)를 새로 던지지 않는다.
- 비즈니스 예외는 `BusinessException(ErrorType)`만 사용한다.
- feature별 `{Feature}ErrorType`을 만들고 common error를 남용하지 않는다.
- 응답 envelope와 HTTP status는 `docs/api-standard.md`, `docs/error-spec.md`를 따른다.

## 5. Flyway

스키마 변경은 Flyway 마이그레이션으로만 한다. Hibernate `ddl-auto`는 `validate`다.

- 파일명: `src/main/resources/db/migration/V{yyyyMMddHHmmss}__{description}.sql`
- 타임스탬프 생성: `date +%Y%m%d%H%M%S`
- 이미 적용된 마이그레이션 파일은 수정하지 않는다. 변경은 새 마이그레이션으로 추가한다.
- MySQL 문법으로 작성하고 Testcontainers Repository 테스트로 검증한다.

## 6. 설정과 시크릿

- 새 시크릿은 SSM Parameter Store에 둔다.
- local은 `/thumbsup/local/`, prod는 `/thumbsup/prod/`만 읽는다.
- 설정 프로퍼티는 `@ConfigurationProperties` + Bean Validation을 우선한다.
- `@Value("${KEY:default}")` 형태의 default는 금지한다.
- 로컬 DB 접속정보는 docker-compose 고정값을 유지한다.

## 7. AI agent 작업 규칙

- `server/` 밖은 건드리지 않는다.
- 광범위 리팩터링과 feature 구현을 한 PR에 섞지 않는다.
- notice 패턴과 기존 테스트 스타일을 먼저 복제한다.
- 모르는 SDK/프레임워크 동작은 공식 문서나 현재 의존성 메타데이터로 확인한다.
- generated secret, 실제 계정, AWS credential을 만들거나 문서에 남기지 않는다.
- PR 전 변경 파일 목록을 확인하고, 필요한 파일만 명시적으로 stage한다.

## 8. PR 전 게이트

```bash
cd server
./gradlew --no-daemon spotlessApply build
```

추가 확인:

- `git diff --cached`에 secret 값이 없는가
- Swagger/OpenAPI가 public `permitAll`이 아닌가
- 새 Flyway 파일명이 충돌하지 않는가
- 새 API의 성공/실패/검증/DB 테스트가 있는가

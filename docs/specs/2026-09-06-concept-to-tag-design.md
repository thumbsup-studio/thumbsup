# Concept → Tag 재설계 — 지식 그래프 데이터 모델 확장

- **날짜**: 2026-09-06
- **상태**: 설계 완료 — 이슈 미생성(브레인스토밍 단계, 구현 착수 전)
- **관련**: 이슈 [#233](https://github.com/thumbsup-studio/thumbsup/issues/233)(CLOSED)/PR [#253](https://github.com/thumbsup-studio/thumbsup/pull/253)(merged)에서 만든 지식 그래프 모델의 후속 재설계

## 배경과 목표

`#233`에서 만든 지식 그래프(`/api/v1/history/graph`)는 퀴즈 하나당 정규화된 핵심 개념(`Concept`)을 **딱 1개**만 연결한다(`quiz_concept.quiz_id`에 UNIQUE 제약). 그 결과 유저가 학습한 노드 수가 완료한 퀴즈 수를 넘지 못하고, 그래프가 단조롭게 그려진다.

이 문서는 "개념(concept)" 도메인을 "태그(tag)"로 재명명하면서, 퀴즈 하나당 태그를 최대 3개까지 연결할 수 있도록 카디널리티를 넓히는 재설계를 다룬다. 목표는 그래프 밀도를 높이는 것 하나다 — 그 외 기능은 늘리지 않는다(YAGNI).

## 결정 사항

| 질문 | 결정 |
|---|---|
| concept → tag 변경의 성격 | 이름만 바꾸는 게 아니라 **카디널리티도 변경**(퀴즈당 1개 → 최대 3개) |
| 태그 간 관계(그래프 엣지) | `TagRelation` **테이블 구조는 그대로 유지**(자유 페어 저장, 코스·카테고리 경계 없음, rename만 수행). **채우는 방식**은 사람의 수동 큐레이션 대신 **LLM 판단**(전체 태그 목록을 주고 관련 쌍을 판단시켜 후보를 얻음)으로 전환 예정 — 이 population 로직 자체는 이번 스펙 범위 밖, 재태깅과 같은 후속 이슈에서 다룬다(아래 "비범위" 참고) |
| 기존 콘텐츠(4개 코스, 이미 시드된 퀴즈) | 이번 스펙 범위에서 **제외**(비범위 참고) — AI 저작 파이프라인으로 태그 2개씩 추가하는 재큐레이션은 별도 후속 이슈 |
| 같은 태그의 여러 코스 재사용 | **허용**됨 → 기존 `LearnedConceptRecorder`의 동시성 안전 근거(태그=단일 코스 불변식)가 깨지므로 별도 수정 필요 |
| `/history/graph` API 계약 | **필드 구조 변경 없음** — `nodes[].{id,label,description,learnedAt,category,relatedSteps}`, `edges[].{source,target}` 그대로, 데이터만 밀도 증가. FE 코드 변경/핸드오프 불필요 |
| 퀴즈당 태그 상한(3개) 강제 위치 | DB 제약이 아니라 **저작 파이프라인(앱 레벨)** — 저작 자동화가 생기면 재검토(아래 "확장성" 참고) |
| `Tag.name` 중복 방지 | 정확 일치 unique 제약에 더해 **대소문자·앞뒤 공백 무시 정규화 unique 제약**을 추가(이번 스펙 포함) |

## 스코프

### 포함

- 테이블/엔티티 rename: `Concept`→`Tag` 등
- `quiz_concept` → `quiz_tag` 카디널리티 확장(1개 → 최대 3개)
- `Tag.name` 정규화 unique 제약 추가
- `LearnedConceptRecorder`의 동시성 버그 수정
- Java 패키지 이동(`quiz/concept/` → `quiz/tag/`) 및 rename 범위 전체

### 비범위 (후속 이슈로 분리)

- **기존 4개 코스 퀴즈 재태깅**(태그 2개씩 추가) — 스키마 변경과 같은 브랜치/PR에 묶지 않는다. 이 레포는 코스별 콘텐츠 시드를 이미 별도 커밋/PR로 관례화했고(`V20260904142250` 등), 합치면 AI 저작 산출물의 문제가 스키마 변경 롤백 리스크까지 끌어들인다.
- **저작 시점 자동 태깅**(AI가 퀴즈 생성과 동시에 태그까지 자동 연결) — `QuizConcept`(→`QuizTag`) Javadoc이 이미 "후속 이슈" 범위로 명시해뒀고, 이번 재설계도 그 경계를 유지한다.
- **태그 매칭/중복 방지 판단 프로세스**(오타·동의어·표기 차이로 "의미상 같은데 다른 문자열"인 태그 판단, 예: "재귀" vs "재귀함수" vs "Recursion") — 이건 스키마로 해결되는 문제가 아니라, 저작 시점에 기존 태그 목록을 먼저 검색해 후보를 보여주고 사람이 확인하는 **프로세스/도구의 문제**다. 이번 스펙은 정확 일치(정규화 포함) 중복만 DB 레벨로 막고, 의미적 중복 판단은 후속 재태깅 파이프라인 설계의 몫으로 남긴다.
- **`TagRelation` population — LLM 기반 관계 판단** — 전체 태그 목록(이름+카테고리)을 LLM에게 주고 관련 있는 쌍을 판단시켜 후보를 얻은 뒤 검수·insert-only 마이그레이션으로 반영하는 파이프라인. 재태깅이 먼저 끝나 태그 목록이 확정돼야 의미 있는 관계를 판단할 수 있고, "AI 생성 → 검수 → 시드 마이그레이션"이라는 동일한 작업 패턴이라 재태깅과 같은 후속 이슈에서 함께 다룬다. 이번 스펙은 `TagRelation` 테이블 스키마만 그대로 이관한다.

## 데이터 모델

### 1. 테이블/컬럼 rename

현재 라이브 스키마 기준(`V20260801192744`, `V20260814205342`로 진화한 최종 상태) 컬럼명으로 rename한다. 새 Flyway 마이그레이션 파일 하나로 수행하고, 기존 적용된 마이그레이션 파일은 건드리지 않는다.

```sql
-- 1) 테이블명 변경
RENAME TABLE concept TO tag;
RENAME TABLE concept_relation TO tag_relation;
RENAME TABLE concept_description TO tag_description;
RENAME TABLE user_concept TO user_tag;
RENAME TABLE user_concept_step TO user_tag_step;
RENAME TABLE quiz_concept TO quiz_tag;
RENAME TABLE quiz_derived_concept TO quiz_derived_tag;

-- 2) FK 컬럼명 변경 (MySQL RENAME TABLE은 컬럼명까지 바꿔주지 않는다)
ALTER TABLE tag_relation
    CHANGE COLUMN source_concept_id source_tag_id BIGINT NOT NULL,
    CHANGE COLUMN target_concept_id target_tag_id BIGINT NOT NULL;

ALTER TABLE tag_description
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;

ALTER TABLE user_tag
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;

ALTER TABLE user_tag_step
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;

ALTER TABLE quiz_tag
    CHANGE COLUMN concept_id tag_id BIGINT NOT NULL;
```

> 제약/인덱스 이름(`uk_concept_name`, `fk_concept_relation_source` 등)은 MySQL이 rename 시 자동으로 안 바꿔준다. 기능에는 영향 없지만 가독성을 위해 같은 마이그레이션에서 `DROP`+`ADD CONSTRAINT`로 이름도 `tag_*` 접두로 정리한다(실제 구현 단계에서 전체 목록 작성).

### 2. `quiz_tag` 카디널리티 확장

```sql
ALTER TABLE quiz_tag DROP INDEX uk_quiz_concept_quiz;         -- quiz_id 단독 unique 제거
ALTER TABLE quiz_tag ADD CONSTRAINT uk_quiz_tag_pair UNIQUE (quiz_id, tag_id);
```

"퀴즈당 최대 3개"는 DB 제약이 아니라 저작 파이프라인(신규 재태깅/향후 자동 태깅)이 강제하는 앱 레벨 규칙이다.

### 3. `Tag.name` 정규화 unique 제약

기존 `uk_concept_name UNIQUE(name)`은 `utf8mb4_unicode_ci` collation 덕에 이미 대소문자를 구분하지 않는다. 하지만 앞뒤 공백 등 표기 차이까지는 못 잡으므로, 명시적인 정규화 컬럼을 추가해 의도를 코드로 남긴다.

```sql
ALTER TABLE tag DROP INDEX uk_concept_name;
ALTER TABLE tag
    ADD COLUMN normalized_name VARCHAR(200)
        GENERATED ALWAYS AS (LOWER(TRIM(name))) STORED NOT NULL;
ALTER TABLE tag ADD CONSTRAINT uk_tag_normalized_name UNIQUE (normalized_name);
```

내부 공백(예: "재귀  함수" vs "재귀 함수")이나 동의어까지는 잡지 않는다 — 그 이상은 위 "비범위"에서 밝힌 저작 프로세스의 몫이다.

## 동시성 수정 — `LearnedConceptRecorder` → `LearnedTagRecorder`

기존 코드는 "조회 후 삽입"이 안전한 근거로 "① 유저·코스 단위 비관적 락으로 같은 코스 내 동시 완료는 직렬화됨, ② 하나의 개념은 하나의 코스에서만 출제된다는 시드 큐레이션 불변식 덕에 서로 다른 코스의 동시 완료가 경합하지 않음"을 들었다. 태그가 여러 코스에서 재사용될 수 있게 되면서 근거 ②가 깨진다.

**수정 방향** (빅테크 리드 리뷰에서 지적받은 두 가지 반영):

1. **예외 catch 방식 대신 네이티브 upsert 사용.** 이 클래스는 호출자(`QuizService`)와 같은 트랜잭션에 동참하도록 의도적으로 설계됐다(AFTER_COMMIT 리스너를 쓰지 않음). JPA `save()`가 unique 제약 위반 예외를 던지면 persistence context가 rollback-only로 마킹돼 같은 트랜잭션의 다른 작업(진행도 갱신 등)까지 커밋 실패할 수 있다. `UserTagRepository`에 `INSERT IGNORE`(또는 `INSERT ... ON DUPLICATE KEY UPDATE id = id`) 네이티브 쿼리를 추가해 DB가 예외를 던지지 않게 한다.
2. **`UserTag`와 `UserTagStep` insert를 분리해서 처리한다.** 멱등 보호가 필요한 건 `UserTag`(userId, tagId) unique뿐이다. 같은 루프에서 두 insert를 한 번에 묶으면, 경합에서 "졌다"고 판단된 스레드가 `UserTagStep`(관련 스텝 기록)까지 스킵해버려 그 스텝이 그래프 상세카드 `relatedSteps`에서 영구 누락된다(insert-once라 복구 불가). `UserTagStep`은 경합 승패와 무관하게 항상 독립적으로 insert한다.

네이티브 insert는 JPA Auditing(`created_at`/`updated_at` 자동 채움)을 우회하므로, 호출부에서 주입받은 `Clock`으로 타임스탬프를 직접 계산해 넘긴다(구체 시그니처는 구현 단계에서 확정).

## API 계약

`/api/v1/history/graph` 응답 필드 구조 변경 없음. `HistoryService`/`HistoryGraphResponse`는 참조 타입만 `Concept`→`Tag`로 바꾸고 JSON 필드명은 그대로 유지한다. FE 코드 변경이나 핸드오프가 필요 없다 — 그래프가 더 조밀해질 뿐이다.

## 확장성 — 재검토 트리거

`QuizTag` Javadoc에 "퀴즈당 최대 3개는 저작 파이프라인이 강제하는 앱 레벨 규칙이며, 저작 시점 자동 채움(AI가 퀴즈 생성과 동시에 태그 연결)이 생기면 동시 쓰기로 인한 TOCTOU(상한 위반) 가능성을 재검토해야 한다"는 문구를 남긴다.

## 영향받는 파일 (rename 범위 — 예상보다 넓음)

- `server/src/main/java/studio/thumbsup/server/quiz/concept/**` (패키지 전체, `quiz/tag/`로 이동)
- `server/src/main/java/studio/thumbsup/server/quiz/QuizDerivedConcept.java` → `QuizDerivedTag`
- `server/src/main/java/studio/thumbsup/server/quiz/history/HistoryService.java`, `dto/HistoryGraphResponse.java`
- 테스트: `quiz/concept/`(4종), `quiz/history/`(관련 테스트), `quiz` 최상위의 `QuizServiceLearnedConceptTest`, `QuizStepHistoryServiceTest` 등 최소 8개 파일

## 테스트 전략

- 기존 concept 테스트 4종(Service/Controller/Repository/Fixture)을 rename하고, "퀴즈당 태그 최대 3개" 케이스를 보강한다.
- `LearnedTagRecorder` 동시성 시나리오: 서로 다른 코스를 동시에 완료하며 같은 태그를 처음 학습하는 경합 상황에서 `UserTag`는 1행만 남고 `UserTagStep`은 두 스텝 모두 정상 기록되는지 검증한다.
- `HistoryService`: 퀴즈당 태그 3개가 붙은 상태에서 노드·엣지가 올바르게 확장되는지 검증한다.
- `@DataJpaTest` + Testcontainers로 rename된 테이블·정규화 unique 제약(`normalized_name`)이 마이그레이션대로 적용됐는지 확인한다.
# 문제 콘텐츠 규칙

문제가 어떻게 생겨야 하는지의 정본. 슬롯 구성·프롬프트·검증·저장이 여기 다 모여 있다.

```text
server/.../quiz/generation/          ← 패키지 이름은 레거시 CLI 시절 것이다
  QuizGenerationPromptBuilder     프롬프트 조립 (static) — SYSTEM_PROMPT 상수도 여기
  GeneratedQuizValidator          파싱·검증 진입점
    └ CodeSnippetValidator · CodeSnippetLineGuard · KeywordMarkerValidator  (package-private)
  GeneratedQuizSet                draft payload 직렬화 포맷이자 저작 API 응답 타입
  QuizPersister                   라이브 quiz 테이블 저장
  QuizGenerationException
        ↑
  AuthoringJobService · AuthoringApprovalService  (저작 경로가 전부 재사용)
```

⚠️ **패키지 이름에 속지 마라.** `quiz/generation/`은 서버가 엘리스를 직접 호출하던 [레거시 CLI 시절](./content-fix.md#히스토리--지금-라이브-문제는-어디서-왔나) 이름이지만, **저작 파이프라인이 이 코드를 그대로 쓴다.** 그 시절의 호출 코드(`EliceClient`·`QuizGenerationService`·`QuizGenerationRunner`)는 제거됐다 — **서버는 LLM을 직접 부르지 않는다.** 실행은 팀원 노트북의 브리지가 한다.

여기를 고치면 저작 파이프라인 전체에 영향이 간다.

## 스텝 구성 (고정, 변경 불가)

`GeneratedQuizValidator.EXPECTED_SLOTS`에 하드코딩. 순서·유형·난이도가 정확히 이 조합이어야 하고 어긋나면 검증 실패다.

| 슬롯 | 유형 | 난이도 |
|---|---|---|
| 1 | OX | EASY |
| 2 | OX | EASY |
| 3 | MULTIPLE_CHOICE | MEDIUM |
| 4 | MULTIPLE_CHOICE | MEDIUM |
| 5 | KEYWORD_BLANK | HARD |

변형 출제(슬롯당 여러 후보 중 랜덤)는 지원하지 않는다 — 슬롯당 문제 1개 고정 스키마와 일치시킨 설계.

⚠️ **이 표의 난이도는 "형식" 난이도다.** `EASY`/`MEDIUM`/`HARD`는 문제 유형의 난이도이지 **콘텐츠 난이도가 아니다.** 이 조합은 바뀌지 않는다 — 늘 OX 2개·사지선다 2개·키워드 빈칸 1개다.

"얼마나 쉬운/어려운 개념을 다루는가"는 **별도 축**으로, `GenerationLevel`(BASIC·STANDARD·ADVANCED)이 `QuizGenerationPromptBuilder`의 유형별 콘텐츠 난이도 힌트를 켠다(#193). **저작 파이프라인은 이 축을 쓰지 않는다** — `AuthoringPromptFactory`가 `build(topic)` 1인자 오버로드를 불러 **STANDARD 고정**이고(힌트 없이 모델 판단에 맡김), 대시보드에도 난이도 선택 UI가 없다. 레벨을 태우려면 `AuthoringPromptFactory`부터 고쳐야 한다.

슬롯 배열은 `validateSet`(5문제 세트)에서만 쓴다. `validateSingle`은 호출자가 넘긴 type/difficulty와 대조하며, 저작 경로의 IMPROVE 단건 검수용이다.

## 프롬프트 — 정본은 코드다

⚠️ **프롬프트 전문을 문서에 복붙하지 마라.** 과거 이 스킬은 91줄을 복붙해뒀는데, 코드와 문서를 **같은 커밋에서 동시에 고쳤는데도** 두 군데가 갈라졌다. 그중 하나는 문서 버전을 코드로 되돌리면 `QuizGenerationPromptBuilderTest`가 깨지는 상태였다. 복붙본은 유지보수되지 않는다.

| 조각 | 위치 |
|---|---|
| system 프롬프트 (고정 페르소나) | `QuizGenerationPromptBuilder.SYSTEM_PROMPT` |
| user 프롬프트 조립 | `QuizGenerationPromptBuilder.build(topic)` |
| └ 슬롯 구성 지시 | `SLOT_COMPOSITION` |
| └ 공통 요구사항·꼬리질문 상세 | `COMMON_REQUIREMENTS` |
| └ 마커 규칙 | `MARKER_RULES` |
| └ JSON 스키마 | `SCHEMA` |
| 저작 REVIEW 전용 템플릿 | `AuthoringPromptFactory.REVIEW_TEMPLATE` |

**REVIEW 잡은 `QuizGenerationPromptBuilder`를 쓰지 않는다.** `AuthoringPromptFactory`의 자체 템플릿이며, 공유하는 건 `SYSTEM_PROMPT` 헤더뿐이다. 조건부 섹션 두 개가 붙는다 — 피드백(비어 있으면 생략), 형제 문제 목록(IMPROVE 경로에서 같은 스텝의 다른 문제 questionText를 "개념 중복 금지" 맥락으로 주입).

프롬프트를 고칠 땐 `QuizGenerationPromptBuilderTest`가 부분 문자열을 assert하고 있으니 함께 확인할 것.

### system 프롬프트가 그렇게 쓰인 이유

"교재 수준의 정확성"·"확신이 없으면 더 널리 알려진 소재로 대체"를 명시한 건, 페르소나 없이 돌렸을 때 그럴듯하지만 미묘하게 틀린 사실(존재하지 않는 알고리즘 이름 등)이 섞여 나왔기 때문이다. 불확실한 소재 자체를 피하도록 유도한다.

⚠️ **`temperature=0.2`·`response_format=json_object`는 더 이상 없다.** 서버가 엘리스를 직접 부르던 시절(`EliceClient`) 설정이고, 지금 실행 주체는 브리지가 띄우는 개인 CLI다.

JSON 구조를 강제하는 수단은 **CLI마다 다르다** — claude만 `--json-schema`(서버가 준 스키마)를 받고, **codex·gemini는 스키마 인자 없이 프롬프트에만 의존한다**([bridge.md](./bridge.md#격리-플래그--왜-붙어-있나-제거-금지)). 그래서 출력 형식의 최종 보증은 전적으로 `GeneratedQuizValidator`이고, 코드펜스가 섞여 오는 경우가 있어 파싱 전에 한 번 더 벗긴다(`stripMarkdownFence`).

## 검증 규칙

진입점은 `GeneratedQuizValidator`다. (`QuizGenerationService#validate`라는 메서드는 **없다** — 예전 문서의 오기.)

- `parse(json)` — 코드펜스 제거 후 Jackson 역직렬화
- `stripMarkdownFence(json)` — public. 저작 경로의 `ReviewResult` 역직렬화가 재사용한다
- `validateSet(set)` — 5문제 세트 전체
- `validateSingle(quiz, type, difficulty)` — 단건(IMPROVE 검수)

하나라도 어기면 `QuizGenerationException`을 던지고 **그 스텝 전체를 저장하지 않는다**(부분 저장 없음).

**공통 필드**
- 문제 정확히 5개, 슬롯별 유형·난이도 일치
- `questionText`·`explanationSummary`·`wrongAnswerExplanation` non-blank. **`explanationExample`은 검증하지 않는다**(null 허용)
- `explanationSummary`는 **정확히 3줄** — 빈 줄 없고 줄 끝 공백도 없어야 한다
- `derivedConcepts` 1개 이상, `keywords` 1개 이상(각 원소의 `keyword`가 non-blank여야 하며 `description`은 검증 안 함)

**타입별**
- OX → `correctAnswer`가 정확히 `"O"` 또는 `"X"`
- MULTIPLE_CHOICE → 선택지 정확히 4개, `isCorrect=true`가 정확히 1개
- KEYWORD_BLANK → `answerKeywords` 바깥 배열 길이 == `questionText`의 `___` 개수, 각 동의어 묶음 non-empty

**꼬리질문**
- `isPrimary=true`가 정확히 1개(리스트가 null이면 여기서 먼저 실패)
- 각 꼬리질문: `content` non-blank이고 **마커 금지** · `difficulty` non-null · `oneLineAnswer` non-blank · `keywords` 1개 이상
- `blocks` 1개 이상, 첫 블록 label이 `"해설"`, **모든 블록의 label·content가 non-blank**

### 코드 지문 (`CodeSnippetValidator` + `CodeSnippetLineGuard`)

`codeSnippet`은 null이거나, **모든 유효 줄이 코드 형태**이면서 **실행 구조를 입증하는 줄이 1개 이상** 있어야 한다. 슬롯 4 전용이 아니라 **모든 슬롯**에 적용된다.

거부: 빈 문자열 · 주석뿐인 값 · 자연어·표·조건 목록 · 리터럴 대입만 나열한 입력 데이터 · 500자를 넘는 한 줄
허용(명시적): 함수 선언·호출·제어 흐름·계산식 · 대문자 의사코드(`IF..THEN`, `FOR..TO` 등) · 전처리기·import · **SQL** · **셸 파이프라인**

`CodeSnippetLineGuard`는 정규식으로 못 잡는 것을 문자 단위로 검사한다 — 따옴표 짝, 대괄호 인덱스 구조, 함수 호출 인자 구조. `note(items[사용자가 로그인한 경우])` 같은 자연어 위장을 여기서 거른다.

이건 컴파일러가 아니라 **보수적인 가드**다. 미지원 언어 문법의 진짜 코드를 거부하는 false negative는 안전 쪽 선택이다. prod 반영 전 사람의 의미 검수는 여전히 생략할 수 없다.

### 키워드 마커 (`[[용어]]`)

마커를 넣는 곳은 **두 묶음뿐이고 묶음마다 사전이 다르다.**

| 스코프 | 사전 | 규칙 |
|---|---|---|
| 해설 3개 컬럼 (`explanationSummary`·`explanationExample`·`wrongAnswerExplanation`) | 그 **문제**의 `keywords` | 등록 키워드마다 **스코프 전체에서 정확히 1회** |
| 각 꼬리질문의 `oneLineAnswer` + 모든 `blocks[].content` | 그 **꼬리질문**의 `keywords` (부모 것이 아니다) | 꼬리질문 하나 안에서 정확히 1회. 꼬리질문끼리는 서로 독립 |

`questionText`·`codeSnippet`·꼬리질문 `content`에는 절대 넣지 않는다.

- 마커 안 문자열은 사전 값과 **공백·대소문자까지 정확히 일치**해야 한다(오타 감지).
- 조사는 마커 밖에 둔다 — `[[프로세스]]는` (O) / `[[프로세스는]]` (X)
- 등록한 키워드는 최소 한 곳에 마킹돼 있어야 한다(커버리지). 본문에 자연스럽게 못 넣을 용어는 `keywords`에 아예 넣지 마라.
- 중첩 마커(`[[가상 [[메모리]]]]`)에 **전용 검사는 없다.** 마커 정규식이 안쪽 대괄호를 허용하지 않아 매칭에 실패하고, 남은 괄호가 "짝이 맞지 않습니다"로 걸린다.

책임 분리(에러 메시지를 추적할 때 필요):
- **필드 내부** 중복·오타·괄호 짝 → `KeywordMarkerValidator.validateField`
- **필드 간** 중복과 스코프 커버리지 → `GeneratedQuizValidator.validateFieldAcrossScope` / `validateKeywordMarkers` / `validateFollowUpMarkers`

에러 메시지의 스코프 라벨은 `"해설 3개 컬럼"`, `"한 줄 답과 상세 정리 블록"`이다.

## 프롬프트 설계에서 겪은 실패와 대응

규칙이 왜 그렇게 생겼는지의 기록이다. 프롬프트를 손보기 전에 읽어라 — 지운 규칙이 과거에 무엇을 막고 있었는지 알 수 있다.

- **동의어를 빈칸으로 착각** — 모델이 "PCB"와 "Process Control Block"을 별도 빈칸 2개로 쪼개 `answerKeywords` 길이가 실제 `___` 개수와 어긋났다. "동의어는 같은 원소 안에 함께 나열"(중첩 배열) 규칙 + 개수 대조 검증을 함께 넣어 해결.
- **마커 위치 오탐** — 서버가 문자열 검색으로 하이라이트하던 시절, 한국어 조사 때문에 "정렬"이 "정렬되지 않은"의 부분 문자열로 오매칭됐다. 저작 시점에 `[[ ]]`로 위치를 명시하는 방식으로 전환하고 "조사는 마커 밖" 규칙을 추가.
- **키워드가 본문에 없음** — 모델이 `keywords` 목록만 만들고 마킹을 빼먹었다. 프롬프트에 커버리지 문장을 넣고 서버 검증으로 이중 방어했다 — **프롬프트만 믿지 않는다**가 이 파이프라인의 기본 태도다.
- **해설 영역마다 같은 키워드 중복 하이라이트**(#147) — 필드별 첫 등장 규칙만 두면 같은 용어가 요약·예시·오답에서 각각 마킹된다. 3개 컬럼을 **하나의 스코프**로 검증하도록 바꾸고 프롬프트에 컬럼 우선순위를 명시.
- **꼬리질문 영역마다 중복 하이라이트**(#162) — 위와 같은 문제. 한 줄 답 + 모든 블록을 한 스코프로 묶고, 한 줄 답 → 블록 표시 순서를 우선순위로.
- **상세 없는 꼬리질문이 화면에서 사라짐**(#133) — 조회 API가 `hasDetail()`로 거르기 때문에 상세를 빠뜨린 생성물은 **에러 없이 조용히 누락**된다. 그래서 프롬프트에 필드를 넣는 데 그치지 않고 검증으로 저장 전에 막는다.
- **자연어가 코드 블록으로 노출**(#157) — 슬롯 4에 코드 지문을 권장했더니 필요 없는 문제에서도 자연어 상황·조건 목록을 `codeSnippet`에 채웠다. 코드 지문을 선택 사항으로 바꾸고 `CodeSnippetValidator`로 거부.

## 저장 (`QuizPersister`)

- `stepOrder`는 `quizRepository.findMaxStepOrder() + 1`로 자동 채번. 이 쿼리는 **`step_order > 0`인 것만** 본다 — 0은 "스텝 밖 placeholder 샘플" sentinel이다. 또 `quiz_step`이 아니라 **`quiz` 테이블**의 MAX를 보므로, 문제 없이 만들어진 빈 스텝 행이 있으면 번호가 겹칠 수 있는 구조다.
- `QuizStep`(스텝 번호 + 주제명 + `estimatedMinutes`, 기본 3) 먼저 저장 후 5문제를 `slotOrder` 1~5로 배정. `quiz.step_order`가 `quiz_step.step_order`를 FK로 참조해 커리큘럼 무결성이 DB 레벨에서 강제된다.
- 꼬리질문은 `attachDetail`(난이도·한 줄 답) → `addBlock`(`display_order` 1부터, 타입은 `TEXT` 고정) → `addKeyword` 순. `difficulty`와 `one_line_answer`는 DB CHECK 제약으로 짝으로만 존재하도록 강제된다.
- `blocks[].type`은 모델에게 받지 않는다 — `FollowUpBlockType`에 `TEXT`뿐이라 고를 여지를 주면 잘못된 값만 늘어난다.
- `persist`는 `@Transactional`이지만 `populate`는 아니다(저작 IMPROVE 승인이 바깥 트랜잭션 안에서 재사용한다).

`QuizPersister`가 `QuizGenerationService`와 별도 `@Service`인 이유: `@Transactional` 메서드를 같은 클래스에서 `this.x()`로 부르면 Spring AOP 프록시를 안 거쳐(self-invocation) 트랜잭션이 적용되지 않는다. 반드시 외부 빈 호출로 프록시를 타야 한다.

## 알아둘 것

- **마커가 없는 구버전 시드 데이터**는 해설 조회 API에서 `highlights`가 빈 배열로 나간다 — 에러가 아니라 정상.
- **Testcontainers 통합 테스트는 seed 마이그레이션까지 전부 적용**되므로, 테스트 픽스처의 `step_order`는 실제 커리큘럼과 겹치지 않는 값(101/102 등)을 쓴다.
- 테스트 픽스처(`GeneratedQuizJsonFixture`)는 부모 문제 사전을 `PCB`, 꼬리질문 사전을 `FIFO`로 **일부러 갈라놨다** — 둘을 섞어 쓰면 검증기가 오타로 잡아야 한다는 게 픽스처가 지키는 계약이다.
- `QuizGenerationException`은 `RuntimeException` 직접 상속이라 `BusinessException`/`ErrorType` 체계 밖에 있다.

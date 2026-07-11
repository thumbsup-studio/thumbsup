---
name: quiz-generation
description: 엘리스 GPT-5.4로 퀴즈 문제 세트(스텝당 5문제)를 자동 생성해 DB에 저장하는 파이프라인(#26). CLI 트리거 방법, 프롬프트 스키마, [[키워드]] 마커·동의어 그룹 규칙, 생성 검증 로직, prod 반영(로컬 생성→검수→SQL 마이그레이션) 절차를 알아야 할 때. 사용자가 "문제 어떻게 생성해", "새 스텝 만들어줘", "커리큘럼 추가", "퀴즈 생성 파이프라인"이라고 할 때 트리거.
---

# quiz-generation — 문제 생성 파이프라인 (#26)

엘리스 GPT-5.4(`elice-models` 스킬 참조)로 주제 하나당 5문제(스텝 1개)를 생성해 DB에 저장한다. 상시 HTTP 엔드포인트가 아니라 **CLI 전용**이다 — LLM 호출 비용이 들고, 아직 admin/role 체계가 없는 코드베이스에서 열어두면 안전하지 않기 때문.

## 아키텍처 (한 스텝 생성 흐름)

```
QuizGenerationRunner (CLI, @Profile("generate"))
  → QuizGenerationService#generateStep(topic)
      1. EliceClient.generate(prompt)          — 트랜잭션 밖. LLM 호출은 수십 초 걸릴 수 있어
                                                   DB 커넥션을 점유하면 안 된다.
      2. parse()                                — 마크다운 코드펜스 제거 후 GeneratedQuizSet으로 역직렬화
      3. validate()                             — 스키마·마커·빈칸 정합성 검증 (아래 "검증 규칙")
      4. QuizPersister.persist(topic, generated) — @Transactional, 여기서만 DB 커넥션 사용
  → 배정된 stepOrder 반환
```

`QuizPersister`가 `QuizGenerationService`와 분리된 별도 `@Service`인 이유: `@Transactional` 메서드를 같은 클래스 안에서 `this.x()`로 호출하면 Spring AOP 프록시를 거치지 않아(self-invocation) 트랜잭션이 적용되지 않는다. 반드시 외부 빈 호출로 프록시를 타야 한다.

## 실행 방법

```bash
cd server
# 주제 1개, 스텝 1개
./gradlew bootRun --args='--spring.profiles.active=local,generate --topic=운영체제 --steps=1'

# 여러 주제(각각 스텝 1개씩) — 반드시 파일 방식
./gradlew bootRun --args='--spring.profiles.active=local,generate --topicsFile=/path/to/topics.txt'
```

- `topics.txt`는 한 줄에 주제 하나씩(공백 포함 가능).
- ⚠️ **Gradle `--args`는 공백 기준으로 토큰을 통째로 쪼갠다.** `--topics=주제1,주제2`처럼 콤마 나열 방식은 주제에 공백(예: "프로세스 동기화")이 있으면 첫 단어만 남고 잘린다. 여러 주제, 특히 한글 복합 주제는 **항상 `--topicsFile`을 쓴다.**
- 우선순위: `--topicsFile` → `--topics`(콤마, 공백 없는 주제 전용) → `--topic`+`--steps`(같은 주제 반복).
- 실행이 끝나면 웹서버로 남지 않고 `SpringApplication.exit()` + `System.exit()`로 즉시 종료한다.

## 스텝 구성 (고정, 변경 불가)

슬롯 순서와 유형·난이도가 정확히 이 조합이어야 하며 어긋나면 검증에서 실패한다.

| 슬롯 | 유형 | 난이도 |
|---|---|---|
| 1 | OX | EASY |
| 2 | OX | EASY |
| 3 | MULTIPLE_CHOICE | MEDIUM |
| 4 | MULTIPLE_CHOICE | MEDIUM |
| 5 | KEYWORD_BLANK | HARD |

변형 출제(문제 뱅크에서 슬롯당 여러 후보 중 랜덤 출제)는 지원하지 않는다 — 슬롯당 문제 1개 고정 스키마의 전제와 일치시킨 설계.

## 프롬프트 구성 (`EliceClient` + `QuizGenerationPromptBuilder`)

요청은 system 메시지(고정 페르소나·톤) + user 메시지(주제별 스키마·규칙)로 나뉜다. `temperature=0.2`(사실 기반 콘텐츠라 창의성보다 일관성 우선), `response_format=json_object`(자유 텍스트 섞임 방지, 그래도 코드펜스가 섞여 오는 경우가 있어 파싱 전에 한 번 더 벗겨낸다), `readTimeout=2분`(문제 5개 생성은 수십 초 걸릴 수 있음).

### system 프롬프트 (`EliceClient.SYSTEM_PROMPT`, 고정)

```text
너는 컴퓨터공학 전공 교재 수준의 정확성을 가진 CS 강사이며, 학습자의 이해도를 확인하는 퀴즈를 만든다.

- 사실 기반으로만 작성한다. 확실하지 않은 내용, 검증되지 않은 수치·통계, 존재하지 않는 개념이나
  용어를 지어내지 않는다. 확신이 없으면 더 널리 알려진 확실한 소재로 대체한다.
- 사용자가 제시한 JSON 스키마를 한 글자도 벗어나지 않고 정확히 지킨다. 스키마에 없는 필드를
  추가하거나, 요구된 필드를 누락하거나, 타입(문자열/배열/불리언 등)을 다르게 쓰지 않는다.
- 응답은 오직 유효한 JSON 객체 하나뿐이어야 한다. 인사말, 설명 문장, 주석, 마크다운 코드펜스
  (```)는 절대 포함하지 않는다.
```

"교재 수준의 정확성"·"확신이 없으면 대체"를 넣은 이유: 초기 튜닝에서 페르소나 없이 돌렸을 때 그럴듯하지만 미묘하게 틀린 사실(예: 존재하지 않는 알고리즘 이름)이 섞여 나온 적이 있어, 불확실한 소재 자체를 피하도록 명시적으로 유도했다.

### user 프롬프트 (`QuizGenerationPromptBuilder.build(topic)`, 주제별로 조립)

```text
"{주제}" 주제로 학습 퀴즈 5문제를 한 세트로 생성해줘. 오직 아래 JSON 스키마와 정확히 일치하는
JSON 객체 하나만 출력하고, 그 외 설명·마크다운 코드펜스는 절대 포함하지 마.

난이도 구성(정확히 이 순서·개수를 지켜야 함):
1. EASY(OX) — 참/거짓 판정 문제. choices와 answerKeywords는 null, correctAnswer는 "O" 또는 "X".
2. EASY(OX) — 위와 같은 유형, 다른 소재.
3. MEDIUM(MULTIPLE_CHOICE) — 4지선다, choices 배열에 정확히 4개, 그중 정답 1개만 isCorrect=true.
   correctAnswer와 answerKeywords는 null.
4. MEDIUM(MULTIPLE_CHOICE) — 위와 같은 유형, 다른 소재.
5. HARD(KEYWORD_BLANK) — 빈칸 채우기. questionText에 빈칸(___)을 포함하고, answerKeywords는
   "빈칸 개수만큼의 배열"이어야 한다 — 배열 원소 하나가 빈칸 하나다. 빈칸이 1개면 answerKeywords도
   원소 1개짜리 배열이다. 절대로 같은 뜻의 다른 표현(동의어·약어/전체 이름 등)을 별도 빈칸으로
   쪼개서 배열 길이를 늘리지 마라 — 동의어는 그 빈칸에 해당하는 원소 안에 함께 나열한다.
   예: 빈칸 1개, 정답이 "PCB"와 "Process Control Block" 둘 다 인정되면
   answerKeywords = [["PCB", "Process Control Block"]] (배열 길이 1, 안쪽에 동의어 2개).
   choices와 correctAnswer는 null.

모든 문제 공통 요구사항:
- codeSnippet: 실제 코드나 실행 흐름이 명확한 의사코드가 문제 풀이에 필요할 때만 작성한다.
  코드/의사코드가 아니면 반드시 null로 두고, 자연어 상황 설명·표·조건 목록은 questionText에 작성한다.
  변수명에 리터럴 입력값만 대입해 나열한 데이터도 코드가 아니므로 questionText에 문장으로 작성한다.
- explanationSummary: 정확히 개행(\n) 3줄로 된 핵심 요약. 줄 끝 공백·빈 줄 없이 정확히 3줄이어야 한다.
- wrongAnswerExplanation: 이 문제를 틀렸을 때 보여줄, 왜 틀렸는지 설명하는 해설
- followUpQuestions: 1개 이상, 그중 정확히 1개는 isPrimary=true. 각 꼬리질문은 아래 "꼬리질문 상세"를
  빠짐없이 갖춰야 한다
- derivedConcepts: 1개 이상
- keywords: 지문 속에서 학습자가 어려워할 만한 용어 1개 이상과 그 설명

꼬리질문 상세 (followUpQuestions의 각 원소):
- 꼬리질문 화면은 읽기 전용이다 — 학습자가 다시 풀거나 채점받지 않고 읽기만 한다. 그러니 방금 푼
  문제에서 한 걸음 더 들어가는 질문을 쓰고, 그 답과 정리를 같은 원소 안에 함께 담아라.
- content: 질문 본문. 여기엔 마커를 넣지 마라 — 서버가 평문 그대로 내려준다.
- difficulty: 이 꼬리질문 자체의 난이도. 부모 문제의 난이도와 무관하다(HARD 문제의 꼬리질문이 EASY일 수 있다).
- oneLineAnswer: 질문에 답하는 한 문장. 500자 이내.
- blocks: 상세 정리. 첫 블록의 label은 반드시 "해설"이다. 그 뒤로는 문제 성격에 맞는 블록을 필요한 만큼
  덧붙여라(예: "실무 사용처", "흔한 오해", "비교"). label은 50자 이내.
- keywords: 이 꼬리질문 전용 용어 사전. 부모 문제의 keywords와 별개이며, 부모 지문에 없던 용어를
  새로 등록해도 된다. 1개 이상.

키워드 하이라이트 마커:
- 마커를 넣는 곳은 두 묶음뿐이고, 묶음마다 사전이 다르다.
  (1) 해설 3개 컬럼(explanationSummary·explanationExample·wrongAnswerExplanation) — 그 문제의 keywords를 사전으로 쓴다.
  (2) 각 꼬리질문의 oneLineAnswer와 blocks의 content — 그 꼬리질문의 keywords를 사전으로 쓴다.
      부모 문제의 keywords가 아니다.
- questionText·codeSnippet·followUpQuestions의 content에는 절대 넣지 마라.
- 사전에 등록한 각 용어는 아래 영역 우선순위로 선택한 한 위치의 첫 등장만 [[용어]]로 감싸라.
  예: "[[프로세스]]는 실행 중인 프로그램이다."
- 마커 안 문자열은 keyword 값과 공백·대소문자까지 정확히 일치해야 한다.
  조사(은/는/이/가/을/를 등)는 마커 밖에 둔다. 올바름: [[프로세스]]는 / 잘못됨: [[프로세스는]]
- 문제 keywords의 각 용어는 해설 3개 컬럼 전체에서 정확히 한 번만 마킹한다.
  같은 용어가 여러 컬럼에 등장하면 explanationSummary → explanationExample → wrongAnswerExplanation
  우선순위로 한 곳만 골라 마킹하고, 나머지는 마커 없는 평문으로 둔다.
- 꼬리질문 keywords의 각 용어는 oneLineAnswer와 모든 blocks의 content 전체에서 정확히 한 번만 마킹한다.
  같은 용어가 여러 영역에 등장하면 oneLineAnswer → blocks 배열 순서(displayOrder 오름차순) 우선순위로
  한 곳만 골라 마킹하고, 나머지 영역의 같은 용어는 마커 없는 평문으로 둔다.
- 마커를 중첩하거나 겹치게 쓰지 마라 (예: [[가상 [[메모리]]]] 금지).
- 커버리지: 문제의 keywords는 해설 3개 컬럼 중 최소 한 곳에, 꼬리질문의 keywords는 그 꼬리질문의
  oneLineAnswer나 blocks의 content 중 최소 한 곳에 자연스러운 문장으로 등장하고 마킹돼야 한다.
  본문에 자연스럽게 넣을 수 없는 용어는 keywords 목록에 아예 넣지 마라.

JSON 스키마:
{
  "quizzes": [
    {
      "type": "OX | MULTIPLE_CHOICE | KEYWORD_BLANK",
      "difficulty": "EASY | MEDIUM | HARD",
      "questionText": "문제 본문",
      "codeSnippet": "실제 코드 또는 실행 흐름이 명확한 의사코드(필요하지 않으면 null)",
      "explanationSummary": "핵심 3줄 요약 해설 — 해설 3개 컬럼 전체의 keywords 마커 정책 적용",
      "explanationExample": "실무 적용/코드 예시(없으면 null) — 해설 3개 컬럼 전체의 keywords 마커 정책 적용",
      "wrongAnswerExplanation": "오답 해설(왜 틀렸는지) — 해설 3개 컬럼 전체의 keywords 마커 정책 적용",
      "correctAnswer": "OX 전용 정답 \"O\" 또는 \"X\"(그 외 유형은 null)",
      "choices": [{"content": "선택지 내용", "isCorrect": true}],
      "answerKeywords": [["빈칸1 정답", "빈칸1과 같은 뜻의 동의어(있으면)"], ["빈칸2 정답"]],
      "followUpQuestions": [
        {
          "content": "꼬리질문 본문 — 마커를 넣지 않는 평문",
          "isPrimary": true,
          "difficulty": "EASY | MEDIUM | HARD — 이 꼬리질문 자체의 난이도",
          "oneLineAnswer": "한 줄 답 — 꼬리질문 전체 keywords 마커 정책의 최우선 영역",
          "blocks": [
            {"label": "해설", "content": "블록 본문 — 꼬리질문 전체 keywords 마커 정책 적용"}
          ],
          "keywords": [{"keyword": "이 꼬리질문의 어려운 용어", "description": "그 용어의 설명"}]
        }
      ],
      "derivedConcepts": ["관련 파생 개념 이름"],
      "keywords": [{"keyword": "지문 속 어려운 용어", "description": "그 용어의 설명"}]
    }
  ]
}
```

`blocks[].type`은 모델에게 받지 않는다 — `FollowUpBlockType`에 `TEXT`뿐이라 고를 여지를 주면 잘못된 값만 늘어난다.
`QuizPersister`가 `TEXT`로 고정해 저장한다.

### 프롬프트 설계에서 겪은 실패와 그에 대한 대응

- **동의어를 빈칸으로 착각**: 초기 버전은 "동의어도 인정하고 싶으면 어떻게 하라"는 지시가 없었다 — 모델이 "PCB"와 "Process Control Block"을 별도 빈칸 2개로 쪼개 `answerKeywords` 길이가 실제 빈칸(`___`) 개수와 안 맞는 응답을 냈다. 위 5번 규칙(동의어는 같은 원소 안에)과 `validateAnswerKeywords`의 개수 대조 검증을 함께 추가해 해결.
- **마커 위치 오탐**: 마커 규칙 없이 요청하면 한국어 조사 때문에 "정렬"이 "정렬되지 않은"의 부분 문자열로 오매칭되는 문제가 있었다(서버 측 문자열 검색 방식일 때). 저작 시점에 `[[키워드]]`로 위치를 명시하는 방식으로 전환하면서 프롬프트에도 "조사는 마커 밖" 규칙을 명시했다.
- **키워드가 본문에 없음**: 모델이 `keywords` 목록만 만들고 본문에 마킹을 빼먹는 경우가 있어 "커버리지" 문장("반드시 이 3개 컬럼 중 최소 한 곳에 …")을 프롬프트에 넣고, 서버 검증(`validateKeywordMarkers`)으로 이중 방어했다 — 프롬프트만 믿지 않는다.
- **해설 영역마다 같은 키워드가 중복 하이라이트됨**(#147): 필드별 첫 등장 규칙만 두면 같은 용어가 요약·예시·오답 해설에서 각각 마킹될 수 있다. 문제 해설은 3개 컬럼을 하나의 범위로 검증해 등록 키워드마다 정확히 1회만 허용하고, 프롬프트에 컬럼 우선순위도 명시한다.
- **꼬리질문 영역마다 같은 키워드가 중복 하이라이트됨**(#162): 한 줄 답과 블록을 각각 검사하면 같은 용어가 여러 영역에서 반복 마킹될 수 있다. 꼬리질문 하나의 `oneLineAnswer`와 모든 `blocks[].content`를 한 범위로 검증하고, 한 줄 답 뒤에는 블록의 표시 순서를 우선순위로 삼는다.
- **상세 없는 꼬리질문은 화면에서 사라진다**(#133): 조회 API가 `hasDetail()`로 거르기 때문에, 꼬리질문 상세를 빠뜨린 생성물은 에러 없이 조용히 누락된다. 그래서 프롬프트에 상세 필드를 넣는 데 그치지 않고 `validateFollowUpQuestions`로 저장 전에 막는다.
- **자연어가 코드 블록으로 노출된다**(#157): Slot 4에 코드 지문을 권장했더니 모델이 코드가 필요하지 않은 문제에서도 자연어 상황·조건 목록을 `codeSnippet`에 채웠다. 코드 지문을 선택 사항으로 바꾸고, `CodeSnippetValidator`가 실행 구조의 근거가 없는 값을 저장 전에 거부한다.

## 검증 규칙 (`QuizGenerationService#validate`)

생성 응답이 아래 중 하나라도 어기면 `QuizGenerationException`을 던지고 그 스텝 전체를 저장하지 않는다(부분 저장 없음).

- 문제 개수 정확히 5개, 슬롯별 유형/난이도 정확히 일치
- 공통 필드(`questionText`/`explanationSummary`/`wrongAnswerExplanation`) 비어있지 않음
- `followUpQuestions` 1개 이상, 그중 정확히 1개만 `isPrimary=true`
- `derivedConcepts`·`keywords` 1개 이상
- `explanationSummary` 정확히 3줄, 빈 줄·줄 끝 공백 없음
- `codeSnippet`은 null이거나 모든 유효 줄이 코드 형태이고 실행 구조를 입증하는 줄을 1개 이상 포함 — 빈 문자열, 주석뿐인 값, 자연어·표·조건 목록, 리터럴 대입만 나열한 입력 데이터, 500자를 초과하는 한 줄은 거부
- 타입별: OX는 `correctAnswer`가 `O`/`X`, 사지선다는 선택지 정확히 4개 중 정답 1개, 키워드 빈칸은 `answerKeywords` 배열 길이가 `questionText`의 실제 빈칸(`___`) 개수와 일치
- **꼬리질문마다**: `content` 비어있지 않고 마커 없음 · `difficulty` non-null · `oneLineAnswer` 비어있지 않음 · `keywords` 1개 이상 · `blocks` 1개 이상이고 첫 블록 `label`이 `해설`

### 마커 검증 (`KeywordMarkerValidator`)

괄호 짝 · 마커 문자열이 사전에 등록된 것과 정확히 일치(오타 감지) · 등록된 키워드 전부가 최소 한 곳에 마킹돼 있는지(커버리지)를 공통으로 검증한다.

**사전이 무엇이냐는 호출자가 정한다.** 해설 3개 컬럼은 그 문제의 `keywords`를, 꼬리질문의 `oneLineAnswer`·`blocks[].content`는 **그 꼬리질문의** `keywords`를 쓴다. 그래서 `validateKeywordMarkers`(문제용)와 `validateFollowUpMarkers`(꼬리질문용)가 갈라져 있다.

- 문제 해설은 `explanationSummary`·`explanationExample`·`wrongAnswerExplanation` **전체에서 등록 키워드마다 정확히 1회**만 허용한다. 필드 내부 중복과 필드 간 중복을 모두 저장 전에 거부한다.
- 꼬리질문은 각 질문의 `oneLineAnswer`·모든 `blocks[].content` **전체에서 전용 등록 키워드마다 정확히 1회**만 허용한다. 필드 내부 중복과 필드 간 중복을 모두 저장 전에 거부하되, 서로 다른 꼬리질문은 각자의 사전과 마커 범위를 독립적으로 검증한다.

## 영속화 (`QuizPersister`)

- `stepOrder`는 `quizRepository.findMaxStepOrder() + 1`로 자동 이어붙인다(수동 지정 없음) — 실행할 때마다 다음 빈 스텝에 채워진다.
- `QuizStep`(스텝 번호 + 주제명, `step_order` UNIQUE) 먼저 저장 후 5문제를 `slotOrder` 1~5로 배정.
- `quiz.step_order`는 `quiz_step.step_order`를 FK로 참조 — 커리큘럼 구조 무결성이 DB 레벨에서 강제된다.
- 꼬리질문은 `attachDetail`(난이도·한 줄 답) → `addBlock`(`display_order` 1부터) → `addKeyword` 순으로 상세를 함께 저장한다. `difficulty`와 `one_line_answer`는 DB CHECK 제약(`ck_quiz_follow_up_question_detail`)이 짝으로만 존재하도록 강제한다.

## 환경설정

`thumbsup.elice.quiz.{api-key,base-url,model}` (SSM `/thumbsup/{local,prod}/ELICE_API_KEY` 등, 모델은 `openai/gpt-5.4`). 상세 base URL 규칙·인증 동작·비용은 [`elice-models` 스킬](../elice-models/SKILL.md) 참조 — 이 스킬은 quiz 도메인에 특화된 프롬프트·검증·저장 규칙만 다룬다.

## prod 반영 절차 (직접 API 호출 금지 — 팀 결정)

이 파이프라인은 **로컬 DB에만 쓴다.** prod에 반영하는 흐름은 다음과 같다:

1. 로컬에서 생성 (`--topicsFile`로 스텝 여러 개 한 번에)
2. **사람이 전 문제를 검수** — 정답·해설·키워드 커버리지·문제 해설 3개 컬럼 전체와 각 꼬리질문 전체의 키워드별 마커 1회까지 전부 눈으로 확인한다. `codeSnippet`이 있으면 실제 코드 또는 실행 흐름이 분명한 의사코드인지 확인하고, 자연어 상황·표·조건 목록이면 `questionText`로 옮긴 뒤 null로 바꾼다. LLM 생성물이라 신뢰하지 않는다.
3. 검수 통과분만 **Flyway 마이그레이션으로 prod 반영** — 로컬 DB의 실제 저장값을 스크립트로 뽑아 SQL을 생성한다(수기 전사 금지 — 손으로 옮겨 적으면 내용이 미묘하게 바뀔 위험이 있다).
4. 마이그레이션은 `INSERT ... ; SET @qid = LAST_INSERT_ID(); INSERT INTO quiz_follow_up_question (quiz_id, ...) VALUES (@qid, ...);` 패턴으로 부모(quiz)-자식(꼬리질문·파생개념·키워드) 관계를 auto-increment ID로 연결한다. id는 로컬 값과 무관하게 prod에서 새로 채번된다.

직접 prod API를 호출해 생성하지 않는 이유: 검수 없이 LLM 원본이 바로 서비스에 노출되는 걸 막고, Flyway 마이그레이션 파일 자체가 "무엇이 언제 반영됐는지"의 감사 기록(정본)이 되게 하기 위함.

### 이미 있는 문제에 콘텐츠만 덧붙일 때

문제·해설을 그대로 두고 자식 행만 채우는 경우다(#133의 꼬리질문 상세 백필이 그 예).

- `LAST_INSERT_ID()`를 쓸 수 없다. 대신 **업무상 좌표**로 찾는다: `(step_order, slot_order)` → `quiz_id` → `(quiz_id, display_order)` → `follow_up_question_id`. auto-increment id는 로컬과 prod가 다르다.
- 좌표가 어긋나 변수가 `NULL`이 되면 이어지는 `INSERT`가 `NOT NULL` 제약에 걸려 마이그레이션 전체가 실패한다 — 조용히 넘어가지 않는 게 의도다.
- **적용된 마이그레이션 파일은 절대 수정하지 않는다.** 새 파일로 낸다.
- 기존 원문을 guard로 확인하는 보정 마이그레이션이 실패하면 drift 원인을 먼저 확인한다. 운영에서 `repair`를 먼저 실행하거나 적용된 파일을 고치지 말고, 트랜잭션 롤백 여부와 schema history를 확인한 뒤 필요한 수정은 새 마이그레이션으로 처리한다.
- 실물 예시: `V20260710174600__seed_follow_up_question_detail.sql`(샘플 3건, 손저작), `V20260710213249__backfill_follow_up_question_detail.sql`(커리큘럼 120건, 스크립트 생성).

## 알려진 주의사항

- 마커가 없는(구버전) 시드 데이터는 해설 조회 API에서 `highlights`가 빈 배열로 나간다 — 에러 아님, 정상.
- Testcontainers 통합 테스트는 seed 마이그레이션까지 전부 적용되므로, 테스트 픽스처의 `step_order`는 실제 커리큘럼 범위와 겹치지 않는 값(예: 101/102)을 쓴다.
- 생성 실패는 스텝 단위로 전부 롤백된다(부분 저장 없음) — 재시도는 같은 주제로 다시 실행하면 된다(단, `stepOrder`가 자동 증가하므로 실패한 시도가 스텝 번호를 소비하지는 않는다 — 저장 자체가 안 됐으므로).
- **상세 없는 꼬리질문은 시드에 더 이상 없다**(#133 백필 이후). "상세가 없을 때 404" 같은 경로를 테스트하려면 픽스처를 직접 만들어야 한다 — 시드에서 주워 쓰면 `orElseThrow()`에서 터진다.
- `CodeSnippetValidator`는 컴파일러나 언어별 파서가 아니라 코드 구조를 보수적으로 확인하는 가드다. 모든 유효 줄이 코드 형태여야 하고 선언·호출·제어 흐름·계산식 같은 강한 근거가 하나 이상 있어야 한다. 그래서 리터럴 대입만 있는 입력 데이터는 거부하며, 미지원 언어 문법의 실제 코드를 거부하는 false negative는 안전 쪽 선택이다. prod 반영 전 사람의 의미 검수는 여전히 생략할 수 없다.

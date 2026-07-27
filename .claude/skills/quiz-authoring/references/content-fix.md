# 라이브 콘텐츠 보정 (Flyway)

이미 라이브에 있는 문제를 **여러 건 한꺼번에** 고칠 때의 절차. 한 문제만 고치려면 대시보드의 개선(IMPROVE) 흐름을 쓰는 게 맞다 — 여기는 마커 일괄 정정, 필드 백필처럼 SQL이 필요한 경우다.

## ⚠️ 먼저: prod의 실제 `MAX(step_order)`를 확인하라

대시보드 **승인이 라이브 quiz 테이블에 직접 쓴다.** 즉 마이그레이션을 거치지 않고 스텝이 늘어난다.

로컬 기준 번호를 그대로 옮기면 `uk_quiz_step_order` UNIQUE 충돌로 마이그레이션이 실패하고, **Flyway 실패는 곧 부팅 실패**다. 새 스텝을 넣는 마이그레이션을 쓸 거라면 반드시 운영 값을 먼저 조회할 것.

`quiz_step`이 아니라 **`quiz` 테이블**의 MAX를 봐야 한다는 점도 주의(`findMaxStepOrder()`가 그렇게 구현돼 있고, `step_order > 0`만 센다 — 0은 스텝 밖 placeholder sentinel).

## 이미 있는 문제에 자식 행만 덧붙일 때

`LAST_INSERT_ID()`를 쓸 수 없다. auto-increment id는 로컬과 prod가 다르기 때문이다. 대신 **업무상 좌표**로 찾는다:

```text
(step_order, slot_order) → quiz_id → (quiz_id, display_order) → follow_up_question_id
```

- 좌표가 어긋나 변수가 `NULL`이 되면 이어지는 `INSERT`가 `NOT NULL`에 걸려 전체가 실패한다 — **조용히 넘어가지 않는 게 의도다.**
- **적용된 마이그레이션 파일은 절대 수정하지 않는다.** 새 파일로 낸다.
- 보정 마이그레이션이 실패하면 운영에서 `repair`부터 돌리지 말고 drift 원인·schema history를 먼저 확인하라.
- 머지 순서 사고(동시 머지로 버전이 엇갈리는 것)는 `merge` 스킬의 Flyway 게이트가 잡는다.

새로 스텝을 통째로 넣는 경우라면 부모-자식은 auto-increment로 잇는다:

```sql
INSERT INTO quiz ...;
SET @qid = LAST_INSERT_ID();
INSERT INTO quiz_follow_up_question (quiz_id, ...) VALUES (@qid, ...);
```

## 검수는 생략할 수 없다

콘텐츠를 손댄다면 [content-rules.md](./content-rules.md)의 규칙을 그대로 만족해야 한다 — 특히 스코프별 마커 1회, `explanationSummary` 정확히 3줄, 빈칸 개수와 `answerKeywords` 길이 일치.

⚠️ **`GeneratedQuizValidator`는 앱 레이어(`@Component`)라 Flyway SQL은 이를 통째로 우회한다.** 마커·3줄·빈칸 개수 같은 콘텐츠 규칙은 **아무도 막아주지 않고 그대로 저장된다.**

DB가 잡아주는 건 구조적 제약뿐이다 — `uk_quiz_step_order`, `uk_quiz_follow_up_block_order`(질문별 display_order 중복), `uk_quiz_follow_up_keyword_term`(질문별 키워드 중복), `ck_quiz_follow_up_question_detail`(difficulty·one_line_answer 짝). 이건 위반하면 마이그레이션이 실패하니 오히려 안전한 쪽이고, 위험한 건 **조용히 통과하는 콘텐츠 규칙 위반**이다.

## 실물 예시

| 파일 | 무엇 |
|---|---|
| `V20260710174600__seed_follow_up_question_detail.sql` | 샘플 3건, 손저작 |
| `V20260710223718__backfill_follow_up_question_detail.sql` · `V20260710223922__backfill_follow_up_question_detail.sql` | 커리큘럼 백필, 스크립트 생성 (같은 설명, 두 파일) |
| `V20260711110000__dedupe_explanation_highlight_markers.sql` | 해설 마커 중복 보정 (#147) |
| `V20260711135000__dedupe_follow_up_highlight_markers.sql` | 꼬리질문 마커 중복 보정 (#162) |
| `V20260711140000__fix_non_code_quiz_snippets.sql` | 코드 지문 오분류 보정 (#157) |

> SQL 추출 스크립트는 레포에 없다(개인 로컬 절차였다). 필요하면 새로 작성해야 한다.

## 히스토리 — 지금 라이브 문제는 어디서 왔나

2026-07 중순까지는 서버가 엘리스 GPT-5.4를 **직접 호출**하는 CLI(`--spring.profiles.active=local,generate`)로 문제를 만들어 로컬 DB에 저장하고, 사람이 검수한 뒤 위 Flyway 절차로 prod에 올렸다(#26). 지금 라이브에 있는 문제 대부분이 이 경로로 들어왔다.

LLM 비용이 **공용 API 키**로 나가는 구조였고, 그걸 팀원 개인 구독으로 옮긴 것이 지금의 저작 파이프라인이다. 서버의 엘리스 호출 코드(`EliceClient`·`QuizGenerationService`·`QuizGenerationRunner`와 설정 `thumbsup.elice.quiz.*`)는 **제거됐다** — 이제 서버는 LLM을 직접 부르지 않는다.

남은 것과 이름의 유래:
- `server/.../quiz/generation/` 패키지와 `QuizGenerationPromptBuilder`·`GeneratedQuizValidator`·`QuizPersister`는 그대로 살아 있고 **저작 파이프라인이 쓴다**. 이름만 이 시절 것이다.
- `SYSTEM_PROMPT`는 `EliceClient`에서 `QuizGenerationPromptBuilder`로 옮겼다.
- 엘리스 자체는 죽지 않았다 — `app/e2e/visual-qa.ts`의 **시각 QA**가 `ELICE_API_KEY`·`ELICE_QA_BASE_URL`로 계속 쓴다(`elice-models` 스킬). 없어진 건 서버의 *문제 생성* 용도뿐이다.

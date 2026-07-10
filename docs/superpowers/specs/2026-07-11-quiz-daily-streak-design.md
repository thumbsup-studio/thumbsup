# 오늘의 학습(1스텝) 완료 → 스트릭 갱신·완료 플래그 설계

- **날짜**: 2026-07-11
- **상태**: 설계 완료 — [#152](https://github.com/thumbsup-studio/thumbsup/issues/152) 티켓팅 완료, 미착수
- **선행 문서**: `docs/superpowers/specs/2026-07-10-quiz-progress-sync-design.md`(A/B/C안 검토, 이번 문서가 그 후속 결정), `docs/superpowers/specs/2026-07-10-learning-quiz-merge-design.md`(§64-65 "하루 문제 수 제한" 갭을 이미 예고함)

## 배경과 목표

`user_progress.streak`은 컬럼만 있고 이를 갱신하는 코드가 어디에도 없다(`UserProgress`엔 `create()` 정적 팩토리와 getter만 있고 mutator가 없음). 그 결과 홈 화면의 스트릭이 항상 시드 값에 고정된다.

또한 "오늘의 문제 5개"는 지금 코드에서 커리큘럼 스텝 1개와 우연히 일치할 뿐, 날짜 개념이 전혀 없다 — 스텝을 다 풀면 즉시 커서가 다음 스텝으로 넘어가고, 하루에 몇 스텝까지 풀 수 있는지 제한이 없다.

이 문서는 다음 세 가지를 확정한다.
1. 오늘의 학습(1스텝)을 다 풀면 스트릭 +1
2. 오늘의 학습을 다 풀면 앱이 더 이상 진행 못 하게 막을 수 있도록 "오늘 완료" 플래그를 홈 응답에 내려줌
3. 하루를 건너뛰면 스트릭이 끊어져 다음 완료 시 1부터 다시 시작

그리고 향후(M1 범위 아님) 스트릭 히스토리를 잔디밭처럼 보여줄 가능성을 고려해, 지금 단계에서 무리하게 히스토리 테이블을 만들지 않으면서도 나중에 쉽게 얹을 수 있는 구조로 설계한다.

## 전제 변경 — 어제 문서 대비

`2026-07-10-quiz-progress-sync-design.md`는 `UserProgress`가 `learning` 패키지에 있고 ArchUnit의 `피처_간_직접_의존_금지` 규칙이 `quiz`→`learning` 직접 의존을 막는다는 전제로 A(이벤트)/B(클라이언트 오케스트레이션)/C(별도 계층) 세 안을 검토했다. 그런데 같은 날 병합된 `#117`(`learning`을 `quiz`로 통합)로 `UserProgress`·`HomeService`가 이미 `quiz` 패키지로 옮겨져, `QuizProgress`·`QuizService`와 **같은 슬라이스**가 됐다. ArchUnit이 막던 문제 자체가 사라졌으므로, 이번 설계는 이벤트·배치·별도 API 호출 없이 **기존 트랜잭션에 직접 편승**하는 방식(어제 문서의 A/B/C 중 어디에도 해당하지 않는, 지금 상황에서 가장 단순한 4번째 선택지)을 택한다.

## 결정 사항

| 질문 | 결정 |
|---|---|
| "오늘의 문제 5개"란? | 커리큘럼 스텝 1개(하루 1스텝 제한) |
| 스트릭 계산 시점 | 배치 없이, 스텝 완료 시점(쓰기)과 홈 조회 시점(읽기)에 그때그때 계산 |
| 스트릭이 끊겼을 때 표시 | 홈 조회 즉시 반영(끊긴 상태를 DB에 저장하지 않고 응답 시점에 계산) |
| 하루 여러 스텝 완료 시 스트릭 | 하루에 1번만 증가(멱등) |
| "더 못 풀게 막기" | 서버는 플래그만 내려주고 하드 블록하지 않음(앱이 UI로 막음). 단, 스트릭 카운트 자체는 서버가 멱등 처리로 보호 |
| 커서(`currentStepOrder`) 진행 | 막지 않음 — 플래그를 무시하고 다음 스텝을 풀면 진행은 그대로 앞으로 감 |
| 과거 스텝 복습(재풀이) | 스트릭·플래그에 영향 없음 (아래 "복습과의 상호작용" 참고) |
| 스트릭 히스토리(잔디밭) | 이번 스코프 아님. 확장 지점만 마련(아래 "확장성" 참고) |

## 데이터 모델

`user_progress`에 컬럼 추가 (신규 Flyway 마이그레이션):

```sql
ALTER TABLE user_progress ADD COLUMN last_completed_date DATE NULL;
```

`UserProgress` 엔티티에 메서드 2개 추가 (기존 `QuizProgress.advanceToNextStep()`과 같은 컨벤션 — 규칙은 엔티티가 소유):

```java
// 쓰기: 스텝을 처음 완료했을 때 호출. 같은 날 두 번 불려도 안전(멱등).
public void recordCompletion(LocalDate today) {
    if (today.equals(lastCompletedDate)) {
        return;
    }
    boolean continuedFromYesterday =
            lastCompletedDate != null && lastCompletedDate.equals(today.minusDays(1));
    streak = continuedFromYesterday ? streak + 1 : 1;
    lastCompletedDate = today;
}

// 읽기: 화면 표시용. DB는 건드리지 않음 — "끊긴 상태"를 저장하지 않고 조회 시점에 계산.
public int getEffectiveStreak(LocalDate today) {
    if (lastCompletedDate == null || lastCompletedDate.isBefore(today.minusDays(1))) {
        return 0;
    }
    return streak;
}
```

## 아키텍처 — 어디에 훅을 거는가

`QuizService.advanceProgressIfStepCompleted(userId, stepOrder)`(`server/src/main/java/studio/thumbsup/server/quiz/QuizService.java:205-221`)는 이미 두 겹의 조건으로 "이 유저가 이 스텝을 지금 막 처음 완료했는지"를 판별한다.

```java
boolean stepCompleted = stepQuizIds.stream().allMatch(attemptedQuizIds::contains);
if (!stepCompleted) {
    return;
}
if (progress.getCurrentStepOrder() == stepOrder) {   // ★ 훅은 반드시 이 안쪽
    progress.advanceToNextStep();
    userProgressService.recordStepCompletion(userId, todayKst);   // 신규 추가
}
```

`recordStepCompletion` 호출은 **반드시 안쪽 `if` 안**에 있어야 한다. 바깥쪽 `stepCompleted` 체크만 보고 걸면, 과거에 이미 끝난 스텝을 복습으로 다시 풀 때도 `stepCompleted`가 항상 참이라 잘못 걸린다(아래 "복습과의 상호작용" 참고).

`QuizProgress`용 비관적 락(`findByUserIdForUpdate`)이 이 메서드 전체를 유저 단위로 이미 직렬화하고 있으므로, `UserProgress` 쪽에 별도 락은 필요 없다 — 이 메서드 호출 시점엔 이미 동시성이 해소된 상태다.

### 새 컴포넌트 — `UserProgressService`

`quiz` 패키지 내부에 작은 서비스를 추가한다.

```java
@Service
public class UserProgressService {
    private final UserProgressRepository userProgressRepository;

    @Transactional
    public void recordStepCompletion(Long userId, LocalDate today) {
        UserProgress progress = userProgressRepository.findByUserId(userId)
                .orElseGet(() -> UserProgress.create(userId, 0, 0));
        progress.recordCompletion(today);
        userProgressRepository.save(progress);
    }
}
```

`today`는 서버 규칙(주입받은 `Clock`, `common.time.TimeZones.KST`)대로 계산한 KST 기준 오늘 날짜를 사용한다(`LocalDateTime.now()` 직접 호출 금지, `server/CLAUDE.md` 규칙 6).

### 복습과의 상호작용

`QuizService.validateAccessible`(`QuizService.java:121-129`)은 "현재 스텝과 과거 스텝은 허용한다(복습 여지)"고 명시하며, `submitAnswer` 주석(`QuizService.java:99`)도 "재시도를 허용하므로 이력은 매번 새로 쌓인다"고 말한다. 즉 과거 스텝 문제를 복습으로 다시 풀 수 있고 `QuizAttempt`가 매번 새로 쌓인다.

- 과거 스텝 복습 시: `stepCompleted`는 참(이미 다 풀었으니까)이지만 `progress.getCurrentStepOrder() == stepOrder`는 거짓(커서가 이미 앞서 있으니까) → 훅 자체가 안 불림. 스트릭·플래그 영향 없음.
- 같은 날 새 스텝을 연달아 여러 개 처음 완료할 때: 훅이 여러 번 불릴 수 있음(커서를 막지 않기로 했으므로) → `recordCompletion`의 멱등 체크(`today.equals(lastCompletedDate)`)가 두 번째 이후 호출을 무시.

## API 변경 — `GET /api/v1/home`

`HomeResponse`에 `todayCompleted: boolean` 필드를 추가한다.

```java
LocalDate todayKst = LocalDate.now(clock.withZone(TimeZones.KST));  // 기존 TimeZones 유틸 재사용
boolean todayCompleted = todayKst.equals(userProgress.getLastCompletedDate());
int streakDays = userProgress.getEffectiveStreak(todayKst);
```

DB 쓰기 없이 조회 시점에 계산한다(스케줄러 불필요). 앱은 `todayCompleted`를 보고 "오늘 학습 완료" UI로 전환해 더 이상 못 풀게 막는다 — 서버 하드 블록은 이번 스코프가 아니다.

## 확장성 — 향후 잔디밭(히스토리) 대비

쓰기 경로가 `UserProgressService.recordStepCompletion()` 한 곳으로 모여 있다. 나중에 일별 히스토리(잔디밭)가 필요해지면, 이 메서드 안에 insert-only 로그 테이블(예: `learning_daily_completion(user_id, completed_date)`) 저장 한 줄을 추가하면 된다. 지금은 그 테이블/엔티티를 만들지 않는다(YAGNI) — 이 메서드가 유일한 확장 지점이라는 것만 문서로 남긴다.

## 비범위

- 서버가 하루 1스텝 초과를 하드 블록하는 것 — 지금은 앱 UI만 막고, 스트릭 카운트만 서버가 멱등 처리로 보호한다. 악용 방지가 필요해지면 `QuizErrorType`에 새 에러 타입을 추가해 `advanceProgressIfStepCompleted` 진입 시점에 막는 걸 후속으로 검토한다.
- 잔디밭/히스토리 테이블의 실제 구현.
- `points`(포인트) 로직 — 원 요청 범위 밖이며 이번 변경과 무관하게 그대로 둔다.

## 테스트 전략

- `QuizService`: 스텝 최초 완료 시 `recordStepCompletion` 호출과 `streak`/`lastCompletedDate` 갱신 검증. 과거 스텝 재풀이 시 **불변** 검증(회귀 방지). 연속 완료(스트릭 누적) / 하루 건너뛰기(1로 리셋) / 같은 날 스텝 2개 완료(멱등) 각 케이스.
- `HomeService`: `lastCompletedDate`가 오늘/어제/2일 전/null일 때 `todayCompleted`·`streakDays` 응답 검증.
- Repository: `@DataJpaTest` + Testcontainers로 마이그레이션 컬럼 확인(기존 패턴).

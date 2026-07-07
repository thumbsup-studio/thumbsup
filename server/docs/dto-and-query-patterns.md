# DTO 규칙 & 크로스 도메인 조회 패턴 (서버)

[공통 API 규격](../../docs/api-standard.md)을 서버에서 구현할 때의 DTO 작성 규칙과
도메인 경계를 넘는 조회의 표준 패턴이다. 실제 예시 코드는 레퍼런스 feature(템플릿)에 포함된다.

## 1. DTO 규칙

**API별로 Request/Response DTO를 따로 만들고, 재사용하지 않는다.**

- 공유 DTO는 "한 API의 요구 변경 → 다른 API 파급 + 머지 충돌"의 핫스팟이자 nullable 필드가 늘어나는 god DTO의 원인이다. API별 분리로 한 API를 한 사람이 소유한다.
- 형식: **Java `record`** (불변) + **정적 팩토리 수동 매핑** — `QuizResponse.from(entity)`. MapStruct 등 매핑 라이브러리는 쓰지 않는다.
- **JPA 엔티티를 응답으로 직접 반환 금지** — 항상 DTO로 변환한다.

### 공통화 판별 기준

> "자체 정체성을 가진 도메인 개념인가(→ `model`로 공유), 지금 우연히 모양이 같은가(→ 각자 복제)?"

| 공유 O (`model`로 분리) | 공유 X (복제) |
|---|---|
| enum, 값객체(VO), ID 타입 — 바뀌면 모든 곳이 같이 바뀌어야 맞는 것 | `UserSummary` 같은 응답 조각 — 지금 필드가 같을 뿐인 것 |

- 의존 방향은 **`DTO → model` 단방향** (model이 DTO를 알면 안 됨).
- 공유 `model`에 JPA 엔티티 금지 — 순수 값타입/enum만.
- 지금 모양이 같다고 공유하지 않는다 — **중복이 잘못된 결합보다 낫다** (WET > 성급한 DRY).

## 2. 크로스 도메인 조회 조합 패턴

도메인 경계를 넘는 참조는 JPA 연관관계가 아니라 **ID 값**으로만 한다
(`Long userId` — `@ManyToOne User` 금지, DB FK 제약은 유지).
따라서 "퀴즈 목록 + 작성자 이름"처럼 다른 도메인 데이터가 필요한 조회는 join 대신 아래 패턴으로 조립한다.

```text
1) 주 도메인 조회        : List<Quiz> quizzes = quizRepository.findBy...(...)
2) 참조 ID 수집          : Set<Long> userIds = quizzes → quiz.getUserId() 수집
3) in절 일괄 조회 (1회)  : Map<Long, User> users = userRepository.findAllById(userIds) → id로 맵핑
4) Service에서 조립      : quizzes + users → QuizListResponse.from(quiz, user)
```

- ❌ **금지**: 루프 안에서 `userRepository.findById(quiz.getUserId())` 호출 — N+1 쿼리.
- 조회는 항상 "ID 수집 → **한 번의** in절 조회 → 메모리에서 조립" 순서다.
- 같은 도메인 내부에서는 `@ManyToOne` 등 연관관계를 자유롭게 사용해도 된다.

### 구현 예시 (첫 크로스 도메인 feature는 이 코드를 따른다)

> `notice` 레퍼런스 feature는 단일 엔티티라 이 패턴을 담지 않는다.
> **작성자·소유자 등 다른 도메인을 참조하는 첫 feature(quiz 등)가 이 예시를 구현**한다.

```java
// Service — 다른 도메인은 Repository로 "따로" 조회해 메모리에서 합친다 (JPA 조인 아님)
public CursorPage<QuizListResponse> getQuizzes(String cursor, int size) {
    List<Quiz> quizzes = fetchPage(cursor, size + 1);           // 1) 주 도메인

    Set<Long> authorIds = quizzes.stream()
            .map(Quiz::getAuthorId).collect(toSet());           // 2) 참조 ID 수집
    Map<Long, String> authorNames = userRepository.findAllById(authorIds).stream()
            .collect(toMap(User::getId, User::getNickname));    // 3) in절 1회 (findAllById)

    // 4) 조립 — 없는 작성자는 방어적 기본값(탈퇴 등). 여기서 절대 findById 재조회 금지.
    List<QuizListResponse.Item> items = quizzes.stream()
            .map(q -> QuizListResponse.Item.of(q, authorNames.getOrDefault(q.getAuthorId(), "(알 수 없음)")))
            .toList();
    // ... hasNext/nextCursor 산출은 notice 패턴과 동일
}
```

### 인증 유저 식별 (IDOR 방지)

"내 것"을 다루는 API(내 북마크, 내가 쓴 글)는 **userId를 파라미터로 받지 않는다** — 토큰에서 꺼낸다.
JwtAuthenticationFilter가 SecurityContext에 심은 principal(=userId)을 컨트롤러에서 읽는다.

```java
@GetMapping("/api/v1/quizzes/mine")
public ApiResponse<QuizListResponse> myQuizzes(
        @AuthenticationPrincipal Long userId,   // ✅ 토큰에서. request param의 userId는 절대 신뢰 금지
        @RequestParam(required = false) String cursor,
        @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    CursorPage<QuizListResponse> page = quizService.getMyQuizzes(userId, cursor, size);
    return ApiResponse.success(page.data(), page.meta());
}
```

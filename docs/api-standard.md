# API 공통 규격

Thumbs Up 서버의 모든 HTTP API가 따르는 규격이다.
서버 개발자는 이 규격대로 구현하고, FE 개발자는 이 규격을 전제로 호출한다.

## 1. 기본

- **베이스 경로**: `/api/v1`
- **형식**: JSON (UTF-8), `Content-Type: application/json`
- **URL 경로**: 소문자 케밥 케이스, 리소스는 **복수형 명사** — `/api/v1/quizzes/{quizId}`
- 개별 엔드포인트 명세는 Swagger UI가 정본 (이 문서는 공통 규칙만 정의)

## 2. 공통 응답 Envelope

모든 응답 바디는 아래 4필드 구조를 따른다. **예외 없음** — FE는 파싱 로직 하나로 모든 응답을 처리한다.

```jsonc
{
  "code": "SUCCESS",        // 문자열 enum. 성공 = "SUCCESS", 에러 = ErrorType 코드
  "message": "OK",          // 사람이 읽는 메시지 (에러 시 사용자 표시용 기본 문구)
  "data": { },              // 실제 페이로드. 없으면 null
  "meta": null              // 페이지네이션 등 부가정보. 없으면 null
}
```

### 성공 예시

```json
{
  "code": "SUCCESS",
  "message": "OK",
  "data": {
    "quizId": 42,
    "title": "자료구조 기초",
    "createdAt": "2026-07-07T21:00:00+09:00"
  },
  "meta": null
}
```

에러 응답 형식은 [error-spec.md](error-spec.md) 참조.

## 3. HTTP Status 정책

| 상황 | Status | 비고 |
|------|--------|------|
| 조회/수정/삭제 성공 | **200** | 기본값 |
| 생성 성공 | **201** | `data`에 생성된 리소스(또는 최소한 id) 포함 |
| 클라이언트 오류 | **4xx** | 세부 구분은 `code`(ErrorType)로 |
| 서버 오류 | **5xx** | 〃 |

- **204(No Content)는 사용하지 않는다.** 삭제 성공도 `200` + envelope(`data: null`)로 응답한다 — FE 파싱 로직을 단일화하기 위함.
- Status는 대분류(성공/클라이언트 오류/서버 오류), `code`는 세분류(원인)로 역할을 나눈다.

## 4. 필드 네이밍

| 대상 | 규칙 | 예 |
|------|------|-----|
| JSON 필드 | camelCase | `quizId`, `createdAt` |
| 약어 포함 필드 | 약어도 camelCase (대문자 연속 금지) | `imageUrl` (~~imageURL~~), `apiKey` |
| enum 값 | UPPER_SNAKE_CASE | `"MULTIPLE_CHOICE"` |
| 리스트 키 | 항상 **`items`** | `data.items` (~~list, events, tips~~) |

- **`items` 규칙은 그 응답의 주인공이 목록일 때만 적용된다** — 페이지네이션 대상이 되는 최상위 컬렉션(`data.items`)을 가리킨다.
- 상세 응답 안에 딸린 배열은 무엇을 담았는지 드러나는 이름을 쓴다 — `data.choices`, `data.keywords`, `data.followUpQuestions`. 한 응답에 배열이 여럿일 수 있으므로 전부 `items`일 수는 없다.

## 5. 날짜/시간

- 직렬화: **ISO 8601 + KST 오프셋** — `"2026-07-07T21:00:00+09:00"`
- 날짜만 필요한 경우: `"2026-07-07"`
- 서버 내부 저장은 UTC(서버 정책 — FE는 신경 쓸 필요 없음). API 경계에서는 항상 위 형식.

## 6. GET 요청 규칙

- **GET에 request body 금지.** 모든 파라미터는 query string으로 — `?keyword=자료구조&cursor=eyJpZCI6NTF9&size=20`
- 필수/선택 파라미터와 기본값은 각 API의 Swagger 명세에 정의한다.

## 7. 페이지네이션 (커서 방식)

offset 방식은 사용하지 않는다. 무한스크롤 기준의 커서 방식으로 통일한다.

### 요청

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `cursor` | string (선택) | 이전 응답 `meta.nextCursor` 값. **첫 페이지는 생략** |
| `size` | int (선택) | 페이지 크기. 기본 20, 최대 100 |

### 응답

```json
{
  "code": "SUCCESS",
  "message": "OK",
  "data": {
    "items": [ { "quizId": 42, "title": "..." } ]
  },
  "meta": {
    "hasNext": true,
    "nextCursor": "eyJpZCI6NTF9"
  }
}
```

- `nextCursor`는 **불투명(opaque) 문자열** — FE는 값을 해석하지 말고 그대로 다음 요청에 전달한다.
- 마지막 페이지: `hasNext: false`, `nextCursor: null`.

## 8. 인증

- 방식: `Authorization: Bearer {accessToken}` (JWT)
- **유저 식별값(userId 등)을 request body/query로 보내지 않는다.** 서버는 항상 토큰에서 유저를 식별한다 (IDOR 방지).
- **S0 범위는 자체 로그인**(이메일/비밀번호). 소셜 로그인은 이후 마일스톤.

### 토큰 정책

| 항목 | 값 |
|------|-----|
| Access Token | 수명 30분. 매 요청 `Authorization` 헤더로 전달 |
| Refresh Token | 수명 14일. **서버 DB 저장 + 회전(rotation)** — 재발급 시 이전 refresh는 무효화 |
| 재발급 | access 만료(401 + `TOKEN_EXPIRED`) 시 refresh로 재발급 요청 |
| 로그아웃 | 서버가 refresh token 폐기. FE는 저장한 토큰 삭제 |

(수명 값은 운영하며 조정 가능. 변경 시 이 문서를 갱신한다.)

401/403 구분과 FE 처리 흐름은 [error-spec.md](error-spec.md) 참조.

## 9. CORS

CORS의 기준은 "서버 위치"가 아니라 **브라우저에 떠 있는 FE 페이지의 origin**이다.
같은 컴퓨터라도 포트가 다르면(3000 vs 8080) 다른 origin이라 허용 설정이 필요하다.

| 서버 프로파일 | 허용 Origin | 커버하는 상황 |
|------|-------------|--------------|
| local | `http://localhost:3000` (Next.js 개발 서버 기본 포트 — FE 확인 필요) | 개발자(FE든 서버든)가 **자기 로컬에 띄운 서버**를 로컬 FE에서 호출 |
| prod | `http://localhost:3000`, `https://thumbsup-app.vercel.app`, `https://*-thumbsup.vercel.app` | 로컬 FE, Vercel main 배포 및 PR preview → 운영 서버 |

- 로컬 FE(3000) → **prod 서버** 호출을 허용한다. 서버를 로컬에 띄우지 못하는 FE 개발자는 배포 API를 기본으로 쓰고, 로컬 서버를 직접 띄우는 개발자는 `NEXT_PUBLIC_API_URL=http://localhost:8080`으로 override한다.
- 인증 쿠키/세션 호환을 위해 서버는 Spring `allowedOriginPatterns`와 `allowCredentials(true)`를 사용한다. `allowCredentials(true)`에서는 `allowedOrigins=*`를 쓰지 않는다.
- 허용 메서드: `GET, POST, PUT, PATCH, DELETE`. `Authorization`, `Content-Type`, `X-Request-Id` 헤더 허용.

---

> 이 규격을 서버에서 **어떻게 구현하는지**(DTO 작성 규칙, 크로스 도메인 조회 패턴, 예외 처리 구현 등)는 [`server/docs/`](../server/docs/)에서 관리한다. FE는 볼 필요 없다.

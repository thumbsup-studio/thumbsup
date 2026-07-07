# 오류 규격 (ErrorType)

모든 에러 응답의 형식과 에러 코드 체계를 정의한다.
FE는 이 규격 하나로 모든 에러를 처리할 수 있어야 한다.

## 1. 에러 응답 형식

에러도 [공통 envelope](api-standard.md#2-공통-응답-envelope)를 그대로 사용한다.

```json
{
  "code": "QUIZ_NOT_FOUND",
  "message": "존재하지 않는 퀴즈입니다.",
  "data": null,
  "meta": null
}
```

- `code`: **ErrorType 코드** (문자열 enum). FE 분기 처리의 기준.
- `message`: 사용자에게 그대로 보여줄 수 있는 한국어 기본 문구. FE가 `code` 기준으로 다른 문구로 교체해도 된다.
- HTTP status는 대분류(400/401/403/404/500), `code`는 세분류(원인)다.

### 입력값 검증 실패 (예외적으로 data 사용)

Bean Validation 실패는 어떤 필드가 왜 틀렸는지를 `data.fieldErrors`로 내려준다.

```json
{
  "code": "INVALID_INPUT",
  "message": "입력값이 올바르지 않습니다.",
  "data": {
    "fieldErrors": [
      { "field": "email", "reason": "이메일 형식이 아닙니다." },
      { "field": "password", "reason": "8자 이상이어야 합니다." }
    ]
  },
  "meta": null
}
```

## 2. ErrorType 코드 체계

### 네이밍 규칙

```text
{도메인}_{원인}   →  QUIZ_NOT_FOUND, USER_EMAIL_DUPLICATED
{원인}            →  INVALID_INPUT (공통 에러)
```

UPPER_SNAKE_CASE. 한 번 배포된 코드 값은 변경하지 않는다 (FE 분기가 깨짐).

> 이 코드들이 서버 내부에서 어떻게 구현되는지(ErrorType 인터페이스, feature별 enum, 전역 핸들러)는 [서버 구현 문서](../server/docs/error-implementation.md)에서 관리한다 — FE는 몰라도 된다.

## 3. 공통 에러 카탈로그 (CommonErrorType)

| code | HTTP | 의미 |
|------|------|------|
| `INVALID_INPUT` | 400 | 입력값 검증 실패 (fieldErrors 포함) |
| `UNAUTHORIZED` | 401 | 인증 정보 없음/유효하지 않음 |
| `TOKEN_EXPIRED` | 401 | access token 만료 — **FE는 refresh 재발급 시도** |
| `FORBIDDEN` | 403 | 인증은 됐으나 권한 없음 |
| `NOT_FOUND` | 404 | 리소스 없음 (도메인 코드가 더 구체적이면 그쪽 우선) |
| `METHOD_NOT_ALLOWED` | 405 | 지원하지 않는 HTTP 메서드 |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | 지원하지 않는 Content-Type (예: JSON 엔드포인트에 text/plain) |
| `INTERNAL_ERROR` | 500 | 서버 내부 오류. message는 상세 노출 금지 |

도메인별 에러 코드(`QUIZ_NOT_FOUND` 등)는 각 API의 Swagger 명세에 기재한다.

## 4. FE 처리 가이드

```text
HTTP status로 대분류
├─ 2xx        → data 사용
├─ 401
│   ├─ code == TOKEN_EXPIRED → refresh 재발급 → 원 요청 재시도 (1회)
│   └─ 그 외(재발급 실패 포함) → 로그인 화면으로
├─ 403        → 권한 없음 안내
├─ 400
│   └─ code == INVALID_INPUT → data.fieldErrors로 폼 필드별 표시
├─ 그 외 4xx  → code별 분기, 기본은 message 표시
└─ 5xx        → 공통 오류 안내 ("잠시 후 다시 시도")
```

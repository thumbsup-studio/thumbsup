# 오류 처리 구현 규칙 (서버)

FE와 공유하는 오류 **계약**은 [docs/error-spec.md](../../docs/error-spec.md)가 정본이다.
이 문서는 그 계약을 서버 코드로 구현하는 규칙을 정의한다.

## 1. ErrorType 구조 — 인터페이스 + feature별 enum

- `common`에는 **`ErrorType` 인터페이스**와 공통 에러(`CommonErrorType`)만 둔다.
- **각 feature가 자체 enum으로 구현**한다 — 예: `QuizErrorType implements ErrorType`.
- 이유: 중앙 단일 enum이면 API 추가마다 `common/`을 수정하게 되어 3명 병렬 작업의 상시 충돌 지점이 된다.

```java
// common/exception/ErrorType.java
public interface ErrorType {
    HttpStatus getStatus();
    String getCode();      // 응답 envelope의 code
    String getMessage();   // 기본 문구
}

// quiz/exception/QuizErrorType.java — feature 소유 (CommonErrorType과 동일 패턴)
public enum QuizErrorType implements ErrorType {
    QUIZ_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 퀴즈입니다.");

    private final HttpStatus status;
    private final String message;

    QuizErrorType(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
    }

    @Override
    public HttpStatus getStatus() {
        return status;
    }

    @Override
    public String getCode() {
        return name(); // 코드 값 = enum 이름 — 별도 문자열을 두지 않는다
    }

    @Override
    public String getMessage() {
        return message;
    }
}
```

- 코드 값(`getCode()`)의 네이밍·불변 규칙은 [계약 문서 §2](../../docs/error-spec.md) 참조.
- 공통 에러 카탈로그(`CommonErrorType`)의 코드·HTTP 매핑도 계약 문서가 정본 — 서버 enum이 계약과 어긋나면 안 된다.

## 2. 예외 던지기 규칙

1. **표준 예외 직접 사용 금지** — `IllegalArgumentException`, `IllegalStateException` 등을 비즈니스 로직에서 던지지 않는다. 항상 `BusinessException(ErrorType)`.
   - 이 규칙은 ArchUnit 테스트로 강제된다 (CI에서 빌드 실패).
2. 컨트롤러/서비스에서 try-catch로 에러 응답을 직접 만들지 않는다 — 던지기만 하고, 변환은 전역 핸들러의 몫.

## 3. 전역 핸들러 (@RestControllerAdvice)

1. `BusinessException` → `ErrorType`의 status/code/message로 envelope 변환.
2. 프레임워크가 던지는 예외도 **fallback 핸들러**가 공통 카탈로그 코드로 변환한다 — 규격 밖 에러 응답이 새어나가지 않게.
   - `MethodArgumentNotValidException` → `INVALID_INPUT` + `data.fieldErrors`
   - `HttpRequestMethodNotSupportedException` → `METHOD_NOT_ALLOWED`
   - `HttpMediaTypeNotSupportedException` → `UNSUPPORTED_MEDIA_TYPE`
   - 그 외 미분류 예외 → `INTERNAL_ERROR`
4. 표준 예외 금지 규칙(ArchUnit)은 `java.*` 패키지의 모든 RuntimeException 계열 생성을 잡는다.
   단, **메서드 레퍼런스(`IllegalArgumentException::new`)는 정적 분석 한계로 탐지 불가** — 코드리뷰에서 확인한다.
3. **500 에러의 `message`에 스택트레이스·내부 정보를 담지 않는다** (로그에만 기록).

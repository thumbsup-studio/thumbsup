package studio.thumbsup.server.common.exception;

import jakarta.validation.ConstraintViolationException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import studio.thumbsup.server.common.response.ApiResponse;

/**
 * 모든 예외를 공통 envelope로 변환하는 단일 지점 — 계약: docs/error-spec.md.
 *
 * <p>컨트롤러/서비스에서 try-catch로 에러 응답을 직접 만들지 않는다. 던지기만 하면 여기서 변환한다.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException e) {
        ErrorType errorType = e.getErrorType();
        if (errorType.getStatus().is5xxServerError()) {
            log.error("비즈니스 예외(5xx): {}", errorType.getCode(), e);
        } else {
            log.warn("비즈니스 예외: {} - {}", errorType.getCode(), e.getMessage());
        }
        return ResponseEntity.status(errorType.getStatus()).body(ApiResponse.error(errorType));
    }

    /** Bean Validation(@Valid body) 실패 → INVALID_INPUT + fieldErrors */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<ValidationErrorData>> handleValidation(MethodArgumentNotValidException e) {
        List<FieldErrorDetail> fieldErrors = e.getBindingResult().getFieldErrors().stream()
                .map(error -> new FieldErrorDetail(error.getField(), error.getDefaultMessage()))
                .toList();
        return ResponseEntity.status(CommonErrorType.INVALID_INPUT.getStatus())
                .body(ApiResponse.error(CommonErrorType.INVALID_INPUT, new ValidationErrorData(fieldErrors)));
    }

    /** body 파싱 실패·타입 불일치·필수 파라미터 누락·쿼리 파라미터 검증 실패 → INVALID_INPUT */
    @ExceptionHandler({
        HttpMessageNotReadableException.class,
        MethodArgumentTypeMismatchException.class,
        MissingServletRequestParameterException.class,
        ConstraintViolationException.class
    })
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(Exception e) {
        log.warn("잘못된 요청: {}", e.getMessage());
        return ResponseEntity.status(CommonErrorType.INVALID_INPUT.getStatus())
                .body(ApiResponse.error(CommonErrorType.INVALID_INPUT));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> handleMethodNotAllowed(HttpRequestMethodNotSupportedException e) {
        return ResponseEntity.status(CommonErrorType.METHOD_NOT_ALLOWED.getStatus())
                .body(ApiResponse.error(CommonErrorType.METHOD_NOT_ALLOWED));
    }

    /** 지원하지 않는 Content-Type — 클라이언트 실수가 500으로 위장되지 않게 별도 처리 */
    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException e) {
        return ResponseEntity.status(CommonErrorType.UNSUPPORTED_MEDIA_TYPE.getStatus())
                .body(ApiResponse.error(CommonErrorType.UNSUPPORTED_MEDIA_TYPE));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNotFound(NoResourceFoundException e) {
        return ResponseEntity.status(CommonErrorType.NOT_FOUND.getStatus())
                .body(ApiResponse.error(CommonErrorType.NOT_FOUND));
    }

    /** 미분류 예외의 최종 fallback — 내부 정보는 응답에 담지 않는다 (로그에만) */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception e) {
        log.error("처리되지 않은 예외", e);
        return ResponseEntity.status(CommonErrorType.INTERNAL_ERROR.getStatus())
                .body(ApiResponse.error(CommonErrorType.INTERNAL_ERROR));
    }
}

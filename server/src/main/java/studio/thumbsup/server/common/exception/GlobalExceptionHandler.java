package studio.thumbsup.server.common.exception;

import jakarta.validation.ConstraintViolationException;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.MessageSourceResolvable;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.validation.method.ParameterErrors;
import org.springframework.validation.method.ParameterValidationResult;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
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
        return validationErrorResponse(fieldErrors);
    }

    /** 쿼리/경로 파라미터 검증 실패 → INVALID_INPUT + fieldErrors */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<ValidationErrorData>> handleConstraintViolation(ConstraintViolationException e) {
        log.warn("파라미터 검증 실패: {}", e.getMessage());
        List<FieldErrorDetail> fieldErrors = e.getConstraintViolations().stream()
                .map(violation -> new FieldErrorDetail(
                        removeMethodPrefix(violation.getPropertyPath().toString()), violation.getMessage()))
                .toList();
        return validationErrorResponse(fieldErrors);
    }

    /** 쿼리/경로 파라미터 검증 실패(Spring MVC method validation) → INVALID_INPUT + fieldErrors */
    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<ApiResponse<ValidationErrorData>> handleHandlerMethodValidation(
            HandlerMethodValidationException e) {
        log.warn("파라미터 검증 실패: {}", e.getMessage());
        List<FieldErrorDetail> fieldErrors = e.getParameterValidationResults().stream()
                .flatMap(this::toFieldErrors)
                .toList();
        return validationErrorResponse(fieldErrors);
    }

    /** body 파싱 실패·타입 불일치·필수 파라미터 누락 → INVALID_INPUT */
    @ExceptionHandler({
        HttpMessageNotReadableException.class,
        MethodArgumentTypeMismatchException.class,
        MissingServletRequestParameterException.class
    })
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(Exception e) {
        log.warn("잘못된 요청: {}", e.getMessage());
        return errorResponse(CommonErrorType.INVALID_INPUT);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> handleMethodNotAllowed(HttpRequestMethodNotSupportedException e) {
        return errorResponse(CommonErrorType.METHOD_NOT_ALLOWED);
    }

    /** 지원하지 않는 Content-Type — 클라이언트 실수가 500으로 위장되지 않게 별도 처리 */
    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException e) {
        return errorResponse(CommonErrorType.UNSUPPORTED_MEDIA_TYPE);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNotFound(NoResourceFoundException e) {
        return errorResponse(CommonErrorType.NOT_FOUND);
    }

    /** 미분류 예외의 최종 fallback — 내부 정보는 응답에 담지 않는다 (로그에만) */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception e) {
        log.error("처리되지 않은 예외", e);
        return ResponseEntity.status(CommonErrorType.INTERNAL_ERROR.getStatus())
                .body(ApiResponse.error(CommonErrorType.INTERNAL_ERROR));
    }

    private ResponseEntity<ApiResponse<Void>> errorResponse(CommonErrorType errorType) {
        return ResponseEntity.status(errorType.getStatus()).body(ApiResponse.error(errorType));
    }

    private ResponseEntity<ApiResponse<ValidationErrorData>> validationErrorResponse(
            List<FieldErrorDetail> fieldErrors) {
        return ResponseEntity.status(CommonErrorType.INVALID_INPUT.getStatus())
                .body(ApiResponse.error(CommonErrorType.INVALID_INPUT, new ValidationErrorData(fieldErrors)));
    }

    private Stream<FieldErrorDetail> toFieldErrors(ParameterValidationResult result) {
        String parameterName = Optional.ofNullable(result.getMethodParameter().getParameterName())
                .orElse("arg" + result.getMethodParameter().getParameterIndex());
        if (result instanceof ParameterErrors parameterErrors && parameterErrors.hasFieldErrors()) {
            return parameterErrors.getFieldErrors().stream()
                    .map(error -> new FieldErrorDetail(fieldName(parameterName, error), error.getDefaultMessage()));
        }
        return result.getResolvableErrors().stream()
                .map(error -> new FieldErrorDetail(parameterName, defaultMessage(error)));
    }

    private String fieldName(String parameterName, FieldError error) {
        if (parameterName.equals(error.getField())) {
            return parameterName;
        }
        return parameterName + "." + error.getField();
    }

    private String defaultMessage(MessageSourceResolvable error) {
        return Optional.ofNullable(error.getDefaultMessage()).orElse("입력값이 올바르지 않습니다.");
    }

    private String removeMethodPrefix(String path) {
        int index = path.indexOf('.');
        if (index < 0 || index == path.length() - 1) {
            return path;
        }
        return path.substring(index + 1);
    }
}

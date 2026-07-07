package studio.thumbsup.server.common.exception;

import java.util.List;

/** INVALID_INPUT 응답의 data payload — {@code data.fieldErrors} 형태로 직렬화된다 */
public record ValidationErrorData(List<FieldErrorDetail> fieldErrors) {}

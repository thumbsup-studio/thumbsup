package studio.thumbsup.server.common.exception;

/** 검증 실패한 필드 하나 — 계약: docs/error-spec.md §1 */
public record FieldErrorDetail(String field, String reason) {}

/**
 * API 에러 표현.
 *
 * 서버 envelope의 `code`(ErrorType)로 분기하고, HTTP status는 대분류로만 쓴다.
 * (docs/error-spec.md 참조)
 */

export type FieldError = { field: string; reason: string };

/** 자주 분기하는 에러 코드 (docs/error-spec.md의 카탈로그 부분집합) */
export const ErrorCode = {
  /** 400 — 입력값 검증 실패. data.fieldErrors 포함 */
  INVALID_INPUT: "INVALID_INPUT",
  /** 401 — access token 만료. refresh 재발급 시도 대상 */
  TOKEN_EXPIRED: "TOKEN_EXPIRED",
  /** 401 — 인증 정보 없음/무효 */
  UNAUTHORIZED: "UNAUTHORIZED",
  /** 401 — 로그인 실패(원인 미구분: 없는 계정/틀린 비번 통합) */
  INVALID_CREDENTIALS: "INVALID_CREDENTIALS",
  /** 409 — 이미 가입된 이메일 */
  USER_EMAIL_DUPLICATED: "USER_EMAIL_DUPLICATED",
} as const;

export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode];

/**
 * 서버가 내려준 에러 응답을 감싼 예외.
 * - `code`: envelope의 ErrorType 코드 (분기 기준)
 * - `status`: HTTP status (대분류)
 * - `message`: 서버가 준 사용자 노출용 한국어 기본 문구
 * - `fieldErrors`: INVALID_INPUT일 때 폼 필드별 사유
 */
export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  readonly fieldErrors?: FieldError[];

  constructor(params: {
    code: string;
    status: number;
    message: string;
    fieldErrors?: FieldError[];
  }) {
    super(params.message);
    this.name = "ApiError";
    this.code = params.code;
    this.status = params.status;
    this.fieldErrors = params.fieldErrors;
  }

  is(code: ErrorCodeValue): boolean {
    return this.code === code;
  }
}

/** 네트워크 단절 등 응답을 받기 전 실패 */
export class NetworkError extends Error {
  constructor(message = "네트워크에 연결할 수 없어요.") {
    super(message);
    this.name = "NetworkError";
  }
}

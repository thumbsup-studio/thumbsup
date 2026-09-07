import { createAuthApi } from "./auth";
import { createApiTransport } from "./client";
import { createCourseApi } from "./course";
import { createFeedbackApi } from "./feedback";
import { createHistoryApi } from "./history";
import { createQuizApi } from "./quiz";
import type { TokenStorage } from "./token-storage";

export type CreateApiClientOptions = {
  baseUrl: string;
  tokenStorage: TokenStorage;
};

/** 환경과 저장소를 주입받아 서로 격리된 API 클라이언트 인스턴스를 만든다. */
export function createApiClient({ baseUrl, tokenStorage }: CreateApiClientOptions) {
  const transport = createApiTransport(baseUrl, tokenStorage);
  return {
    ...transport,
    getAccessToken: () => Promise.resolve(tokenStorage.getAccess()),
    ...createAuthApi(transport.apiRequest, tokenStorage),
    ...createCourseApi(transport.apiRequest),
    ...createFeedbackApi(transport.apiRequest),
    ...createHistoryApi(transport.apiRequest),
    ...createQuizApi(transport.apiRequest),
  };
}

export type ApiClient = ReturnType<typeof createApiClient>;

export type {
  ApiRequest,
  ApiRequestWithMeta,
  ApiResponse,
  CursorMeta,
  EnvelopeResult,
  RequestOptions,
} from "./client";
export type { MyProfile, Role } from "./auth";
export type { CourseItem, CourseListResponse, CourseStep, CourseStepState } from "./course";
export { ApiError, ErrorCode, type ErrorCodeValue, type FieldError, NetworkError } from "./errors";
export type {
  HistoryGraphEdge,
  HistoryGraphNode,
  HistoryGraphRelatedStep,
  HistoryGraphResponse,
} from "./history";
export type {
  AnnotatedText,
  AnswerSubmitResponse,
  CompletedStep,
  CompletedStepsResponse,
  Highlight,
  QuizChoice,
  QuizDifficulty,
  QuizExplanationResponse,
  QuizFollowUpQuestion,
  QuizHintResponse,
  QuizKeyword,
  QuizNextResponse,
  QuizStepBriefingBlock,
  QuizStepBriefingBlockType,
  QuizStepBriefingResponse,
  QuizType,
  RetryHint,
  RetryHintBlank,
} from "./quiz";
export type { TokenStorage, Tokens } from "./token-storage";
export type { FollowUpQuestionDetail } from "@thumbsup/core/types";
export { createWebTokenStorage, type WebTokenStorage } from "./web-token-storage";

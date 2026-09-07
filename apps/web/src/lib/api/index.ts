import { createApiClient } from "@thumbsup/api";
import { createWebTokenStorage } from "./web-token-storage";

const DEFAULT_API_URL = "https://thumbsup-api.duckdns.org";

export const tokenStore = createWebTokenStorage();
export const apiClient = createApiClient({
  baseUrl: process.env.NEXT_PUBLIC_API_URL || DEFAULT_API_URL,
  tokenStorage: tokenStore,
});

export const {
  apiRequest,
  apiRequestWithMeta,
  apiUrl,
  getCompletedSteps,
  getCourses,
  getHistoryGraph,
  getMyProfile,
  getNextQuiz,
  getNextQuizForStep,
  getNextStepBriefing,
  getQuizExplanation,
  getStepQuiz,
  login,
  logout,
  refresh,
  requestQuizHint,
  sendFeedback,
  signup,
  submitQuizAnswer,
} = apiClient;

export * from "@thumbsup/api";

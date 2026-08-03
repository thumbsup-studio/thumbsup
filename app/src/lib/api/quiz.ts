import { apiRequest } from "./client";

export type QuizType = "OX" | "MULTIPLE_CHOICE" | "KEYWORD_BLANK";
export type QuizDifficulty = "EASY" | "MEDIUM" | "HARD";

export type QuizChoice = {
  choiceId: number;
  content: string;
  displayOrder: number;
};

export type QuizNextResponse = {
  quizId: number;
  type: QuizType;
  difficulty: QuizDifficulty;
  questionText: string;
  codeSnippet: string | null;
  choices: QuizChoice[] | null;
  blankCount: number | null;
  stepOrder: number;
  slotOrder: number;
  /**
   * 이 문제가 속한 스텝의 전체 문제 수(이슈 266). 스텝마다 문제 수가 달라 클라이언트가
   * 상수로 가정할 수 없다 — 진행 표시와 완주 판정이 모두 이 값을 기준으로 한다.
   */
  totalCount: number;
};

/** 빈칸 하나에 대한 재도전 힌트. answerLength는 공백을 제외한 글자 수. */
export type RetryHintBlank = {
  slotOrder: number;
  revealedPrefix: string;
  answerLength: number;
};

/**
 * 오답 재도전 힌트(#63) — 오답이고 중·상 난이도일 때만 채워지고 그 외에는 null.
 * 사지선다면 소거할 오답 하나(eliminatedChoiceId), 빈칸이면 슬롯별 힌트(blankHints) 중 하나만 채워진다.
 */
export type RetryHint = {
  eliminatedChoiceId: number | null;
  blankHints: RetryHintBlank[] | null;
};

export type AnswerSubmitResponse = {
  isCorrect: boolean;
  retryHint: RetryHint | null;
};

/** 사용자가 제출 전에 요청하는, 문제 유형과 무관한 한 문장 힌트. */
export type QuizHintResponse = {
  hint: string;
};

export type Highlight = {
  keyword: string;
  start: number;
  end: number;
};

export type AnnotatedText = {
  text: string;
  highlights: Highlight[];
};

export type QuizKeyword = {
  keyword: string;
  description: string;
};

export type QuizFollowUpQuestion = {
  followUpQuestionId: number;
  content: string;
  isPrimary: boolean;
};

export type QuizExplanationResponse = {
  quizId: number;
  questionText: string;
  type: QuizType;
  difficulty: QuizDifficulty;
  currentNumber: number;
  totalCount: number;
  courseTitle: string;
  unitTitle: string;
  explanationSummary: AnnotatedText[];
  explanationExample: AnnotatedText | null;
  wrongAnswerExplanation: AnnotatedText;
  keywords: QuizKeyword[];
  followUpQuestions: QuizFollowUpQuestion[];
};

export type CompletedStep = {
  stepOrder: number;
  topic: string;
};

export type CompletedStepsResponse = {
  steps: CompletedStep[];
};

export function getNextQuiz(): Promise<QuizNextResponse> {
  return apiRequest<QuizNextResponse>("/quizzes/next");
}

/** 유저가 완료한(현재 진행 스텝보다 이전) 스텝 목록 — 히스토리 복습 화면용. */
export function getCompletedSteps(): Promise<CompletedStepsResponse> {
  return apiRequest<CompletedStepsResponse>("/quizzes/steps/completed");
}

/**
 * 지정한 스텝·슬롯의 문제 1개. `/quizzes/next`와 동일 계약이지만 시도 여부와 무관하게
 * 항상 슬롯 순서로 준다(완료 스텝 재풀이용).
 */
export function getStepQuiz(stepOrder: number, slotOrder: number): Promise<QuizNextResponse> {
  return apiRequest<QuizNextResponse>(`/quizzes/steps/${stepOrder}/${slotOrder}`);
}

export function submitQuizAnswer(quizId: number, answers: string[]): Promise<AnswerSubmitResponse> {
  return apiRequest<AnswerSubmitResponse>(`/quizzes/${quizId}/answers`, {
    method: "POST",
    body: { answers },
  });
}

export function requestQuizHint(quizId: number): Promise<QuizHintResponse> {
  return apiRequest<QuizHintResponse>(`/quizzes/${quizId}/hints`, {
    method: "POST",
  });
}

export function getQuizExplanation(quizId: number): Promise<QuizExplanationResponse> {
  return apiRequest<QuizExplanationResponse>(`/quizzes/${quizId}/explanation`);
}

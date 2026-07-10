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
  /** 서버가 추가하면 사용하고, 없으면 MVP 기본 5문제 세트로 fallback한다. */
  totalCount?: number;
};

export type AnswerSubmitResponse = {
  isCorrect: boolean;
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

export function getQuizExplanation(quizId: number): Promise<QuizExplanationResponse> {
  return apiRequest<QuizExplanationResponse>(`/quizzes/${quizId}/explanation`);
}

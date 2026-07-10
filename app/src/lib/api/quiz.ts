import { apiRequest } from "./client";

export type QuizType = "OX" | "MULTIPLE_CHOICE" | "KEYWORD_BLANK";
export type QuizDifficulty = "LOW" | "MEDIUM" | "HIGH";

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
  followUpQuestions: string[];
};

export function getNextQuiz(): Promise<QuizNextResponse> {
  return apiRequest<QuizNextResponse>("/quizzes/next");
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

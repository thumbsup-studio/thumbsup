/**
 * 문제 저작 대시보드 도메인 타입.
 * 필드명은 서버 REST 계약(docs/superpowers/plans/2026-07-14-quiz-authoring-{app,server}.md)과 1:1.
 */

export type DraftOrigin = "NEW" | "IMPROVE";
export type DraftStatus = "DRAFT" | "APPROVED";
export type JobKind = "GENERATE" | "REVIEW";
export type JobRunStatus = "QUEUED" | "RUNNING" | "SUCCEEDED" | "FAILED";

export type DraftSummary = {
  draftId: number;
  origin: DraftOrigin;
  status: DraftStatus;
  topic: string;
  sourceQuizId: number | null;
  revisionCount: number;
  updatedAt: string;
};

export type Revision = {
  revisionNo: number;
  reviewSummary: string | null;
  reviewedBy: number | null;
  jobId: number;
  createdAt: string;
};

export type DraftDetail = DraftSummary & {
  payload: { quizzes: GeneratedQuiz[] };
  revisions: Revision[];
  createdBy: number;
  approvedBy: number | null;
  approvedAt: string | null;
};

export type JobStatus = {
  jobId: number;
  kind: JobKind;
  status: JobRunStatus;
  draftId: number | null;
  error: string | null;
  createdAt: string;
  startedAt: string | null;
  finishedAt: string | null;
};

export type AuthoringStepQuiz = {
  quizId: number;
  slotOrder: number;
  type: string;
  difficulty: string;
  questionText: string;
};

export type AuthoringStep = {
  stepOrder: number;
  topic: string;
  quizzes: AuthoringStepQuiz[];
};

export type GeneratedQuizChoice = {
  content: string;
  isCorrect: boolean;
};

export type GeneratedQuizKeyword = {
  keyword: string;
  description: string;
};

export type GeneratedFollowUpQuestion = {
  content: string;
  isPrimary: boolean;
  difficulty: string;
  oneLineAnswer: string;
  blocks: { label: string; content: string }[];
  keywords: GeneratedQuizKeyword[];
};

export type GeneratedQuiz = {
  type: string;
  difficulty: string;
  questionText: string;
  codeSnippet: string | null;
  explanationSummary: string;
  explanationExample: string | null;
  wrongAnswerExplanation: string;
  correctAnswer: string | null;
  choices: GeneratedQuizChoice[] | null;
  answerKeywords: string[][] | null;
  followUpQuestions: GeneratedFollowUpQuestion[] | null;
  derivedConcepts: string[] | null;
  keywords: GeneratedQuizKeyword[] | null;
};

export type AuthoringCourse = { courseId: number; title: string; category: string };

export type AuthoringDetailedQuiz = {
  quizId: number;
  slotOrder: number;
  generated: GeneratedQuiz;
};

export type AuthoringDetailedStep = {
  stepOrder: number;
  topic: string | null;
  quizzes: AuthoringDetailedQuiz[];
};

export type AuthoringCourseDetail = {
  courseId: number;
  title: string;
  steps: AuthoringDetailedStep[];
};

export type Difficulty = "low" | "medium" | "high";

export type QuestionKind = "ox" | "multiple-choice" | "keyword-blank";

type BaseQuestion = {
  id: string;
  difficulty: Difficulty;
  prompt: string;
  explanation: string;
  insight: {
    summary: string[];
    example: string;
    referenceLabel: string;
  };
};

export type OxQuestion = BaseQuestion & {
  kind: "ox";
  answer: boolean;
};

export type MultipleChoiceQuestion = BaseQuestion & {
  kind: "multiple-choice";
  code?: {
    language: "ts" | "pseudo";
    source: string;
  };
  options: {
    id: string;
    label: string;
  }[];
  answerId: string;
};

export type KeywordBlankQuestion = BaseQuestion & {
  kind: "keyword-blank";
  blankLabel: string;
  code?: {
    language: "pseudo";
    before: string;
    after: string;
  };
  acceptedAnswers: string[];
};

export type PlayQuestion = OxQuestion | MultipleChoiceQuestion | KeywordBlankQuestion;

export type PlaySession = {
  id: string;
  courseTitle: string;
  unitTitle: string;
  questions: PlayQuestion[];
};

export type AnswerDraft = boolean | string | null;

export type GradeResult = {
  questionId: string;
  correct: boolean;
};

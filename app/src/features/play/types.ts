export type Difficulty = "low" | "medium" | "high";

export type QuestionKind = "ox" | "multiple-choice" | "keyword-blank";

/**
 * 해설에서 이어지는 꼬리 질문. 본 문제(PlayQuestion) 1개당 1개. API 미확정이라 목업으로 채운다.
 * oneLineAnswer·explanation·usageExample 안의 keyword.term은 KeywordTooltipText로 하이라이트된다.
 */
export type FollowUpQuestion = {
  category: string;
  difficulty: Difficulty;
  question: string;
  oneLineAnswer: string;
  explanation: string;
  usageExample: string;
  keywords: {
    term: string;
    description: string;
  }[];
};

type BaseQuestion = {
  id: string;
  difficulty: Difficulty;
  prompt: string;
  explanation: string;
  insight: {
    summary: string[];
    wrongReason: string;
    codeExample?: {
      language: "ts" | "pseudo";
      source: string;
      description: string;
    };
    usageExample: string;
    keywords: {
      term: string;
      description: string;
    }[];
    referenceLabel: string;
  };
  followUp?: FollowUpQuestion;
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

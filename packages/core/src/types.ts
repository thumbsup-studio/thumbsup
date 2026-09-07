export type Difficulty = "low" | "medium" | "high";

export type QuestionKind = "ox" | "multiple-choice" | "keyword-blank";

/** 서버 오프셋 기반 키워드 하이라이트. 단위는 UTF-16 code unit, end는 배타적. */
export type Highlight = { keyword: string; start: number; end: number };

/** 하이라이트 오프셋이 딸린 서버 원문. */
export type AnnotatedText = { text: string; highlights: Highlight[] };

/** 꼬리질문 자체의 난이도(서버 표기). PlayQuestion의 Difficulty와는 별개 스케일. */
export type ServerDifficulty = "EASY" | "MEDIUM" | "HARD";

export type FollowUpBlock = { label: string; type: "TEXT"; content: AnnotatedText };

export type FollowUpKeyword = { keyword: string; description: string };

/** GET /api/v1/follow-up-questions/{id} 응답. */
export type FollowUpQuestionDetail = {
  followUpQuestionId: number;
  sourceQuizId: number;
  sourceQuizNumber: number;
  difficulty: ServerDifficulty;
  question: string;
  oneLineAnswer: AnnotatedText;
  blocks: FollowUpBlock[];
  keywords: FollowUpKeyword[];
};

/** 해설 응답에 실려오는 꼬리질문 요약(상세 API 호출 전 목록/CTA용). */
export type FollowUpSummary = { followUpQuestionId: number; content: string; isPrimary: boolean };

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
  followUpQuestions: FollowUpSummary[];
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

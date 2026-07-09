import type { AnswerDraft, GradeResult, PlayQuestion } from "@/features/play/types";

const difficultyLabels = {
  low: "난이도 하",
  medium: "난이도 중",
  high: "난이도 상",
} as const;

export function getDifficultyLabel(difficulty: keyof typeof difficultyLabels) {
  return difficultyLabels[difficulty];
}

export function getProgressPercent(currentIndex: number, total: number) {
  if (total <= 0) {
    return 0;
  }

  return Math.round(((currentIndex + 1) / total) * 100);
}

export function clampQuestionIndex(index: number, total: number) {
  if (total <= 0) {
    return 0;
  }

  if (!Number.isFinite(index)) {
    return 0;
  }

  return Math.min(Math.max(Math.trunc(index), 0), total - 1);
}

export function normalizeKeywordAnswer(value: string) {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

export function canSubmitAnswer(question: PlayQuestion, draft: AnswerDraft) {
  if (question.kind === "ox") {
    return typeof draft === "boolean";
  }

  if (question.kind === "multiple-choice") {
    return typeof draft === "string" && draft.length > 0;
  }

  return typeof draft === "string" && draft.trim().length > 0;
}

export function gradeMockAnswer(question: PlayQuestion, draft: AnswerDraft): GradeResult {
  if (question.kind === "ox") {
    return {
      questionId: question.id,
      correct: draft === question.answer,
    };
  }

  if (question.kind === "multiple-choice") {
    return {
      questionId: question.id,
      correct: draft === question.answerId,
    };
  }

  const normalizedDraft = normalizeKeywordAnswer(String(draft ?? ""));

  return {
    questionId: question.id,
    correct: question.acceptedAnswers.some(
      (answer) => normalizeKeywordAnswer(answer) === normalizedDraft,
    ),
  };
}

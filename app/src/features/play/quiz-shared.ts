import type { QuizDifficulty, QuizType } from "@/lib/api/quiz";

export const difficultyLabels: Record<QuizDifficulty, string> = {
  EASY: "난이도 하",
  MEDIUM: "난이도 중",
  HARD: "난이도 상",
};

export function getPlayQuestionKindLabel(type: QuizType) {
  if (type === "OX") {
    return "OX";
  }

  if (type === "MULTIPLE_CHOICE") {
    return "사지선다";
  }

  return "키워드 빈칸";
}

export function getInsightQuestionKindLabel(type: QuizType) {
  return `${getPlayQuestionKindLabel(type)} 해설`;
}

export function isUnauthorized(error: unknown) {
  return typeof error === "object" && error !== null && "status" in error && error.status === 401;
}

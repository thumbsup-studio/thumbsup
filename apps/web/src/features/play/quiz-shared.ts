import type { QuizChoice, QuizDifficulty, QuizType } from "@/lib/api/quiz";

/** 이 수부터 연속 정답을 화면에 띄운다 — 1은 "연속"이라 부를 수 없다. 풀이·해설 화면이 같은 기준을 쓴다. */
export const comboVisibleFrom = 2;

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

/**
 * 복습으로 같은 문제를 다시 풀 때 정답 "번호"를 외워버리는 것을 막기 위해 선택지 순서를 섞는다.
 * 채점은 서버가 choiceId로 하므로 표시 순서를 바꿔도 정답 판정에는 영향이 없다.
 */
export function shuffleChoices(
  choices: QuizChoice[],
  random: () => number = Math.random,
): QuizChoice[] {
  const shuffled = [...choices];

  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const target = Math.floor(random() * (index + 1));
    [shuffled[index], shuffled[target]] = [shuffled[target], shuffled[index]];
  }

  return shuffled;
}

export function isUnauthorized(error: unknown) {
  return typeof error === "object" && error !== null && "status" in error && error.status === 401;
}

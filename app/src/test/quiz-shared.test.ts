import { describe, expect, it } from "vitest";
import { shuffleChoices } from "@/features/play/quiz-shared";
import type { QuizChoice } from "@/lib/api/quiz";

const choices: QuizChoice[] = [
  { choiceId: 11, content: "뮤텍스", displayOrder: 1 },
  { choiceId: 12, content: "캐시", displayOrder: 2 },
  { choiceId: 13, content: "스택", displayOrder: 3 },
  { choiceId: 14, content: "힙", displayOrder: 4 },
];

describe("shuffleChoices", () => {
  it("reorders choices with the given random source", () => {
    const shuffled = shuffleChoices(choices, () => 0);

    expect(shuffled.map((choice) => choice.choiceId)).toEqual([12, 13, 14, 11]);
  });

  it("keeps every choice exactly once", () => {
    const shuffled = shuffleChoices(choices, () => 0.5);

    expect([...shuffled].sort((a, b) => a.choiceId - b.choiceId)).toEqual(choices);
  });

  it("does not mutate the original array", () => {
    const original = [...choices];

    shuffleChoices(choices, () => 0);

    expect(choices).toEqual(original);
  });

  it("returns a single choice unchanged", () => {
    const single = choices.slice(0, 1);

    expect(shuffleChoices(single, () => 0)).toEqual(single);
  });

  it("returns an empty list unchanged", () => {
    expect(shuffleChoices([], () => 0)).toEqual([]);
  });
});

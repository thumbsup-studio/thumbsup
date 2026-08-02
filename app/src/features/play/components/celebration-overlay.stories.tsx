import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { getCelebration } from "@/features/play/celebration-logic";
import { CelebrationOverlay } from "@/features/play/components/celebration-overlay";

/**
 * 이슈 211 완료 기준 3번("학습 흐름을 방해하지 않는 선에서 강도 튜닝")은 글로 정할 수 없다.
 * 이 스토리에서 사다리 각 칸을 반복 재생하며 celebration-logic의 HOLD_MS를 확정한다.
 */
const meta = {
  component: CelebrationOverlay,
  parameters: { layout: "fullscreen" },
  title: "play/CelebrationOverlay",
} satisfies Meta<typeof CelebrationOverlay>;

export default meta;

type Story = StoryObj<typeof meta>;

function celebration(overrides: Parameters<typeof getCelebration>[0]) {
  return getCelebration(overrides);
}

const base = {
  correct: true,
  difficulty: "EASY" as const,
  prefersReducedMotion: false,
  quizId: 7,
  wasRetry: false,
};

export const Combo1: Story = {
  args: { celebration: celebration({ ...base, combo: 1 }), onContinue: () => {} },
};

export const Combo2: Story = {
  args: { celebration: celebration({ ...base, combo: 2 }), onContinue: () => {} },
};

export const Combo3Confetti: Story = {
  args: { celebration: celebration({ ...base, combo: 3 }), onContinue: () => {} },
};

export const HardDifficulty: Story = {
  args: {
    celebration: celebration({ ...base, combo: 1, difficulty: "HARD" }),
    onContinue: () => {},
  },
};

export const RetrySuccess: Story = {
  args: {
    celebration: celebration({ ...base, combo: 2, wasRetry: true }),
    onContinue: () => {},
  },
};

export const Wrong: Story = {
  args: {
    celebration: celebration({ ...base, combo: 0, correct: false }),
    onContinue: () => {},
  },
};

export const ReducedMotion: Story = {
  args: {
    celebration: celebration({ ...base, combo: 5, prefersReducedMotion: true }),
    onContinue: () => {},
  },
};

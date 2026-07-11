import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { CharacterBlock } from "./character-block";

/**
 * fullness 슬라이더를 드래그하면 링·표정(happy/neutral/hungry)이 실시간으로 바뀐다 —
 * 임계값은 home-logic.ts의 getCharacterMood(70%↑ 행복 · 30~69% 보통 · 29%↓ 배고픔).
 */
const meta: Meta<typeof CharacterBlock> = {
  title: "Home/CharacterBlock",
  component: CharacterBlock,
  args: { name: "보리", fullness: 62 },
  argTypes: {
    fullness: { control: { type: "range", min: 0, max: 100, step: 1 } },
  },
};
export default meta;

export const Playground: StoryObj<typeof CharacterBlock> = {};

export const Happy: StoryObj<typeof CharacterBlock> = { args: { fullness: 85 } };
export const Neutral: StoryObj<typeof CharacterBlock> = { args: { fullness: 50 } };
export const Hungry: StoryObj<typeof CharacterBlock> = { args: { fullness: 15 } };

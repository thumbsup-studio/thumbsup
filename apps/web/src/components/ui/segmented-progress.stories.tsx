import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { SegmentedProgress } from "./segmented-progress";

const meta: Meta<typeof SegmentedProgress> = {
  title: "UI/SegmentedProgress",
  component: SegmentedProgress,
};
export default meta;

export const Default: StoryObj<typeof SegmentedProgress> = { args: { value: 2, total: 5 } };

/** 스텝마다 문제 수가 다르다 — 3문제짜리 스텝. */
export const ShortStep: StoryObj<typeof SegmentedProgress> = { args: { value: 1, total: 3 } };

/** 연속 정답 중 — 채워진 칸이 스트릭 색으로 바뀐다. */
export const Hot: StoryObj<typeof SegmentedProgress> = { args: { value: 4, total: 5, hot: true } };

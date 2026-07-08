import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Button } from "./button";
import { EmptyState } from "./empty-state";

const meta: Meta<typeof EmptyState> = { title: "UI/EmptyState", component: EmptyState };
export default meta;
export const NoData: StoryObj<typeof EmptyState> = {
  args: { title: "오늘의 학습이 없어요", description: "새 코스를 골라보세요." },
};
export const WithAction: StoryObj<typeof EmptyState> = {
  args: {
    title: "아직 학습 기록이 없어요",
    description: "첫 문제를 풀면 여기에 쌓여요.",
    action: <Button>오늘의 문제 시작</Button>,
  },
};

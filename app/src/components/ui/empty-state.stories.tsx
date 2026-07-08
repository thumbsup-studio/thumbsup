import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { EmptyState } from "./empty-state";

const meta: Meta<typeof EmptyState> = { title: "UI/EmptyState", component: EmptyState };
export default meta;
export const NoData: StoryObj<typeof EmptyState> = {
  args: { title: "오늘의 학습이 없어요", description: "새 코스를 골라보세요." },
};

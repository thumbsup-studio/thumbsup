import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Feedback } from "./feedback";

const meta: Meta<typeof Feedback> = { title: "UI/Feedback", component: Feedback };
export default meta;
type Story = StoryObj<typeof Feedback>;

export const Info: Story = { args: { children: "오늘의 목표 10문제 중 4문제 완료" } };
export const Pending: Story = { args: { tone: "pending", children: "히스토리는 준비 중입니다." } };
export const Success: Story = { args: { tone: "success", children: "정답이에요! +10P" } };
export const ErrorState: Story = {
  args: { tone: "error", children: "불러오지 못했어요.", onRetry: () => {} },
};

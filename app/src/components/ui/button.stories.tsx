import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Button } from "./button";

const meta: Meta<typeof Button> = { title: "UI/Button", component: Button };
export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = { args: { children: "오늘의 문제 시작" } };
export const Secondary: Story = { args: { variant: "secondary", children: "다음 화" } };
export const Ghost: Story = { args: { variant: "ghost", children: "건너뛰기" } };
export const Loading: Story = { args: { loading: true, children: "정답 확인" } };
export const LoadingWithText: Story = {
  args: { loading: true, loadingText: "로그인 중…", children: "로그인" },
};
export const Disabled: Story = { args: { disabled: true, children: "정답 확인" } };

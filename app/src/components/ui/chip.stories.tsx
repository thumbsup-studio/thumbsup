import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Chip } from "./chip";

const meta: Meta<typeof Chip> = { title: "UI/Chip", component: Chip };
export default meta;
type Story = StoryObj<typeof Chip>;

export const Neutral: Story = { args: { children: "자료구조" } };
export const Primary: Story = { args: { tone: "primary", children: "네트워크" } };
export const Success: Story = { args: { tone: "success", children: "정답" } };
export const Danger: Story = { args: { tone: "danger", children: "오답" } };

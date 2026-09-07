import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Card } from "./card";

const meta: Meta<typeof Card> = { title: "UI/Card", component: Card };
export default meta;
type Story = StoryObj<typeof Card>;

export const Surface: Story = { args: { children: "오늘의 학습 카드" } };
export const Hero: Story = { args: { variant: "hero", children: "TCP와 UDP의 차이" } };

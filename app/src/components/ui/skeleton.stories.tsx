import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Skeleton } from "./skeleton";

const meta: Meta<typeof Skeleton> = { title: "UI/Skeleton", component: Skeleton };
export default meta;
export const Card: StoryObj<typeof Skeleton> = { args: { className: "h-24 w-full" } };

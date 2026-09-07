import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { Progress } from "./progress";

const meta: Meta<typeof Progress> = { title: "UI/Progress", component: Progress };
export default meta;
export const Half: StoryObj<typeof Progress> = { args: { value: 4, max: 10 } };

import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { AppToastProvider } from "../src/app-toast-provider";

const meta = {
  title: "Providers/AppToastProvider",
  component: AppToastProvider,
  args: { children: <p>토스트 컨텍스트가 적용된 콘텐츠</p> },
} satisfies Meta<typeof AppToastProvider>;

export default meta;
type Story = StoryObj<typeof meta>;
export const Default: Story = {};

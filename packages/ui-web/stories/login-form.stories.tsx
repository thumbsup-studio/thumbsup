import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { LoginForm } from "../src/login-form";

const meta = {
  title: "UI/LoginForm",
  component: LoginForm,
  args: { onSubmit: async () => {} },
} satisfies Meta<typeof LoginForm>;

export default meta;
type Story = StoryObj<typeof meta>;
export const Default: Story = {};

import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { LockIcon, MailIcon } from "@/components/icons";
import { Input } from "./input";

const meta: Meta<typeof Input> = { title: "UI/Input", component: Input };
export default meta;
type Story = StoryObj<typeof Input>;

export const Email: Story = {
  args: {
    label: "이메일",
    type: "email",
    placeholder: "you@example.com",
    leftIcon: <MailIcon className="size-5" />,
  },
};

export const Password: Story = {
  args: {
    label: "비밀번호",
    type: "password",
    placeholder: "8자 이상 입력",
    leftIcon: <LockIcon className="size-5" />,
  },
};

export const WithFieldError: Story = {
  args: {
    label: "비밀번호",
    type: "password",
    defaultValue: "1234",
    error: "8자 이상 72자 이하로 입력해 주세요.",
    leftIcon: <LockIcon className="size-5" />,
  },
};

export const InvalidNoMessage: Story = {
  args: {
    label: "비밀번호",
    type: "password",
    defaultValue: "1234",
    error: true,
    leftIcon: <LockIcon className="size-5" />,
  },
};

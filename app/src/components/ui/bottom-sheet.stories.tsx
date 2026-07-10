import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { CircleCheckIcon } from "@/components/icons";
import { BottomSheet } from "./bottom-sheet";
import { Button } from "./button";

const meta: Meta<typeof BottomSheet> = { title: "UI/BottomSheet", component: BottomSheet };
export default meta;
type Story = StoryObj<typeof BottomSheet>;

export const LogoutConfirm: Story = {
  args: {
    open: true,
    title: "로그아웃 확인",
    onClose: () => {},
    children: (
      <div className="text-center">
        <div
          aria-hidden="true"
          className="mx-auto flex size-13 items-center justify-center rounded-chip bg-danger/10 text-danger"
        >
          <CircleCheckIcon className="size-6" />
        </div>
        <div className="mt-4 text-xl font-extrabold text-ink">로그아웃할까요?</div>
        <p className="mt-1.5 text-sm text-ink-muted">다시 이용하려면 이메일로 로그인해야 해요.</p>
        <div className="mt-6 flex flex-col gap-2.5">
          <Button className="bg-danger text-primary-fg">로그아웃</Button>
          <Button variant="secondary">취소</Button>
        </div>
      </div>
    ),
  },
};

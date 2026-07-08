import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { BottomTabBar } from "./bottom-tab-bar";

const meta: Meta<typeof BottomTabBar> = { title: "UI/BottomTabBar", component: BottomTabBar };
export default meta;
type Story = StoryObj<typeof BottomTabBar>;

export const FourTabs: Story = {
  args: {
    tabs: [
      { key: "today", label: "투데이", active: true },
      { key: "course", label: "코스" },
      { key: "atlas", label: "아틀라스" },
      { key: "basecamp", label: "베이스캠프" },
    ],
  },
};

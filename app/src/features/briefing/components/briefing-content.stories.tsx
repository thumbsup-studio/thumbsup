import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { BriefingContent } from "./briefing-content";

const meta = {
  title: "Features/Briefing/BriefingContent",
  component: BriefingContent,
  args: {
    summary: "CPU를 기다리는 작업의 실행 순서와 응답성 사이의 관계를 살펴봅니다.",
    blocks: [
      {
        type: "CONCEPT",
        heading: "기준이 다르면 실행 순서도 달라져요",
        content: "도착 순서, 예상 실행 시간, 우선순위처럼 어떤 기준을 쓰는지 먼저 확인해요.",
        displayOrder: 1,
      },
      {
        type: "EXAMPLE",
        heading: "시간을 나누어 쓰는 경우",
        content: "여러 프로그램에 짧은 실행 시간을 차례로 주면 빠르게 반응하는 것처럼 보여요.",
        displayOrder: 2,
      },
      {
        type: "CAUTION",
        heading: "전환에도 비용이 들어요",
        content: "실행 대상을 너무 자주 바꾸면 실제 작업에 쓸 CPU 시간이 줄 수 있어요.",
        displayOrder: 3,
      },
    ],
  },
  parameters: { layout: "padded" },
} satisfies Meta<typeof BriefingContent>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};

export const Overview: Story = {
  args: {
    variant: "overview",
    expanded: false,
  },
};

export const OverviewExpanded: Story = {
  args: {
    variant: "overview",
    expanded: true,
  },
};

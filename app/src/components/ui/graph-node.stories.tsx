import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { GraphNode } from "./graph-node";

const meta: Meta<typeof GraphNode> = {
  title: "UI/GraphNode",
  component: GraphNode,
  decorators: [
    (Story) => (
      <svg
        aria-label="GraphNode 미리보기"
        className="bg-graph-bg"
        height={80}
        role="img"
        viewBox="0 0 280 80"
        width={280}
      >
        <Story />
      </svg>
    ),
  ],
};
export default meta;
type Story = StoryObj<typeof GraphNode>;

export const Master: Story = { args: { id: "ip", label: "IP", mastery: "master", x: 140, y: 40 } };
export const Learning: Story = {
  args: { id: "udp", label: "UDP", mastery: "learning", x: 140, y: 40 },
};
export const Unlearned: Story = {
  args: { id: "tls", label: "TLS", mastery: "unlearned", x: 140, y: 40 },
};
export const Selected: Story = {
  args: { id: "udp", label: "UDP", mastery: "learning", x: 140, y: 40, selected: true },
};

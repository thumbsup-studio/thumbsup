import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { GRAPH_ARROW_MARKER_ID, GraphEdge } from "./graph-edge";

const meta: Meta<typeof GraphEdge> = {
  title: "UI/GraphEdge",
  component: GraphEdge,
  decorators: [
    (Story) => (
      <svg
        aria-label="GraphEdge 미리보기"
        className="bg-graph-bg"
        height={120}
        role="img"
        viewBox="0 0 200 120"
        width={200}
      >
        <defs>
          <marker
            id={GRAPH_ARROW_MARKER_ID}
            markerHeight={6}
            markerWidth={6}
            orient="auto-start-reverse"
            refX={8}
            refY={5}
            viewBox="0 0 10 10"
          >
            <path className="fill-graph-edge" d="M 0 0 L 10 5 L 0 10 Z" />
          </marker>
        </defs>
        <Story />
      </svg>
    ),
  ],
};
export default meta;
type Story = StoryObj<typeof GraphEdge>;

export const Default: Story = { args: { x1: 20, y1: 20, x2: 180, y2: 100 } };

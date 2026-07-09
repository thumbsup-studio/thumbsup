import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { GraphLegend } from "./graph-legend";

const meta: Meta<typeof GraphLegend> = {
  title: "UI/GraphLegend",
  component: GraphLegend,
  decorators: [
    (Story) => (
      <div className="bg-graph-bg p-4">
        <Story />
      </div>
    ),
  ],
};
export default meta;
type Story = StoryObj<typeof GraphLegend>;

export const Default: Story = {};

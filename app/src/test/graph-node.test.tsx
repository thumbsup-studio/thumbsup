import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { GraphNode } from "@/components/ui/graph-node";

describe("GraphNode", () => {
  it("renders an accessible label describing each mastery level", () => {
    const { rerender } = render(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="ip" label="IP" mastery="master" x={50} y={30} />
      </svg>,
    );
    expect(screen.getByRole("button", { name: "IP, 숙련도 마스터" })).toBeInTheDocument();

    rerender(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="udp" label="UDP" mastery="learning" x={50} y={30} />
      </svg>,
    );
    expect(screen.getByRole("button", { name: "UDP, 숙련도 학습중" })).toBeInTheDocument();

    rerender(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="tls" label="TLS" mastery="unlearned" x={50} y={30} />
      </svg>,
    );
    expect(screen.getByRole("button", { name: "TLS, 숙련도 미학습" })).toBeInTheDocument();
  });

  it("renders a checkmark icon for master nodes", () => {
    const { container } = render(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="ip" label="IP" mastery="master" x={50} y={30} />
      </svg>,
    );
    expect(container.querySelector("path.stroke-graph-bg")).toBeInTheDocument();
  });

  it("renders a half-filled circle icon for learning nodes", () => {
    const { container } = render(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="udp" label="UDP" mastery="learning" x={50} y={30} />
      </svg>,
    );
    expect(container.querySelector("circle.stroke-graph-fg")).toBeInTheDocument();
    expect(container.querySelector("path.fill-graph-fg")).toBeInTheDocument();
  });

  it("renders a dashed circle icon for unlearned nodes", () => {
    const { container } = render(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="tls" label="TLS" mastery="unlearned" x={50} y={30} />
      </svg>,
    );
    expect(container.querySelector('circle[stroke-dasharray="2 2"]')).toBeInTheDocument();
  });

  it("calls onSelect on click and on Enter/Space keydown", () => {
    const onSelect = vi.fn();
    render(
      <svg aria-label="테스트 캔버스" role="img">
        <GraphNode id="ip" label="IP" mastery="master" onSelect={onSelect} x={50} y={30} />
      </svg>,
    );
    const node = screen.getByRole("button", { name: "IP, 숙련도 마스터" });

    fireEvent.click(node);
    fireEvent.keyDown(node, { key: "Enter" });
    fireEvent.keyDown(node, { key: " " });

    expect(onSelect).toHaveBeenCalledTimes(3);
    expect(onSelect).toHaveBeenCalledWith("ip");
  });
});

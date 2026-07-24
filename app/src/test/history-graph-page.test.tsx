import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { HistoryGraphPage } from "@/features/history-graph/components/history-graph-page";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock }),
}));

vi.mock("next/dynamic", () => ({
  default: (loader: () => Promise<{ default: unknown }>) => {
    void loader();
    return function MockForceGraph() {
      return <div data-testid="force-graph">force graph</div>;
    };
  },
}));

vi.mock("react-force-graph-2d", () => ({
  default: () => <div data-testid="force-graph-module">force graph module</div>,
}));

function renderPage() {
  return render(
    <AppToastProvider>
      <HistoryGraphPage />
    </AppToastProvider>,
  );
}

describe("HistoryGraphPage", () => {
  it("renders the graph canvas and the default concept detail", async () => {
    renderPage();

    expect(await screen.findByRole("heading", { name: "지식 그래프" })).toBeInTheDocument();
    expect(screen.getByTestId("force-graph")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "프로세스" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /프로세스와 스레드/ })).toHaveAttribute(
      "href",
      "/play?step=1&slot=1&rc=0&rs=0&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4%EC%99%80+%EC%8A%A4%EB%A0%88%EB%93%9C",
    );
  });

  it("does not render graph stats or a separate concept list", async () => {
    renderPage();

    expect(await screen.findByRole("heading", { name: "지식 그래프" })).toBeInTheDocument();

    expect(screen.queryByText("배운 노드")).not.toBeInTheDocument();
    expect(screen.queryByText("연결 수")).not.toBeInTheDocument();
    expect(screen.queryByText("이번 주 확장")).not.toBeInTheDocument();
    expect(screen.queryByText("개념 목록")).not.toBeInTheDocument();
  });

  it("does not render related concept buttons in the detail card", async () => {
    renderPage();

    expect(await screen.findByRole("heading", { name: "프로세스" })).toBeInTheDocument();

    expect(screen.queryByText("관련된 개념들")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "스레드" })).not.toBeInTheDocument();
  });
});

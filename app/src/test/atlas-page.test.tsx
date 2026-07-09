import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { AtlasPage } from "@/features/atlas/components/atlas-page";
import type { AtlasData } from "@/features/atlas/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const baseData: AtlasData = {
  stats: { learnedNodeCount: 46, connectionCount: 112, weeklyGrowth: 7 },
  categories: [{ id: "network", label: "네트워크", recentlyExpanded: true }],
  nodes: [
    {
      id: "ip",
      categoryId: "network",
      label: "IP",
      mastery: "master",
      x: 60,
      y: 40,
      summary: "IP 요약",
    },
    {
      id: "udp",
      categoryId: "network",
      label: "UDP",
      mastery: "learning",
      x: 120,
      y: 100,
      summary: "UDP 요약",
    },
  ],
  edges: [{ id: "e1", fromId: "ip", toId: "udp" }],
};

function renderPage(data: AtlasData = baseData) {
  return render(
    <AppToastProvider>
      <AtlasPage data={data} />
    </AppToastProvider>,
  );
}

describe("AtlasPage", () => {
  it("shows the stat card values", () => {
    renderPage();

    expect(screen.getByText("46")).toBeInTheDocument();
    expect(screen.getByText("112")).toBeInTheDocument();
    expect(screen.getByText("+7")).toBeInTheDocument();
  });

  it("shows the concept sheet with a review CTA when a node is selected", () => {
    renderPage();

    fireEvent.click(screen.getByRole("button", { name: "IP, 숙련도 마스터" }));

    expect(screen.getByRole("heading", { name: "IP" })).toBeInTheDocument();
    expect(screen.getByText("IP 요약")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "복습하기" })).toBeInTheDocument();
  });

  it("renders a dark empty state when the active category has no nodes", () => {
    renderPage({ ...baseData, nodes: [], edges: [] });

    expect(screen.getByText("아직 연결된 개념이 없어요")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "퀴즈 시작하기" })).toBeInTheDocument();
  });

  it("shows a distinct empty state when a search yields no results", () => {
    renderPage();

    fireEvent.change(screen.getByRole("searchbox"), { target: { value: "존재하지않는개념" } });

    expect(screen.getByText("검색 결과가 없어요")).toBeInTheDocument();
    // 검색 결과 없음에는 데이터 없음용 '퀴즈 시작하기' CTA를 띄우지 않는다
    expect(screen.queryByRole("button", { name: "퀴즈 시작하기" })).not.toBeInTheDocument();
  });
});

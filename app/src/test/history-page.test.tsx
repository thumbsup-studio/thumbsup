import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { HistoryPage } from "@/features/history/components/history-page";
import { getCompletedSteps } from "@/lib/api";

const mockRouter = vi.hoisted(() => ({
  push: vi.fn(),
  replace: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

vi.mock("@/lib/api", () => ({
  getCompletedSteps: vi.fn(),
}));

describe("HistoryPage", () => {
  beforeEach(() => {
    vi.mocked(getCompletedSteps).mockReset();
    mockRouter.push.mockReset();
    mockRouter.replace.mockReset();
  });

  it("완료한 스텝 목록을 불러와 보여준다", async () => {
    vi.mocked(getCompletedSteps).mockResolvedValue({
      steps: [{ stepOrder: 2, topic: "반복문 기초" }],
    });

    render(<HistoryPage />);

    expect(await screen.findByText("STEP 2")).toBeInTheDocument();
    expect(screen.getByText("반복문 기초")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "지식 그래프" })).toHaveAttribute("href", "/history");
  });

  it("스텝을 누르면 전체 복습과 문제 번호별 재풀이 링크가 펼쳐진다", async () => {
    vi.mocked(getCompletedSteps).mockResolvedValue({
      steps: [{ stepOrder: 2, topic: "반복문 기초" }],
    });

    render(<HistoryPage />);

    const stepToggle = await screen.findByRole("button", { name: /STEP 2/ });
    expect(stepToggle).toHaveAttribute("aria-expanded", "false");

    fireEvent.click(stepToggle);

    expect(stepToggle).toHaveAttribute("aria-expanded", "true");

    expect(screen.getByRole("link", { name: "전체 복습 (5문제)" })).toHaveAttribute(
      "href",
      "/play?step=2&slot=1&rc=0&rs=0&topic=%EB%B0%98%EB%B3%B5%EB%AC%B8+%EA%B8%B0%EC%B4%88",
    );

    for (let slot = 1; slot <= 5; slot += 1) {
      expect(screen.getByRole("link", { name: `${slot}번 문제 다시 풀기` })).toHaveAttribute(
        "href",
        `/play?step=2&slot=${slot}&rc=0&rs=0&topic=%EB%B0%98%EB%B3%B5%EB%AC%B8+%EA%B8%B0%EC%B4%88&single=1`,
      );
    }
  });

  it("펼친 스텝을 다시 누르면 접힌다", async () => {
    vi.mocked(getCompletedSteps).mockResolvedValue({
      steps: [{ stepOrder: 2, topic: "반복문 기초" }],
    });

    render(<HistoryPage />);

    const stepToggle = await screen.findByRole("button", { name: /STEP 2/ });
    fireEvent.click(stepToggle);
    expect(screen.getByRole("link", { name: "전체 복습 (5문제)" })).toBeInTheDocument();

    fireEvent.click(stepToggle);
    expect(screen.queryByRole("link", { name: "전체 복습 (5문제)" })).not.toBeInTheDocument();
  });
});

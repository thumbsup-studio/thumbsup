import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { InsightPage } from "@/features/play/components/insight-page";
import { mockPlaySession } from "@/features/play/mock-play-session";

describe("InsightPage", () => {
  it("renders the current question explanation and links back to the next play question", () => {
    render(<InsightPage correct questionIndex={0} session={mockPlaySession} />);

    expect(screen.getByText("정답")).toBeInTheDocument();
    expect(screen.getByText("문제 해설")).toBeInTheDocument();
    expect(screen.getByText("핵심 정리")).toBeInTheDocument();
    expect(screen.getByText("OS process model")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "다음 문제 풀기" })).toHaveAttribute(
      "href",
      "/play?question=1",
    );
  });

  it("links the last question insight back home", () => {
    render(<InsightPage correct={false} questionIndex={4} session={mockPlaySession} />);

    expect(screen.getByText("오답")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "홈으로 돌아가기" })).toHaveAttribute("href", "/");
  });
});

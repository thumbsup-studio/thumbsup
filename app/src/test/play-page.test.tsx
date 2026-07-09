import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { PlayPage } from "@/features/play/components/play-page";
import { mockPlaySession } from "@/features/play/mock-play-session";

describe("PlayPage", () => {
  it("renders the low difficulty ox question first and links to insight after grading", async () => {
    vi.useFakeTimers();
    const onInsightNavigate = vi.fn();

    render(<PlayPage onInsightNavigate={onInsightNavigate} session={mockPlaySession} />);

    expect(screen.getByText("1/5")).toBeInTheDocument();
    expect(screen.getByText("난이도 하")).toBeInTheDocument();
    expect(screen.queryByText("하")).not.toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "O" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "정답 확인" })).toBeDisabled();

    fireEvent.click(screen.getByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
    await act(async () => {
      vi.advanceTimersByTime(240);
    });

    expect(onInsightNavigate).toHaveBeenCalledWith("/insight?question=0&correct=true");
    expect(screen.queryByText("정답입니다")).not.toBeInTheDocument();

    vi.useRealTimers();
  });

  it("renders the multiple choice code question with four choices", () => {
    render(
      <PlayPage session={{ ...mockPlaySession, questions: [mockPlaySession.questions[2]] }} />,
    );

    expect(screen.getByText("사지선다")).toBeInTheDocument();
    expect(screen.getByText("ts")).toBeInTheDocument();
    expect(screen.getByRole("group", { name: "사지선다 선택지" })).toBeInTheDocument();
    expect(screen.getAllByRole("radio")).toHaveLength(4);
  });

  it("renders the keyword blank input and accepts a normalized answer", async () => {
    vi.useFakeTimers();
    const onInsightNavigate = vi.fn();

    render(
      <PlayPage
        onInsightNavigate={onInsightNavigate}
        session={{ ...mockPlaySession, questions: [mockPlaySession.questions[4]] }}
      />,
    );

    fireEvent.change(screen.getByRole("textbox", { name: "핵심 키워드" }), {
      target: { value: "critical section" },
    });
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
    await act(async () => {
      vi.advanceTimersByTime(240);
    });

    expect(onInsightNavigate).toHaveBeenCalledWith("/insight?question=0&correct=true");

    vi.useRealTimers();
  });

  it("can start from a later question index", () => {
    render(<PlayPage initialQuestionIndex={1} session={mockPlaySession} />);

    expect(screen.getByText("2/5")).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "X" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "이전 문제로 돌아가기" })).toHaveAttribute(
      "href",
      "/play?question=0",
    );
  });
});

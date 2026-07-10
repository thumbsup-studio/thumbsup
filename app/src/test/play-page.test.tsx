import { act, fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PlayPage } from "@/features/play/components/play-page";
import { mockPlaySession } from "@/features/play/mock-play-session";

const mockRouter = vi.hoisted(() => ({
  push: vi.fn(),
}));
const { feedMascotMock } = vi.hoisted(() => ({
  feedMascotMock: vi.fn().mockResolvedValue({ name: "보리", fullness: 100 }),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));
vi.mock("@/features/home/api", () => ({
  feedMascot: feedMascotMock,
}));

describe("PlayPage", () => {
  beforeEach(() => {
    mockRouter.push.mockClear();
    feedMascotMock.mockClear();
    window.localStorage.clear();
  });

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

    expect(onInsightNavigate).toHaveBeenCalledWith("/insight?question=0&correct=true&streak=1");
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

    expect(onInsightNavigate).toHaveBeenCalledWith("/insight?question=0&correct=true&streak=1");

    vi.useRealTimers();
  });

  it("passes the updated consecutive correct streak to insight", async () => {
    vi.useFakeTimers();
    const onInsightNavigate = vi.fn();

    window.localStorage.setItem("thumbsup:insight-correct-streak:mock-os-process-thread", "2");

    render(
      <PlayPage
        initialQuestionIndex={2}
        onInsightNavigate={onInsightNavigate}
        session={mockPlaySession}
      />,
    );

    fireEvent.click(screen.getByRole("radio", { name: /경쟁 상태/ }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
    await act(async () => {
      vi.advanceTimersByTime(240);
    });

    expect(onInsightNavigate).toHaveBeenCalledWith("/insight?question=2&correct=true&streak=3");

    vi.useRealTimers();
  });

  it("uses Next router push when no navigation override is provided", async () => {
    vi.useFakeTimers();

    render(<PlayPage session={mockPlaySession} />);

    fireEvent.click(screen.getByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
    await act(async () => {
      vi.advanceTimersByTime(240);
    });

    expect(mockRouter.push).toHaveBeenCalledWith("/insight?question=0&correct=true&streak=1");

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

  it("feeds the mascot when the last (5th) question is submitted", async () => {
    vi.useFakeTimers();

    render(<PlayPage initialQuestionIndex={4} session={mockPlaySession} />);

    fireEvent.change(screen.getByRole("textbox", { name: "핵심 키워드" }), {
      target: { value: "critical section" },
    });
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
    await act(async () => {
      vi.advanceTimersByTime(240);
    });

    expect(feedMascotMock).toHaveBeenCalledTimes(1);

    vi.useRealTimers();
  });

  it("does not feed the mascot before the last question", async () => {
    vi.useFakeTimers();

    render(<PlayPage session={mockPlaySession} />);

    fireEvent.click(screen.getByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
    await act(async () => {
      vi.advanceTimersByTime(240);
    });

    expect(feedMascotMock).not.toHaveBeenCalled();

    vi.useRealTimers();
  });
});

import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { InsightPage } from "@/features/play/components/insight-page";
import { getQuizExplanation } from "@/lib/api/quiz";

const mockRouter = vi.hoisted(() => ({
  replace: vi.fn(),
}));

const lottieCompleteListeners = vi.hoisted(() => new Set<() => void>());

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

vi.mock("@/lib/api/quiz", () => ({
  getQuizExplanation: vi.fn(),
}));

vi.mock("@lottiefiles/dotlottie-react", async () => {
  const React = await import("react");

  return {
    DotLottieReact: ({
      dotLottieRefCallback,
    }: {
      dotLottieRefCallback?: (
        player: {
          addEventListener: (eventName: string, listener: () => void) => void;
          removeEventListener: (eventName: string, listener: () => void) => void;
        } | null,
      ) => void;
    }) => {
      React.useEffect(() => {
        const player = {
          addEventListener: (eventName: string, listener: () => void) => {
            if (eventName === "complete") {
              lottieCompleteListeners.add(listener);
            }
          },
          removeEventListener: (eventName: string, listener: () => void) => {
            if (eventName === "complete") {
              lottieCompleteListeners.delete(listener);
            }
          },
        };

        dotLottieRefCallback?.(player);

        return undefined;
      }, [dotLottieRefCallback]);

      return <canvas data-testid="dotlottie-canvas" />;
    },
  };
});

const explanation = {
  quizId: 7,
  questionText: "프로세스는 자원을 독립적으로 가진다.",
  type: "OX" as const,
  difficulty: "EASY" as const,
  currentNumber: 2,
  totalCount: 5,
  courseTitle: "운영체제",
  unitTitle: "프로세스와 스레드",
  explanationSummary: [
    {
      text: "프로세스는 독립된 자원 단위다.",
      highlights: [{ keyword: "프로세스", start: 0, end: 4 }],
    },
    {
      text: "스레드는 프로세스 안의 실행 흐름이다.",
      highlights: [
        { keyword: "스레드", start: 0, end: 3 },
        { keyword: "프로세스", start: 5, end: 9 },
      ],
    },
  ],
  explanationExample: {
    text: "브라우저 탭은 프로세스로 격리될 수 있다.\n탭 내부 작업은 스레드로 나뉜다.",
    highlights: [
      { keyword: "프로세스", start: 8, end: 12 },
      { keyword: "스레드", start: 31, end: 34 },
    ],
  },
  wrongAnswerExplanation: {
    text: "스레드는 같은 프로세스의 자원을 공유한다.",
    highlights: [
      { keyword: "스레드", start: 0, end: 3 },
      { keyword: "프로세스", start: 8, end: 12 },
    ],
  },
  keywords: [
    { keyword: "프로세스", description: "운영체제가 자원을 관리하는 실행 단위" },
    { keyword: "스레드", description: "프로세스 안의 실행 흐름" },
  ],
  followUpQuestions: [
    {
      followUpQuestionId: 10,
      content: "스레드가 자원을 공유하면 어떤 문제가 생길까요?",
      isPrimary: true,
    },
  ],
};

describe("InsightPage", () => {
  beforeEach(() => {
    mockRouter.replace.mockClear();
    vi.mocked(getQuizExplanation).mockReset();
    lottieCompleteListeners.clear();
  });

  it("loads explanation by quiz id and renders quiz context", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={7} correctStreak={0} />);

    expect(await screen.findByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("프로세스와 스레드")).toBeInTheDocument();
    expect(screen.getByText("2/5")).toBeInTheDocument();
    expect(screen.getByText("난이도 하")).toBeInTheDocument();
    expect(screen.getByText("프로세스는 자원을 독립적으로 가진다.")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "꼬리 질문 풀기" })).toHaveAttribute(
      "href",
      "/follow-up?quizId=7&correct=true&streak=0&fq=10",
    );
    expect(screen.getByRole("link", { name: "다음 문제 풀기" })).toHaveAttribute("href", "/play");
  });

  it("shows a home CTA after the last quiz in the step", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue({
      ...explanation,
      currentNumber: 5,
      totalCount: 5,
    });

    render(<InsightPage correct quizId={7} correctStreak={0} />);

    expect(await screen.findByText("5/5")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "홈으로 가기" })).toHaveAttribute("href", "/");
    expect(screen.queryByRole("link", { name: "다음 문제 풀기" })).not.toBeInTheDocument();
  });

  it("renders every server summary line without hard-coding three items", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={7} />);

    const summary = await screen.findByRole("list", { name: "핵심 정리" });

    expect(within(summary).getAllByRole("listitem")).toHaveLength(2);
    expect(within(summary).getByText("1")).toBeInTheDocument();
    expect(within(summary).getByText("2")).toBeInTheDocument();
    expect(within(summary).queryByText("3")).not.toBeInTheDocument();
  });

  it("uses server highlight offsets for keyword tooltips", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={7} />);

    const processButtons = await screen.findAllByRole("button", { name: "프로세스 설명 보기" });
    fireEvent.click(processButtons[0]);

    expect(screen.getByRole("dialog")).toHaveTextContent("운영체제가 자원을 관리하는 실행 단위");

    fireEvent.click(screen.getAllByRole("button", { name: "스레드 설명 보기" })[0]);

    expect(screen.getByRole("dialog")).toHaveTextContent("프로세스 안의 실행 흐름");
  });

  it("shows keyword descriptions in a centered dimmed dialog that stays inside the mobile viewport", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={7} />);

    const processButtons = await screen.findAllByRole("button", { name: "프로세스 설명 보기" });
    fireEvent.click(processButtons[0]);

    const tooltip = screen.getByRole("dialog");

    expect(tooltip).toHaveClass("fixed", "top-1/2", "right-4", "left-4", "max-w-md");
    expect(tooltip).toHaveTextContent("프로세스");
    expect(tooltip).toHaveTextContent("운영체제가 자원을 관리하는 실행 단위");
    expect(document.querySelector('[aria-hidden="true"].fixed.inset-0')).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "툴팁 닫기" }));

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("renders incorrect-only explanation and hides points", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct={false} quizId={7} />);

    expect(await screen.findByText("오답")).toBeInTheDocument();
    expect(screen.getByText("왜 틀렸는지")).toBeInTheDocument();
    expect(screen.queryByText("+10P")).not.toBeInTheDocument();
  });

  it("renders the optional explanation example when present", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={7} />);

    expect(await screen.findByText("적용 예시")).toBeInTheDocument();
    expect(screen.getByText(/브라우저 탭은/)).toBeInTheDocument();
  });

  it("shows fanfare from the third consecutive correct answer and hides it on completion", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={7} correctStreak={3} />);

    expect(await screen.findByTestId("lottie-fanfare")).toHaveAttribute(
      "data-src",
      "/lottie/fanfare.lottie",
    );
    await waitFor(() => {
      expect(lottieCompleteListeners.size).toBeGreaterThan(0);
    });

    act(() => {
      for (const listener of lottieCompleteListeners) {
        listener();
      }
    });

    await waitFor(() => {
      expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
    });
  });

  it("shows fanfare in review mode when the review streak reaches three and keeps review completion CTA", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue({
      ...explanation,
      currentNumber: 5,
      totalCount: 5,
    });

    render(
      <InsightPage
        correct
        quizId={7}
        review={{ step: 2, slot: 5, correct: 3, streak: 3, topic: "문맥 전환" }}
      />,
    );

    expect(await screen.findByTestId("lottie-fanfare")).toHaveAttribute(
      "data-src",
      "/lottie/fanfare.lottie",
    );
    expect(screen.getByRole("link", { name: "복습 완료" })).toHaveAttribute(
      "href",
      "/history/done?step=2&slot=5&rc=3&rs=3&topic=%EB%AC%B8%EB%A7%A5+%EC%A0%84%ED%99%98",
    );
  });

  it("does not show fanfare in review mode below the review streak threshold", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        correct
        quizId={7}
        review={{ step: 2, slot: 2, correct: 2, streak: 2, topic: "문맥 전환" }}
      />,
    );

    expect(await screen.findByText("운영체제")).toBeInTheDocument();
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("redirects to login when the explanation API reports an unauthorized session", async () => {
    vi.mocked(getQuizExplanation).mockRejectedValue({ status: 401 });

    render(<InsightPage correct quizId={7} />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/login");
    });
  });

  it("does not show fanfare while the explanation API is in an error state", async () => {
    vi.mocked(getQuizExplanation).mockRejectedValue(new Error("network"));

    render(<InsightPage correct quizId={7} correctStreak={3} />);

    expect(await screen.findByText("해설을 불러오지 못했어요.")).toBeInTheDocument();
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });
});

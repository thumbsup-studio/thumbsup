import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { StrictMode } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { InsightPage } from "@/features/play/components/insight-page";
import { getQuizExplanation } from "@/lib/api/quiz";
import { setPrefersReducedMotion } from "@/test/setup";

const mockRouter = vi.hoisted(() => ({
  replace: vi.fn(),
}));

const lottieCompleteListenersBySrc = vi.hoisted(() => new Map<string, Set<() => void>>());

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
      src,
    }: {
      dotLottieRefCallback?: (
        player: {
          addEventListener: (eventName: string, listener: () => void) => void;
          removeEventListener: (eventName: string, listener: () => void) => void;
        } | null,
      ) => void;
      src: string;
    }) => {
      React.useEffect(() => {
        const player = {
          addEventListener: (eventName: string, listener: () => void) => {
            if (eventName === "complete") {
              const listeners = lottieCompleteListenersBySrc.get(src) ?? new Set<() => void>();
              listeners.add(listener);
              lottieCompleteListenersBySrc.set(src, listeners);
            }
          },
          removeEventListener: (eventName: string, listener: () => void) => {
            if (eventName === "complete") {
              lottieCompleteListenersBySrc.get(src)?.delete(listener);
            }
          },
        };

        dotLottieRefCallback?.(player);

        return undefined;
      }, [dotLottieRefCallback, src]);

      return <canvas data-src={src} data-testid="dotlottie-canvas" />;
    },
  };
});

function getLottieListeners(src: string) {
  return lottieCompleteListenersBySrc.get(src) ?? new Set<() => void>();
}

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
    lottieCompleteListenersBySrc.clear();
    window.sessionStorage.clear();
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

  it("코스 탭에서 진입한 세션이면 다음 문제·뒤로가기 링크가 같은 코스로 이어진다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct correctStreak={0} courseId={2} quizId={7} />);

    expect(await screen.findByRole("link", { name: "다음 문제 풀기" })).toHaveAttribute(
      "href",
      "/play?courseId=2",
    );
    expect(screen.getByRole("link", { name: "문제로 돌아가기" })).toHaveAttribute(
      "href",
      "/play?courseId=2",
    );
    expect(screen.getByRole("link", { name: "꼬리 질문 풀기" })).toHaveAttribute(
      "href",
      "/follow-up?quizId=7&correct=true&streak=0&fq=10&courseId=2",
    );
  });

  it("코스 탭에서 진입한 마지막 문제면 코스 목록으로 돌아간다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue({
      ...explanation,
      currentNumber: 5,
      totalCount: 5,
    });

    render(<InsightPage correct correctStreak={0} courseId={2} quizId={7} />);

    expect(await screen.findByRole("link", { name: "코스 목록으로 가기" })).toHaveAttribute(
      "href",
      "/course",
    );
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

  it("완주 요약을 받으면 정답 수와 최고 콤보를 그린다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage completion={{ answered: 5, bestCombo: 3, correct: 4 }} correct quizId={1} />,
    );

    const cardTitle = await screen.findByText("오늘의 학습 완료");
    const card = cardTitle.closest(".rounded-control");
    expect(card).not.toBeNull();
    if (!(card instanceof HTMLElement)) {
      return;
    }

    expect(within(card).getByText("정답")).toBeInTheDocument();
    expect(within(card).getByText("최고 콤보")).toBeInTheDocument();
  });

  it("조작된 완주 URL 값은 문제 수 상한으로 자른다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        completion={{ answered: 999, bestCombo: 999, correct: 999 }}
        correct
        quizId={1}
      />,
    );

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByText("999")).not.toBeInTheDocument();
  });

  it("마이그레이션된 세션(answered 불일치)은 정답·정확도 값을 비운다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage completion={{ answered: 0, bestCombo: 2, correct: 0 }} correct quizId={1} />,
    );

    const cardTitle = await screen.findByText("오늘의 학습 완료");
    const card = cardTitle.closest(".rounded-control");
    expect(card).not.toBeNull();
    if (!(card instanceof HTMLElement)) {
      return;
    }

    // 칸은 남기되 복원할 수 없는 값은 0 대신 —로 둔다 — 틀린 숫자를 보여주지 않는다.
    expect(within(card).getByText("정답")).toBeInTheDocument();
    expect(within(card).getAllByText("—")).toHaveLength(2);
    expect(within(card).getByText("최고 콤보")).toBeInTheDocument();
  });

  it("완주가 아니면 카드를 그리지 않는다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={1} />);

    await screen.findByText(/정답이에요/);
    expect(screen.queryByText("오늘의 학습 완료")).not.toBeInTheDocument();
  });

  // StrictMode(개발)는 이펙트를 두 번 돌린다. 첫 실행이 sessionStorage에 "재생함"을
  // 기록하므로, 두 번째 실행이 그대로 판정하면 방금 띄운 팡파레를 스스로 꺼버린다.
  it("StrictMode로 이펙트가 두 번 실행돼도 퍼펙트 팡파레가 살아 있다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <StrictMode>
        <InsightPage completion={{ answered: 5, bestCombo: 5, correct: 5 }} correct quizId={1} />
      </StrictMode>,
    );

    expect(await screen.findByTestId("lottie-fanfare")).toBeInTheDocument();
  });

  it("완주 퍼펙트면 팡파레를 두 겹으로 띄우고 재생이 끝나면 감춘다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage completion={{ answered: 5, bestCombo: 5, correct: 5 }} correct quizId={1} />,
    );

    expect(await screen.findByTestId("lottie-fanfare")).toHaveAttribute(
      "data-sources",
      "/lottie/fanfare.lottie,/lottie/fanfare-vertical.lottie",
    );

    await waitFor(() => {
      expect(getLottieListeners("/lottie/fanfare-vertical.lottie").size).toBeGreaterThan(0);
    });

    act(() => {
      for (const listener of getLottieListeners("/lottie/fanfare-vertical.lottie")) {
        listener();
      }
    });

    await waitFor(() => {
      expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
    });
  });

  it("하나라도 틀린 완주에는 팡파레가 없다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage completion={{ answered: 5, bestCombo: 3, correct: 4 }} correct quizId={1} />,
    );

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  // 복습 팡파레는 /history/done의 퍼펙트로 옮겼다(이슈 211). 여기선 더 이상 뜨지 않는다.
  it("복습 연속 정답만으로는 해설 화면에 팡파레가 뜨지 않고, 복습 완료 CTA는 그대로다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue({
      ...explanation,
      currentNumber: 5,
      totalCount: 5,
    });

    render(
      <InsightPage
        correct
        quizId={7}
        review={{ step: 2, slot: 5, correct: 3, streak: 3, topic: "문맥 전환", single: false }}
      />,
    );

    expect(await screen.findByRole("link", { name: "복습 완료" })).toHaveAttribute(
      "href",
      "/history/done?step=2&slot=5&rc=3&rs=3&topic=%EB%AC%B8%EB%A7%A5+%EC%A0%84%ED%99%98",
    );
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("모션 줄이기를 켠 사용자는 퍼펙트 팡파레도 보지 않는다", async () => {
    setPrefersReducedMotion(true);
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage completion={{ answered: 5, bestCombo: 5, correct: 5 }} correct quizId={1} />,
    );

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("연속 정답만으로는 더 이상 팡파레가 뜨지 않는다 — 퀴즈 화면에서 이미 축하했다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct correctStreak={5} quizId={1} />);

    await screen.findByText(/정답이에요/);
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("같은 완주 화면에 다시 들어오면 팡파레를 반복하지 않는다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);
    const summary = { answered: 5, bestCombo: 5, correct: 5 };

    const first = render(<InsightPage completion={summary} correct quizId={1} />);
    await screen.findByTestId("lottie-fanfare");
    first.unmount();

    render(<InsightPage completion={summary} correct quizId={1} />);

    await screen.findByText("오늘의 학습 완료");
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

import { act, fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { InsightPage } from "@/features/play/components/insight-page";
import { mockPlaySession } from "@/features/play/mock-play-session";

const lottieCompleteListeners = vi.hoisted(() => new Set<() => void>());

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

describe("InsightPage", () => {
  it("renders the current question explanation and links back to the next play question", () => {
    render(<InsightPage correct questionIndex={0} session={mockPlaySession} />);

    expect(screen.getByText("정답")).toBeInTheDocument();
    expect(screen.getByText("+10P")).toBeInTheDocument();
    expect(screen.getByText("문제 해설")).toBeInTheDocument();
    expect(screen.getByText("핵심 3줄")).toBeInTheDocument();
    expect(screen.getByText("OS process model")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "다음 문제 풀기" })).toHaveAttribute(
      "href",
      "/play?question=1",
    );
  });

  it("renders the summary as exactly three numbered items", () => {
    render(<InsightPage correct questionIndex={0} session={mockPlaySession} />);

    const summary = screen.getByRole("list", { name: "핵심 3줄" });

    expect(within(summary).getAllByRole("listitem")).toHaveLength(3);
    expect(within(summary).getByText("1")).toBeInTheDocument();
    expect(within(summary).getByText("2")).toBeInTheDocument();
    expect(within(summary).getByText("3")).toBeInTheDocument();
  });

  it("shows inline keyword tooltip content one keyword at a time", () => {
    render(<InsightPage correct questionIndex={0} session={mockPlaySession} />);

    fireEvent.click(screen.getAllByRole("button", { name: "프로세스 설명 보기" })[0]);

    expect(screen.getByRole("tooltip")).toHaveTextContent(
      "운영체제가 자원을 독립적으로 관리하는 실행 단위",
    );

    fireEvent.click(screen.getAllByRole("button", { name: "스레드 설명 보기" })[0]);

    expect(screen.getByRole("tooltip")).toHaveTextContent("프로세스 안에서 나뉘는 실행 흐름");
  });

  it("closes inline keyword tooltip with Escape", () => {
    render(<InsightPage correct questionIndex={0} session={mockPlaySession} />);

    fireEvent.click(screen.getAllByRole("button", { name: "프로세스 설명 보기" })[0]);
    expect(screen.getByRole("tooltip")).toBeInTheDocument();

    fireEvent.keyDown(document, { key: "Escape" });

    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("renders code application and real-world usage sections", () => {
    render(<InsightPage correct questionIndex={2} session={mockPlaySession} />);

    expect(screen.getByText("코드 적용 예시")).toBeInTheDocument();
    expect(screen.getByText("실무 사용처")).toBeInTheDocument();
    expect(screen.getByText("ts")).toBeInTheDocument();
    expect(screen.getByText("코드 적용 예시").closest("div")).toHaveTextContent("락이나 원자 연산");
  });

  it("renders incorrect-only explanation without points", () => {
    render(<InsightPage correct={false} questionIndex={1} session={mockPlaySession} />);

    expect(screen.getByText("오답")).toBeInTheDocument();
    expect(screen.getByText("왜 틀렸는지")).toBeInTheDocument();
    expect(screen.queryByText("+10P")).not.toBeInTheDocument();
  });

  it("shows fanfare only from the third consecutive correct answer and hides it on completion", () => {
    const { rerender } = render(
      <InsightPage correct correctStreak={2} questionIndex={2} session={mockPlaySession} />,
    );

    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();

    rerender(<InsightPage correct correctStreak={3} questionIndex={2} session={mockPlaySession} />);

    expect(screen.getByTestId("lottie-fanfare")).toHaveAttribute(
      "data-src",
      "/lottie/fanfare.lottie",
    );
    expect(screen.getByTestId("lottie-fanfare")).toHaveClass("fixed", "inset-0");

    act(() => {
      for (const listener of lottieCompleteListeners) {
        listener();
      }
    });

    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("links the last question insight back home", () => {
    render(<InsightPage correct={false} questionIndex={4} session={mockPlaySession} />);

    expect(screen.getByText("오답")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "홈으로 돌아가기" })).toHaveAttribute("href", "/");
  });
});

import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AttemptHistoryPage } from "@/features/history/components/attempt-history-page";
import { ApiError, getAttemptHistory } from "@/lib/api";

const mockRouter = vi.hoisted(() => ({
  push: vi.fn(),
  replace: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

vi.mock("@/lib/api", async () => {
  const actual = await vi.importActual<typeof import("@/lib/api")>("@/lib/api");
  return { ...actual, getAttemptHistory: vi.fn() };
});

describe("AttemptHistoryPage", () => {
  beforeEach(() => {
    vi.mocked(getAttemptHistory).mockReset();
    mockRouter.push.mockReset();
    mockRouter.replace.mockReset();
  });

  it("풀이 기록을 문제·답·정오·유형과 함께 보여준다", async () => {
    vi.mocked(getAttemptHistory).mockResolvedValue({
      data: {
        items: [
          {
            attemptId: 2,
            quizId: 20,
            type: "MULTIPLE_CHOICE",
            questionText: "다음 코드의 시간복잡도는?",
            selectedAnswer: "O(n)",
            isCorrect: false,
            submittedAt: "2026-08-03T09:00:00+09:00",
          },
          {
            attemptId: 1,
            quizId: 10,
            type: "OX",
            questionText: "TCP는 연결 지향 프로토콜이다.",
            selectedAnswer: "O",
            isCorrect: true,
            submittedAt: "2026-08-03T08:00:00+09:00",
          },
        ],
      },
      meta: { hasNext: false, nextCursor: null },
    });

    render(<AttemptHistoryPage />);

    expect(await screen.findByText("다음 코드의 시간복잡도는?")).toBeInTheDocument();
    expect(screen.getByText("O(n)")).toBeInTheDocument();
    expect(screen.getByText("✕ 오답")).toBeInTheDocument();
    expect(screen.getByText("TCP는 연결 지향 프로토콜이다.")).toBeInTheDocument();
    expect(screen.getByText("✓ 정답")).toBeInTheDocument();
    expect(screen.getByText("사지선다")).toBeInTheDocument();
    expect(screen.getByText("OX")).toBeInTheDocument();
    expect(screen.getByText("지금까지 2문제 풀었어요")).toBeInTheDocument();
  });

  it("아직 푼 문제가 없으면 빈 상태를 보여준다", async () => {
    vi.mocked(getAttemptHistory).mockResolvedValue({
      data: { items: [] },
      meta: { hasNext: false, nextCursor: null },
    });

    render(<AttemptHistoryPage />);

    // sr-only 라이브 리전이 같은 문구를 한 번 더 담고 있어(접근성 목적) getAllByText로 확인한다.
    expect(await screen.findAllByText("아직 푼 문제가 없어요")).not.toHaveLength(0);
  });

  it("다음 페이지가 있으면 더 불러오는 중 표시를 보여준다", async () => {
    vi.mocked(getAttemptHistory).mockResolvedValue({
      data: {
        items: [
          {
            attemptId: 1,
            quizId: 10,
            type: "OX",
            questionText: "TCP는 연결 지향 프로토콜이다.",
            selectedAnswer: "O",
            isCorrect: true,
            submittedAt: "2026-08-03T08:00:00+09:00",
          },
        ],
      },
      meta: { hasNext: true, nextCursor: "cursor-1" },
    });

    render(<AttemptHistoryPage />);

    expect(await screen.findByText("더 불러오는 중")).toBeInTheDocument();
  });

  it("불러오기 실패 시 에러와 재시도 버튼을 보여주고 재시도하면 다시 불러온다", async () => {
    vi.mocked(getAttemptHistory).mockRejectedValueOnce(new Error("network"));

    render(<AttemptHistoryPage />);

    expect(await screen.findByRole("status")).toHaveTextContent("풀이 기록을 불러오지 못했어요.");

    vi.mocked(getAttemptHistory).mockResolvedValueOnce({
      data: { items: [] },
      meta: { hasNext: false, nextCursor: null },
    });
    fireEvent.click(screen.getByRole("button", { name: "재시도" }));

    expect(await screen.findAllByText("아직 푼 문제가 없어요")).not.toHaveLength(0);
  });

  it("인증이 만료됐으면 로그인 화면으로 보낸다", async () => {
    vi.mocked(getAttemptHistory).mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "세션이 만료됐어요." }),
    );

    render(<AttemptHistoryPage />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/login");
    });
  });
});

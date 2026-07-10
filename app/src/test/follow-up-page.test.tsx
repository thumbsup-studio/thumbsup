import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { FollowUpPage } from "@/features/play/components/follow-up-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import type { FollowUpQuestionDetail } from "@/features/play/types";
import { ApiError } from "@/lib/api";

const mockRouter = vi.hoisted(() => ({ replace: vi.fn() }));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

const { fetchFollowUpQuestion } = vi.hoisted(() => ({ fetchFollowUpQuestion: vi.fn() }));

vi.mock("@/features/play/api", () => ({ fetchFollowUpQuestion }));

const detail: FollowUpQuestionDetail = {
  followUpQuestionId: 1,
  sourceQuizId: 100,
  sourceQuizNumber: 1,
  difficulty: "MEDIUM",
  question: "프로세스끼리 어떻게 데이터를 주고받을까?",
  oneLineAnswer: {
    text: "운영체제가 중개하는 IPC로 주고받습니다.",
    highlights: [{ keyword: "IPC", start: 11, end: 14 }],
  },
  blocks: [
    {
      label: "해설",
      type: "TEXT",
      content: { text: "주소 공간이 분리돼 IPC로 통신합니다.", highlights: [] },
    },
    {
      label: "실무 사용처",
      type: "TEXT",
      content: { text: "브라우저 탭은 IPC로 협력합니다.", highlights: [] },
    },
  ],
  keywords: [{ keyword: "IPC", description: "프로세스 간 통신 방식." }],
};

function renderFollowUp() {
  return render(
    <FollowUpPage
      correct
      correctStreak={2}
      followUpQuestionId={1}
      questionIndex={0}
      quizId={100}
      session={mockPlaySession}
    />,
  );
}

describe("FollowUpPage", () => {
  beforeEach(() => {
    fetchFollowUpQuestion.mockReset();
    mockRouter.replace.mockReset();
  });

  it("masks the one-line answer until revealed, then reveals text and block labels", async () => {
    fetchFollowUpQuestion.mockResolvedValue(detail);
    renderFollowUp();

    expect(await screen.findByText("먼저 스스로 답을 떠올려 보세요.")).toBeInTheDocument();
    expect(screen.queryByText("운영체제가 중개하는", { exact: false })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "답 확인하기" }));

    expect(screen.queryByText("먼저 스스로 답을 떠올려 보세요.")).not.toBeInTheDocument();
    expect(screen.getByText("운영체제가 중개하는", { exact: false })).toBeInTheDocument();
    expect(screen.getByText("해설")).toBeInTheDocument();
    expect(screen.getByText("실무 사용처")).toBeInTheDocument();
  });

  it("threads quizId back to the insight route so 해설로 돌아가기 restores the explanation", async () => {
    fetchFollowUpQuestion.mockResolvedValue(detail);
    renderFollowUp();

    const backLink = await screen.findByRole("link", { name: "해설로 돌아가기" });
    expect(backLink).toHaveAttribute("href", "/insight?quizId=100&correct=true&streak=2");
  });

  it("shows a 준비 중 notice when the follow-up detail is not ready yet", async () => {
    fetchFollowUpQuestion.mockRejectedValue(
      new ApiError({ code: "FOLLOW_UP_DETAIL_NOT_FOUND", status: 404, message: "준비 중" }),
    );
    renderFollowUp();

    expect(await screen.findByText("꼬리 질문을 준비 중이에요")).toBeInTheDocument();
  });

  it("redirects to login on 401", async () => {
    fetchFollowUpQuestion.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );
    renderFollowUp();

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/login");
    });
  });

  it("shows an error state with retry when the fetch fails generically", async () => {
    fetchFollowUpQuestion.mockRejectedValueOnce(new Error("network"));
    renderFollowUp();

    expect(await screen.findByText("꼬리 질문을 불러오지 못했어요")).toBeInTheDocument();

    fetchFollowUpQuestion.mockResolvedValueOnce(detail);
    fireEvent.click(screen.getByRole("button", { name: "다시 시도" }));

    expect(await screen.findByText(detail.question)).toBeInTheDocument();
  });
});

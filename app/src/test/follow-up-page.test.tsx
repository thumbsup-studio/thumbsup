import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { FollowUpPage } from "@/features/play/components/follow-up-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import type { FollowUpQuestion } from "@/features/play/types";

const followUp: FollowUpQuestion = {
  category: "프로세스",
  difficulty: "medium",
  question: "프로세스끼리 어떻게 데이터를 주고받을까?",
  oneLineAnswer: "운영체제가 중개하는 IPC로 주고받습니다.",
  explanation: "주소 공간이 분리돼 IPC로 통신합니다.",
  usageExample: "브라우저 탭은 IPC로 협력합니다.",
  keywords: [{ term: "IPC", description: "프로세스 간 통신 방식." }],
};

function renderFollowUp() {
  return render(
    <FollowUpPage
      correct
      correctStreak={2}
      followUp={followUp}
      questionIndex={0}
      session={mockPlaySession}
    />,
  );
}

describe("FollowUpPage", () => {
  it("masks the one-line answer until revealed", () => {
    renderFollowUp();

    expect(screen.getByText("먼저 스스로 답을 떠올려 보세요.")).toBeInTheDocument();
    expect(screen.queryByText("운영체제가 중개하는", { exact: false })).not.toBeInTheDocument();
  });

  it("reveals the answer when 답 확인하기 is pressed", () => {
    renderFollowUp();

    fireEvent.click(screen.getByRole("button", { name: "답 확인하기" }));

    expect(screen.queryByText("먼저 스스로 답을 떠올려 보세요.")).not.toBeInTheDocument();
    expect(screen.getByText("운영체제가 중개하는", { exact: false })).toBeInTheDocument();
  });

  it("links skip and back to the right destinations before reveal", () => {
    renderFollowUp();

    expect(screen.getByRole("link", { name: "이 질문 건너뛰기" })).toHaveAttribute(
      "href",
      "/play?question=1",
    );
    expect(screen.getByRole("link", { name: "해설로 돌아가기" })).toHaveAttribute(
      "href",
      "/insight?question=0&correct=true&streak=2",
    );
  });

  it("links 다음 문제로 to the next question after reveal", () => {
    renderFollowUp();

    fireEvent.click(screen.getByRole("button", { name: "답 확인하기" }));

    expect(screen.getByRole("link", { name: "다음 문제로" })).toHaveAttribute(
      "href",
      "/play?question=1",
    );
  });
});

import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { QuizzesScreen } from "@/features/authoring/components/quizzes-screen";
import type { AuthoringStep } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getAuthoringQuizzesMock, improveQuizMock, mockRouter } = vi.hoisted(() => ({
  getAuthoringQuizzesMock: vi.fn(),
  improveQuizMock: vi.fn(),
  // useRouter()가 매 렌더 새 객체를 반환하면 무한 재조회 루프가 생긴다(T4 사고 재발 방지) — 안정된 참조를 반환.
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  getAuthoringQuizzes: getAuthoringQuizzesMock,
  improveQuiz: improveQuizMock,
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

function renderScreen() {
  render(
    <AppToastProvider>
      <QuizzesScreen />
    </AppToastProvider>,
  );
}

const STEPS: AuthoringStep[] = [
  {
    stepOrder: 1,
    topic: "운영체제",
    quizzes: [
      {
        quizId: 101,
        slotOrder: 1,
        type: "OX",
        difficulty: "EASY",
        questionText: "프로세스는 독립된 자원을 갖는다.",
      },
      {
        quizId: 102,
        slotOrder: 2,
        type: "MULTIPLE_CHOICE",
        difficulty: "MEDIUM",
        questionText: "다음 중 옳은 것은?",
      },
    ],
  },
];

beforeEach(() => {
  getAuthoringQuizzesMock.mockReset();
  improveQuizMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
});

describe("QuizzesScreen", () => {
  it("스텝 헤더 아래 슬롯 순으로 문제 행을 렌더한다", async () => {
    getAuthoringQuizzesMock.mockResolvedValue(STEPS);

    renderScreen();

    expect(await screen.findByText(/STEP 1/)).toBeInTheDocument();
    expect(screen.getByText(/운영체제/)).toBeInTheDocument();
    expect(screen.getByText("프로세스는 독립된 자원을 갖는다.")).toBeInTheDocument();
    expect(screen.getByText("다음 중 옳은 것은?")).toBeInTheDocument();
  });

  it("개선 → 시트(지시 필수) → 제출 시 improveQuiz를 호출하고 잡 화면으로 이동한다", async () => {
    getAuthoringQuizzesMock.mockResolvedValue(STEPS);
    improveQuizMock.mockResolvedValue({ draftId: 3, jobId: 8 });

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    const improveButtons = screen.getAllByRole("button", { name: "개선" });
    fireEvent.click(improveButtons[0]);

    const submit = screen.getByRole("button", { name: "개선 요청" });
    expect(submit).toBeDisabled();

    fireEvent.change(screen.getByLabelText("개선 지시"), { target: { value: "   " } });
    expect(submit).toBeDisabled();

    fireEvent.change(screen.getByLabelText("개선 지시"), { target: { value: "설명을 더 쉽게" } });
    expect(submit).not.toBeDisabled();
    fireEvent.click(submit);

    await waitFor(() => expect(improveQuizMock).toHaveBeenCalledWith(101, "설명을 더 쉽게"));
    await waitFor(() => expect(mockRouter.push).toHaveBeenCalledWith("/authoring/jobs/8"));
  });

  it("409(AUTHORING_IMPROVE_DRAFT_EXISTS) 시 이미 열린 개선 draft 안내 토스트를 띄운다", async () => {
    getAuthoringQuizzesMock.mockResolvedValue(STEPS);
    improveQuizMock.mockRejectedValue(
      new ApiError({ code: "AUTHORING_IMPROVE_DRAFT_EXISTS", status: 409, message: "conflict" }),
    );

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getAllByRole("button", { name: "개선" })[0]);
    fireEvent.change(screen.getByLabelText("개선 지시"), { target: { value: "설명을 더 쉽게" } });
    fireEvent.click(screen.getByRole("button", { name: "개선 요청" }));

    expect(await screen.findByText(/이미 열린 개선 draft/)).toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인 화면으로 이동한다", async () => {
    getAuthoringQuizzesMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });

  it("권한 없음(403)이면 홈으로 이동한다", async () => {
    getAuthoringQuizzesMock.mockRejectedValue(
      new ApiError({ code: "FORBIDDEN", status: 403, message: "forbidden" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/"));
  });
});

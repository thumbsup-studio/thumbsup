import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { DraftDetailScreen } from "@/features/authoring/components/draft-detail-screen";
import type { DraftDetail } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getDraftMock, reviewDraftMock, approveDraftMock, mockRouter } = vi.hoisted(() => ({
  getDraftMock: vi.fn(),
  reviewDraftMock: vi.fn(),
  approveDraftMock: vi.fn(),
  // useRouter()가 매 렌더 새 객체를 반환하면 router를 deps로 둔 useCallback이 매 렌더 재생성돼
  // useEffect가 무한 재실행된다(T4 사고 재발 방지 — 안정된 단일 참조를 반환한다).
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  getDraft: getDraftMock,
  reviewDraft: reviewDraftMock,
  approveDraft: approveDraftMock,
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

function renderScreen() {
  render(
    <AppToastProvider>
      <DraftDetailScreen draftId={5} />
    </AppToastProvider>,
  );
}

const BASE_DRAFT: DraftDetail = {
  draftId: 5,
  origin: "NEW",
  status: "DRAFT",
  topic: "운영체제",
  sourceQuizId: null,
  revisionCount: 2,
  updatedAt: "2026-07-14T00:00:00Z",
  payload: {
    quizzes: [
      {
        type: "OX",
        difficulty: "EASY",
        questionText: "프로세스는 독립된 자원을 갖는다.",
        codeSnippet: null,
        explanationSummary: "프로세스는 자원을 독립적으로 관리한다.",
        explanationExample: null,
        wrongAnswerExplanation: "스레드와 혼동하지 말 것.",
        correctAnswer: "O",
        choices: null,
        answerKeywords: null,
        followUpQuestions: null,
        derivedConcepts: null,
        keywords: null,
      },
      {
        type: "MULTIPLE_CHOICE",
        difficulty: "MEDIUM",
        questionText: "다음 중 옳은 것은?",
        codeSnippet: null,
        explanationSummary: "정답은 B다.",
        explanationExample: null,
        wrongAnswerExplanation: "A는 오답이다.",
        correctAnswer: null,
        choices: [
          { content: "A 선지", isCorrect: false },
          { content: "B 선지", isCorrect: true },
        ],
        answerKeywords: null,
        followUpQuestions: null,
        derivedConcepts: null,
        keywords: null,
      },
    ],
  },
  revisions: [
    {
      revisionNo: 1,
      reviewSummary: "선지 순서 수정",
      reviewedBy: 2,
      jobId: 10,
      createdAt: "2026-07-14T01:00:00Z",
    },
    {
      revisionNo: 2,
      reviewSummary: "설명 보강",
      reviewedBy: 3,
      jobId: 11,
      createdAt: "2026-07-14T02:00:00Z",
    },
  ],
  createdBy: 1,
  approvedBy: null,
  approvedAt: null,
};

beforeEach(() => {
  getDraftMock.mockReset();
  reviewDraftMock.mockReset();
  approveDraftMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
});

describe("DraftDetailScreen", () => {
  it("payload.quizzes를 슬롯 순서대로 렌더한다(칩·질문·MC 정답 표시·해설 요약)", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);

    renderScreen();

    expect(await screen.findByText("프로세스는 독립된 자원을 갖는다.")).toBeInTheDocument();
    expect(screen.getByText("다음 중 옳은 것은?")).toBeInTheDocument();
    expect(screen.getByText(/B 선지/)).toBeInTheDocument();
    expect(screen.getByText(/정답은 B다\./)).toBeInTheDocument();
    // 오답 선지엔 정답 표시가 없어야 한다
    expect(screen.getByText("A 선지")).toBeInTheDocument();
  });

  it("revisions 이력을 revisionNo 내림차순으로 렌더한다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);

    renderScreen();

    await screen.findByText("설명 보강");
    const bodyText = document.body.textContent ?? "";
    expect(bodyText.indexOf("설명 보강")).toBeLessThan(bodyText.indexOf("선지 순서 수정"));
  });

  it("검수 시작 → 시트 → 제출 시 reviewDraft를 호출하고 잡 화면으로 이동한다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);
    reviewDraftMock.mockResolvedValue({ jobId: 9 });

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getByRole("button", { name: "검수 시작" }));
    fireEvent.change(screen.getByLabelText("피드백"), { target: { value: "선지 순서 바꿔줘" } });
    fireEvent.click(screen.getByRole("button", { name: "검수 요청" }));

    await waitFor(() => expect(reviewDraftMock).toHaveBeenCalledWith(5, "선지 순서 바꿔줘"));
    await waitFor(() => expect(mockRouter.push).toHaveBeenCalledWith("/authoring/jobs/9"));
  });

  it("승인 → 확인 시트('승인 즉시 라이브 반영' 경고) → approveDraft → 성공 토스트 + 재조회", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);
    approveDraftMock.mockResolvedValue({ draftId: 5, status: "APPROVED" });

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getByRole("button", { name: "승인" }));
    expect(await screen.findByText(/승인 즉시 라이브 반영/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "승인하기" }));

    await waitFor(() => expect(approveDraftMock).toHaveBeenCalledWith(5));
    expect(await screen.findByText(/승인했어요/)).toBeInTheDocument();
    await waitFor(() => expect(getDraftMock).toHaveBeenCalledTimes(2));
  });

  it("status=APPROVED면 검수·승인 버튼을 렌더하지 않는다", async () => {
    getDraftMock.mockResolvedValue({ ...BASE_DRAFT, status: "APPROVED" });

    renderScreen();

    await screen.findByText("프로세스는 독립된 자원을 갖는다.");
    expect(screen.queryByRole("button", { name: "검수 시작" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "승인" })).not.toBeInTheDocument();
  });

  it("409(AUTHORING_DRAFT_JOB_ACTIVE) 시 진행 중인 잡 안내 토스트를 띄운다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);
    reviewDraftMock.mockRejectedValue(
      new ApiError({ code: "AUTHORING_DRAFT_JOB_ACTIVE", status: 409, message: "conflict" }),
    );

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getByRole("button", { name: "검수 시작" }));
    fireEvent.click(screen.getByRole("button", { name: "검수 요청" }));

    expect(await screen.findByText(/진행 중인 잡이 있습니다/)).toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인 화면으로 이동한다", async () => {
    getDraftMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });

  it("권한 없음(403)이면 홈으로 이동한다", async () => {
    getDraftMock.mockRejectedValue(
      new ApiError({ code: "FORBIDDEN", status: 403, message: "forbidden" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/"));
  });
});

import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { DraftsScreen } from "@/features/authoring/components/drafts-screen";
import { ApiError } from "@/lib/api";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getDraftsMock, generateDraftMock, mockRouter } = vi.hoisted(() => ({
  getDraftsMock: vi.fn(),
  generateDraftMock: vi.fn(),
  // useRouter()가 매 렌더 새 객체를 반환하면 router를 deps에 둔 useCallback이 매 렌더 재생성돼
  // useEffect가 무한 재실행된다(follow-up-page.test.tsx 등과 동일하게 안정된 참조를 반환).
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  getDrafts: getDraftsMock,
  generateDraft: generateDraftMock,
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

function renderScreen() {
  render(
    <AppToastProvider>
      <DraftsScreen />
    </AppToastProvider>,
  );
}

const DRAFTS = [
  {
    draftId: 1,
    origin: "NEW" as const,
    status: "DRAFT" as const,
    topic: "운영체제",
    sourceQuizId: null,
    revisionCount: 2,
    updatedAt: "2026-07-14T00:00:00Z",
  },
];

beforeEach(() => {
  getDraftsMock.mockReset();
  generateDraftMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
});

describe("DraftsScreen", () => {
  it("로딩 후 draft 카드 목록을 렌더한다(topic·origin·status·revisionCount 표시)", async () => {
    getDraftsMock.mockResolvedValue(DRAFTS);

    renderScreen();

    expect(await screen.findByText("운영체제")).toBeInTheDocument();
    const card = within(screen.getByRole("listitem"));
    expect(card.getByText("신규")).toBeInTheDocument();
    expect(card.getByText("검토중")).toBeInTheDocument();
    expect(card.getByText("검수 2회")).toBeInTheDocument();
    expect(getDraftsMock).toHaveBeenCalledWith("DRAFT");
  });

  it("빈 목록이면 EmptyState를 렌더한다", async () => {
    getDraftsMock.mockResolvedValue([]);

    renderScreen();

    expect(await screen.findByText(/draft가 없어요/)).toBeInTheDocument();
  });

  it("문제 생성 시트에서 제출하면 generateDraft를 호출하고 잡 화면으로 이동한다", async () => {
    getDraftsMock.mockResolvedValue([]);
    generateDraftMock.mockResolvedValue({ jobId: 7 });

    renderScreen();
    await screen.findByText(/draft가 없어요/);

    fireEvent.click(screen.getByRole("button", { name: "문제 생성" }));
    fireEvent.change(screen.getByLabelText("주제"), { target: { value: "운영체제" } });
    fireEvent.click(screen.getByRole("button", { name: "생성 시작" }));

    await waitFor(() => expect(generateDraftMock).toHaveBeenCalledWith("운영체제"));
    await waitFor(() => expect(mockRouter.push).toHaveBeenCalledWith("/authoring/jobs/7"));
  });

  it("API 에러 시 에러 상태와 재시도 버튼을 렌더한다", async () => {
    getDraftsMock.mockRejectedValue(new Error("network"));

    renderScreen();

    expect(await screen.findByText(/불러오지 못했어요/)).toBeInTheDocument();
    const retry = screen.getByRole("button", { name: "다시 시도" });

    getDraftsMock.mockResolvedValue(DRAFTS);
    fireEvent.click(retry);

    expect(await screen.findByText("운영체제")).toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인 화면으로 이동한다", async () => {
    getDraftsMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });
});

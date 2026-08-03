import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { OutlineDetailScreen } from "@/features/authoring/components/outline-detail-screen";
import type { OutlineDetail } from "@/features/authoring/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getOutlineMock, mockRouter } = vi.hoisted(() => ({
  getOutlineMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  addOutlineStep: vi.fn(),
  deleteOutlineStep: vi.fn(),
  generateStepQuizzes: vi.fn(),
  getOutline: getOutlineMock,
  publishOutline: vi.fn(),
  regenerateOutline: vi.fn(),
  reorderOutlineStep: vi.fn(),
  updateOutline: vi.fn(),
  updateOutlineStep: vi.fn(),
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

const DETAIL: OutlineDetail = {
  outlineId: 1,
  title: "네트워크 기초",
  category: "CS",
  status: "DRAFT" as const,
  toc: "목차",
  steps: [
    {
      stepId: 11,
      orderNo: 1,
      topic: "네트워크 구조",
      learningGoal: "구조를 설명할 수 있어요.",
      fillState: "EMPTY" as const,
      draftId: null,
      activeJobId: null,
    },
    {
      stepId: 12,
      orderNo: 2,
      topic: "OSI 모델",
      learningGoal: null,
      fillState: "GENERATING" as const,
      draftId: null,
      activeJobId: 21,
    },
    {
      stepId: 13,
      orderNo: 3,
      topic: "TCP/IP 모델",
      learningGoal: null,
      fillState: "REVIEWING" as const,
      draftId: 31,
      activeJobId: null,
    },
    {
      stepId: 14,
      orderNo: 4,
      topic: "패킷 전송",
      learningGoal: null,
      fillState: "APPROVED" as const,
      draftId: 41,
      activeJobId: null,
    },
  ],
};

function renderScreen(detail = DETAIL) {
  getOutlineMock.mockResolvedValue(detail);
  return render(
    <AppToastProvider>
      <OutlineDetailScreen outlineId={detail.outlineId} />
    </AppToastProvider>,
  );
}

beforeEach(() => {
  getOutlineMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
});

describe("OutlineDetailScreen", () => {
  it("fillState별 액션을 표시한다", async () => {
    renderScreen();

    expect(await screen.findByText("문제 생성")).toBeInTheDocument();
    expect(screen.getByText("터미널 보기")).toBeInTheDocument();
    expect(screen.getByText("draft 검수하기")).toBeInTheDocument();
    expect(screen.getByText("✓ 완료")).toBeInTheDocument();
  });

  it("모든 스텝이 승인됐을 때만 발행 버튼을 활성화한다", async () => {
    const { unmount } = renderScreen({
      ...DETAIL,
      steps: DETAIL.steps.map((step) => ({ ...step, fillState: "APPROVED" as const })),
    });

    expect(await screen.findByRole("button", { name: "코스 발행" })).toBeEnabled();
    unmount();

    renderScreen({
      ...DETAIL,
      steps: DETAIL.steps.map((step, index) => ({
        ...step,
        fillState: index === 0 ? ("REVIEWING" as const) : ("APPROVED" as const),
      })),
    });

    expect(await screen.findByRole("button", { name: "코스 발행" })).toBeDisabled();
  });

  it("첫 행의 위로와 마지막 행의 아래로 버튼을 비활성화한다", async () => {
    renderScreen();

    await screen.findByText("네트워크 구조");

    expect(screen.getByRole("button", { name: "1번 스텝 위로" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "4번 스텝 아래로" })).toBeDisabled();
  });

  it("스텝이 없으면 뼈대 다시 생성 버튼을 표시한다", async () => {
    renderScreen({ ...DETAIL, steps: [] });

    expect(await screen.findByText("아직 뼈대가 없어요")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "뼈대 다시 생성" })).toBeInTheDocument();
  });
});

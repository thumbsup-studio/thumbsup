import { act, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OutlineDetailScreen } from "@/features/authoring/components/outline-detail-screen";
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

const BASE_DETAIL = {
  outlineId: 1,
  title: "네트워크 기초",
  category: "CS",
  status: "DRAFT" as const,
  toc: "목차",
};

beforeEach(() => {
  vi.useFakeTimers();
  getOutlineMock.mockReset();
  mockRouter.replace.mockReset();
});

async function flushEffects() {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
  });
}

afterEach(() => {
  vi.useRealTimers();
});

describe("OutlineDetailScreen polling", () => {
  it("생성 중인 스텝이 있으면 5초 뒤 상세를 재조회한다", async () => {
    getOutlineMock.mockResolvedValue({
      ...BASE_DETAIL,
      steps: [
        {
          stepId: 11,
          orderNo: 1,
          topic: "네트워크 구조",
          learningGoal: null,
          fillState: "GENERATING",
          draftId: null,
          activeJobId: 21,
        },
      ],
    });

    render(
      <AppToastProvider>
        <OutlineDetailScreen outlineId={1} />
      </AppToastProvider>,
    );

    await flushEffects();
    expect(screen.getByText("생성 중")).toBeInTheDocument();
    expect(getOutlineMock).toHaveBeenCalledTimes(1);

    await act(async () => {
      vi.advanceTimersByTime(5000);
    });

    expect(getOutlineMock).toHaveBeenCalledTimes(2);
  });

  it("생성 중인 스텝이 없으면 타이머를 시작하지 않는다", async () => {
    getOutlineMock.mockResolvedValue({
      ...BASE_DETAIL,
      steps: [
        {
          stepId: 11,
          orderNo: 1,
          topic: "네트워크 구조",
          learningGoal: null,
          fillState: "EMPTY",
          draftId: null,
          activeJobId: null,
        },
      ],
    });

    render(
      <AppToastProvider>
        <OutlineDetailScreen outlineId={1} />
      </AppToastProvider>,
    );

    await flushEffects();
    expect(screen.getByText("비어있음")).toBeInTheDocument();

    await act(async () => {
      vi.advanceTimersByTime(10000);
    });

    expect(getOutlineMock).toHaveBeenCalledTimes(1);
  });

  it("언마운트하면 생성 중 폴링을 정리한다", async () => {
    getOutlineMock.mockResolvedValue({
      ...BASE_DETAIL,
      steps: [
        {
          stepId: 11,
          orderNo: 1,
          topic: "네트워크 구조",
          learningGoal: null,
          fillState: "GENERATING",
          draftId: null,
          activeJobId: 21,
        },
      ],
    });

    const { unmount } = render(
      <AppToastProvider>
        <OutlineDetailScreen outlineId={1} />
      </AppToastProvider>,
    );

    await flushEffects();
    expect(screen.getByText("생성 중")).toBeInTheDocument();
    unmount();

    await act(async () => {
      vi.advanceTimersByTime(10000);
    });

    expect(getOutlineMock).toHaveBeenCalledTimes(1);
  });
});

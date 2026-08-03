import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { OutlinesScreen } from "@/features/authoring/components/outlines-screen";
import { ApiError } from "@/lib/api";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getOutlinesMock, mockRouter } = vi.hoisted(() => ({
  getOutlinesMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({ getOutlines: getOutlinesMock }));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

function renderScreen() {
  render(
    <AppToastProvider>
      <OutlinesScreen />
    </AppToastProvider>,
  );
}

beforeEach(() => {
  getOutlinesMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
});

describe("OutlinesScreen", () => {
  it("발행된 코스 카드는 링크가 아니고, 진행 텍스트를 표시한다", async () => {
    getOutlinesMock.mockResolvedValue([
      {
        outlineId: 1,
        title: "네트워크 기초",
        category: "CS",
        status: "DRAFT",
        stepCount: 5,
        approvedStepCount: 2,
      },
      {
        outlineId: 2,
        title: "발행된 네트워크",
        category: "CS",
        status: "PUBLISHED",
        stepCount: 3,
        approvedStepCount: 3,
      },
    ]);

    renderScreen();

    expect(await screen.findByText("스텝 2/5 채움")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /네트워크 기초/ })).toHaveAttribute(
      "href",
      "/authoring/outlines/1",
    );
    expect(screen.queryByRole("link", { name: /발행된 네트워크/ })).not.toBeInTheDocument();
  });

  it("빈 목록이면 저작 코스 EmptyState를 표시한다", async () => {
    getOutlinesMock.mockResolvedValue([]);

    renderScreen();

    expect(await screen.findByText("저작 중인 코스가 없어요")).toBeInTheDocument();
    expect(screen.getByText("새 코스 만들기로 목차를 붙여넣어 시작해 보세요.")).toBeInTheDocument();
  });

  it("권한 없음(403)이면 홈으로 이동한다", async () => {
    getOutlinesMock.mockRejectedValue(
      new ApiError({ code: "FORBIDDEN", status: 403, message: "forbidden" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/"));
  });
});

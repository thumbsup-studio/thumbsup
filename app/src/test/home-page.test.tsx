import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { HomePage } from "@/features/home/components/home-page";
import type { HomeData } from "@/features/home/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

const baseData: HomeData = {
  streakDays: 12,
  todayCourse: {
    title: "운영체제",
    subtitle: "프로세스와 스레드",
    progress: 3,
    total: 8,
    durationLabel: "3분이면 끝나요",
  },
} as HomeData;

afterEach(() => {
  vi.useRealTimers();
  pushMock.mockClear();
});

describe("HomePage", () => {
  it("hides the streak block when streakDays is zero", () => {
    render(
      <AppToastProvider>
        <HomePage
          data={{ ...baseData, streakDays: 0 }}
          now={new Date("2026-07-08T08:00:00+09:00")}
        />
      </AppToastProvider>,
    );

    expect(screen.queryByLabelText("연속 학습")).not.toBeInTheDocument();
  });

  it("renders the required course card text", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("프로세스와 스레드")).toBeInTheDocument();
    expect(screen.getByText("3/8")).toBeInTheDocument();
    expect(screen.getByText("3분이면 끝나요")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "시작하기" })).toHaveAttribute("href", "/play");
  });

  it("navigates to /history from the history tab and toasts for not-yet-built tabs", () => {
    vi.useFakeTimers();

    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "히스토리" }));
    expect(pushMock).toHaveBeenCalledWith("/history");

    fireEvent.click(screen.getByRole("button", { name: "프로필" }));
    expect(screen.getByText("프로필은 준비 중입니다.")).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.queryByText("프로필은 준비 중입니다.")).not.toBeInTheDocument();
  });

  it("links the start action to the play page", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByRole("link", { name: "시작하기" })).toHaveAttribute("href", "/play");
  });
});

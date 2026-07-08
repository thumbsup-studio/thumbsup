import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { HomePage } from "@/features/home/components/home-page";
import type { HomeData } from "@/features/home/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const baseData: HomeData = {
  streakDays: 12,
  todayCourse: {
    title: "운영체제",
    subtitle: "프로세스와 스레드",
    progress: 3,
    durationLabel: "3분이면 끝나요",
  },
};

afterEach(() => {
  vi.useRealTimers();
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
    expect(screen.getByText("3/10")).toBeInTheDocument();
    expect(screen.getByText("3분이면 끝나요")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "시작하기" })).toBeInTheDocument();
  });

  it("shows a coming soon message when inactive tabs are clicked", () => {
    vi.useFakeTimers();

    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "히스토리" }));
    expect(screen.getByText("히스토리는 준비 중입니다.")).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.queryByText("히스토리는 준비 중입니다.")).not.toBeInTheDocument();
  });

  it("shows a toast when the start button is clicked", () => {
    vi.useFakeTimers();

    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "시작하기" }));
    expect(screen.getByText("퀴즈는 준비 중입니다.")).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.queryByText("퀴즈는 준비 중입니다.")).not.toBeInTheDocument();
  });
});

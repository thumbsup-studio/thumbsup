import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { HomePage } from "@/features/home/components/home-page";
import type { HomeData } from "@/features/home/types";

const baseData: HomeData = {
  streakDays: 12,
  todayCourse: {
    title: "운영체제",
    subtitle: "프로세스와 스레드",
    progress: 3,
    durationLabel: "3분이면 끝나요",
  },
};

describe("HomePage", () => {
  it("hides the streak block when streakDays is zero", () => {
    render(
      <HomePage
        data={{ ...baseData, streakDays: 0 }}
        now={new Date("2026-07-08T08:00:00+09:00")}
      />,
    );

    expect(screen.queryByLabelText("연속 학습")).not.toBeInTheDocument();
  });

  it("renders the required course card text", () => {
    render(<HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />);

    expect(screen.getByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("프로세스와 스레드")).toBeInTheDocument();
    expect(screen.getByText("3/10")).toBeInTheDocument();
    expect(screen.getByText("3분이면 끝나요")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "시작하기" })).toBeInTheDocument();
  });

  it("shows a coming soon message when inactive tabs are clicked", () => {
    render(<HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />);

    fireEvent.click(screen.getByRole("button", { name: "히스토리" }));
    expect(screen.getByText("히스토리는 준비 중입니다.")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "프로필" }));
    expect(screen.getByText("프로필은 준비 중입니다.")).toBeInTheDocument();
  });
});

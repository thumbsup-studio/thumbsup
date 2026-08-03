import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { HomePage } from "@/features/home/components/home-page";
import type { HomeData } from "@/features/home/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

const baseData: HomeData = {
  streakDays: 12,
  todayCompleted: false,
  character: {
    name: "보리",
    fullness: 62,
  },
  courses: [
    {
      courseId: 1,
      title: "운영체제",
      subtitle: "프로세스와 스레드",
      progress: 3,
      total: 8,
      durationLabel: "3분이면 끝나요",
    },
  ],
};

const secondCourse: HomeData["courses"][number] = {
  courseId: 2,
  title: "디자인 패턴",
  subtitle: "팩토리 메서드와 추상 팩토리",
  progress: 1,
  total: 2,
  durationLabel: "3분이면 끝나요",
};

afterEach(() => {
  pushMock.mockClear();
});

describe("HomePage", () => {
  it("shows the start-streak prompt instead of a day count when streakDays is zero", () => {
    render(
      <AppToastProvider>
        <HomePage
          data={{ ...baseData, streakDays: 0 }}
          now={new Date("2026-07-08T08:00:00+09:00")}
        />
      </AppToastProvider>,
    );

    const streak = screen.getByLabelText("연속 학습");
    expect(streak).toHaveTextContent("오늘 시작");
    expect(streak).not.toHaveTextContent("0일");
  });

  it("renders the character block with name and fullness", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByText("보리")).toBeInTheDocument();
    expect(screen.getByText("포만감")).toBeInTheDocument();
    expect(screen.getByText("62%")).toBeInTheDocument();
  });

  it("renders the required course card text", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("프로세스와 스레드")).toBeInTheDocument();
    expect(screen.getByText("총 8개 중 3개 코스 진행중")).toBeInTheDocument();
    expect(screen.getByText("코스 진행중")).toBeInTheDocument();
    expect(screen.getByText("3분이면 끝나요")).toBeInTheDocument();
  });

  it("links each course card to the play page with its courseId", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByRole("link", { name: "시작하기" })).toHaveAttribute(
      "href",
      "/play?courseId=1",
    );
  });

  it("navigates to /history and /profile from the bottom tabs", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "히스토리" }));
    expect(pushMock).toHaveBeenCalledWith("/history");

    fireEvent.click(screen.getByRole("button", { name: "프로필" }));
    expect(pushMock).toHaveBeenCalledWith("/profile");
  });

  it("keeps the start link and swaps the chip when today's learning is already done", () => {
    render(
      <AppToastProvider>
        <HomePage
          data={{ ...baseData, todayCompleted: true }}
          now={new Date("2026-07-08T08:00:00+09:00")}
        />
      </AppToastProvider>,
    );

    // 오늘 학습을 마쳐도 추가 풀이를 막지 않는다 — CTA는 유지하고 칩만 완료 상태로 바뀐다(#23).
    expect(screen.getByRole("link", { name: "시작하기" })).toBeInTheDocument();
    expect(screen.getByText("오늘 학습 완료")).toBeInTheDocument();
    expect(screen.queryByText("오늘의 학습")).not.toBeInTheDocument();
  });

  it("renders every course as a carousel slide with a position indicator", () => {
    render(
      <AppToastProvider>
        <HomePage
          data={{ ...baseData, courses: [secondCourse, ...baseData.courses] }}
          now={new Date("2026-07-08T08:00:00+09:00")}
        />
      </AppToastProvider>,
    );

    // 서버가 준 최근 푼 순서를 그대로 렌더한다 — 디자인 패턴(최근)이 먼저.
    const links = screen.getAllByRole("link", { name: "시작하기" });
    expect(links[0]).toHaveAttribute("href", "/play?courseId=2");
    expect(links[1]).toHaveAttribute("href", "/play?courseId=1");
    expect(screen.getByText("디자인 패턴")).toBeInTheDocument();
    expect(screen.getByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("2개 코스 중 1번째")).toBeInTheDocument();
  });

  it("renders a single course without the position indicator", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.queryByText(/코스 중 .*번째/)).not.toBeInTheDocument();
  });
});

import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { HomePage } from "@/features/home/components/home-page";
import type { HomeData } from "@/features/home/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

const baseData: HomeData = {
  streakDays: 12,
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
      completed: false,
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
  completed: false,
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

    expect(screen.getByRole("heading", { name: "최근 학습 코스" })).toBeInTheDocument();
    expect(screen.getByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("프로세스와 스레드")).toBeInTheDocument();
    // progress(완료 3) + 1 = 4번째 스텝을 풀 차례.
    expect(screen.getByText("총 8개 스텝 중 4번째 진행중")).toBeInTheDocument();
    expect(screen.getByText("스텝 진행중")).toBeInTheDocument();
    expect(screen.getByText("3분이면 끝나요")).toBeInTheDocument();
  });

  it("links each incomplete course card to its briefing", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByRole("link", { name: "시작하기" })).toHaveAttribute(
      "href",
      "/briefing?courseId=1",
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
    expect(links[0]).toHaveAttribute("href", "/briefing?courseId=2");
    expect(links[1]).toHaveAttribute("href", "/briefing?courseId=1");
    expect(screen.getByText("디자인 패턴")).toBeInTheDocument();
    expect(screen.getByText("운영체제")).toBeInTheDocument();
    // 위치 문구는 aria-live로 감싸 스와이프 전환도 스크린리더에 안내한다(TC-23-27).
    const indicator = screen.getByText("2개 코스 중 1번째");
    expect(indicator).toBeInTheDocument();
    expect(indicator.closest("p")).toHaveAttribute("aria-live", "polite");
  });

  it("moves between slides with the arrow buttons (TC-23-26)", () => {
    const originalScrollTo = Element.prototype.scrollTo;
    const scrollToMock = vi.fn();
    Element.prototype.scrollTo = scrollToMock as unknown as typeof Element.prototype.scrollTo;
    try {
      render(
        <AppToastProvider>
          <HomePage
            data={{ ...baseData, courses: [secondCourse, ...baseData.courses] }}
            now={new Date("2026-07-08T08:00:00+09:00")}
          />
        </AppToastProvider>,
      );

      // 첫 슬라이드에서는 이전 버튼이 비활성 — 스와이프 없이 버튼만으로도 전환 가능해야 한다.
      expect(screen.getByRole("button", { name: "이전 코스" })).toBeDisabled();

      // offsetLeft는 positioned 조상(여기선 문서) 기준이라 리스트 자신의 페이지 좌표가 섞인다.
      // 가운데 정렬 레이아웃을 흉내 내 리스트 100px, 두 번째 슬라이드 512px로 두면
      // 스크롤 목표는 리스트 기준 상대값인 412px이어야 한다.
      const slides = screen.getAllByRole("listitem");
      const list = slides[0]?.parentElement;
      if (!list || !slides[1]) {
        throw new Error("carousel list not rendered");
      }
      Object.defineProperty(list, "offsetLeft", { value: 100 });
      Object.defineProperty(slides[1], "offsetLeft", { value: 512 });

      fireEvent.click(screen.getByRole("button", { name: "다음 코스" }));
      expect(scrollToMock).toHaveBeenCalledWith({ left: 412 });
    } finally {
      Element.prototype.scrollTo = originalScrollTo;
    }
  });

  it("marks a completed course with the chip and swaps the CTA and progress label", () => {
    const completedCourse = {
      ...baseData.courses[0],
      progress: 7,
      total: 8,
      completed: true,
    } as HomeData["courses"][number];
    render(
      <AppToastProvider>
        <HomePage
          data={{ ...baseData, courses: [completedCourse] }}
          now={new Date("2026-07-08T08:00:00+09:00")}
        />
      </AppToastProvider>,
    );

    // 완주는 "마지막 스텝 풀 차례"(8/8 진행중)와 다르게 칩·문구로 구분된다.
    expect(screen.getByText("완주")).toBeInTheDocument();
    expect(screen.getByText("스텝 완주")).toBeInTheDocument();
    expect(screen.getByText("총 8개 스텝 완주")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "복습하기" })).toHaveAttribute(
      "href",
      "/course?courseId=1",
    );
    expect(screen.queryByText("스텝 진행중")).not.toBeInTheDocument();
  });

  it("shows the recent-course list rule without requiring hover", () => {
    render(
      <AppToastProvider>
        <HomePage data={baseData} now={new Date("2026-07-08T08:00:00+09:00")} />
      </AppToastProvider>,
    );

    expect(screen.getByText(/최대 10개까지 보여드려요/)).toBeInTheDocument();
    expect(screen.getByText(/하단의 코스 탭에서 볼 수 있어요/)).toBeInTheDocument();
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

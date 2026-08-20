import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { BriefingScreen } from "@/features/briefing/components/briefing-screen";
import { ApiError, NetworkError } from "@/lib/api";
import { getNextStepBriefing } from "@/lib/api/quiz";

const mockRouter = vi.hoisted(() => ({ push: vi.fn(), replace: vi.fn() }));

vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));
vi.mock("@/lib/api/quiz", () => ({ getNextStepBriefing: vi.fn() }));

const briefing = {
  quizStepId: 42,
  courseId: 2,
  stepOrder: 3,
  topic: "CPU 스케줄링",
  summary: "CPU 실행 순서와 응답성을 학습합니다.",
  blocks: [
    {
      type: "CAUTION" as const,
      heading: "전환 비용을 확인해요",
      content: "너무 잦은 전환은 실제 작업 시간을 줄일 수 있어요.",
      displayOrder: 2,
    },
    {
      type: "CONCEPT" as const,
      heading: "실행 기준이 달라요",
      content: "도착 순서와 우선순위 같은 기준을 먼저 확인해요.",
      displayOrder: 1,
    },
  ],
};

describe("BriefingScreen", () => {
  beforeEach(() => {
    vi.mocked(getNextStepBriefing).mockReset();
    mockRouter.push.mockReset();
    mockRouter.replace.mockReset();
    vi.restoreAllMocks();
  });

  it("브리핑을 요약과 제목만 먼저 보여주고 두 CTA가 같은 stepId 문제 경로를 가리킨다", async () => {
    vi.mocked(getNextStepBriefing).mockResolvedValue(briefing);

    render(<BriefingScreen courseId={2} />);

    expect(await screen.findByRole("heading", { name: "CPU 스케줄링" })).toBeInTheDocument();
    expect(screen.getByText("CPU 실행 순서와 응답성을 학습합니다.")).toBeInTheDocument();
    const headings = screen.getAllByRole("heading", { level: 3 });
    expect(headings.map((heading) => heading.textContent)).toEqual([
      "실행 기준이 달라요",
      "전환 비용을 확인해요",
    ]);
    expect(
      screen.queryByText("도착 순서와 우선순위 같은 기준을 먼저 확인해요."),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "자세히 읽기" })).toHaveAttribute(
      "aria-expanded",
      "false",
    );
    expect(screen.getByRole("link", { name: "건너뛰기" })).toHaveAttribute(
      "href",
      "/play?courseId=2&stepId=42",
    );
    expect(screen.getByRole("link", { name: "문제 풀기" })).toHaveAttribute(
      "href",
      "/play?courseId=2&stepId=42",
    );
  });

  it("자세히 읽기를 누르면 모든 설명 본문을 펼치고 다시 접을 수 있다", async () => {
    vi.mocked(getNextStepBriefing).mockResolvedValue(briefing);

    render(<BriefingScreen courseId={2} />);

    fireEvent.click(await screen.findByRole("button", { name: "자세히 읽기" }));

    expect(screen.getByText("도착 순서와 우선순위 같은 기준을 먼저 확인해요.")).toBeInTheDocument();
    expect(
      screen.getByText("너무 잦은 전환은 실제 작업 시간을 줄일 수 있어요."),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "간단히 보기" })).toHaveAttribute(
      "aria-expanded",
      "true",
    );

    fireEvent.click(screen.getByRole("button", { name: "간단히 보기" }));

    expect(
      screen.queryByText("도착 순서와 우선순위 같은 기준을 먼저 확인해요."),
    ).not.toBeInTheDocument();
  });

  it("브리핑이 누락되면 기록을 남기고 기존 문제 경로로 즉시 우회한다", async () => {
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});
    vi.mocked(getNextStepBriefing).mockRejectedValue(
      new ApiError({
        code: "QUIZ_STEP_BRIEFING_NOT_AVAILABLE",
        status: 409,
        message: "아직 준비되지 않은 스텝 브리핑입니다.",
      }),
    );

    render(<BriefingScreen courseId={2} />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/play?courseId=2");
    });
    expect(consoleError).toHaveBeenCalledWith(
      "현재 스텝 브리핑 누락으로 기존 문제 흐름으로 우회합니다.",
      { courseId: 2, code: "QUIZ_STEP_BRIEFING_NOT_AVAILABLE" },
    );
  });

  it("네트워크 오류에는 다시 시도 버튼을 제공한다", async () => {
    vi.mocked(getNextStepBriefing)
      .mockRejectedValueOnce(new NetworkError())
      .mockResolvedValueOnce(briefing);

    render(<BriefingScreen courseId={2} />);

    fireEvent.click(await screen.findByRole("button", { name: "재시도" }));

    expect(await screen.findByRole("heading", { name: "CPU 스케줄링" })).toBeInTheDocument();
    expect(getNextStepBriefing).toHaveBeenCalledTimes(2);
  });

  it("코스를 완주했으면 해당 코스의 복습 목록으로 이동한다", async () => {
    vi.mocked(getNextStepBriefing).mockRejectedValue(
      new ApiError({
        code: "QUIZ_STEP_COMPLETED",
        status: 404,
        message: "현재 스텝의 문제를 모두 풀었습니다.",
      }),
    );

    render(<BriefingScreen courseId={2} />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/course?courseId=2");
    });
  });

  it("접근할 수 없는 코스면 코스 목록으로 이동한다", async () => {
    vi.mocked(getNextStepBriefing).mockRejectedValue(
      new ApiError({ code: "QUIZ_NOT_ACCESSIBLE", status: 403, message: "접근할 수 없습니다." }),
    );

    render(<BriefingScreen courseId={2} />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/course");
    });
  });
});

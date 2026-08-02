import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { JobScreen } from "@/features/authoring/components/job-screen";

const { useJobLogStreamMock, getJobMock, mockRouter } = vi.hoisted(() => ({
  useJobLogStreamMock: vi.fn(),
  getJobMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/use-job-log-stream", () => ({
  useJobLogStream: useJobLogStreamMock,
}));
vi.mock("@/features/authoring/api", () => ({ getJob: getJobMock }));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));
vi.mock("@/features/authoring/components/terminal-viewer", () => ({
  TerminalViewer: ({
    onReady,
  }: {
    onReady: (handle: { write: (line: string) => void }) => void;
  }) => {
    onReady({ write: vi.fn() });
    return <div data-testid="terminal-stub" />;
  },
}));

beforeEach(() => {
  useJobLogStreamMock.mockReset();
  getJobMock.mockReset();
  mockRouter.replace.mockReset();
  getJobMock.mockResolvedValue({
    jobId: 7,
    kind: "OUTLINE",
    status: "SUCCEEDED",
    draftId: null,
    error: null,
    createdAt: "2026-07-14T00:00:00Z",
    startedAt: "2026-07-14T00:00:01Z",
    finishedAt: "2026-07-14T00:00:02Z",
    outlineId: 9,
    outlineStepId: null,
  });
});

describe("JobScreen outline completion", () => {
  it("OUTLINE 잡 완료 시 뼈대 확인하기 링크를 표시한다", async () => {
    useJobLogStreamMock.mockReturnValue({
      phase: "done",
      kind: "OUTLINE",
      status: "SUCCEEDED",
      draftId: null,
      outlineId: 9,
      error: null,
    });

    render(<JobScreen jobId={7} />);

    const link = await screen.findByRole("link", { name: "뼈대 확인하기" });
    expect(link).toHaveAttribute("href", "/authoring/outlines/9");
  });

  it("뼈대 스텝 문제 생성 완료 시 뼈대와 draft 링크를 모두 표시한다", async () => {
    useJobLogStreamMock.mockReturnValue({
      phase: "done",
      kind: "GENERATE",
      status: "SUCCEEDED",
      draftId: 42,
      outlineId: 9,
      error: null,
    });

    render(<JobScreen jobId={7} />);

    expect(await screen.findByRole("link", { name: "뼈대로 돌아가기" })).toHaveAttribute(
      "href",
      "/authoring/outlines/9",
    );
    expect(screen.getByRole("link", { name: "Draft 보러가기" })).toHaveAttribute(
      "href",
      "/authoring/drafts/42",
    );
  });

  it("outlineId가 없는 레거시 잡은 기존 Draft 문구만 표시한다", async () => {
    useJobLogStreamMock.mockReturnValue({
      phase: "done",
      kind: "GENERATE",
      status: "SUCCEEDED",
      draftId: 42,
      outlineId: null,
      error: null,
    });

    render(<JobScreen jobId={7} />);

    expect(await screen.findByText(/문제 생성이 완료됐어요/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Draft 보러가기" })).toHaveAttribute(
      "href",
      "/authoring/drafts/42",
    );
    expect(screen.queryByRole("link", { name: "뼈대로 돌아가기" })).not.toBeInTheDocument();
  });
});

import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { JobScreen } from "@/features/authoring/components/job-screen";

const { useJobLogStreamMock, getJobMock } = vi.hoisted(() => ({
  useJobLogStreamMock: vi.fn(),
  getJobMock: vi.fn(),
}));

vi.mock("@/features/authoring/use-job-log-stream", () => ({
  useJobLogStream: useJobLogStreamMock,
}));
vi.mock("@/features/authoring/api", () => ({ getJob: getJobMock }));
vi.mock("@/features/authoring/components/terminal-viewer", () => ({
  TerminalViewer: ({ onReady }: { onReady: (h: { write: (line: string) => void }) => void }) => {
    onReady({ write: vi.fn() });
    return <div data-testid="terminal-stub" />;
  },
}));

beforeEach(() => {
  useJobLogStreamMock.mockReset();
  getJobMock.mockReset();
  getJobMock.mockResolvedValue({
    jobId: 7,
    kind: "GENERATE",
    status: "RUNNING",
    draftId: null,
    error: null,
    createdAt: "2026-07-14T00:00:00Z",
    startedAt: "2026-07-14T00:00:01Z",
    finishedAt: null,
  });
});

describe("JobScreen", () => {
  it("연결 중(connecting)이면 스켈레톤을 렌더한다", () => {
    useJobLogStreamMock.mockReturnValue({ phase: "connecting" });

    render(<JobScreen jobId={7} />);

    expect(screen.queryByTestId("terminal-stub")).not.toBeInTheDocument();
  });

  it("streaming 중이면 JobStatusChip '실행 중'을 렌더한다", async () => {
    useJobLogStreamMock.mockReturnValue({ phase: "streaming" });

    render(<JobScreen jobId={7} />);

    expect(await screen.findByText("실행 중")).toBeInTheDocument();
  });

  it("done(SUCCEEDED, draftId=42)이면 Draft 보러가기 링크를 렌더한다", async () => {
    useJobLogStreamMock.mockReturnValue({
      phase: "done",
      status: "SUCCEEDED",
      draftId: 42,
      error: null,
    });

    render(<JobScreen jobId={7} />);

    const link = await screen.findByRole("link", { name: "Draft 보러가기" });
    expect(link).toHaveAttribute("href", "/authoring/drafts/42");
  });

  it("done(FAILED, error)이면 에러 메시지와 다시 시도 안내를 렌더한다", async () => {
    useJobLogStreamMock.mockReturnValue({
      phase: "done",
      status: "FAILED",
      draftId: null,
      error: "검증 실패",
    });

    render(<JobScreen jobId={7} />);

    expect(await screen.findByText(/검증 실패/)).toBeInTheDocument();
    expect(screen.getByText(/다시 시도/)).toBeInTheDocument();
  });

  it("QUEUED 상태가 지속되고 로그가 없으면 브리지 대기 문구를 렌더한다", async () => {
    getJobMock.mockResolvedValue({
      jobId: 7,
      kind: "GENERATE",
      status: "QUEUED",
      draftId: null,
      error: null,
      createdAt: "2026-07-14T00:00:00Z",
      startedAt: null,
      finishedAt: null,
    });
    useJobLogStreamMock.mockReturnValue({ phase: "streaming" });

    render(<JobScreen jobId={7} />);

    expect(await screen.findByText(/브리지 대기 중/)).toBeInTheDocument();
  });
});

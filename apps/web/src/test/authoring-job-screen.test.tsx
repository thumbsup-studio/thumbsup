import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { JobScreen } from "@/features/authoring/components/job-screen";

const { useJobLogStreamMock, getJobMock, mockRouter } = vi.hoisted(() => ({
  useJobLogStreamMock: vi.fn(),
  getJobMock: vi.fn(),
  // useRouter()가 매 렌더 새 객체를 반환하면 무한 루프를 유발한다(T4 사고 재발 방지) — 안정된 참조를 반환.
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/use-job-log-stream", () => ({
  useJobLogStream: useJobLogStreamMock,
}));
vi.mock("@/features/authoring/api", () => ({ getJob: getJobMock }));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));
vi.mock("@/features/authoring/components/terminal-viewer", () => ({
  TerminalViewer: ({ onReady }: { onReady: (h: { write: (line: string) => void }) => void }) => {
    onReady({ write: vi.fn() });
    return <div data-testid="terminal-stub" />;
  },
}));

beforeEach(() => {
  useJobLogStreamMock.mockReset();
  getJobMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
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

  it("unauthorized 상태면 로그인 화면으로 이동한다", async () => {
    useJobLogStreamMock.mockReturnValue({ phase: "unauthorized" });

    render(<JobScreen jobId={7} />);

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });

  it("error 상태면 터미널을 숨기고 재시도 버튼을 렌더한다", async () => {
    useJobLogStreamMock.mockReturnValue({ phase: "error" });

    render(<JobScreen jobId={7} />);

    expect(screen.queryByTestId("terminal-stub")).not.toBeInTheDocument();
    const retry = await screen.findByRole("button", { name: "재시도" });

    // 재시도 클릭은 스트림 훅을 리마운트로 재시작한다(같은 mock 반환값이라 상태 자체는 안 바뀌지만,
    // 클릭 후에도 화면이 정상적으로(에러 상태 유지) 다시 렌더되는지 — 크래시 없는지 — 확인한다.
    fireEvent.click(retry);
    expect(await screen.findByRole("button", { name: "재시도" })).toBeInTheDocument();
  });
});

import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { JobStatusChip } from "@/features/authoring/components/job-status-chip";
import type { TerminalHandle } from "@/features/authoring/components/terminal-viewer";
import { TerminalViewer } from "@/features/authoring/components/terminal-viewer";

const { openMock, writeMock, disposeMock, loadAddonMock, TerminalCtor, FitAddonCtor } = vi.hoisted(
  () => {
    const openMock = vi.fn();
    const writeMock = vi.fn();
    const disposeMock = vi.fn();
    const loadAddonMock = vi.fn();
    const TerminalCtor = vi.fn().mockImplementation(() => ({
      open: openMock,
      write: writeMock,
      dispose: disposeMock,
      loadAddon: loadAddonMock,
    }));
    const FitAddonCtor = vi.fn().mockImplementation(() => ({ fit: vi.fn() }));
    return { openMock, writeMock, disposeMock, loadAddonMock, TerminalCtor, FitAddonCtor };
  },
);

vi.mock("@xterm/xterm", () => ({ Terminal: TerminalCtor }));
vi.mock("@xterm/addon-fit", () => ({ FitAddon: FitAddonCtor }));

beforeEach(() => {
  vi.clearAllMocks();
});

describe("TerminalViewer", () => {
  it("마운트 시 Terminal.open이 컨테이너 엘리먼트로 호출된다", async () => {
    render(<TerminalViewer onReady={vi.fn()} />);

    const containerEl = screen.getByLabelText("잡 실행 로그 터미널");
    await waitFor(() => expect(openMock).toHaveBeenCalledWith(containerEl));
    expect(loadAddonMock).toHaveBeenCalledTimes(1);
  });

  it("onReady로 받은 handle.write가 개행(\\r\\n)을 붙여 내부 term.write에 전달한다", async () => {
    let handle: TerminalHandle | undefined;
    render(
      <TerminalViewer
        onReady={(h) => {
          handle = h;
        }}
      />,
    );

    await waitFor(() => expect(handle).toBeDefined());
    handle?.write("abc");

    expect(writeMock).toHaveBeenCalledWith("abc\r\n");
  });

  it("언마운트 시 dispose를 호출한다", async () => {
    const { unmount } = render(<TerminalViewer onReady={vi.fn()} />);
    await waitFor(() => expect(openMock).toHaveBeenCalled());

    unmount();

    expect(disposeMock).toHaveBeenCalledTimes(1);
  });
});

describe("JobStatusChip", () => {
  it.each([
    ["QUEUED", "대기"],
    ["RUNNING", "실행 중"],
    ["SUCCEEDED", "완료"],
    ["FAILED", "실패"],
  ] as const)("%s 상태는 '%s' 라벨을 렌더한다", (status, label) => {
    render(<JobStatusChip status={status} />);

    expect(screen.getByText(label)).toBeInTheDocument();
  });
});

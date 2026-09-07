import { renderHook, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useJobLogStream } from "@/features/authoring/use-job-log-stream";
import { ApiError } from "@/lib/api";

const { getJobMock, streamJobLogsMock } = vi.hoisted(() => ({
  getJobMock: vi.fn(),
  streamJobLogsMock: vi.fn(),
}));

vi.mock("@/features/authoring/api", () => ({ getJob: getJobMock }));
vi.mock("@/features/authoring/sse", () => ({ streamJobLogs: streamJobLogsMock }));

const RUNNING_JOB = {
  jobId: 7,
  kind: "GENERATE",
  status: "RUNNING",
  draftId: null,
  error: null,
  createdAt: "2026-07-14T00:00:00Z",
  startedAt: "2026-07-14T00:00:01Z",
  finishedAt: null,
};

beforeEach(() => {
  getJobMock.mockReset();
  streamJobLogsMock.mockReset();
});

describe("useJobLogStream — 스트림 EOF/세션 만료 복원력", () => {
  it("status 이벤트 없이 스트림이 EOF로 끊기고 재확인 결과가 종료 상태(SUCCEEDED)면 done으로 전이한다", async () => {
    getJobMock
      .mockResolvedValueOnce(RUNNING_JOB) // 최초 조회 — 아직 실행 중이라 스트림 시작
      .mockResolvedValueOnce({ ...RUNNING_JOB, status: "SUCCEEDED", draftId: 42 }); // EOF 후 재확인
    streamJobLogsMock.mockResolvedValue(undefined); // onStatus/onError 호출 없이 그냥 반환(프록시 타임아웃 등 조용한 끊김)

    const { result } = renderHook(() => useJobLogStream(7, vi.fn()));

    await waitFor(() =>
      expect(result.current).toEqual({
        phase: "done",
        status: "SUCCEEDED",
        draftId: 42,
        error: null,
      }),
    );
    expect(getJobMock).toHaveBeenCalledTimes(2);
  });

  it("EOF 재확인 결과도 아직 종료 상태가 아니면 error로 전이한다(무한 실행 중 고착 방지)", async () => {
    getJobMock.mockResolvedValueOnce(RUNNING_JOB).mockResolvedValueOnce(RUNNING_JOB);
    streamJobLogsMock.mockResolvedValue(undefined);

    const { result } = renderHook(() => useJobLogStream(7, vi.fn()));

    await waitFor(() => expect(result.current).toEqual({ phase: "error" }));
  });

  it("status/error 이벤트로 이미 종료된 경우엔 EOF 재확인을 하지 않는다", async () => {
    getJobMock.mockResolvedValueOnce(RUNNING_JOB);
    streamJobLogsMock.mockImplementation(async (_jobId, handlers) => {
      handlers.onStatus({ status: "FAILED", draftId: null, error: "검증 실패" });
    });

    const { result } = renderHook(() => useJobLogStream(7, vi.fn()));

    await waitFor(() =>
      expect(result.current).toEqual({
        phase: "done",
        status: "FAILED",
        draftId: null,
        error: "검증 실패",
      }),
    );
    // onStatus로 이미 확정됐으므로 재확인용 추가 getJob 호출이 없어야 한다(최초 1회만).
    expect(getJobMock).toHaveBeenCalledTimes(1);
  });

  it("최초 getJob이 401이면 unauthorized로 전이한다", async () => {
    getJobMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    const { result } = renderHook(() => useJobLogStream(7, vi.fn()));

    await waitFor(() => expect(result.current).toEqual({ phase: "unauthorized" }));
  });
});

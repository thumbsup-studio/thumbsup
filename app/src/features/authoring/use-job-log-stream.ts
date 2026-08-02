"use client";

import { useEffect, useRef, useState } from "react";
import type { JobStatus } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";
import { getJob } from "./api";
import { streamJobLogs } from "./sse";

export type JobStreamState =
  | { phase: "connecting" }
  | { phase: "streaming" }
  | {
      phase: "done";
      kind: JobStatus["kind"];
      status: string;
      draftId: number | null;
      outlineId: number | null;
      error: string | null;
    }
  | { phase: "error" }
  | { phase: "unauthorized" };

const TERMINAL_STATUSES = new Set(["SUCCEEDED", "FAILED"]);

/** 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3) — unauthorized로 구분해 error와 분기. */
function phaseForError(error: unknown): JobStreamState {
  if (error instanceof ApiError && error.status === 401) {
    return { phase: "unauthorized" };
  }
  return { phase: "error" };
}

/**
 * 잡 로그 스트림 훅. 마운트 시 `getJob`을 1회 선호출해 토큰을 리프레시(apiRequest가 처리)한 뒤
 * 신선한 토큰으로 SSE 스트림을 연다. 이미 종료 상태(SUCCEEDED/FAILED)면 스트림 없이 바로 done.
 * 언마운트 시 스트림을 abort한다.
 */
export function useJobLogStream(jobId: number, onLine: (line: string) => void): JobStreamState {
  const [state, setState] = useState<JobStreamState>({ phase: "connecting" });
  // onLine의 참조 변경(부모 렌더마다 새 함수)이 스트림 재연결을 유발하지 않도록 ref로 최신값만 추적
  const onLineRef = useRef(onLine);
  onLineRef.current = onLine;

  useEffect(() => {
    const controller = new AbortController();
    let cancelled = false;
    // streamJobLogs가 onStatus/onError 둘 다 없이 반환하면(예: Nginx proxy_read_timeout으로 status
    // 이벤트 전 연결이 조용히 끊김) "실행 중"에 영원히 갇히므로, 그 경우만 아래에서 getJob으로 재확인한다.
    let settled = false;
    setState({ phase: "connecting" });

    void (async () => {
      try {
        const job = await getJob(jobId);
        if (cancelled) return;
        if (TERMINAL_STATUSES.has(job.status)) {
          setState({
            phase: "done",
            kind: job.kind,
            status: job.status,
            draftId: job.draftId,
            outlineId: job.outlineId,
            error: job.error,
          });
          return;
        }
        setState({ phase: "streaming" });
        await streamJobLogs(
          jobId,
          {
            onLog: (entry) => onLineRef.current(entry.line),
            onStatus: (status) => {
              settled = true;
              if (!cancelled) {
                setState({ phase: "done", kind: job.kind, ...status });
              }
            },
            onError: () => {
              settled = true;
              if (!cancelled) setState({ phase: "error" });
            },
          },
          controller.signal,
        );

        if (cancelled || settled) return;

        // 조용한 EOF — 서버가 실제로는 끝났을 수도, 아직 진행 중일 수도 있으니 잡 상태를 다시 물어본다.
        const recheckedJob = await getJob(jobId);
        if (cancelled) return;
        setState(
          TERMINAL_STATUSES.has(recheckedJob.status)
            ? {
                phase: "done",
                kind: recheckedJob.kind,
                status: recheckedJob.status,
                draftId: recheckedJob.draftId,
                outlineId: recheckedJob.outlineId,
                error: recheckedJob.error,
              }
            : { phase: "error" },
        );
      } catch (error) {
        if (!cancelled) setState(phaseForError(error));
      }
    })();

    return () => {
      cancelled = true;
      controller.abort();
    };
  }, [jobId]);

  return state;
}

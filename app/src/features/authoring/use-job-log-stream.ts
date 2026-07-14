"use client";

import { useEffect, useRef, useState } from "react";
import { getJob } from "./api";
import { streamJobLogs } from "./sse";

export type JobStreamState =
  | { phase: "connecting" }
  | { phase: "streaming" }
  | { phase: "done"; status: string; draftId: number | null; error: string | null }
  | { phase: "error" };

const TERMINAL_STATUSES = new Set(["SUCCEEDED", "FAILED"]);

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
    setState({ phase: "connecting" });

    void (async () => {
      try {
        const job = await getJob(jobId);
        if (cancelled) return;
        if (TERMINAL_STATUSES.has(job.status)) {
          setState({ phase: "done", status: job.status, draftId: job.draftId, error: job.error });
          return;
        }
        setState({ phase: "streaming" });
        await streamJobLogs(
          jobId,
          {
            onLog: (entry) => onLineRef.current(entry.line),
            onStatus: (status) => {
              if (!cancelled) setState({ phase: "done", ...status });
            },
            onError: () => {
              if (!cancelled) setState({ phase: "error" });
            },
          },
          controller.signal,
        );
      } catch {
        if (!cancelled) setState({ phase: "error" });
      }
    })();

    return () => {
      cancelled = true;
      controller.abort();
    };
  }, [jobId]);

  return state;
}

"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getJob } from "@/features/authoring/api";
import { JobStatusChip } from "@/features/authoring/components/job-status-chip";
import {
  type TerminalHandle,
  TerminalViewer,
} from "@/features/authoring/components/terminal-viewer";
import type { JobStatus } from "@/features/authoring/types";
import { useJobLogStream } from "@/features/authoring/use-job-log-stream";

/**
 * 잡 실행 터미널 화면 — SSE로 로그를 실시간으로 밀어넣고, 종료 시 결과 액션을 보여준다.
 * SSE는 log/status 이벤트만 보내고 QUEUED→RUNNING 전이는 별도로 알려주지 않으므로,
 * "QUEUED로 시작했는데 아직 로그가 한 줄도 없다"를 브리지 대기 상태로 간주한다.
 */
export function JobScreen({ jobId }: { jobId: number }) {
  const handleRef = useRef<TerminalHandle | null>(null);
  // onReady는 ref만 대입하므로 deps 없이 고정 — 매 렌더 새 함수를 넘기면 TerminalViewer가 재마운트된다.
  const handleReady = useCallback((handle: TerminalHandle) => {
    handleRef.current = handle;
  }, []);

  const [hasLog, setHasLog] = useState(false);
  const [initialStatus, setInitialStatus] = useState<JobStatus["status"] | null>(null);

  useEffect(() => {
    let ignore = false;
    setHasLog(false);
    setInitialStatus(null);
    getJob(jobId)
      .then((job) => {
        if (!ignore) {
          setInitialStatus(job.status);
        }
      })
      .catch(() => {
        // 최초 상태 조회 실패는 무시한다 — useJobLogStream이 자체적으로 error phase로 표시한다.
      });
    return () => {
      ignore = true;
    };
  }, [jobId]);

  const streamState = useJobLogStream(jobId, (line) => {
    setHasLog(true);
    handleRef.current?.write(line);
  });

  if (streamState.phase === "connecting") {
    return <JobScreenSkeleton />;
  }

  const waitingForBridge =
    streamState.phase === "streaming" && initialStatus === "QUEUED" && !hasLog;

  return (
    <div className="flex flex-col gap-4">
      {streamState.phase === "streaming" ? (
        <div className="flex items-center gap-3">
          <JobStatusChip status={waitingForBridge ? "QUEUED" : "RUNNING"} />
        </div>
      ) : null}

      {waitingForBridge ? (
        <Feedback tone="pending">브리지 대기 중 — 브리지를 켜세요.</Feedback>
      ) : null}

      <TerminalViewer onReady={handleReady} />

      {streamState.phase === "done" ? (
        streamState.status === "SUCCEEDED" ? (
          <Feedback tone="success">
            문제 생성이 완료됐어요.{" "}
            <Link
              className="font-semibold underline"
              href={`/authoring/drafts/${streamState.draftId}`}
            >
              Draft 보러가기
            </Link>
          </Feedback>
        ) : (
          <Feedback tone="error">
            {streamState.error ?? "생성에 실패했어요."} Draft 화면에서 다시 시도해 주세요.
          </Feedback>
        )
      ) : null}

      {streamState.phase === "error" ? (
        <Feedback tone="error">로그를 불러오지 못했어요.</Feedback>
      ) : null}
    </div>
  );
}

function JobScreenSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-7 w-24" />
      <Skeleton className="h-80 w-full" />
    </div>
  );
}

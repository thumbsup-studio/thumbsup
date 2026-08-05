import { ApiError, type BridgeApi } from "./api.js";
import type { CliAdapter } from "./adapters/types.js";

export type RunnerDeps = { api: BridgeApi; adapter: CliAdapter; pollIntervalMs?: number; logFlushMs?: number };

const DEFAULT_POLL_INTERVAL_MS = 3000;
const DEFAULT_LOG_FLUSH_MS = 3000;

/**
 * 잡이 이미 종결돼 서버가 제출을 거절한 경우의 에러 코드. 결과가 먼저 반영된 뒤 뒤늦게 도착한
 * postFail이 여기 걸리는데, 이건 정상 동작이라 실패로 보고하지 않는다.
 */
const JOB_NOT_CLAIMABLE = "AUTHORING_JOB_NOT_CLAIMABLE";

const KIND_LABEL: Record<string, string> = {
  GENERATE: "문제 생성",
  REVIEW: "검수",
  OUTLINE: "뼈대 생성",
};

function describe(kind: string): string {
  return KIND_LABEL[kind] ?? kind;
}

function stamp(): string {
  return new Date().toLocaleTimeString("ko-KR", { hour12: false });
}

/**
 * 잡 하나를 처리한다: nextJob() → 없으면 idle. 있으면 어댑터 실행 중 로그를 배치로
 * postLogs 전송하면서 결과를 기다려 postResult(성공/서버 FAILED 판정 모두 done) 또는
 * 예외 시 postFail(failed)로 마무리한다.
 */
export async function runOnce(deps: RunnerDeps): Promise<"idle" | "done" | "failed"> {
  const { api, adapter, logFlushMs = DEFAULT_LOG_FLUSH_MS } = deps;

  const job = await api.nextJob();
  if (!job) return "idle";

  console.log(`[${stamp()}] 잡 #${job.jobId} ${describe(job.kind)} 시작 — ${adapter.cli} 실행 중…`);

  const logBuffer: string[] = [];
  // T2 리뷰 이월: flush끼리 겹치면 postLogs가 동시에 두 번 나가 토큰 refresh 경합을 일으킬 수 있다.
  // 프로미스 체인으로 직렬화 — 진행 중인 flush가 끝난 뒤에야 다음 flush(쌓인 만큼만)가 시작된다.
  let flushChain: Promise<void> = Promise.resolve();
  const scheduleFlush = (): Promise<void> => {
    flushChain = flushChain.then(async () => {
      if (logBuffer.length === 0) return;
      const toSend = logBuffer.splice(0, logBuffer.length);
      try {
        await api.postLogs(job.jobId, toSend);
      } catch {
        // best-effort — 로그 전송 실패해도 잡 실행 자체는 계속 진행한다.
      }
    });
    return flushChain;
  };

  const interval = setInterval(() => {
    void scheduleFlush();
  }, logFlushMs);

  try {
    // outputSchema는 서버가 객체로 내려준 그대로 어댑터에 전달한다(재직렬화 금지 — T3 리뷰 이월).
    const resultJson = await adapter.run(
      { prompt: job.prompt, outputSchema: job.outputSchema },
      { onLog: (line) => logBuffer.push(line) },
    );
    // 서버는 RUNNING 상태 잡에만 로그를 받는다 — postResult로 상태가 바뀌기 전에 남은 로그를 먼저 보낸다.
    clearInterval(interval);
    await scheduleFlush();
    // 서버가 결과를 검증해 최종 판정을 돌려준다 — 제출 성공과 검증 통과는 다르므로 그대로 보여준다.
    const outcome = await api.postResult(job.jobId, adapter.cli, resultJson);
    if (outcome.status === "FAILED") {
      console.log(
        `[${stamp()}] 잡 #${job.jobId} 서버 검증 거부 — ${outcome.error ?? "사유 없음"}\n` +
          "           대시보드에서 다시 생성하면 됩니다.",
      );
    } else {
      console.log(`[${stamp()}] 잡 #${job.jobId} 완료 — 서버 반영됨`);
    }
    return "done";
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    // postFail 이전에도 마찬가지로 RUNNING 상태에서 남은 로그를 먼저 보낸다.
    clearInterval(interval);
    await scheduleFlush();
    console.log(`[${stamp()}] 잡 #${job.jobId} 실행 실패 — ${message}`);
    try {
      await api.postFail(job.jobId, message);
    } catch (postFailError) {
      // 결과가 이미 반영돼 잡이 종결된 뒤 뒤늦게 도착한 postFail은 서버가 거절하는 게 정상이다.
      // 실패로 보이면 사용자가 오작동으로 오해하므로 정보성 문구로만 남긴다.
      if (postFailError instanceof ApiError && postFailError.code === JOB_NOT_CLAIMABLE) {
        console.log(`[${stamp()}] 잡 #${job.jobId}는 이미 종결된 상태 — 실패 보고는 건너뜁니다.`);
      } else {
        // 네트워크 오류·서버 재배포 중 등 진짜 전송 실패. 데몬은 죽이지 않고 다음 사이클로 계속한다.
        console.error(
          `[${stamp()}] 잡 #${job.jobId} 실패 보고를 전송하지 못했습니다:`,
          postFailError instanceof Error ? postFailError.message : postFailError,
        );
      }
    }
    return "failed";
  } finally {
    // 안전망 — 위 두 경로에서 이미 정리됐다면 clearInterval은 무해한 재호출, scheduleFlush는 버퍼가 비어 즉시 반환.
    clearInterval(interval);
    await scheduleFlush();
  }
}

function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    if (signal.aborted) {
      resolve();
      return;
    }
    let timer: ReturnType<typeof setTimeout>;
    const onAbort = () => {
      clearTimeout(timer);
      resolve();
    };
    // 타이머가 정상 완료되는(대다수) 경로에서도 abort 리스너를 반드시 제거한다.
    // 안 지우면 같은 signal로 sleep()을 반복 호출할 때마다(runLoop의 매 idle 사이클)
    // 리스너가 계속 쌓여 메모리 누수가 된다.
    timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    signal.addEventListener("abort", onAbort, { once: true });
  });
}

/**
 * idle일 때만 pollIntervalMs만큼 쉬며 계속 폴링한다. signal이 abort되면 현재 잡을 마친 뒤 멈춘다.
 * runOnce 자체가 throw해도(WiFi 끊김·노트북 sleep/wake·서버 재배포 중 502 등) 데몬 전체가 죽지 않도록
 * 여기서 잡아 로그만 남기고 pollIntervalMs만큼 backoff한 뒤 다음 사이클을 계속한다.
 */
export async function runLoop(deps: RunnerDeps, signal: AbortSignal): Promise<void> {
  const pollIntervalMs = deps.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS;
  // 폴링은 3초마다 도는데 매번 찍으면 로그가 도배된다 — 대기 상태로 "들어갈 때" 한 번만 알린다.
  let announcedIdle = false;
  while (!signal.aborted) {
    try {
      const outcome = await runOnce(deps);
      if (outcome === "idle") {
        if (!announcedIdle) {
          console.log(`[${stamp()}] 잡 대기 중… (대시보드에서 생성을 누르면 여기서 실행됩니다)`);
          announcedIdle = true;
        }
        await sleep(pollIntervalMs, signal);
      } else {
        announcedIdle = false;
      }
    } catch (error) {
      console.error("잡 처리 중 예외 발생 — 다음 사이클로 계속:", error instanceof Error ? error.message : error);
      announcedIdle = false;
      await sleep(pollIntervalMs, signal);
    }
  }
}

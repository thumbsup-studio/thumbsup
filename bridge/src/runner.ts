import type { CliAdapter } from "./adapters/types.js";
import type { BridgeApi } from "./api.js";

export type RunnerDeps = { api: BridgeApi; adapter: CliAdapter; pollIntervalMs?: number; logFlushMs?: number };

const DEFAULT_POLL_INTERVAL_MS = 3000;
const DEFAULT_LOG_FLUSH_MS = 3000;

/**
 * 잡 하나를 처리한다: nextJob() → 없으면 idle. 있으면 어댑터 실행 중 로그를 배치로
 * postLogs 전송하면서 결과를 기다려 postResult(성공/서버 FAILED 판정 모두 done) 또는
 * 예외 시 postFail(failed)로 마무리한다.
 */
export async function runOnce(deps: RunnerDeps): Promise<"idle" | "done" | "failed"> {
  const { api, adapter, logFlushMs = DEFAULT_LOG_FLUSH_MS } = deps;

  const job = await api.nextJob();
  if (!job) return "idle";

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
    await api.postResult(job.jobId, adapter.cli, resultJson);
    return "done";
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await api.postFail(job.jobId, message);
    return "failed";
  } finally {
    clearInterval(interval);
    await scheduleFlush(); // 마지막 남은 로그까지 전송(직전 flush가 진행 중이면 그 뒤에 이어서)
  }
}

function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    if (signal.aborted) {
      resolve();
      return;
    }
    const timer = setTimeout(resolve, ms);
    signal.addEventListener(
      "abort",
      () => {
        clearTimeout(timer);
        resolve();
      },
      { once: true },
    );
  });
}

/** idle일 때만 pollIntervalMs만큼 쉬며 계속 폴링한다. signal이 abort되면 현재 잡을 마친 뒤 멈춘다. */
export async function runLoop(deps: RunnerDeps, signal: AbortSignal): Promise<void> {
  const pollIntervalMs = deps.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS;
  while (!signal.aborted) {
    const outcome = await runOnce(deps);
    if (outcome === "idle") await sleep(pollIntervalMs, signal);
  }
}

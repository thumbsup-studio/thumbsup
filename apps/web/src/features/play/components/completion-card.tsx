import type { ReactNode } from "react";
import { CircleCheckIcon } from "@/components/icons";
import { type CompletionSummary, clampCompletion } from "@/features/play/completion-params";

type CompletionCardProps = {
  summary: CompletionSummary;
  totalCount: number;
};

export function CompletionCard({ summary, totalCount }: CompletionCardProps) {
  const safe = clampCompletion(summary, totalCount);
  // 구키에서 마이그레이션된 세션은 answered를 복원할 수 없어 0이다.
  // 틀린 숫자를 보여주느니 값을 감춘다(session-progress.ts migrateLegacy 주석 참고).
  const canShowScore = safe.answered === totalCount && totalCount > 0;
  const accuracy = canShowScore ? Math.round((safe.correct / totalCount) * 100) : null;

  return (
    <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
      <div className="flex items-center gap-2">
        <span className="grid h-8 w-8 place-items-center rounded-chip bg-success/10 text-success">
          <CircleCheckIcon className="h-5 w-5" />
        </span>
        <p className="text-sm font-bold text-ink">오늘의 학습 완료</p>
      </div>

      {/* 한 줄 요약 대신 칸을 나눠 세운다 — 자랑할 숫자가 눈에 먼저 들어오게. */}
      <dl className="mt-3 grid grid-cols-3 gap-2">
        <Stat
          label="정답"
          value={
            canShowScore ? (
              <>
                <span className="text-success">{safe.correct}</span>
                <span className="text-base text-ink-muted">/{totalCount}</span>
              </>
            ) : null
          }
        />
        <Stat label="정확도" value={accuracy === null ? null : <>{accuracy}%</>} />
        <Stat label="최고 콤보" value={<span className="text-accent">{safe.bestCombo}</span>} />
      </dl>
    </div>
  );
}

/** 값이 null이면 자리를 비우지 않고 —로 채운다 — 칸 수가 흔들리면 요약처럼 읽히지 않는다. */
function Stat({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-control bg-surface-muted px-2 py-3 text-center">
      <dt className="text-xs font-semibold text-ink-muted">{label}</dt>
      <dd className="mt-1 text-xl font-black text-ink">{value ?? "—"}</dd>
    </div>
  );
}

import { CircleCheckIcon, DogIcon } from "@/components/icons";
import { type CompletionSummary, clampCompletion } from "@/features/play/completion-params";

type CompletionCardProps = {
  summary: CompletionSummary;
  totalCount: number;
};

export function CompletionCard({ summary, totalCount }: CompletionCardProps) {
  const safe = clampCompletion(summary, totalCount);
  // 구키에서 마이그레이션된 세션은 answered를 복원할 수 없어 0이다.
  // 틀린 숫자를 보여주느니 줄을 감춘다(session-progress.ts migrateLegacy 주석 참고).
  const canShowScore = safe.answered === totalCount && totalCount > 0;

  return (
    <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
      <div className="flex items-center gap-2">
        <span className="grid h-8 w-8 place-items-center rounded-chip bg-success/10 text-success">
          <CircleCheckIcon className="h-5 w-5" />
        </span>
        <p className="text-sm font-bold text-ink">오늘의 학습 완료</p>
      </div>

      <dl className="mt-3 space-y-2">
        {canShowScore ? (
          <div className="flex items-center justify-between text-sm">
            <dt className="font-semibold text-ink-muted">정답</dt>
            <dd className="font-black text-ink">
              <span className="text-success">{safe.correct}</span> / {totalCount}
            </dd>
          </div>
        ) : null}
        <div className="flex items-center justify-between text-sm">
          <dt className="font-semibold text-ink-muted">최고 콤보</dt>
          <dd className="font-black text-ink">{safe.bestCombo}</dd>
        </div>
        <div className="flex items-center justify-between text-sm">
          <dt className="font-semibold text-ink-muted">보리</dt>
          {/*
            포만감 수치를 쓰지 않는다 — Mascot.MAX_FULLNESS(100) 캡 때문에
            먹이 1회가 항상 +20%인 게 아니다. 사실인 문장만 쓴다.
          */}
          <dd className="flex items-center gap-1.5 font-black text-ink">
            <DogIcon className="h-5 w-5" mood="happy" />
            밥을 줬어요
          </dd>
        </div>
      </dl>
    </div>
  );
}

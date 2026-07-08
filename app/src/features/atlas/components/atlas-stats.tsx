import type { AtlasStats } from "@/features/atlas/types";

type AtlasStatsRowProps = {
  stats: AtlasStats;
};

export function AtlasStatsRow({ stats }: AtlasStatsRowProps) {
  return (
    <div className="grid grid-cols-3 gap-3">
      <StatCard label="배운 노드" value={stats.learnedNodeCount} />
      <StatCard label="연결 수" value={stats.connectionCount} />
      <StatCard accent label="이번 주 확장" value={`+${stats.weeklyGrowth}`} />
    </div>
  );
}

function StatCard({
  label,
  value,
  accent = false,
}: {
  label: string;
  value: number | string;
  accent?: boolean;
}) {
  return (
    <div className="rounded-card border border-border bg-surface px-4 py-3 shadow-card">
      <p className="text-xs font-medium text-ink-muted">{label}</p>
      <p
        className={`mt-1 text-xl font-semibold tracking-tight ${accent ? "text-accent" : "text-ink"}`}
      >
        {accent ? (
          <span aria-hidden="true" className="mr-0.5">
            ↗
          </span>
        ) : null}
        {value}
      </p>
    </div>
  );
}

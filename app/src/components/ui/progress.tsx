export function Progress({
  value,
  max = 10,
  label = "진행률",
}: {
  value: number;
  max?: number;
  label?: string;
}) {
  const pct = Math.min(100, Math.max(0, (value / max) * 100));
  return (
    <div
      role="progressbar"
      aria-valuenow={value}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-label={label}
      className="h-2 w-full overflow-hidden rounded-chip bg-surface-muted"
    >
      <div className="h-full rounded-chip bg-primary transition-all" style={{ width: `${pct}%` }} />
    </div>
  );
}

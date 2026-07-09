import type { ReactNode } from "react";

type EmptyStateTone = "light" | "dark";

const TONE: Record<EmptyStateTone, { box: string; title: string; description: string }> = {
  light: {
    box: "border border-border bg-surface",
    title: "text-ink",
    description: "text-ink-muted",
  },
  dark: {
    box: "bg-graph-bg",
    title: "text-graph-fg",
    description: "text-graph-fg-muted",
  },
};

export function EmptyState({
  title,
  description,
  action,
  icon,
  tone = "light",
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  icon?: ReactNode;
  tone?: EmptyStateTone;
}) {
  const t = TONE[tone];
  return (
    <div
      className={`flex flex-col items-center gap-2 rounded-card px-6 py-10 text-center ${t.box}`}
    >
      {icon ? <div className="mb-1">{icon}</div> : null}
      <p className={`text-base font-semibold ${t.title}`}>{title}</p>
      {description ? <p className={`text-sm ${t.description}`}>{description}</p> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}

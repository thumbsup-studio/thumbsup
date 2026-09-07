import type { ReactNode } from "react";
import { Button } from "./button";

type FeedbackTone = "info" | "pending" | "error" | "success";

const TONE: Record<FeedbackTone, { box: string; mark: string; markColor: string }> = {
  info: { box: "bg-surface-muted text-ink", mark: "ℹ", markColor: "text-ink" },
  pending: { box: "bg-surface-muted text-ink-muted", mark: "⏳", markColor: "text-ink-muted" },
  // text-danger on bg-danger/10 fails WCAG AA (~3.9:1 on page bg) for the message text,
  // so the message uses text-ink; the icon mark keeps text-danger (only needs 3:1 as a
  // non-text UI indicator, which it clears) so the tone is still color-coded, not just ink.
  error: { box: "bg-danger/10 text-ink", mark: "⚠", markColor: "text-danger" },
  success: { box: "bg-success/10 text-ink", mark: "✓", markColor: "text-success" },
};

export function Feedback({
  tone = "info",
  onRetry,
  children,
}: {
  tone?: FeedbackTone;
  onRetry?: () => void;
  children: ReactNode;
}) {
  const t = TONE[tone];
  return (
    <div
      role="status"
      aria-live="polite"
      className={`flex items-center gap-3 rounded-control px-4 py-3 text-sm font-medium ${t.box}`}
    >
      <span aria-hidden="true" className={t.markColor}>
        {t.mark}
      </span>
      <span className="flex-1">{children}</span>
      {tone === "error" && onRetry ? (
        <Button variant="ghost" onClick={onRetry} className="text-sm">
          재시도
        </Button>
      ) : null}
    </div>
  );
}

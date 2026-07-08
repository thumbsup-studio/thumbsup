import type { ComponentProps } from "react";

type ChipTone = "neutral" | "primary" | "success" | "danger";

const TONE: Record<ChipTone, string> = {
  neutral: "bg-surface-muted text-ink-muted",
  primary: "bg-primary text-primary-fg",
  success: "bg-success text-primary-fg",
  danger: "bg-danger text-primary-fg",
};

type ChipProps = ComponentProps<"span"> & { tone?: ChipTone };

export function Chip({ tone = "neutral", className = "", ...props }: ChipProps) {
  return (
    <span
      className={`inline-flex items-center rounded-chip px-3 py-1 text-xs font-semibold ${TONE[tone]} ${className}`}
      {...props}
    />
  );
}

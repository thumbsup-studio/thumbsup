import type { ComponentProps } from "react";

export function Skeleton({ className = "", ...props }: ComponentProps<"div">) {
  return (
    <div
      aria-hidden="true"
      className={`motion-safe:animate-pulse rounded-control bg-surface-muted ${className}`}
      {...props}
    />
  );
}

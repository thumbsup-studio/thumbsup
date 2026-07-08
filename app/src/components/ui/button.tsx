import type { ComponentProps } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost";

const VARIANT: Record<ButtonVariant, string> = {
  primary: "bg-primary text-primary-fg",
  secondary: "bg-surface-muted text-ink",
  ghost: "bg-transparent text-ink",
};

type ButtonProps = ComponentProps<"button"> & {
  variant?: ButtonVariant;
  loading?: boolean;
};

export function Button({
  variant = "primary",
  loading = false,
  disabled,
  className = "",
  children,
  ...props
}: ButtonProps) {
  const isDisabled = disabled || loading;
  return (
    <button
      type="button"
      disabled={isDisabled}
      aria-busy={loading}
      className={`inline-flex min-h-12 items-center justify-center rounded-control px-4 py-3 text-base font-semibold transition-colors disabled:opacity-60 disabled:pointer-events-none ${VARIANT[variant]} ${className}`}
      {...props}
    >
      {loading ? "처리 중…" : children}
    </button>
  );
}

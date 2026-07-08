import type { ComponentProps, ReactNode } from "react";
import { SpinnerIcon } from "@/components/icons";

type ButtonVariant = "primary" | "secondary" | "ghost";

const VARIANT: Record<ButtonVariant, string> = {
  primary: "bg-primary text-primary-fg",
  secondary: "bg-surface-muted text-ink",
  ghost: "bg-transparent text-ink",
};

type ButtonProps = ComponentProps<"button"> & {
  variant?: ButtonVariant;
  loading?: boolean;
  /** 로딩 중 표시할 문구. 미지정 시 "처리 중…" */
  loadingText?: ReactNode;
};

export function Button({
  variant = "primary",
  loading = false,
  loadingText,
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
      className={`inline-flex min-h-12 items-center justify-center gap-2 rounded-control px-4 py-3 text-base font-semibold transition-colors disabled:opacity-60 disabled:pointer-events-none ${VARIANT[variant]} ${className}`}
      {...props}
    >
      {loading ? (
        <>
          <SpinnerIcon className="size-5" />
          {loadingText ?? "처리 중…"}
        </>
      ) : (
        children
      )}
    </button>
  );
}

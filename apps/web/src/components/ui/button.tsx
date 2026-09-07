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
  // active:scale-95 — 누르는 감각을 모든 버튼이 공유하게 한다(이슈 211).
  // prefers-reduced-motion은 globals.css의 전역 가드가 duration을 눌러 처리한다.
  const base =
    "inline-flex min-h-12 items-center justify-center gap-2 rounded-control px-4 py-3 text-base font-semibold transition duration-150 active:scale-95 disabled:opacity-60 disabled:pointer-events-none";

  return (
    <button
      type="button"
      disabled={isDisabled}
      aria-busy={loading}
      className={`${base} ${VARIANT[variant]} ${className}`}
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

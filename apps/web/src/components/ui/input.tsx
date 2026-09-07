"use client";

import { type ComponentProps, type ReactNode, useId, useState } from "react";
import { AlertCircleIcon, EyeIcon, EyeOffIcon } from "@/components/icons";

type InputProps = Omit<ComponentProps<"input">, "id"> & {
  label: string;
  /** 왼쪽 장식 아이콘(메일·자물쇠 등). `size-5` 정도로 전달. */
  leftIcon?: ReactNode;
  /**
   * 에러 표시. `true`면 테두리·아이콘만(문구는 폼 단위 Feedback이 담당),
   * 문자열이면 필드 하단에 그 문구까지 노출.
   */
  error?: boolean | string;
};

export function Input({
  label,
  leftIcon,
  error,
  type = "text",
  className = "",
  ...props
}: InputProps) {
  const id = useId();
  const errorId = `${id}-error`;
  const [reveal, setReveal] = useState(false);

  const isPassword = type === "password";
  const inputType = isPassword && reveal ? "text" : type;
  const hasError = Boolean(error);
  const errorMessage = typeof error === "string" ? error : undefined;

  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-sm font-semibold text-ink">
        {label}
      </label>
      <div
        className={`flex items-center gap-2 rounded-control border bg-surface px-3 transition-colors focus-within:border-primary ${
          hasError ? "border-danger" : "border-border"
        }`}
      >
        {leftIcon ? (
          <span
            className={`shrink-0 ${hasError ? "text-danger" : "text-ink-muted"}`}
            aria-hidden="true"
          >
            {leftIcon}
          </span>
        ) : null}
        <input
          id={id}
          type={inputType}
          aria-invalid={hasError}
          aria-describedby={errorMessage ? errorId : undefined}
          className={`min-h-11 min-w-0 flex-1 bg-transparent py-2 text-base text-ink outline-none placeholder:text-ink-muted ${className}`}
          {...props}
        />
        {/* 비밀번호는 에러 중에도 표시 토글을 유지(입력값 확인 가능). 에러는 테두리·좌측 아이콘·하단 메시지로 전달. */}
        {isPassword ? (
          <button
            type="button"
            onClick={() => setReveal((v) => !v)}
            aria-label={reveal ? "비밀번호 숨기기" : "비밀번호 표시"}
            aria-pressed={reveal}
            className="inline-flex size-11 shrink-0 items-center justify-center rounded-control text-ink-muted"
          >
            {reveal ? <EyeOffIcon className="size-5" /> : <EyeIcon className="size-5" />}
          </button>
        ) : hasError ? (
          <AlertCircleIcon className="size-5 shrink-0 text-danger" />
        ) : null}
      </div>
      {errorMessage ? (
        <p id={errorId} className="text-sm font-medium text-danger">
          {errorMessage}
        </p>
      ) : null}
    </div>
  );
}

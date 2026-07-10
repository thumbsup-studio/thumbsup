"use client";

import { type ReactNode, useEffect, useRef } from "react";

type BottomSheetProps = {
  open: boolean;
  onClose: () => void;
  /** 스크린리더용 시트 이름(aria-label). 시각 제목은 children에서 렌더한다. */
  title: string;
  children: ReactNode;
};

/**
 * 하단에서 올라오는 모달 시트. 오버레이 클릭·Esc로 닫히고, 열릴 때 시트로 포커스를 옮겼다가
 * 닫히면 직전 트리거로 포커스를 되돌린다. 배경 스크롤은 열려 있는 동안 잠근다.
 * 로그아웃 확인·의견 보내기 등 화면 위에 겹치는 흐름에서 재사용한다.
 */
export function BottomSheet({ open, onClose, title, children }: BottomSheetProps) {
  const sheetRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    const previouslyFocused = document.activeElement as HTMLElement | null;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };
    document.addEventListener("keydown", onKeyDown);

    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";
    sheetRef.current?.focus();

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = overflow;
      previouslyFocused?.focus();
    };
  }, [open, onClose]);

  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col justify-end">
      <button
        type="button"
        aria-label="닫기"
        onClick={onClose}
        className="absolute inset-0 bg-ink/40 motion-safe:animate-overlay-fade"
      />
      <div className="relative flex justify-center px-4 pb-4">
        <div
          ref={sheetRef}
          aria-label={title}
          aria-modal="true"
          className="w-full max-w-md rounded-card border border-border bg-surface p-6 shadow-card outline-none motion-safe:animate-sheet-rise"
          role="dialog"
          tabIndex={-1}
        >
          {children}
        </div>
      </div>
    </div>
  );
}

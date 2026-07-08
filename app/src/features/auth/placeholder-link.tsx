"use client";

import type { ReactNode } from "react";
import { useAppToast } from "@/providers/app-toast-provider";

/**
 * 아직 별도 이슈로 남은 화면(비밀번호 찾기·약관·도움말 등)으로 향하는 링크 자리.
 * 죽은 링크(404) 대신, 앱 관례대로 클릭 시 "준비 중" 토스트를 띄운다.
 * 라우트가 생기면 이 컴포넌트를 next/link로 교체한다.
 */
export function PlaceholderLink({
  message,
  className = "",
  children,
}: {
  /** 토스트로 보여줄 안내 문구(호출부가 조사까지 맞춰 전달) */
  message: string;
  className?: string;
  children: ReactNode;
}) {
  const { showToast } = useAppToast();
  return (
    <button type="button" onClick={() => showToast({ message })} className={className}>
      {children}
    </button>
  );
}

"use client";

import { useRouter } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { tokenStore } from "@/lib/api";

/**
 * 이미 로그인(토큰 보유)한 사용자를 홈으로 보내고, 미인증이 확인될 때까지 인증 화면(children)을
 * 렌더하지 않는다 — 리다이렉트 전 폼이 잠깐 노출되는 것을 막는다. 브라우저 재접속 시 자동 로그인
 * 유지(이슈 #1). 토큰은 localStorage(클라이언트 전용)라 마운트 후 확인한다.
 */
export function RedirectIfAuthenticated({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [showChildren, setShowChildren] = useState(false);

  useEffect(() => {
    if (tokenStore.isAuthenticated()) {
      router.replace("/");
    } else {
      setShowChildren(true);
    }
  }, [router]);

  return showChildren ? children : null;
}

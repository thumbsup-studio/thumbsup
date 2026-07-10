"use client";

import { useRouter } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { tokenStore } from "@/lib/api";

/**
 * 앱 진입 관문(이슈 #1). 로그인하지 않은 사용자는 /login으로 보내고, 인증이 확인될 때까지
 * 보호된 콘텐츠(children)를 렌더하지 않는다 — 리다이렉트 전 홈이 잠깐 노출되는 것을 막는다.
 * 토큰은 localStorage(클라이언트 전용)라 마운트 후 확인하므로, 확인 전에는 아무것도 그리지 않는다
 * (하드닝 단계에서 httpOnly cookie로 이전하면 SSR에서 판정 가능).
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    if (tokenStore.isAuthenticated()) {
      setAuthorized(true);
    } else {
      router.replace("/login");
    }
  }, [router]);

  return authorized ? children : null;
}

"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { tokenStore } from "@/lib/api";

/**
 * 앱 진입 관문(이슈 #1). 로그인하지 않은 사용자가 보호된 화면(홈)에 오면 로그인 화면으로 보낸다.
 * 토큰은 localStorage(클라이언트 전용)라 마운트 후 확인한다 — 미인증 시 화면이 잠깐 보인 뒤
 * 이동하는 플래시는 localStorage 저장 방식의 트레이드오프(하드닝 단계에서 httpOnly cookie로
 * 이전하면 SSR에서 판정 가능해 자연 해소).
 */
export function RequireAuth() {
  const router = useRouter();

  useEffect(() => {
    if (!tokenStore.isAuthenticated()) {
      router.replace("/login");
    }
  }, [router]);

  return null;
}

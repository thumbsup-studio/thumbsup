"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { tokenStore } from "@/lib/api";

/**
 * 이미 로그인(토큰 보유)한 사용자가 /login·/signup에 오면 홈으로 보낸다.
 * 브라우저 재접속(탭 닫고 다시 열기) 시 자동 로그인 유지(이슈 #1) — 세션이 있으면
 * 인증 화면을 건너뛴다. 토큰은 localStorage(클라이언트 전용)라 마운트 후 확인한다.
 */
export function RedirectIfAuthenticated() {
  const router = useRouter();

  useEffect(() => {
    if (tokenStore.isAuthenticated()) {
      router.replace("/");
    }
  }, [router]);

  return null;
}

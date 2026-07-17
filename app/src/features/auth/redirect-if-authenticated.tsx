"use client";

import { useRouter } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { fetchMe } from "@/features/profile/api";
import { tokenStore } from "@/lib/api";

/**
 * 이미 로그인(토큰 보유)한 사용자를 role에 따라 보내고(ADMIN→저작 대시보드, 그 외→홈),
 * 목적지가 정해질 때까지 인증 화면(children)을 렌더하지 않는다 — 리다이렉트 전 폼이 잠깐
 * 노출되는 것을 막는다. 브라우저 재접속 시 자동 로그인 유지(이슈 #1). 토큰이 무효(만료 등)면
 * 인증 화면을 노출해 재로그인하게 한다. 토큰은 localStorage(클라이언트 전용)라 마운트 후 확인한다.
 */
export function RedirectIfAuthenticated({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [showChildren, setShowChildren] = useState(false);

  useEffect(() => {
    let ignore = false;

    if (!tokenStore.isAuthenticated()) {
      setShowChildren(true);
      return;
    }

    fetchMe()
      .then((me) => {
        if (ignore) return;
        router.replace(me.role === "ADMIN" ? "/authoring" : "/");
      })
      .catch(() => {
        // 토큰이 무효면 인증 화면을 노출해 재로그인하게 한다(홈으로 튕겨 가두지 않는다).
        if (!ignore) setShowChildren(true);
      });

    return () => {
      ignore = true;
    };
  }, [router]);

  return showChildren ? children : null;
}

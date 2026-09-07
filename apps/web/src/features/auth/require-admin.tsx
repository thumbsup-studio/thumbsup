"use client";

import { useRouter } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { fetchMe } from "@/features/profile/api";
import { ApiError } from "@/lib/api";

/**
 * /authoring(문제 저작 대시보드) 진입 관문(이슈 176) — `GET /auth/me`의 role이 ADMIN인지 확인해
 * ADMIN이 아니면 홈으로 돌려보낸다. RequireAuth(토큰 존재)와 별개로 서버 권한을 재확인하는
 * 계층이라, RequireAuth 안쪽에 중첩해 써도 되고 이 컴포넌트 단독으로 써도 된다(둘 다
 * 인증 안 된 상태를 각자 처리 — 아래 401 분기가 그 대칭이다).
 */
export function RequireAdmin({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    let ignore = false;

    fetchMe()
      .then((me) => {
        if (ignore) return;
        if (me.role === "ADMIN") {
          setAuthorized(true);
        } else {
          router.replace("/");
        }
      })
      .catch((error) => {
        if (ignore) return;
        // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3). 그 외는 홈으로.
        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
        } else {
          router.replace("/");
        }
      });

    return () => {
      ignore = true;
    };
  }, [router]);

  return authorized ? children : null;
}

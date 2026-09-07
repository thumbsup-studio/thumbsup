"use client";

import { useRouter } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { getMyProfile } from "@/lib/api";

/** 독립 저작 앱의 모든 대시보드 라우트를 ADMIN에게만 노출한다. */
export function RequireAdmin({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    let ignore = false;
    getMyProfile()
      .then((profile) => {
        if (ignore) return;
        if (profile.role === "ADMIN") setAuthorized(true);
        else router.replace("/login");
      })
      .catch(() => {
        if (!ignore) router.replace("/login");
      });
    return () => {
      ignore = true;
    };
  }, [router]);

  return authorized ? children : null;
}

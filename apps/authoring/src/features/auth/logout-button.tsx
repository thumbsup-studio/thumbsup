"use client";

import { Button } from "@thumbsup/ui-web";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { logout } from "@/lib/api";

export function LogoutButton() {
  const router = useRouter();
  const [loggingOut, setLoggingOut] = useState(false);

  async function handleLogout() {
    setLoggingOut(true);
    await logout();
    router.replace("/login");
    router.refresh();
  }

  return (
    <Button
      variant="ghost"
      className="ml-auto px-3 text-sm"
      loading={loggingOut}
      loadingText="로그아웃 중…"
      onClick={handleLogout}
    >
      로그아웃
    </Button>
  );
}

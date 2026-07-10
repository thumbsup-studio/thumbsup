"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { fetchHome } from "@/features/home/api";
import { HomePage } from "@/features/home/components/home-page";
import { HomeSkeleton } from "@/features/home/components/home-skeleton";
import type { HomeData } from "@/features/home/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; data: HomeData };

/**
 * 홈 진입점(이슈 112) — RequireAuth 게이트 통과 후 마운트되므로 토큰이 확보된 상태에서
 * GET /api/v1/home을 호출해 실데이터로 HomePage를 그린다. 로딩·에러 상태를 함께 처리한다.
 */
export function HomeScreen() {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const data = await fetchHome();
      setState({ status: "success", data });
    } catch (error) {
      // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3). 그 외는 재시도 가능한 에러.
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      setState({ status: "error" });
    }
  }, [router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <HomeSkeleton />;
  }

  if (state.status === "error") {
    return (
      <main className="flex min-h-screen flex-col justify-center bg-bg px-4 py-6 text-ink sm:px-6">
        <div className="mx-auto w-full max-w-md">
          <EmptyState
            title="홈 정보를 불러오지 못했어요"
            description="잠시 후 다시 시도해 주세요."
            action={
              <Button variant="secondary" onClick={() => void load()}>
                다시 시도
              </Button>
            }
          />
        </div>
      </main>
    );
  }

  return <HomePage data={state.data} now={new Date().toISOString()} />;
}

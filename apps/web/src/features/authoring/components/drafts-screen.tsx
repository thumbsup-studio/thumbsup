"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { getDrafts } from "@/features/authoring/api";
import { GenerateSheet } from "@/features/authoring/components/generate-sheet";
import type { DraftStatus, DraftSummary } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; drafts: DraftSummary[] };

const ORIGIN_LABEL: Record<DraftSummary["origin"], string> = {
  NEW: "신규",
  IMPROVE: "개선",
  OUTLINE_STEP: "뼈대 스텝",
};
const STATUS_LABEL: Record<DraftStatus, string> = { DRAFT: "검토중", APPROVED: "승인됨" };

/** Draft 목록 화면 — status 필터(DRAFT 기본/APPROVED)로 조회, "문제 생성"으로 새 draft를 만든다. */
export function DraftsScreen() {
  const router = useRouter();
  const [filter, setFilter] = useState<DraftStatus>("DRAFT");
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [sheetOpen, setSheetOpen] = useState(false);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const drafts = await getDrafts(filter);
      setState({ status: "success", drafts });
    } catch (error) {
      // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3). 그 외는 재시도 가능한 에러.
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      // 권한 없음(403) — RequireAdmin이 이미 진입을 막지만, role이 세션 중 바뀌는 경우를 대비한 방어.
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [filter, router]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-2">
          <Button
            aria-pressed={filter === "DRAFT"}
            onClick={() => setFilter("DRAFT")}
            variant={filter === "DRAFT" ? "primary" : "secondary"}
          >
            검토중
          </Button>
          <Button
            aria-pressed={filter === "APPROVED"}
            onClick={() => setFilter("APPROVED")}
            variant={filter === "APPROVED" ? "primary" : "secondary"}
          >
            승인됨
          </Button>
        </div>
        <Button onClick={() => setSheetOpen(true)}>문제 생성</Button>
      </div>

      {state.status === "loading" ? <DraftsSkeleton /> : null}

      {state.status === "error" ? (
        <EmptyState
          action={
            <Button onClick={() => void load()} variant="secondary">
              다시 시도
            </Button>
          }
          description="잠시 후 다시 시도해 주세요."
          title="목록을 불러오지 못했어요"
        />
      ) : null}

      {state.status === "success" ? (
        state.drafts.length === 0 ? (
          <EmptyState
            description="문제 생성 버튼으로 새 draft를 만들어 보세요."
            title="draft가 없어요"
          />
        ) : (
          <ul className="flex flex-col gap-3">
            {state.drafts.map((draft) => (
              <li key={draft.draftId}>
                <Link className="block" href={`/authoring/drafts/${draft.draftId}`}>
                  <Card className="flex items-center justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-base font-semibold text-ink">{draft.topic}</p>
                      <p className="mt-1 text-sm text-ink-muted">검수 {draft.revisionCount}회</p>
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <Chip tone={draft.origin === "NEW" ? "primary" : "neutral"}>
                        {ORIGIN_LABEL[draft.origin]}
                      </Chip>
                      <Chip tone={draft.status === "APPROVED" ? "success" : "neutral"}>
                        {STATUS_LABEL[draft.status]}
                      </Chip>
                    </div>
                  </Card>
                </Link>
              </li>
            ))}
          </ul>
        )
      ) : null}

      <GenerateSheet onClose={() => setSheetOpen(false)} open={sheetOpen} />
    </div>
  );
}

function DraftsSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-20 w-full" key={row} />
      ))}
    </div>
  );
}

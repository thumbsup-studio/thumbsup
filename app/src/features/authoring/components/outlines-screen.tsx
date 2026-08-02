"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { getOutlines } from "@/features/authoring/api";
import { NewOutlineSheet } from "@/features/authoring/components/new-outline-sheet";
import type { OutlineStatus, OutlineSummary } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; outlines: OutlineSummary[] };

const STATUS_LABEL: Record<OutlineStatus, string> = {
  DRAFT: "작업 중",
  PUBLISHED: "발행됨",
};

export function OutlinesScreen() {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [sheetOpen, setSheetOpen] = useState(false);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const outlines = await getOutlines();
      setState({ status: "success", outlines });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [router]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-ink">저작 코스</h2>
          <p className="mt-1 text-sm text-ink-muted">발행 전 코스는 학습자에게 보이지 않아요</p>
        </div>
        <Button onClick={() => setSheetOpen(true)}>새 코스 만들기</Button>
      </header>

      {state.status === "loading" ? <OutlinesSkeleton /> : null}

      {state.status === "error" ? (
        <EmptyState
          action={
            <Button onClick={() => void load()} variant="secondary">
              다시 시도
            </Button>
          }
          description="잠시 후 다시 시도해 주세요."
          title="코스 목록을 불러오지 못했어요"
        />
      ) : null}

      {state.status === "success" ? (
        state.outlines.length === 0 ? (
          <EmptyState
            description="새 코스 만들기로 목차를 붙여넣어 시작해 보세요."
            title="저작 중인 코스가 없어요"
          />
        ) : (
          <ul className="flex flex-col gap-3">
            {state.outlines.map((outline) => (
              <li key={outline.outlineId}>
                <OutlineCard outline={outline} />
              </li>
            ))}
          </ul>
        )
      ) : null}

      <NewOutlineSheet onClose={() => setSheetOpen(false)} open={sheetOpen} />
    </div>
  );
}

function OutlineCard({ outline }: { outline: OutlineSummary }) {
  const content = (
    <Card className="flex flex-col gap-4 transition-colors hover:border-primary">
      <div className="flex flex-wrap items-center gap-2">
        <p className="min-w-0 flex-1 truncate text-base font-semibold text-ink">{outline.title}</p>
        <Chip tone="neutral">{outline.category}</Chip>
        <Chip tone={outline.status === "PUBLISHED" ? "success" : "neutral"}>
          {STATUS_LABEL[outline.status]}
        </Chip>
      </div>

      {outline.stepCount === 0 ? (
        <Chip className="self-start" tone="neutral">
          뼈대 생성 필요
        </Chip>
      ) : (
        <div className="flex flex-col gap-2">
          <Progress
            label={`${outline.title} 스텝 진행률`}
            max={Math.max(outline.stepCount, 1)}
            value={outline.approvedStepCount}
          />
          <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
            <span className="font-semibold text-ink">
              스텝 {outline.approvedStepCount}/{outline.stepCount} 채움
            </span>
            <span className="text-ink-muted">
              {outline.status === "DRAFT" ? "· 비공개" : "· 학습자에게 공개 중"}
            </span>
          </div>
        </div>
      )}
    </Card>
  );

  return outline.status === "DRAFT" ? (
    <Link className="block" href={`/authoring/outlines/${outline.outlineId}`}>
      {content}
    </Link>
  ) : (
    content
  );
}

function OutlinesSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-32 w-full" key={row} />
      ))}
    </div>
  );
}

"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getDraft } from "@/features/authoring/api";
import { ApproveSheet } from "@/features/authoring/components/approve-sheet";
import { QuizDetailCard } from "@/features/authoring/components/quiz-detail-card";
import { ReviewSheet } from "@/features/authoring/components/review-sheet";
import type { DraftDetail, DraftOrigin, DraftStatus } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; draft: DraftDetail };

const ORIGIN_LABEL: Record<DraftOrigin, string> = {
  NEW: "신규",
  IMPROVE: "개선",
  OUTLINE_STEP: "스텝",
};
const STATUS_LABEL: Record<DraftStatus, string> = { DRAFT: "검토중", APPROVED: "승인됨" };

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Draft 상세 화면 — payload 미리보기, 검수 이력, 검수/승인 액션(DRAFT 상태에서만 노출). */
export function DraftDetailScreen({ draftId }: { draftId: number }) {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [reviewOpen, setReviewOpen] = useState(false);
  const [approveOpen, setApproveOpen] = useState(false);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const draft = await getDraft(draftId);
      setState({ status: "success", draft });
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
  }, [draftId, router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <DraftDetailSkeleton />;
  }

  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        draft를 불러오지 못했어요.
      </Feedback>
    );
  }

  const { draft } = state;
  const sortedRevisions = [...draft.revisions].sort((a, b) => b.revisionNo - a.revisionNo);

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-wrap items-center gap-3">
        <h2 className="text-xl font-bold text-ink">{draft.topic}</h2>
        <Chip tone={draft.origin === "NEW" ? "primary" : "neutral"}>
          {ORIGIN_LABEL[draft.origin]}
        </Chip>
        <Chip tone={draft.status === "APPROVED" ? "success" : "neutral"}>
          {STATUS_LABEL[draft.status]}
        </Chip>
      </header>

      <section className="flex flex-col gap-3">
        {draft.payload.quizzes.map((quiz, index) => (
          <QuizDetailCard
            key={`${quiz.type}-${quiz.questionText}`}
            quiz={quiz}
            slotOrder={index + 1}
          />
        ))}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-base font-bold text-ink">검수 이력</h3>
        {sortedRevisions.length === 0 ? (
          <p className="text-sm text-ink-muted">아직 검수 이력이 없어요.</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {sortedRevisions.map((revision) => (
              <li key={revision.revisionNo}>
                <Card className="flex flex-col gap-1">
                  <p className="text-xs font-semibold text-ink-muted">
                    #{revision.revisionNo} · {formatDateTime(revision.createdAt)}
                  </p>
                  <p className="text-sm text-ink">{revision.reviewSummary ?? "요약 없음"}</p>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>

      {draft.status === "DRAFT" ? (
        <div className="flex gap-3">
          <Button onClick={() => setReviewOpen(true)} variant="secondary">
            검수 시작
          </Button>
          <Button onClick={() => setApproveOpen(true)}>승인</Button>
        </div>
      ) : null}

      <ReviewSheet draftId={draftId} onClose={() => setReviewOpen(false)} open={reviewOpen} />
      <ApproveSheet
        draftId={draftId}
        onApproved={() => void load()}
        onClose={() => setApproveOpen(false)}
        open={approveOpen}
      />
    </div>
  );
}

function DraftDetailSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-7 w-40" />
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-24 w-full" key={row} />
      ))}
    </div>
  );
}

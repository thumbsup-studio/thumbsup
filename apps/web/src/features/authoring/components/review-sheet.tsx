"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { reviewDraft } from "@/features/authoring/api";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

/**
 * 검수 시작 바텀시트 — 피드백(선택)을 받아 REVIEW 잡을 만들고, 성공하면 잡 실행 화면으로 이동한다.
 * feedback-sheet.tsx/generate-sheet.tsx와 동일한 폼 패턴(전송 중 loading, 실패 시 입력값 유지 + 에러 토스트).
 */
export function ReviewSheet({
  draftId,
  open,
  onClose,
}: {
  draftId: number;
  open: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [feedback, setFeedback] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    if (submitting) {
      return;
    }
    setSubmitting(true);
    try {
      const trimmed = feedback.trim();
      const { jobId } = await reviewDraft(draftId, trimmed.length > 0 ? trimmed : undefined);
      setFeedback("");
      onClose();
      router.push(`/authoring/jobs/${jobId}`);
    } catch (error) {
      if (error instanceof ApiError && error.code === "AUTHORING_DRAFT_JOB_ACTIVE") {
        showToast({ message: "진행 중인 잡이 있습니다.", tone: "error" });
      } else {
        const message =
          error instanceof ApiError
            ? error.message
            : "검수 요청에 실패했어요. 잠시 후 다시 시도해 주세요.";
        showToast({ message, tone: "error" });
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="검수 시작">
      <p className="text-xl font-extrabold text-ink">검수 시작</p>
      <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
        피드백을 남기면 검수에 반영돼요. 비워두면 일반 검수로 진행돼요.
      </p>
      <textarea
        aria-label="피드백"
        className="mt-4 w-full resize-none rounded-control border border-border bg-surface-muted p-3.5 text-base text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
        onChange={(event) => setFeedback(event.target.value)}
        placeholder="예: 선지 순서를 바꿔주세요 (선택)"
        rows={4}
        value={feedback}
      />
      <Button
        className="mt-4 w-full"
        loading={submitting}
        loadingText="요청 중…"
        onClick={() => void submit()}
      >
        검수 요청
      </Button>
    </BottomSheet>
  );
}

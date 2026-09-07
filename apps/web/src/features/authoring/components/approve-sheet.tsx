"use client";

import { useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { Feedback } from "@/components/ui/feedback";
import { approveDraft } from "@/features/authoring/api";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

/** 승인 확인 바텀시트 — 즉시 라이브 반영됨을 경고하고, 명시적 확인 후에만 approveDraft를 호출한다. */
export function ApproveSheet({
  draftId,
  open,
  onClose,
  onApproved,
}: {
  draftId: number;
  open: boolean;
  onClose: () => void;
  onApproved: () => void;
}) {
  const { showToast } = useAppToast();
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    if (submitting) {
      return;
    }
    setSubmitting(true);
    try {
      await approveDraft(draftId);
      onClose();
      showToast({ message: "승인했어요. 문제가 라이브에 반영됐어요." });
      onApproved();
    } catch (error) {
      if (error instanceof ApiError && error.code === "AUTHORING_DRAFT_JOB_ACTIVE") {
        showToast({ message: "진행 중인 잡이 있습니다.", tone: "error" });
      } else {
        const message =
          error instanceof ApiError
            ? error.message
            : "승인에 실패했어요. 잠시 후 다시 시도해 주세요.";
        showToast({ message, tone: "error" });
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="승인">
      <p className="text-xl font-extrabold text-ink">이 draft를 승인할까요?</p>
      <div className="mt-4">
        <Feedback tone="error">승인 즉시 라이브 반영돼요. 되돌릴 수 없어요.</Feedback>
      </div>
      <div className="mt-4 flex gap-3">
        <Button className="flex-1" onClick={onClose} variant="secondary">
          취소
        </Button>
        <Button
          className="flex-1"
          loading={submitting}
          loadingText="승인 중…"
          onClick={() => void submit()}
        >
          승인하기
        </Button>
      </div>
    </BottomSheet>
  );
}

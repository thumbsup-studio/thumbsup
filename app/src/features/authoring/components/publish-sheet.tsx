"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { publishOutline } from "@/features/authoring/api";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

export function PublishSheet({
  outlineId,
  stepCount,
  open,
  onClose,
}: {
  outlineId: number;
  stepCount: number;
  open: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    if (submitting) {
      return;
    }
    setSubmitting(true);
    try {
      await publishOutline(outlineId);
      onClose();
      showToast({ message: "코스를 발행했어요. 학습자에게 공개됐어요." });
      router.push("/authoring/outlines");
    } catch (error) {
      const message =
        error instanceof ApiError
          ? error.message
          : "코스 발행에 실패했어요. 잠시 후 다시 시도해 주세요.";
      showToast({ message, tone: "error" });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="코스를 발행할까요?">
      <p className="text-xl font-extrabold text-ink">코스를 발행할까요?</p>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        발행하면 학습자에게 즉시 공개돼요. 발행 전까지는 누구에게도 보이지 않아요.
      </p>
      <p className="mt-4 text-sm font-semibold text-ink">
        스텝 {stepCount}개 · 문제 draft 전부 승인 완료
      </p>
      <div className="mt-4 flex gap-3">
        <Button className="flex-1" onClick={onClose} variant="secondary">
          취소
        </Button>
        <Button
          className="flex-1"
          loading={submitting}
          loadingText="발행 중…"
          onClick={() => void submit()}
        >
          발행하기
        </Button>
      </div>
    </BottomSheet>
  );
}

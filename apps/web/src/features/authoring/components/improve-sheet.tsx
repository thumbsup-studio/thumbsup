"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { improveQuiz } from "@/features/authoring/api";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

/**
 * 문제 개선 바텀시트 — 지시(필수)를 받아 REVIEW 잡을 만들고, 성공하면 잡 실행 화면으로 이동한다.
 * review-sheet.tsx/generate-sheet.tsx와 동일한 폼 패턴이되, 지시는 생략 불가(공백만이면 제출 불가).
 */
export function ImproveSheet({
  quizId,
  open,
  onClose,
}: {
  quizId: number | null;
  open: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [instruction, setInstruction] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const trimmed = instruction.trim();
  const canSubmit = trimmed.length > 0 && !submitting && quizId !== null;

  const submit = async () => {
    if (!canSubmit || quizId === null) {
      return;
    }
    setSubmitting(true);
    try {
      const { jobId } = await improveQuiz(quizId, trimmed);
      setInstruction("");
      onClose();
      router.push(`/authoring/jobs/${jobId}`);
    } catch (error) {
      if (error instanceof ApiError && error.code === "AUTHORING_IMPROVE_DRAFT_EXISTS") {
        showToast({ message: "이 문제에 이미 열린 개선 draft가 있습니다.", tone: "error" });
      } else {
        const message =
          error instanceof ApiError
            ? error.message
            : "개선 요청에 실패했어요. 잠시 후 다시 시도해 주세요.";
        showToast({ message, tone: "error" });
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="문제 개선">
      <p className="text-xl font-extrabold text-ink">문제 개선</p>
      <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
        어떻게 개선할지 지시를 입력해 주세요.
      </p>
      <textarea
        aria-label="개선 지시"
        className="mt-4 w-full resize-none rounded-control border border-border bg-surface-muted p-3.5 text-base text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
        onChange={(event) => setInstruction(event.target.value)}
        placeholder="예: 설명을 더 쉽게 풀어써 주세요"
        rows={4}
        value={instruction}
      />
      <Button
        className="mt-4 w-full"
        disabled={!canSubmit}
        loading={submitting}
        loadingText="요청 중…"
        onClick={() => void submit()}
      >
        개선 요청
      </Button>
    </BottomSheet>
  );
}

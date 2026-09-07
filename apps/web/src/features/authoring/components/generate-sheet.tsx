"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { generateDraft } from "@/features/authoring/api";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

/**
 * 문제 생성 바텀시트 — 주제를 받아 GENERATE 잡을 만들고, 성공하면 잡 실행 화면으로 이동한다.
 * feedback-sheet.tsx의 폼 패턴(전송 중 loading, 실패 시 입력값 유지 + 에러 토스트)을 그대로 따른다.
 */
export function GenerateSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [topic, setTopic] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const trimmed = topic.trim();
  const canSubmit = trimmed.length > 0 && !submitting;

  const submit = async () => {
    if (!canSubmit) {
      return;
    }
    setSubmitting(true);
    try {
      const { jobId } = await generateDraft(trimmed);
      setTopic("");
      onClose();
      router.push(`/authoring/jobs/${jobId}`);
    } catch (error) {
      // 실패하면 입력값을 유지해 다시 시도할 수 있게 한다.
      const message =
        error instanceof ApiError
          ? error.message
          : "생성 요청에 실패했어요. 잠시 후 다시 시도해 주세요.";
      showToast({ message, tone: "error" });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="문제 생성">
      <p className="text-xl font-extrabold text-ink">문제 생성</p>
      <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
        주제를 입력하면 문제 5개를 새로 생성해요.
      </p>
      <div className="mt-4">
        <Input
          label="주제"
          onChange={(event) => setTopic(event.target.value)}
          placeholder="예: 운영체제"
          value={topic}
        />
      </div>
      <Button
        aria-busy={submitting}
        className="mt-4 w-full"
        disabled={!canSubmit}
        loading={submitting}
        loadingText="생성 요청 중…"
        onClick={() => void submit()}
      >
        생성 시작
      </Button>
    </BottomSheet>
  );
}

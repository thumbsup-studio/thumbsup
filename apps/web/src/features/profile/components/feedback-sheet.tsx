"use client";

import { useEffect, useRef, useState } from "react";
import { SpinnerIcon } from "@/components/icons";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { ApiError, sendFeedback } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

const MAX_LENGTH = 1000;

/**
 * 의견 보내기 바텀시트 — 자유 텍스트를 서버(POST /feedbacks)로 전송한다.
 * 빈/공백은 전송 불가, 전송 중 버튼 비활성(중복 방지), 실패 시 입력값을 유지한다(거짓 성공 금지).
 */
export function FeedbackSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { showToast } = useAppToast();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [content, setContent] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    if (open) {
      // 시트가 열리면 입력란으로 포커스를 옮겨 바로 작성할 수 있게 한다.
      textareaRef.current?.focus();
    }
  }, [open]);

  const trimmed = content.trim();
  const canSend = trimmed.length > 0 && content.length <= MAX_LENGTH && !sending;

  const submit = async () => {
    if (!canSend) {
      return;
    }
    setSending(true);
    try {
      await sendFeedback(trimmed);
      setContent("");
      onClose();
      showToast({ message: "소중한 의견 고마워요. 잘 전달했어요." });
    } catch (error) {
      // 실패하면 입력값을 유지해 다시 시도할 수 있게 한다.
      const message =
        error instanceof ApiError
          ? error.message
          : "전송에 실패했어요. 잠시 후 다시 시도해 주세요.";
      showToast({ message, tone: "error" });
    } finally {
      setSending(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="의견 보내기">
      <p className="text-xl font-extrabold text-ink">의견 보내기</p>
      <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
        서비스에 바라는 점이나 불편한 점을 자유롭게 남겨 주세요.
      </p>
      <textarea
        ref={textareaRef}
        aria-label="의견 내용"
        className="mt-4 w-full resize-none rounded-control border border-border bg-surface-muted p-3.5 text-base text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
        maxLength={MAX_LENGTH}
        onChange={(event) => setContent(event.target.value)}
        placeholder="의견을 입력해 주세요"
        rows={5}
        value={content}
      />
      <div className="mt-1 text-right text-xs text-ink-muted">
        {content.length}/{MAX_LENGTH}
      </div>
      <button
        aria-busy={sending}
        className="mt-4 flex min-h-14 w-full items-center justify-center gap-2 rounded-control bg-primary text-base font-bold text-primary-fg transition-colors hover:bg-primary/90 disabled:pointer-events-none disabled:opacity-60"
        disabled={!canSend}
        onClick={() => void submit()}
        type="button"
      >
        {sending ? (
          <>
            <SpinnerIcon className="size-5" />
            보내는 중…
          </>
        ) : (
          "보내기"
        )}
      </button>
    </BottomSheet>
  );
}

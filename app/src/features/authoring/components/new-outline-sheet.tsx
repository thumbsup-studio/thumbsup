"use client";

import { useRouter } from "next/navigation";
import { useId, useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createOutline } from "@/features/authoring/api";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

export function NewOutlineSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const tocId = useId();
  const [title, setTitle] = useState("");
  const [category, setCategory] = useState("");
  const [toc, setToc] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const trimmedTitle = title.trim();
  const trimmedCategory = category.trim();
  const trimmedToc = toc.trim();
  const canSubmit =
    trimmedTitle.length > 0 && trimmedCategory.length > 0 && trimmedToc.length > 0 && !submitting;

  const submit = async () => {
    if (!canSubmit) {
      return;
    }
    setSubmitting(true);
    try {
      const { jobId } = await createOutline(trimmedTitle, trimmedCategory, trimmedToc);
      setTitle("");
      setCategory("");
      setToc("");
      onClose();
      router.push(`/authoring/jobs/${jobId}`);
    } catch (error) {
      const message =
        error instanceof ApiError
          ? error.message
          : "코스 생성 요청에 실패했어요. 잠시 후 다시 시도해 주세요.";
      showToast({ message, tone: "error" });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open} onClose={onClose} title="새 코스 만들기">
      <p className="text-xl font-extrabold text-ink">새 코스 만들기</p>
      <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
        AI가 목차를 학습 순서에 맞는 스텝 목록으로 재구성해요.
      </p>
      <div className="mt-4 flex flex-col gap-3">
        <Input
          label="제목"
          onChange={(event) => setTitle(event.target.value)}
          placeholder="예: 네트워크 기초"
          value={title}
        />
        <Input
          label="분류"
          onChange={(event) => setCategory(event.target.value)}
          placeholder="예: 네트워크"
          value={category}
        />
        <div className="flex flex-col gap-1.5">
          <label className="text-sm font-semibold text-ink" htmlFor={tocId}>
            목차 붙여넣기
          </label>
          <textarea
            aria-describedby={`${tocId}-description`}
            className="min-h-48 w-full resize-y rounded-control border border-border bg-surface-muted p-3.5 text-base text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
            id={tocId}
            onChange={(event) => setToc(event.target.value)}
            placeholder={
              "도서 소개 페이지의 목차를 그대로 붙여넣으세요\n\n예)\n1장 네트워크 첫걸음\n  1-1 네트워크의 구조\n2장 OSI 모델과 TCP/IP 모델"
            }
            value={toc}
          />
          <p className="text-sm text-ink-muted" id={`${tocId}-description`}>
            목차를 그대로 붙여넣으면 AI가 스텝으로 정리해요.
          </p>
        </div>
      </div>
      <Button
        className="mt-4 w-full"
        disabled={!canSubmit}
        loading={submitting}
        loadingText="생성 요청 중…"
        onClick={() => void submit()}
      >
        뼈대 생성 시작
      </Button>
    </BottomSheet>
  );
}

"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { generateStepQuizzes } from "@/features/authoring/api";
import type { OutlineStep, QuizPreset } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

const PRESETS: Array<{ id: QuizPreset; name: string; description: string }> = [
  { id: "BASIC_5", name: "기본 5문제", description: "OX 2 · 객관식 2 · 빈칸 1" },
  { id: "LIGHT_3", name: "가볍게 3문제", description: "OX 1 · 객관식 1 · 빈칸 1" },
  { id: "DEEP_7", name: "심화 7문제", description: "OX 2 · 객관식 3 · 빈칸 2" },
];

export function PresetSheet({
  open,
  step,
  onClose,
}: {
  open: boolean;
  step: OutlineStep | null;
  onClose: () => void;
}) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [preset, setPreset] = useState<QuizPreset>("BASIC_5");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (open) {
      setPreset("BASIC_5");
    }
  }, [open]);

  const submit = async () => {
    if (!step || submitting) {
      return;
    }
    setSubmitting(true);
    try {
      const { jobId } = await generateStepQuizzes(step.stepId, preset);
      onClose();
      router.push(`/authoring/jobs/${jobId}`);
    } catch (error) {
      const message =
        error instanceof ApiError
          ? error.message
          : "문제 생성 요청에 실패했어요. 잠시 후 다시 시도해 주세요.";
      showToast({ message, tone: "error" });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BottomSheet open={open && step !== null} onClose={onClose} title="문제 생성 프리셋">
      {step ? (
        <>
          <p className="text-xl font-extrabold text-ink">문제 생성 프리셋</p>
          <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
            스텝 &quot;{step.topic}&quot;을 채울 문제 세트를 선택하세요.
          </p>
          <div className="mt-4 flex flex-col gap-2">
            {PRESETS.map((option) => {
              const selected = preset === option.id;
              return (
                <button
                  aria-pressed={selected}
                  className={`flex min-h-20 flex-col items-start justify-center gap-1 rounded-control border px-4 py-3 text-left transition-colors ${
                    selected
                      ? "border-primary bg-primary/10 text-ink"
                      : "border-border bg-surface text-ink"
                  }`}
                  key={option.id}
                  onClick={() => setPreset(option.id)}
                  type="button"
                >
                  <span className="text-base font-semibold">{option.name}</span>
                  <span className="text-sm text-ink-muted">{option.description}</span>
                </button>
              );
            })}
          </div>
          <Button
            className="mt-4 w-full"
            loading={submitting}
            loadingText="생성 요청 중…"
            onClick={() => void submit()}
          >
            생성 시작
          </Button>
        </>
      ) : null}
    </BottomSheet>
  );
}

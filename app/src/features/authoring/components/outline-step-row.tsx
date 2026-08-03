"use client";

import Link from "next/link";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { Input } from "@/components/ui/input";
import type { OutlineStep, OutlineStepFillState } from "@/features/authoring/types";

const FILL_STATE_LABEL: Record<OutlineStepFillState, string> = {
  EMPTY: "비어있음",
  GENERATING: "생성 중",
  REVIEWING: "검토중",
  APPROVED: "승인됨",
};

const FILL_STATE_TONE: Record<OutlineStepFillState, "neutral" | "primary" | "success"> = {
  EMPTY: "neutral",
  GENERATING: "primary",
  REVIEWING: "neutral",
  APPROVED: "success",
};

type OutlineStepRowProps = {
  outlineId: number;
  step: OutlineStep;
  isFirst: boolean;
  isLast: boolean;
  readOnly?: boolean;
  busyAction: string | null;
  onGenerate: (step: OutlineStep) => void;
  onUpdateTopic: (stepId: number, topic: string) => Promise<void>;
  onReorder: (stepId: number, direction: "UP" | "DOWN") => Promise<void>;
  onDelete: (stepId: number) => Promise<void>;
};

export function OutlineStepRow({
  outlineId,
  step,
  isFirst,
  isLast,
  readOnly = false,
  busyAction,
  onGenerate,
  onUpdateTopic,
  onReorder,
  onDelete,
}: OutlineStepRowProps) {
  const [editing, setEditing] = useState(false);
  const [topicDraft, setTopicDraft] = useState(step.topic);
  const topicAction = `topic-${step.stepId}`;
  const isTopicBusy = busyAction === topicAction;

  const startEditing = () => {
    setTopicDraft(step.topic);
    setEditing(true);
  };

  const commitTopic = async () => {
    setEditing(false);
    const nextTopic = topicDraft.trim();
    if (!nextTopic || nextTopic === step.topic || isTopicBusy) {
      setTopicDraft(step.topic);
      return;
    }
    await onUpdateTopic(step.stepId, nextTopic);
  };

  const actionContent =
    step.fillState === "EMPTY" ? (
      <Button onClick={() => onGenerate(step)}>문제 생성</Button>
    ) : step.fillState === "GENERATING" && step.activeJobId !== null ? (
      <Link
        className="inline-flex min-h-12 items-center justify-center rounded-control bg-surface-muted px-4 py-3 text-base font-semibold text-ink"
        href={`/authoring/jobs/${step.activeJobId}`}
      >
        터미널 보기
      </Link>
    ) : step.fillState === "REVIEWING" && step.draftId !== null ? (
      <Link
        className="inline-flex min-h-12 items-center justify-center rounded-control bg-surface-muted px-4 py-3 text-base font-semibold text-ink"
        href={`/authoring/drafts/${step.draftId}?outlineId=${outlineId}`}
      >
        draft 검수하기
      </Link>
    ) : step.fillState === "APPROVED" ? (
      <span className="text-sm font-semibold text-success">✓ 완료</span>
    ) : null;

  return (
    <Card className="flex flex-col gap-3">
      <div className="flex items-start gap-3">
        <span className="shrink-0 pt-2 text-sm font-bold text-primary">
          {String(step.orderNo).padStart(2, "0")}
        </span>
        <div className="min-w-0 flex-1">
          {editing ? (
            <Input
              autoFocus
              className="text-sm"
              disabled={isTopicBusy}
              label="스텝 주제"
              onBlur={() => void commitTopic()}
              onChange={(event) => setTopicDraft(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  event.currentTarget.blur();
                }
              }}
              value={topicDraft}
            />
          ) : (
            <button
              className="min-h-12 max-w-full text-left text-base font-semibold text-ink"
              disabled={readOnly}
              onClick={startEditing}
              type="button"
            >
              <span className="line-clamp-2">{step.topic}</span>
            </button>
          )}
          {step.learningGoal ? (
            <p className="mt-1 text-sm leading-relaxed text-ink-muted">{step.learningGoal}</p>
          ) : null}
        </div>
        <Chip tone={FILL_STATE_TONE[step.fillState]}>{FILL_STATE_LABEL[step.fillState]}</Chip>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2 border-t border-border pt-3">
        <div>{actionContent}</div>
        {!readOnly ? (
          <div className="flex flex-wrap items-center gap-2">
            <Button
              aria-label={`${step.orderNo}번 스텝 위로`}
              disabled={isFirst || busyAction !== null}
              loading={busyAction === `up-${step.stepId}`}
              onClick={() => void onReorder(step.stepId, "UP")}
              variant="ghost"
            >
              ↑
            </Button>
            <Button
              aria-label={`${step.orderNo}번 스텝 아래로`}
              disabled={isLast || busyAction !== null}
              loading={busyAction === `down-${step.stepId}`}
              onClick={() => void onReorder(step.stepId, "DOWN")}
              variant="ghost"
            >
              ↓
            </Button>
            <Button
              aria-label={`${step.orderNo}번 스텝 삭제`}
              loading={busyAction === `delete-${step.stepId}`}
              onClick={() => void onDelete(step.stepId)}
              variant="ghost"
            >
              삭제
            </Button>
          </div>
        ) : null}
      </div>
    </Card>
  );
}

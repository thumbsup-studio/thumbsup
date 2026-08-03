"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import {
  addOutlineStep,
  deleteOutlineStep,
  getOutline,
  regenerateOutline,
  reorderOutlineStep,
  updateOutline,
  updateOutlineStep,
} from "@/features/authoring/api";
import { OutlineStepRow } from "@/features/authoring/components/outline-step-row";
import { PresetSheet } from "@/features/authoring/components/preset-sheet";
import { PublishSheet } from "@/features/authoring/components/publish-sheet";
import type { OutlineDetail, OutlineStep } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; detail: OutlineDetail };

export function OutlineDetailScreen({ outlineId }: { outlineId: number }) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleDraft, setTitleDraft] = useState("");
  const [titleSubmitting, setTitleSubmitting] = useState(false);
  const [selectedStep, setSelectedStep] = useState<OutlineStep | null>(null);
  const [publishOpen, setPublishOpen] = useState(false);
  const [addingStep, setAddingStep] = useState(false);
  const [newStepTopic, setNewStepTopic] = useState("");
  const [addSubmitting, setAddSubmitting] = useState(false);
  const [regenerating, setRegenerating] = useState(false);
  const [busyAction, setBusyAction] = useState<string | null>(null);

  const load = useCallback(
    async (showLoading = true) => {
      if (showLoading) {
        setState({ status: "loading" });
      }
      try {
        const detail = await getOutline(outlineId);
        setState({ status: "success", detail });
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }
        if (error instanceof ApiError && error.status === 403) {
          router.replace("/");
          return;
        }
        setState({ status: "error" });
      }
    },
    [outlineId, router],
  );

  useEffect(() => {
    void load();
  }, [load]);

  const isGenerating =
    state.status === "success" &&
    state.detail.steps.some((step) => step.fillState === "GENERATING");

  useEffect(() => {
    if (!isGenerating) {
      return;
    }

    const intervalId = window.setInterval(() => {
      void load(false);
    }, 5000);

    return () => window.clearInterval(intervalId);
  }, [isGenerating, load]);

  if (state.status === "loading") {
    return <OutlineDetailSkeleton />;
  }

  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        뼈대 정보를 불러오지 못했어요.
      </Feedback>
    );
  }

  const { detail } = state;
  const approvedCount = detail.steps.filter((step) => step.fillState === "APPROVED").length;
  const isPublished = detail.status === "PUBLISHED";
  const canPublish =
    !isPublished && detail.steps.length > 0 && approvedCount === detail.steps.length;

  const showActionError = (error: unknown, fallback: string) => {
    const message = error instanceof ApiError ? error.message : fallback;
    showToast({ message, tone: "error" });
  };

  const startEditingTitle = () => {
    setTitleDraft(detail.title);
    setEditingTitle(true);
  };

  const commitTitle = async () => {
    setEditingTitle(false);
    const nextTitle = titleDraft.trim();
    if (!nextTitle || nextTitle === detail.title || titleSubmitting) {
      setTitleDraft(detail.title);
      return;
    }

    setTitleSubmitting(true);
    try {
      await updateOutline(outlineId, { title: nextTitle });
      await load(false);
    } catch (error) {
      showActionError(error, "코스 제목을 수정하지 못했어요.");
    } finally {
      setTitleSubmitting(false);
    }
  };

  const runStepAction = async (
    actionKey: string,
    action: () => Promise<void>,
    fallback: string,
  ) => {
    if (busyAction !== null) {
      return;
    }
    setBusyAction(actionKey);
    try {
      await action();
      await load(false);
    } catch (error) {
      showActionError(error, fallback);
    } finally {
      setBusyAction(null);
    }
  };

  const handleUpdateTopic = (stepId: number, topic: string) =>
    runStepAction(
      `topic-${stepId}`,
      () => updateOutlineStep(stepId, topic),
      "스텝 주제를 수정하지 못했어요.",
    );

  const handleReorder = (stepId: number, direction: "UP" | "DOWN") =>
    runStepAction(
      `${direction === "UP" ? "up" : "down"}-${stepId}`,
      () => reorderOutlineStep(stepId, direction),
      "스텝 순서를 변경하지 못했어요.",
    );

  const handleDelete = (stepId: number) =>
    runStepAction(`delete-${stepId}`, () => deleteOutlineStep(stepId), "스텝을 삭제하지 못했어요.");

  const handleAddStep = async () => {
    const topic = newStepTopic.trim();
    if (!topic || addSubmitting || isPublished) {
      return;
    }
    setAddSubmitting(true);
    try {
      await addOutlineStep(outlineId, topic);
      setNewStepTopic("");
      setAddingStep(false);
      await load(false);
    } catch (error) {
      showActionError(error, "스텝을 추가하지 못했어요.");
    } finally {
      setAddSubmitting(false);
    }
  };

  const handleRegenerate = async () => {
    if (regenerating || isPublished) {
      return;
    }
    setRegenerating(true);
    try {
      const { jobId } = await regenerateOutline(outlineId);
      router.push(`/authoring/jobs/${jobId}`);
    } catch (error) {
      showActionError(error, "뼈대 재생성 요청에 실패했어요.");
    } finally {
      setRegenerating(false);
    }
  };

  return (
    <div className="flex flex-col gap-5 pb-36">
      <Link
        className="flex min-h-12 items-center gap-1 text-sm font-semibold text-ink-muted"
        href="/authoring/outlines"
      >
        ← 코스 목록
      </Link>

      <Card className="flex flex-col gap-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            {editingTitle ? (
              <Input
                autoFocus
                disabled={titleSubmitting}
                label="코스 제목"
                onBlur={() => void commitTitle()}
                onChange={(event) => setTitleDraft(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    event.currentTarget.blur();
                  }
                }}
                value={titleDraft}
              />
            ) : (
              <div className="flex items-center gap-2">
                <h2 className="min-w-0 truncate text-xl font-bold text-ink">{detail.title}</h2>
                {!isPublished ? (
                  <Button aria-label="코스 제목 수정" onClick={startEditingTitle} variant="ghost">
                    편집
                  </Button>
                ) : null}
              </div>
            )}
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <Chip tone="neutral">{detail.category}</Chip>
              <Chip tone={isPublished ? "success" : "neutral"}>
                {isPublished ? "발행됨 · 학습자에게 공개 중" : "작업 중 · 비공개"}
              </Chip>
            </div>
          </div>
          <div className="w-full max-w-xs">
            <Progress
              label={`${detail.title} 승인 진행률`}
              max={Math.max(detail.steps.length, 1)}
              value={approvedCount}
            />
            <p className="mt-2 text-right text-sm text-ink-muted">
              {detail.steps.length}개 스텝 중 {approvedCount}개 승인됨
            </p>
          </div>
        </div>
      </Card>

      {detail.steps.length === 0 ? (
        <EmptyState
          action={
            <Button
              disabled={isPublished}
              loading={regenerating}
              onClick={() => void handleRegenerate()}
            >
              뼈대 다시 생성
            </Button>
          }
          description="목차를 다시 보내 스텝을 생성할 수 있어요."
          title="아직 뼈대가 없어요"
        />
      ) : (
        <>
          <ul className="flex flex-col gap-3">
            {detail.steps.map((step, index) => (
              <li key={step.stepId}>
                <OutlineStepRow
                  busyAction={busyAction}
                  isFirst={index === 0}
                  isLast={index === detail.steps.length - 1}
                  onDelete={handleDelete}
                  onGenerate={setSelectedStep}
                  onReorder={handleReorder}
                  onUpdateTopic={handleUpdateTopic}
                  outlineId={outlineId}
                  readOnly={isPublished}
                  step={step}
                />
              </li>
            ))}
          </ul>

          {!isPublished && !addingStep ? (
            <Button onClick={() => setAddingStep(true)} variant="secondary">
              + 스텝 추가
            </Button>
          ) : null}

          {!isPublished && addingStep ? (
            <Card className="flex flex-col gap-3">
              <Input
                autoFocus
                label="새 스텝 주제"
                onChange={(event) => setNewStepTopic(event.target.value)}
                placeholder="예: TCP/IP 4계층"
                value={newStepTopic}
              />
              <div className="flex gap-3">
                <Button className="flex-1" onClick={() => setAddingStep(false)} variant="secondary">
                  취소
                </Button>
                <Button
                  className="flex-1"
                  disabled={newStepTopic.trim().length === 0}
                  loading={addSubmitting}
                  loadingText="추가 중…"
                  onClick={() => void handleAddStep()}
                >
                  추가
                </Button>
              </div>
            </Card>
          ) : null}
        </>
      )}

      <div className="fixed inset-x-0 bottom-0 border-t border-border bg-surface/90 backdrop-blur">
        <div className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-6 py-3">
          <p className="min-w-0 text-sm leading-relaxed text-ink-muted">
            {isPublished
              ? "이 코스는 학습자에게 공개 중이에요."
              : canPublish
                ? "모든 스텝이 승인됐어요. 발행하면 학습자에게 공개돼요."
                : "모든 스텝을 채우면 발행할 수 있어요 · 발행 전까지 학습자에게 비공개"}
          </p>
          <Button disabled={!canPublish} onClick={() => setPublishOpen(true)}>
            코스 발행
          </Button>
        </div>
      </div>

      <PresetSheet
        onClose={() => setSelectedStep(null)}
        open={selectedStep !== null}
        step={selectedStep}
      />
      <PublishSheet
        onClose={() => setPublishOpen(false)}
        open={publishOpen}
        outlineId={outlineId}
        stepCount={detail.steps.length}
      />
    </div>
  );
}

function OutlineDetailSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-7 w-32" />
      <Skeleton className="h-40 w-full" />
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-36 w-full" key={row} />
      ))}
    </div>
  );
}

"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getAuthoringCourseQuizzes } from "@/features/authoring/api";
import { ImproveSheet } from "@/features/authoring/components/improve-sheet";
import { QuizDetailCard } from "@/features/authoring/components/quiz-detail-card";
import type { AuthoringCourseDetail } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; detail: AuthoringCourseDetail };

/** 코스 상세 — 스텝(아코디언) → 문제 요약 행 → 클릭 시 전체 상세. 초기 전체 접힘. */
export function CourseQuizzesScreen({ courseId }: { courseId: number }) {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [openSteps, setOpenSteps] = useState<Set<number>>(new Set());
  const [openQuizzes, setOpenQuizzes] = useState<Set<number>>(new Set());
  const [improvingQuizId, setImprovingQuizId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const detail = await getAuthoringCourseQuizzes(courseId);
      setState({ status: "success", detail });
    } catch (error) {
      // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3). 그 외는 재시도 가능한 에러.
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      // 권한 없음(403) — RequireAdmin이 이미 진입을 막지만, role이 세션 중 바뀌는 경우를 대비한 방어.
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [courseId, router]);

  useEffect(() => {
    void load();
  }, [load]);

  const toggleStep = (stepOrder: number) => {
    setOpenSteps((prev) => {
      const next = new Set(prev);
      if (next.has(stepOrder)) {
        next.delete(stepOrder);
      } else {
        next.add(stepOrder);
      }
      return next;
    });
  };

  const toggleQuiz = (quizId: number) => {
    setOpenQuizzes((prev) => {
      const next = new Set(prev);
      if (next.has(quizId)) {
        next.delete(quizId);
      } else {
        next.add(quizId);
      }
      return next;
    });
  };

  if (state.status === "loading") {
    return <CourseSkeleton />;
  }
  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        문제를 불러오지 못했어요.
      </Feedback>
    );
  }

  const { detail } = state;
  if (detail.steps.length === 0) {
    return <EmptyState description="아직 등록된 문제가 없어요." title="등록된 문제가 없어요" />;
  }

  return (
    <div className="flex flex-col gap-6">
      <h2 className="text-xl font-bold text-ink">{detail.title}</h2>

      <div className="flex flex-col gap-3">
        {detail.steps.map((step) => {
          const stepOpen = openSteps.has(step.stepOrder);
          return (
            <section className="flex flex-col gap-2" key={step.stepOrder}>
              <button
                aria-expanded={stepOpen}
                className="flex items-center justify-between gap-3 rounded-control bg-surface-muted px-4 py-3 text-left"
                onClick={() => toggleStep(step.stepOrder)}
                type="button"
              >
                <span className="text-base font-bold text-ink">
                  STEP {step.stepOrder} · {step.topic ?? "제목 없음"}
                </span>
                <span className="text-sm text-ink-muted">
                  문제 {step.quizzes.length}개 {stepOpen ? "▲" : "▼"}
                </span>
              </button>

              {stepOpen ? (
                <ul className="flex flex-col gap-2">
                  {step.quizzes.map((quiz) => {
                    const quizOpen = openQuizzes.has(quiz.quizId);
                    return (
                      <li key={quiz.quizId}>
                        <button
                          aria-expanded={quizOpen}
                          className="flex w-full items-center gap-2 rounded-control border border-border px-3 py-2 text-left"
                          onClick={() => toggleQuiz(quiz.quizId)}
                          type="button"
                        >
                          <Chip tone="neutral">{quiz.generated.type}</Chip>
                          <Chip tone="neutral">{quiz.generated.difficulty}</Chip>
                          <span className="min-w-0 flex-1 truncate text-sm text-ink">
                            {quiz.generated.questionText}
                          </span>
                          <span className="text-ink-muted text-xs">{quizOpen ? "▲" : "▼"}</span>
                        </button>

                        {quizOpen ? (
                          <div className="mt-2 flex flex-col gap-3">
                            <QuizDetailCard quiz={quiz.generated} slotOrder={quiz.slotOrder} />
                            <div>
                              <Button
                                onClick={() => setImprovingQuizId(quiz.quizId)}
                                variant="secondary"
                              >
                                개선
                              </Button>
                            </div>
                          </div>
                        ) : null}
                      </li>
                    );
                  })}
                </ul>
              ) : null}
            </section>
          );
        })}
      </div>

      <ImproveSheet
        onClose={() => setImprovingQuizId(null)}
        open={improvingQuizId !== null}
        quizId={improvingQuizId}
      />
    </div>
  );
}

function CourseSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-7 w-40" />
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-14 w-full" key={row} />
      ))}
    </div>
  );
}

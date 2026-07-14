"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getAuthoringQuizzes } from "@/features/authoring/api";
import { ImproveSheet } from "@/features/authoring/components/improve-sheet";
import type { AuthoringStep } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; steps: AuthoringStep[] };

/** 라이브 문제 목록 화면 — 스텝별로 그룹핑해 슬롯 순으로 보여주고, 문제별 개선 진입점을 제공한다. */
export function QuizzesScreen() {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [improvingQuizId, setImprovingQuizId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const steps = await getAuthoringQuizzes();
      setState({ status: "success", steps });
    } catch (error) {
      // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3). 그 외는 재시도 가능한 에러.
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      setState({ status: "error" });
    }
  }, [router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <QuizzesSkeleton />;
  }

  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        라이브 문제를 불러오지 못했어요.
      </Feedback>
    );
  }

  if (state.steps.length === 0) {
    return <EmptyState description="아직 등록된 문제가 없어요." title="등록된 문제가 없어요" />;
  }

  return (
    <div className="flex flex-col gap-6">
      {state.steps.map((step) => (
        <section className="flex flex-col gap-3" key={step.stepOrder}>
          <h3 className="text-base font-bold text-ink">
            STEP {step.stepOrder} · {step.topic}
          </h3>
          <ul className="flex flex-col gap-2">
            {step.quizzes.map((quiz) => (
              <li key={quiz.quizId}>
                <Card className="flex items-center justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <Chip tone="neutral">{quiz.type}</Chip>
                      <Chip tone="neutral">{quiz.difficulty}</Chip>
                    </div>
                    <p className="mt-1 truncate text-sm text-ink">{quiz.questionText}</p>
                  </div>
                  <Button onClick={() => setImprovingQuizId(quiz.quizId)} variant="secondary">
                    개선
                  </Button>
                </Card>
              </li>
            ))}
          </ul>
        </section>
      ))}

      <ImproveSheet
        onClose={() => setImprovingQuizId(null)}
        open={improvingQuizId !== null}
        quizId={improvingQuizId}
      />
    </div>
  );
}

function QuizzesSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-6 w-32" />
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-16 w-full" key={row} />
      ))}
    </div>
  );
}

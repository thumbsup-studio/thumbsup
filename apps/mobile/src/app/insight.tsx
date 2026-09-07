import { parseCompletion } from "@thumbsup/core/completion-params";
import { Redirect, useLocalSearchParams } from "expo-router";

import { InsightScreen as InsightFeatureScreen } from "../features/play/insight-screen";
import { parsePositiveIdParam } from "../lib/navigation/route-params";

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function count(value: string | undefined) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

export default function InsightScreen() {
  const params = useLocalSearchParams<{
    a?: string | string[];
    bc?: string | string[];
    c?: string | string[];
    correct?: string | string[];
    courseId?: string | string[];
    done?: string | string[];
    quizId?: string | string[];
    retry?: string | string[];
    slot?: string | string[];
    step?: string | string[];
    streak?: string | string[];
    topic?: string | string[];
  }>();
  const quizId = parsePositiveIdParam(params.quizId);
  if (!quizId) return <Redirect href="/play" />;
  const step = parsePositiveIdParam(params.step);
  const slot = parsePositiveIdParam(params.slot);
  const strings = Object.fromEntries(
    Object.entries(params).map(([key, value]) => [key, first(value)]),
  );

  return (
    <InsightFeatureScreen
      completion={parseCompletion(strings)}
      correct={first(params.correct) === "true"}
      correctStreak={count(first(params.streak))}
      courseId={parsePositiveIdParam(params.courseId)}
      quizId={quizId}
      review={
        step && slot ? { slot, step, topic: first(params.topic) ?? "문제 다시 풀기" } : undefined
      }
      wasRetry={first(params.retry) === "1"}
    />
  );
}

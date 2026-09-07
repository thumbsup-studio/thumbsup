import { Redirect, useLocalSearchParams } from "expo-router";

import { FollowUpScreen as FollowUpFeatureScreen } from "../features/play/follow-up-screen";
import { parsePositiveIdParam } from "../lib/navigation/route-params";

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function positiveCount(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export default function FollowUpScreen() {
  const params = useLocalSearchParams<{
    correct?: string | string[];
    courseId?: string | string[];
    current?: string | string[];
    fq?: string | string[];
    quizId?: string | string[];
    streak?: string | string[];
    total?: string | string[];
  }>();
  const followUpQuestionId = parsePositiveIdParam(params.fq);
  const quizId = parsePositiveIdParam(params.quizId);
  if (!followUpQuestionId || !quizId) return <Redirect href="/play" />;

  return (
    <FollowUpFeatureScreen
      correct={first(params.correct) === "true"}
      correctStreak={positiveCount(first(params.streak), 0)}
      courseId={parsePositiveIdParam(params.courseId)}
      currentNumber={positiveCount(first(params.current), 1)}
      followUpQuestionId={followUpQuestionId}
      quizId={quizId}
      totalCount={positiveCount(first(params.total), 1)}
    />
  );
}

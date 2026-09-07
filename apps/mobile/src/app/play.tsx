import { Redirect, useLocalSearchParams } from "expo-router";

import { PlayScreen as PlayFeatureScreen } from "../features/play/play-screen";
import { hasInvalidIdParam, parsePositiveIdParam } from "../lib/navigation/route-params";

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default function PlayScreen() {
  const params = useLocalSearchParams<{
    courseId?: string | string[];
    slot?: string | string[];
    step?: string | string[];
    stepId?: string | string[];
    topic?: string | string[];
  }>();
  if (hasInvalidIdParam(params.courseId) || hasInvalidIdParam(params.stepId)) {
    return <Redirect href="/(tabs)" />;
  }
  const step = parsePositiveIdParam(params.step);
  const slot = parsePositiveIdParam(params.slot);
  if ((step && !slot) || (!step && slot)) return <Redirect href="/(tabs)/course" />;

  return (
    <PlayFeatureScreen
      courseId={parsePositiveIdParam(params.courseId)}
      quizStepId={parsePositiveIdParam(params.stepId)}
      review={
        step && slot ? { slot, step, topic: first(params.topic) ?? "문제 다시 풀기" } : undefined
      }
    />
  );
}

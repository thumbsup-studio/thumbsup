import { Redirect, useLocalSearchParams } from "expo-router";
import { BriefingScreen as BriefingFeatureScreen } from "../features/briefing/briefing-screen";
import { hasInvalidIdParam, parsePositiveIdParam } from "../lib/navigation/route-params";

export default function BriefingScreen() {
  const { courseId } = useLocalSearchParams<{ courseId?: string | string[] }>();
  if (hasInvalidIdParam(courseId)) return <Redirect href="/(tabs)" />;
  return <BriefingFeatureScreen courseId={parsePositiveIdParam(courseId)} />;
}

import { Redirect, useLocalSearchParams } from "expo-router";
import { CourseScreen as CourseFeatureScreen } from "../../features/course/course-screen";
import { hasInvalidIdParam, parsePositiveIdParam } from "../../lib/navigation/route-params";

export default function CourseScreen() {
  const { courseId } = useLocalSearchParams<{ courseId?: string | string[] }>();
  if (hasInvalidIdParam(courseId)) return <Redirect href="/(tabs)" />;
  return <CourseFeatureScreen initialOpenCourseId={parsePositiveIdParam(courseId)} />;
}

import { RequireAuth } from "@/features/auth/require-auth";
import { CoursePage } from "@/features/course/components/course-page";
import { type CourseSearchParams, parseCourseId } from "@/features/play/course-params";

export const dynamic = "force-dynamic";

type CourseRouteProps = {
  searchParams?: Promise<CourseSearchParams>;
};

export default async function Course({ searchParams }: CourseRouteProps) {
  const params = await searchParams;
  const initialOpenCourseId = parseCourseId(params?.courseId);

  return (
    <RequireAuth>
      <CoursePage initialOpenCourseId={initialOpenCourseId} />
    </RequireAuth>
  );
}

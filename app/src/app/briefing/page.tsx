import { RequireAuth } from "@/features/auth/require-auth";
import { BriefingScreen } from "@/features/briefing/components/briefing-screen";
import { type CourseSearchParams, parseCourseId } from "@/features/play/course-params";

export const dynamic = "force-dynamic";

type BriefingRouteProps = {
  searchParams?: Promise<CourseSearchParams>;
};

export default async function Briefing({ searchParams }: BriefingRouteProps) {
  const params = await searchParams;

  return (
    <RequireAuth>
      <BriefingScreen courseId={parseCourseId(params?.courseId)} />
    </RequireAuth>
  );
}

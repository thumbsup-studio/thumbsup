import { RequireAuth } from "@/features/auth/require-auth";
import { parseReviewContext, type ReviewSearchParams } from "@/features/history/review-params";
import { PlayPage } from "@/features/play/components/play-page";
import { type CourseSearchParams, parseCourseId } from "@/features/play/course-params";

export const dynamic = "force-dynamic";

type PlayRouteProps = {
  searchParams?: Promise<ReviewSearchParams & CourseSearchParams>;
};

export default async function Play({ searchParams }: PlayRouteProps) {
  const params = await searchParams;
  const review = parseReviewContext(params);
  const courseId = parseCourseId(params?.courseId);

  return (
    <RequireAuth>
      <PlayPage courseId={courseId} review={review} />
    </RequireAuth>
  );
}

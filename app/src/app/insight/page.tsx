import { RequireAuth } from "@/features/auth/require-auth";
import { parseReviewContext, type ReviewSearchParams } from "@/features/history/review-params";
import { type CompletionSearchParams, parseCompletion } from "@/features/play/completion-params";
import { InsightPage } from "@/features/play/components/insight-page";
import { type CourseSearchParams, parseCourseId } from "@/features/play/course-params";

export const dynamic = "force-dynamic";

type InsightRouteProps = {
  searchParams?: Promise<
    {
      correct?: string;
      quizId?: string;
      streak?: string;
      retry?: string;
    } & ReviewSearchParams &
      CompletionSearchParams &
      CourseSearchParams
  >;
};

export default async function Insight({ searchParams }: InsightRouteProps) {
  const params = await searchParams;
  // 소수 quizId가 다른 퀴즈로 절삭되지 않도록 양의 정수만 허용(follow-up 라우트와 동일 규약).
  const rawQuizId = Number(params?.quizId);
  const quizId = Number.isInteger(rawQuizId) && rawQuizId > 0 ? rawQuizId : null;
  const rawStreak = Number(params?.streak ?? 0);
  const correctStreak = Number.isFinite(rawStreak) ? Math.max(0, Math.trunc(rawStreak)) : 0;
  const review = parseReviewContext(params);
  // 상한 검증(clamp)은 totalCount를 아는 클라이언트에서 한다.
  const completion = parseCompletion(params);
  const courseId = parseCourseId(params?.courseId);

  return (
    <RequireAuth>
      <InsightPage
        completion={completion}
        correct={params?.correct === "true"}
        correctStreak={correctStreak}
        courseId={courseId}
        quizId={quizId}
        review={review}
        wasRetry={params?.retry === "1"}
      />
    </RequireAuth>
  );
}

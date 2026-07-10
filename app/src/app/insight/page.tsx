import { RequireAuth } from "@/features/auth/require-auth";
import { parseReviewContext, type ReviewSearchParams } from "@/features/history/review-params";
import { InsightPage } from "@/features/play/components/insight-page";

export const dynamic = "force-dynamic";

type InsightRouteProps = {
  searchParams?: Promise<
    {
      correct?: string;
      quizId?: string;
      streak?: string;
    } & ReviewSearchParams
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

  return (
    <RequireAuth>
      <InsightPage
        correct={params?.correct === "true"}
        correctStreak={correctStreak}
        quizId={quizId}
        review={review}
      />
    </RequireAuth>
  );
}

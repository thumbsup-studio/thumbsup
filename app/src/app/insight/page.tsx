import { RequireAuth } from "@/features/auth/require-auth";
import { InsightPage } from "@/features/play/components/insight-page";

export const dynamic = "force-dynamic";

type InsightRouteProps = {
  searchParams?: Promise<{
    correct?: string;
    quizId?: string;
    streak?: string;
  }>;
};

export default async function Insight({ searchParams }: InsightRouteProps) {
  const params = await searchParams;
  const rawQuizId = Number(params?.quizId);
  const quizId = Number.isFinite(rawQuizId) && rawQuizId > 0 ? Math.trunc(rawQuizId) : null;
  const rawStreak = Number(params?.streak ?? 0);
  const correctStreak = Number.isFinite(rawStreak) ? Math.max(0, Math.trunc(rawStreak)) : 0;

  return (
    <RequireAuth>
      <InsightPage
        correct={params?.correct === "true"}
        correctStreak={correctStreak}
        quizId={quizId}
      />
    </RequireAuth>
  );
}

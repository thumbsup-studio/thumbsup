import { InsightPage } from "@/features/play/components/insight-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import { clampQuestionIndex } from "@/features/play/play-logic";

export const dynamic = "force-dynamic";

type InsightRouteProps = {
  searchParams?: Promise<{
    correct?: string;
    question?: string;
    streak?: string;
  }>;
};

export default async function Insight({ searchParams }: InsightRouteProps) {
  const params = await searchParams;
  const questionIndex = clampQuestionIndex(
    Number(params?.question ?? 0),
    mockPlaySession.questions.length,
  );
  const rawStreak = Number(params?.streak ?? 0);
  const correctStreak = Number.isFinite(rawStreak) ? Math.max(0, Math.trunc(rawStreak)) : 0;

  return (
    <InsightPage
      correct={params?.correct === "true"}
      correctStreak={correctStreak}
      questionIndex={questionIndex}
      session={mockPlaySession}
    />
  );
}

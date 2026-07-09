import { InsightPage } from "@/features/play/components/insight-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import { clampQuestionIndex } from "@/features/play/play-logic";

export const dynamic = "force-dynamic";

type InsightRouteProps = {
  searchParams?: Promise<{
    correct?: string;
    question?: string;
  }>;
};

export default async function Insight({ searchParams }: InsightRouteProps) {
  const params = await searchParams;
  const questionIndex = clampQuestionIndex(
    Number(params?.question ?? 0),
    mockPlaySession.questions.length,
  );

  return (
    <InsightPage
      correct={params?.correct === "true"}
      questionIndex={questionIndex}
      session={mockPlaySession}
    />
  );
}

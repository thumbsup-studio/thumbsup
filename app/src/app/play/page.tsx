import { PlayPage } from "@/features/play/components/play-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import { clampQuestionIndex } from "@/features/play/play-logic";

export const dynamic = "force-dynamic";

type PlayRouteProps = {
  searchParams?: Promise<{
    question?: string;
  }>;
};

export default async function Play({ searchParams }: PlayRouteProps) {
  const params = await searchParams;
  const initialQuestionIndex = clampQuestionIndex(
    Number(params?.question ?? 0),
    mockPlaySession.questions.length,
  );

  return <PlayPage initialQuestionIndex={initialQuestionIndex} session={mockPlaySession} />;
}

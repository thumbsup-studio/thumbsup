import { redirect } from "next/navigation";
import { FollowUpPage } from "@/features/play/components/follow-up-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import { clampQuestionIndex } from "@/features/play/play-logic";

export const dynamic = "force-dynamic";

type FollowUpRouteProps = {
  searchParams?: Promise<{
    correct?: string;
    question?: string;
    streak?: string;
  }>;
};

export default async function FollowUp({ searchParams }: FollowUpRouteProps) {
  const params = await searchParams;
  const questionIndex = clampQuestionIndex(
    Number(params?.question ?? 0),
    mockPlaySession.questions.length,
  );
  const followUp = mockPlaySession.questions[questionIndex].followUp;

  // 꼬리질문이 없는 문제로 직접 진입하면 해당 문제 풀이로 돌려보낸다(방어).
  if (!followUp) {
    redirect(`/play?question=${questionIndex}`);
  }

  const rawStreak = Number(params?.streak ?? 0);
  const correctStreak = Number.isFinite(rawStreak) ? Math.max(0, Math.trunc(rawStreak)) : 0;

  return (
    <FollowUpPage
      correct={params?.correct === "true"}
      correctStreak={correctStreak}
      followUp={followUp}
      questionIndex={questionIndex}
      session={mockPlaySession}
    />
  );
}

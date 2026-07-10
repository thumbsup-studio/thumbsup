import { redirect } from "next/navigation";
import { FollowUpPage } from "@/features/play/components/follow-up-page";
import { mockPlaySession } from "@/features/play/mock-play-session";
import { clampQuestionIndex } from "@/features/play/play-logic";

export const dynamic = "force-dynamic";

type FollowUpRouteProps = {
  searchParams?: Promise<{
    correct?: string;
    fq?: string;
    question?: string;
    quizId?: string;
    streak?: string;
  }>;
};

export default async function FollowUp({ searchParams }: FollowUpRouteProps) {
  const params = await searchParams;
  const questionIndex = clampQuestionIndex(
    Number(params?.question ?? 0),
    mockPlaySession.questions.length,
  );

  const rawStreak = Number(params?.streak ?? 0);
  const correctStreak = Number.isFinite(rawStreak) ? Math.max(0, Math.trunc(rawStreak)) : 0;
  const correct = params?.correct === "true";
  const followUpQuestionId = Number(params?.fq);
  // 해설로 돌아갈 때 필요한 quizId — insight 라우트와 동일 규약으로 파싱(page.tsx의 quizId 파싱과 일치).
  // 소수는 다른 퀴즈로 절삭되지 않도록 양의 정수만 허용한다.
  const rawQuizId = Number(params?.quizId);
  const quizId = Number.isInteger(rawQuizId) && rawQuizId > 0 ? rawQuizId : null;

  // 유효하지 않은 꼬리질문 id로 직접 진입하면 해설로 돌려보낸다(방어).
  if (!Number.isFinite(followUpQuestionId) || followUpQuestionId <= 0) {
    redirect(
      `/insight?quizId=${quizId ?? ""}&correct=${correct ? "true" : "false"}&streak=${correctStreak}`,
    );
  }

  return (
    <FollowUpPage
      correct={correct}
      correctStreak={correctStreak}
      followUpQuestionId={followUpQuestionId}
      questionIndex={questionIndex}
      quizId={quizId}
      session={mockPlaySession}
    />
  );
}

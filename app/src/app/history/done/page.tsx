import { redirect } from "next/navigation";
import { RequireAuth } from "@/features/auth/require-auth";
import { ReviewSummaryPage } from "@/features/history/components/review-summary-page";
import { parseReviewContext, type ReviewSearchParams } from "@/features/history/review-params";

export const dynamic = "force-dynamic";

type ReviewDoneRouteProps = {
  searchParams?: Promise<ReviewSearchParams>;
};

export default async function ReviewDone({ searchParams }: ReviewDoneRouteProps) {
  const context = parseReviewContext(await searchParams);

  if (!context) {
    redirect("/history/review");
  }

  return (
    <RequireAuth>
      <ReviewSummaryPage
        correct={context.correct}
        single={context.single}
        slot={context.slot}
        step={context.step}
        topic={context.topic}
      />
    </RequireAuth>
  );
}

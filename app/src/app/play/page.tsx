import { RequireAuth } from "@/features/auth/require-auth";
import { parseReviewContext, type ReviewSearchParams } from "@/features/history/review-params";
import { PlayPage } from "@/features/play/components/play-page";

export const dynamic = "force-dynamic";

type PlayRouteProps = {
  searchParams?: Promise<ReviewSearchParams>;
};

export default async function Play({ searchParams }: PlayRouteProps) {
  const review = parseReviewContext(await searchParams);

  return (
    <RequireAuth>
      <PlayPage review={review} />
    </RequireAuth>
  );
}

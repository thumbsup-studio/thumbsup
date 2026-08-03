import { RequireAuth } from "@/features/auth/require-auth";
import { HistoryPage } from "@/features/history/components/history-page";

export const dynamic = "force-dynamic";

export default function HistoryReview() {
  return (
    <RequireAuth>
      <HistoryPage />
    </RequireAuth>
  );
}

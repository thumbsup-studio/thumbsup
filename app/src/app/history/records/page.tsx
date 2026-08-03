import { RequireAuth } from "@/features/auth/require-auth";
import { AttemptHistoryPage } from "@/features/history/components/attempt-history-page";

export const dynamic = "force-dynamic";

export default function HistoryRecords() {
  return (
    <RequireAuth>
      <AttemptHistoryPage />
    </RequireAuth>
  );
}

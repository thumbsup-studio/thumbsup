import { RequireAuth } from "@/features/auth/require-auth";
import { HistoryGraphPage } from "@/features/history-graph/components/history-graph-page";

export const dynamic = "force-dynamic";

export default function HistoryGraph() {
  return (
    <RequireAuth>
      <HistoryGraphPage />
    </RequireAuth>
  );
}

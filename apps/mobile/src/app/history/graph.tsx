import { useCallback } from "react";
import { HistoryGraphView } from "../../features/history-graph/history-graph-view";
import { useApi } from "../../lib/api/api-provider";

export default function HistoryGraphScreen() {
  const { client, profile } = useApi();
  const fetchGraph = useCallback(() => client.getHistoryGraph(), [client]);

  return <HistoryGraphView cacheKey={profile?.email ?? null} fetchGraph={fetchGraph} />;
}

import type { ApiRequest } from "./client";

export type HistoryGraphRelatedStep = {
  stepOrder: number;
  topic: string;
};

export type HistoryGraphNode = {
  id: string;
  label: string;
  description: string[];
  learnedAt: string | null;
  category: string;
  relatedSteps: HistoryGraphRelatedStep[];
};

export type HistoryGraphEdge = {
  source: string;
  target: string;
};

export type HistoryGraphResponse = {
  nodes: HistoryGraphNode[];
  edges: HistoryGraphEdge[];
};

export function createHistoryApi(apiRequest: ApiRequest) {
  return {
    getHistoryGraph(): Promise<HistoryGraphResponse> {
      return apiRequest<HistoryGraphResponse>("/history/graph");
    },
  };
}

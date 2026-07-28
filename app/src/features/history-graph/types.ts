export type HistoryGraphRelatedStep = {
  stepOrder: number;
  topic: string;
};

export type HistoryGraphNode = {
  id: string;
  label: string;
  description: string;
  learnedAt: string | null;
  category: string;
  relatedSteps: HistoryGraphRelatedStep[];
  position?: {
    x: number;
    y: number;
  };
};

export type HistoryGraphEdge = {
  source: string;
  target: string;
};

export type HistoryGraphResponse = {
  nodes: HistoryGraphNode[];
  edges: HistoryGraphEdge[];
};

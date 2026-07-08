import type { MasteryLevel } from "@/components/ui/graph-node";

export type { MasteryLevel };

export type AtlasCategory = {
  id: string;
  label: string;
  /** 이 카테고리가 최근에 새 노드/연결로 확장됐는지 — 그래프 카드 헤더에 배지로 표시 */
  recentlyExpanded?: boolean;
};

export type AtlasNode = {
  id: string;
  categoryId: string;
  label: string;
  mastery: MasteryLevel;
  /** SVG viewBox 좌표계에서 노드 중심 x */
  x: number;
  /** SVG viewBox 좌표계에서 노드 중심 y */
  y: number;
  /** 개념 시트에 보여줄 한 줄 요약 */
  summary: string;
};

export type AtlasEdge = {
  id: string;
  /** 부모(파생 이전) 노드 id */
  fromId: string;
  /** 자식(파생된) 노드 id */
  toId: string;
};

export type AtlasStats = {
  learnedNodeCount: number;
  connectionCount: number;
  weeklyGrowth: number;
};

export type AtlasData = {
  stats: AtlasStats;
  categories: AtlasCategory[];
  nodes: AtlasNode[];
  edges: AtlasEdge[];
};

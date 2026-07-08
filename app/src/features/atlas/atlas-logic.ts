import type { AtlasData, AtlasEdge, AtlasNode } from "@/features/atlas/types";

export function getNodesForCategory(data: AtlasData, categoryId: string): AtlasNode[] {
  return data.nodes.filter((node) => node.categoryId === categoryId);
}

export function filterNodesByQuery(nodes: AtlasNode[], query: string): AtlasNode[] {
  const needle = query.trim().toLowerCase();
  if (!needle) {
    return nodes;
  }
  // 대소문자 무시(예: "ip" → "IP" 매칭)
  return nodes.filter((node) => node.label.toLowerCase().includes(needle));
}

/** 두 끝 노드가 모두 보이는 엣지만 남긴다(카테고리·검색 필터링 후 씀). */
export function getEdgesForNodes(edges: AtlasEdge[], nodes: AtlasNode[]): AtlasEdge[] {
  const visibleIds = new Set(nodes.map((node) => node.id));
  return edges.filter((edge) => visibleIds.has(edge.fromId) && visibleIds.has(edge.toId));
}

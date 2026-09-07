import type { HistoryGraphResponse } from "@thumbsup/api";
import { Asset } from "expo-asset";
import { File, Paths } from "expo-file-system";

import graphAsset from "../../../assets/graph/index.html";

const cacheFile = new File(Paths.document, "history-graph-v1.json");

export async function loadGraphHtml(): Promise<string> {
  const asset = Asset.fromModule(graphAsset);
  await asset.downloadAsync();
  const uri = asset.localUri ?? asset.uri;
  if (!uri) throw new Error("그래프 렌더러 자산을 찾을 수 없습니다.");
  return new File(uri).text();
}

export async function readCachedGraph(owner: string): Promise<HistoryGraphResponse | null> {
  if (!owner || !cacheFile.exists) return null;
  try {
    const value: unknown = JSON.parse(await cacheFile.text());
    if (!value || typeof value !== "object") return null;
    const cached = value as { owner?: unknown; graph?: unknown };
    if (cached.owner !== owner || !isGraphData(cached.graph)) return null;
    return cached.graph;
  } catch {
    return null;
  }
}

export function writeCachedGraph(owner: string, graph: HistoryGraphResponse): void {
  if (!owner) return;
  cacheFile.write(JSON.stringify({ owner, graph }));
}

export function isGraphData(value: unknown): value is HistoryGraphResponse {
  if (!value || typeof value !== "object") return false;
  const graph = value as Partial<HistoryGraphResponse>;
  if (!Array.isArray(graph.nodes) || !Array.isArray(graph.edges)) return false;
  if (graph.nodes.length > 500 || graph.edges.length > 2000) return false;
  const ids = new Set<string>();
  for (const node of graph.nodes) {
    if (
      !node ||
      typeof node.id !== "string" ||
      typeof node.label !== "string" ||
      !Array.isArray(node.description) ||
      !node.description.every((item) => typeof item === "string") ||
      (node.learnedAt !== null && typeof node.learnedAt !== "string") ||
      typeof node.category !== "string" ||
      !Array.isArray(node.relatedSteps)
    ) {
      return false;
    }
    if (ids.has(node.id)) return false;
    ids.add(node.id);
  }
  return graph.edges.every(
    (edge) =>
      edge &&
      typeof edge.source === "string" &&
      typeof edge.target === "string" &&
      ids.has(edge.source) &&
      ids.has(edge.target),
  );
}

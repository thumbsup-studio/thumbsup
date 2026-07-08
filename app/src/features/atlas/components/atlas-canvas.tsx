import { GRAPH_ARROW_MARKER_ID, GraphEdge } from "@/components/ui/graph-edge";
import { GraphLegend } from "@/components/ui/graph-legend";
import { GraphNode } from "@/components/ui/graph-node";
import type { AtlasEdge, AtlasNode } from "@/features/atlas/types";

const VIEW_BOX = "0 0 320 260";

type AtlasCanvasProps = {
  title: string;
  recentlyExpanded?: boolean;
  nodes: AtlasNode[];
  edges: AtlasEdge[];
  selectedNodeId: string | null;
  onSelectNode: (id: string) => void;
};

export function AtlasCanvas({
  title,
  recentlyExpanded = false,
  nodes,
  edges,
  selectedNodeId,
  onSelectNode,
}: AtlasCanvasProps) {
  const nodeById = new Map<string, AtlasNode>(
    nodes.map((node): [string, AtlasNode] => [node.id, node]),
  );

  return (
    <div className="rounded-card bg-graph-bg p-5 shadow-card">
      <div className="mb-3 flex items-center justify-between">
        <p className="text-sm font-semibold text-graph-fg">{title}</p>
        {recentlyExpanded ? (
          <p className="flex items-center gap-1.5 text-xs font-medium text-accent">
            <span aria-hidden="true" className="size-1.5 rounded-full bg-accent" />
            최근 확장됨
          </p>
        ) : null}
      </div>

      <svg aria-label={`${title} 그래프`} className="w-full" role="img" viewBox={VIEW_BOX}>
        <defs>
          <marker
            id={GRAPH_ARROW_MARKER_ID}
            markerHeight={6}
            markerWidth={6}
            orient="auto-start-reverse"
            refX={8}
            refY={5}
            viewBox="0 0 10 10"
          >
            <path className="fill-graph-edge" d="M 0 0 L 10 5 L 0 10 Z" />
          </marker>
        </defs>
        {edges.map((edge) => {
          const from = nodeById.get(edge.fromId);
          const to = nodeById.get(edge.toId);
          if (!from || !to) {
            return null;
          }
          return <GraphEdge key={edge.id} x1={from.x} x2={to.x} y1={from.y} y2={to.y} />;
        })}
        {nodes.map((node) => (
          <GraphNode
            id={node.id}
            key={node.id}
            label={node.label}
            mastery={node.mastery}
            onSelect={onSelectNode}
            selected={node.id === selectedNodeId}
            x={node.x}
            y={node.y}
          />
        ))}
      </svg>

      <div className="mt-4 border-t border-graph-fg/10 pt-3">
        <GraphLegend />
      </div>
    </div>
  );
}

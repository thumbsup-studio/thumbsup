import { GRAPH_ARROW_MARKER_ID, GraphEdge } from "@/components/ui/graph-edge";
import { GraphLegend } from "@/components/ui/graph-legend";
import { GRAPH_NODE_GLOW_ID, GraphNode } from "@/components/ui/graph-node";
import type { AtlasEdge, AtlasNode } from "@/features/atlas/types";

const VIEW_BOX = "0 0 320 260";
/** 화살촉이 타깃 노드 경계 밖으로 나오도록 엣지 끝을 이 만큼 당긴다(노드 필 대략 반높이+여백). */
const NODE_CLEARANCE = 26;

function edgeEnd(from: AtlasNode, to: AtlasNode) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const len = Math.hypot(dx, dy) || 1;
  const clearance = Math.min(NODE_CLEARANCE, len / 2); // 짧은 엣지 보호
  return { x2: to.x - (dx / len) * clearance, y2: to.y - (dy / len) * clearance };
}

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
          <p className="flex items-center gap-1.5 text-xs font-medium text-graph-fg-muted">
            <span aria-hidden="true" className="size-1.5 rounded-full bg-accent" />
            최근 확장됨
          </p>
        ) : null}
      </div>

      {/* role 미지정 → svg의 암묵 role(graphics-document). 단일 이미지로 묶지 않아 내부 노드(role="button")가 접근성 트리에 노출된다 */}
      <svg aria-label={`${title} 그래프`} className="w-full" viewBox={VIEW_BOX}>
        <defs>
          <marker
            id={GRAPH_ARROW_MARKER_ID}
            markerHeight={7}
            markerWidth={7}
            orient="auto-start-reverse"
            refX={8}
            refY={5}
            viewBox="0 0 10 10"
          >
            <path className="fill-graph-edge" d="M 0 0 L 10 5 L 0 10 Z" />
          </marker>
          {/* 노드 필을 자기 색으로 번지게 하는 글로우(마스터=그린·학습중=블루). 텍스트/아이콘은 별도라 선명 유지. */}
          <filter id={GRAPH_NODE_GLOW_ID} x="-40%" y="-40%" width="180%" height="180%">
            <feGaussianBlur in="SourceGraphic" stdDeviation={3.5} result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        {edges.map((edge) => {
          const from = nodeById.get(edge.fromId);
          const to = nodeById.get(edge.toId);
          if (!from || !to) {
            return null;
          }
          const { x2, y2 } = edgeEnd(from, to);
          return <GraphEdge key={edge.id} x1={from.x} x2={x2} y1={from.y} y2={y2} />;
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

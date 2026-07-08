export const GRAPH_ARROW_MARKER_ID = "graph-arrow";

export type GraphEdgeProps = {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
};

/** 두 노드를 잇는 SVG 선(부모→파생). 화살표는 부모 svg의 <defs>에 정의된 GRAPH_ARROW_MARKER_ID를 참조한다. */
export function GraphEdge({ x1, y1, x2, y2 }: GraphEdgeProps) {
  return (
    <line
      className="stroke-graph-edge"
      markerEnd={`url(#${GRAPH_ARROW_MARKER_ID})`}
      strokeLinecap="round"
      strokeWidth={2}
      x1={x1}
      x2={x2}
      y1={y1}
      y2={y2}
    />
  );
}

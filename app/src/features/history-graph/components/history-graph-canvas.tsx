"use client";

import dynamic from "next/dynamic";
import {
  type ComponentType,
  type MutableRefObject,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import type { ForceGraphMethods, ForceGraphProps, NodeObject } from "react-force-graph-2d";
import type { HistoryGraphEdge, HistoryGraphNode } from "../types";

type GraphCanvasProps = {
  nodes: HistoryGraphNode[];
  edges: HistoryGraphEdge[];
  relatedNodeIds: string[];
  selectedNodeId: string;
  onSelectNode: (nodeId: string) => void;
};

type RenderNode = HistoryGraphNode & { val: number };
type RenderLink = HistoryGraphEdge;
type GraphData = {
  nodes: RenderNode[];
  links: RenderLink[];
};
type ForceGraphRef = ForceGraphMethods<RenderNode, RenderLink>;
type ForceGraphComponentProps = ForceGraphProps<RenderNode, RenderLink> & {
  ref?: MutableRefObject<ForceGraphRef | undefined>;
};

const ForceGraph2D = dynamic(() => import("react-force-graph-2d"), {
  ssr: false,
  loading: () => (
    <div className="grid h-80 place-items-center rounded-card bg-graph-surface text-sm font-semibold text-graph-fg-muted">
      그래프 엔진을 준비하는 중
    </div>
  ),
}) as ComponentType<ForceGraphComponentProps>;

function getCssToken(name: string) {
  if (typeof window === "undefined") {
    return "CanvasText";
  }

  const value = window.getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return value || "CanvasText";
}

function useGraphColors() {
  const [colors, setColors] = useState({
    bg: "Canvas",
    edge: "CanvasText",
    fg: "CanvasText",
    muted: "GrayText",
    mastered: "CanvasText",
    learning: "Highlight",
    related: "GrayText",
    surface: "Canvas",
  });

  useEffect(() => {
    setColors({
      bg: getCssToken("--color-graph-bg"),
      edge: getCssToken("--color-graph-edge"),
      fg: getCssToken("--color-graph-fg"),
      muted: getCssToken("--color-graph-fg-muted"),
      mastered: getCssToken("--color-graph-master"),
      learning: getCssToken("--color-graph-learning"),
      related: getCssToken("--color-graph-unlearned"),
      surface: getCssToken("--color-graph-surface"),
    });
  }, []);

  return colors;
}

function useElementWidth() {
  const ref = useRef<HTMLDivElement | null>(null);
  const [width, setWidth] = useState(360);

  useEffect(() => {
    const element = ref.current;
    if (!element) {
      return undefined;
    }

    const update = () => setWidth(Math.max(320, Math.round(element.getBoundingClientRect().width)));
    update();

    const observer = new ResizeObserver(update);
    observer.observe(element);

    return () => observer.disconnect();
  }, []);

  return { ref, width };
}

function drawNode(
  node: NodeObject<RenderNode>,
  ctx: CanvasRenderingContext2D,
  globalScale: number,
  colors: ReturnType<typeof useGraphColors>,
  selectedNodeId: string,
  relatedNodeIds: Set<string>,
  showAllLabels: boolean,
) {
  const label = node.label;
  const nodeId = node.id ? String(node.id) : "";
  const selected = nodeId === selectedNodeId;
  const related = relatedNodeIds.has(nodeId);
  const radius = selected ? 9 : related ? 6 : 4.5;
  const x = node.x ?? 0;
  const y = node.y ?? 0;
  const fill = selected ? colors.learning : related ? colors.mastered : colors.surface;
  const stroke = selected ? colors.fg : related ? colors.mastered : colors.related;

  ctx.beginPath();
  ctx.arc(x, y, radius, 0, 2 * Math.PI, false);
  ctx.fillStyle = fill;
  ctx.fill();
  ctx.lineWidth = selected ? 2.5 : 1.2;
  ctx.strokeStyle = stroke;
  ctx.stroke();

  if (!showAllLabels && !selected && !related) {
    return;
  }

  const fontSize = Math.max(7, selected ? 10 / globalScale : 8.5 / globalScale);
  ctx.font = `600 ${fontSize}px sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = selected || related ? colors.fg : colors.muted;
  ctx.fillText(label, x, y + radius + 5);
}

function drawPointerArea(
  node: NodeObject<RenderNode>,
  color: string,
  ctx: CanvasRenderingContext2D,
) {
  const x = node.x ?? 0;
  const y = node.y ?? 0;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, 24, 0, 2 * Math.PI, false);
  ctx.fill();
}

function getLinkNodeId(value: unknown) {
  if (typeof value === "object" && value !== null) {
    const candidate = value as { id?: string | number };
    return candidate.id ? String(candidate.id) : null;
  }

  return value ? String(value) : null;
}

export function HistoryGraphCanvas({
  nodes,
  edges,
  relatedNodeIds,
  selectedNodeId,
  onSelectNode,
}: GraphCanvasProps) {
  const colors = useGraphColors();
  const graphRef = useRef<ForceGraphRef | undefined>(undefined);
  const { ref, width } = useElementWidth();
  const relatedNodeSet = useMemo(() => new Set(relatedNodeIds), [relatedNodeIds]);
  const showAllLabels = nodes.length <= 20;
  const graphData: GraphData = useMemo(
    () => ({
      nodes: nodes.map((node) => ({
        ...node,
        val: 2,
      })),
      links: edges,
    }),
    [edges, nodes],
  );
  const fitGraph = useCallback(() => {
    const run = () => {
      graphRef.current?.zoomToFit(320, 28);
    };

    requestAnimationFrame(() => {
      window.setTimeout(run, 80);
    });
  }, []);

  useEffect(() => {
    if (width <= 0 || graphData.nodes.length === 0) {
      return undefined;
    }

    const timer = window.setTimeout(fitGraph, 120);
    return () => window.clearTimeout(timer);
  }, [fitGraph, graphData, width]);

  useEffect(() => {
    const handlePageShow = () => fitGraph();
    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        fitGraph();
      }
    };

    window.addEventListener("pageshow", handlePageShow);
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      window.removeEventListener("pageshow", handlePageShow);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  }, [fitGraph]);

  return (
    <section aria-label="지식 그래프">
      <div ref={ref} className="overflow-hidden rounded-card bg-graph-surface shadow-card">
        {width > 0 ? (
          <ForceGraph2D
            ref={graphRef}
            backgroundColor={colors.surface}
            cooldownTicks={80}
            enableNodeDrag={false}
            enablePanInteraction
            enableZoomInteraction
            graphData={graphData}
            height={320}
            linkDirectionalArrowLength={4}
            linkDirectionalArrowRelPos={0.96}
            linkWidth={(link) => {
              const source = getLinkNodeId(link.source);
              const target = getLinkNodeId(link.target);
              return source === selectedNodeId || target === selectedNodeId ? 2.5 : 1.4;
            }}
            linkColor={(link) => {
              const source = getLinkNodeId(link.source);
              const target = getLinkNodeId(link.target);
              return source === selectedNodeId || target === selectedNodeId
                ? colors.mastered
                : colors.edge;
            }}
            nodeCanvasObject={(node, ctx, scale) =>
              drawNode(node, ctx, scale, colors, selectedNodeId, relatedNodeSet, showAllLabels)
            }
            nodePointerAreaPaint={drawPointerArea}
            onNodeClick={(node) => {
              if (node.id) {
                onSelectNode(String(node.id));
              }
            }}
            showPointerCursor
            width={width}
          />
        ) : null}
      </div>
    </section>
  );
}

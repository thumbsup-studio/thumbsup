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
type GraphPosition = {
  x: number;
  y: number;
};
type ForceGraphRef = ForceGraphMethods<RenderNode, RenderLink>;
type ForceGraphComponentProps = ForceGraphProps<RenderNode, RenderLink> & {
  ref?: MutableRefObject<ForceGraphRef | undefined>;
};

const FIT_DURATION_MS = 320;
const FIT_REVEAL_DELAY_MS = FIT_DURATION_MS + 40;

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
  const [width, setWidth] = useState(0);

  useEffect(() => {
    const element = ref.current;
    if (!element) {
      return undefined;
    }

    const update = () => setWidth(Math.round(element.getBoundingClientRect().width));
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

function buildAdjacency(nodes: HistoryGraphNode[], edges: HistoryGraphEdge[]) {
  const adjacency = new Map<string, string[]>();

  for (const node of nodes) {
    adjacency.set(node.id, []);
  }

  for (const edge of edges) {
    adjacency.get(edge.source)?.push(edge.target);
    adjacency.get(edge.target)?.push(edge.source);
  }

  return adjacency;
}

function getNodeDepths(nodes: HistoryGraphNode[], edges: HistoryGraphEdge[]) {
  const startNode = nodes[0];
  const depths = new Map<string, number>();

  if (!startNode) {
    return depths;
  }

  const adjacency = buildAdjacency(nodes, edges);
  const queue = [startNode.id];
  depths.set(startNode.id, 0);

  for (let index = 0; index < queue.length; index += 1) {
    const nodeId = queue[index];
    const nextDepth = (depths.get(nodeId) ?? 0) + 1;

    for (const nextNodeId of adjacency.get(nodeId) ?? []) {
      if (depths.has(nextNodeId)) {
        continue;
      }

      depths.set(nextNodeId, nextDepth);
      queue.push(nextNodeId);
    }
  }

  return depths;
}

function getStableGraphPositions(
  nodes: HistoryGraphNode[],
  edges: HistoryGraphEdge[],
): Map<string, GraphPosition> {
  const positions = new Map<string, GraphPosition>();
  const positionedNodes = nodes.filter((node) => node.position);

  if (positionedNodes.length === nodes.length) {
    for (const node of positionedNodes) {
      positions.set(node.id, node.position ?? { x: 0, y: 0 });
    }

    return positions;
  }

  const depths = getNodeDepths(nodes, edges);
  const depthGroups = new Map<number, HistoryGraphNode[]>();
  const fallbackDepth = Math.max(1, ...Array.from(depths.values())) + 1;

  for (const node of nodes) {
    const depth = depths.get(node.id) ?? fallbackDepth;
    depthGroups.set(depth, [...(depthGroups.get(depth) ?? []), node]);
  }

  for (const [depth, group] of depthGroups) {
    if (depth === 0) {
      for (const node of group) {
        positions.set(node.id, { x: 0, y: 0 });
      }
      continue;
    }

    const radius = 78 + (depth - 1) * 58;
    const angleOffset = depth % 2 === 0 ? -Math.PI / 2 : -Math.PI * 0.68;

    group.forEach((node, index) => {
      const angle = angleOffset + (2 * Math.PI * index) / group.length;
      positions.set(node.id, {
        x: Math.cos(angle) * radius,
        y: Math.sin(angle) * radius,
      });
    });
  }

  return positions;
}

function getGraphData(nodes: HistoryGraphNode[], edges: HistoryGraphEdge[]): GraphData {
  const positions = getStableGraphPositions(nodes, edges);

  return {
    nodes: nodes.map((node) => {
      const position = positions.get(node.id) ?? { x: 0, y: 0 };

      return {
        ...node,
        fx: position.x,
        fy: position.y,
        val: 2,
        x: position.x,
        y: position.y,
      };
    }),
    links: edges.map((edge) => ({ ...edge })),
  };
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
  const fitRafRef = useRef<number | null>(null);
  const fitTimerRef = useRef<number | null>(null);
  const repeatFitTimerRef = useRef<number | null>(null);
  const revealTimerRef = useRef<number | null>(null);
  const hasFittedRef = useRef(false);
  const [hasFitted, setHasFitted] = useState(false);
  const { ref, width } = useElementWidth();
  const relatedNodeSet = useMemo(() => new Set(relatedNodeIds), [relatedNodeIds]);
  const showAllLabels = nodes.length <= 20;
  const graphData: GraphData = useMemo(() => getGraphData(nodes, edges), [edges, nodes]);
  const clearScheduledFit = useCallback(() => {
    if (fitRafRef.current !== null) {
      window.cancelAnimationFrame(fitRafRef.current);
      fitRafRef.current = null;
    }

    if (fitTimerRef.current !== null) {
      window.clearTimeout(fitTimerRef.current);
      fitTimerRef.current = null;
    }

    if (repeatFitTimerRef.current !== null) {
      window.clearTimeout(repeatFitTimerRef.current);
      repeatFitTimerRef.current = null;
    }

    if (revealTimerRef.current !== null) {
      window.clearTimeout(revealTimerRef.current);
      revealTimerRef.current = null;
    }
  }, []);
  const fitGraph = useCallback(() => {
    graphRef.current?.zoomToFit(FIT_DURATION_MS, 28);

    if (hasFittedRef.current || revealTimerRef.current !== null) {
      return;
    }

    revealTimerRef.current = window.setTimeout(() => {
      revealTimerRef.current = null;
      hasFittedRef.current = true;
      setHasFitted(true);
    }, FIT_REVEAL_DELAY_MS);
  }, []);
  const scheduleFitGraph = useCallback(
    ({ delay = 120, repeat = false }: { delay?: number; repeat?: boolean } = {}) => {
      clearScheduledFit();

      fitRafRef.current = window.requestAnimationFrame(() => {
        fitRafRef.current = null;
        fitTimerRef.current = window.setTimeout(() => {
          fitTimerRef.current = null;
          fitGraph();

          if (repeat) {
            repeatFitTimerRef.current = window.setTimeout(() => {
              repeatFitTimerRef.current = null;
              fitGraph();
            }, 720);
          }
        }, delay);
      });
    },
    [clearScheduledFit, fitGraph],
  );

  useEffect(() => {
    if (width <= 0 || graphData.nodes.length === 0) {
      return undefined;
    }

    hasFittedRef.current = false;
    setHasFitted(false);
    scheduleFitGraph({ delay: 180, repeat: true });
    return clearScheduledFit;
  }, [clearScheduledFit, graphData, scheduleFitGraph, width]);

  useEffect(() => {
    const handlePageShow = () => scheduleFitGraph({ delay: 180, repeat: true });
    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        scheduleFitGraph({ delay: 180, repeat: true });
      }
    };

    window.addEventListener("pageshow", handlePageShow);
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      window.removeEventListener("pageshow", handlePageShow);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  }, [scheduleFitGraph]);

  return (
    <section aria-label="지식 그래프">
      <div ref={ref} className="overflow-hidden rounded-card bg-graph-surface shadow-card">
        {width > 0 ? (
          <div
            className={
              hasFitted
                ? "opacity-100 motion-safe:transition-opacity motion-safe:duration-200"
                : "opacity-0"
            }
          >
            <ForceGraph2D
              ref={graphRef}
              backgroundColor={colors.surface}
              cooldownTicks={20}
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
              onEngineStop={() => scheduleFitGraph({ delay: 0 })}
              onNodeClick={(node) => {
                if (node.id) {
                  onSelectNode(String(node.id));
                }
              }}
              showPointerCursor
              width={width}
            />
          </div>
        ) : null}
      </div>
    </section>
  );
}

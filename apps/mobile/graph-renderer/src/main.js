import ForceGraph from "force-graph";
import "./style.css";

const VERSION = 1;
const MAX_MESSAGE_BYTES = 1024 * 1024;
const MAX_NODES = 500;
const MAX_EDGES = 2000;

const colors = {
  background: "#1d273f",
  edge: "#4b5a80",
  learning: "#2f63ff",
  mastered: "#34c88a",
};

const container = document.getElementById("graph");
const bridge = window.ReactNativeWebView;
let graph;

function send(type, payload) {
  bridge?.postMessage(JSON.stringify({ type, version: VERSION, payload }));
}

function isString(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 200;
}

function validPayload(payload) {
  if (!payload || !Array.isArray(payload.nodes) || !Array.isArray(payload.edges)) return false;
  if (payload.nodes.length > MAX_NODES || payload.edges.length > MAX_EDGES) return false;
  const ids = new Set();
  for (const node of payload.nodes) {
    if (!node || !isString(node.id) || !isString(node.label) || ids.has(node.id)) return false;
    ids.add(node.id);
  }
  return payload.edges.every(
    (edge) => edge && isString(edge.source) && isString(edge.target) && ids.has(edge.source) && ids.has(edge.target),
  );
}

function render(payload) {
  if (!validPayload(payload)) throw new Error("INVALID_GRAPH_DATA");
  const learned = new Set(payload.nodes.filter((node) => node.learnedAt).map((node) => node.id));
  graph = ForceGraph()(container)
    .width(window.innerWidth)
    .height(window.innerHeight)
    .backgroundColor(colors.background)
    .graphData({ nodes: payload.nodes.map((node) => ({ ...node, val: 3 })), links: payload.edges })
    .nodeLabel((node) => node.label)
    .nodeColor((node) => (learned.has(node.id) ? colors.mastered : colors.learning))
    .nodeRelSize(5)
    .linkColor(() => colors.edge)
    .linkWidth(1.4)
    .linkDirectionalArrowLength(3)
    .linkDirectionalArrowRelPos(0.96)
    .enableNodeDrag(true)
    .enablePanInteraction(true)
    .enableZoomInteraction(true)
    .onNodeClick((node) => send("NODE_PRESS", { nodeId: node.id }))
    .onNodeDragEnd((node) => send("NODE_PRESS", { nodeId: node.id }));
  graph.d3Force("charge").strength(-90);
  graph.onEngineStop(() => {
    graph.zoomToFit(250, 28);
    send("RENDERED", { nodeCount: payload.nodes.length, edgeCount: payload.edges.length });
  });
}

function receive(event) {
  try {
    if (typeof event.data !== "string" || event.data.length > MAX_MESSAGE_BYTES) {
      throw new Error("MESSAGE_TOO_LARGE");
    }
    const message = JSON.parse(event.data);
    if (message?.version !== VERSION || message?.type !== "GRAPH_DATA") return;
    render(message.payload);
  } catch (error) {
    send("ERROR", { code: error instanceof Error ? error.message : "RENDER_FAILED" });
  }
}

document.addEventListener("message", receive);
window.addEventListener("message", receive);
window.addEventListener("resize", () => graph?.width(window.innerWidth).height(window.innerHeight));
send("READY", {});

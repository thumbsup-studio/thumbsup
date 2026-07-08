import { describe, expect, it } from "vitest";

import {
  filterNodesByQuery,
  getEdgesForNodes,
  getNodesForCategory,
} from "@/features/atlas/atlas-logic";
import type { AtlasData } from "@/features/atlas/types";

const data: AtlasData = {
  stats: { learnedNodeCount: 2, connectionCount: 1, weeklyGrowth: 1 },
  categories: [
    { id: "network", label: "네트워크" },
    { id: "os", label: "운영체제" },
  ],
  nodes: [
    { id: "ip", categoryId: "network", label: "IP", mastery: "master", x: 0, y: 0, summary: "" },
    {
      id: "udp",
      categoryId: "network",
      label: "UDP",
      mastery: "learning",
      x: 0,
      y: 0,
      summary: "",
    },
    {
      id: "process",
      categoryId: "os",
      label: "프로세스",
      mastery: "master",
      x: 0,
      y: 0,
      summary: "",
    },
  ],
  edges: [
    { id: "e1", fromId: "ip", toId: "udp" },
    { id: "e2", fromId: "ip", toId: "process" },
  ],
};

describe("getNodesForCategory", () => {
  it("returns only nodes belonging to the given category", () => {
    expect(getNodesForCategory(data, "network").map((node) => node.id)).toEqual(["ip", "udp"]);
  });
});

describe("filterNodesByQuery", () => {
  it("returns all nodes when the query is empty", () => {
    const nodes = getNodesForCategory(data, "network");
    expect(filterNodesByQuery(nodes, "  ")).toEqual(nodes);
  });

  it("filters nodes whose label includes the query", () => {
    const nodes = getNodesForCategory(data, "network");
    expect(filterNodesByQuery(nodes, "UD").map((node) => node.id)).toEqual(["udp"]);
  });
});

describe("getEdgesForNodes", () => {
  it("drops edges whose endpoint is not in the visible node set", () => {
    const nodes = getNodesForCategory(data, "network");
    expect(getEdgesForNodes(data.edges, nodes).map((edge) => edge.id)).toEqual(["e1"]);
  });
});

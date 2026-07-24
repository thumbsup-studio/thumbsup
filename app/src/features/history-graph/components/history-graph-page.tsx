"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { AppTabBar } from "@/components/app-tab-bar";
import { ArrowLeftIcon, ChevronRightIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { reviewStartHref } from "@/features/history/review-params";
import { getMockHistoryGraph } from "../mock-graph";
import type { HistoryGraphNode, HistoryGraphResponse } from "../types";
import { HistoryGraphCanvas } from "./history-graph-canvas";

type LoadState =
  | { status: "loading"; graph: null; message: null }
  | { status: "ready"; graph: HistoryGraphResponse; message: null }
  | { status: "error"; graph: null; message: string };

const dateFormatter = new Intl.DateTimeFormat("ko-KR", {
  month: "long",
  day: "numeric",
});

function formatLearnedAt(value: string | null) {
  if (!value) {
    return "학습일 없음";
  }

  return dateFormatter.format(new Date(value));
}

function getRelatedNodes(selectedNode: HistoryGraphNode, graph: HistoryGraphResponse) {
  const relatedIds = new Set<string>();
  for (const edge of graph.edges) {
    if (edge.source === selectedNode.id) {
      relatedIds.add(edge.target);
    }

    if (edge.target === selectedNode.id) {
      relatedIds.add(edge.source);
    }
  }

  return graph.nodes.filter((node) => relatedIds.has(node.id));
}

export function HistoryGraphPage() {
  const router = useRouter();
  const [loadState, setLoadState] = useState<LoadState>({
    status: "loading",
    graph: null,
    message: null,
  });
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let ignore = false;
    const requestKey = reloadKey;

    if (requestKey < 0) {
      return undefined;
    }

    async function load() {
      setLoadState({ status: "loading", graph: null, message: null });

      try {
        const graph = await getMockHistoryGraph();
        if (ignore) {
          return;
        }

        setLoadState({ status: "ready", graph, message: null });
        setSelectedNodeId((current) => current ?? graph.nodes[0]?.id ?? null);
      } catch {
        if (!ignore) {
          setLoadState({
            status: "error",
            graph: null,
            message: "지식 그래프를 불러오지 못했어요.",
          });
        }
      }
    }

    void load();

    return () => {
      ignore = true;
    };
  }, [reloadKey]);

  const graph = loadState.graph;
  const selectedNode = useMemo(() => {
    if (!graph) {
      return null;
    }

    return graph.nodes.find((node) => node.id === selectedNodeId) ?? graph.nodes[0] ?? null;
  }, [graph, selectedNodeId]);

  const relatedNodes = useMemo(() => {
    if (!graph || !selectedNode) {
      return [];
    }

    return getRelatedNodes(selectedNode, graph);
  }, [graph, selectedNode]);
  const relatedNodeIds = useMemo(() => relatedNodes.map((node) => node.id), [relatedNodes]);

  const liveText =
    loadState.status === "loading"
      ? "지식 그래프를 불러오는 중"
      : loadState.status === "error"
        ? loadState.message
        : graph
          ? `배운 개념 ${graph.nodes.length}개`
          : "";

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <header className="flex items-start gap-3">
          <Link
            aria-label="히스토리로 돌아가기"
            className="grid min-h-11 min-w-11 place-items-center rounded-control bg-surface text-ink shadow-card"
            href="/history"
          >
            <ArrowLeftIcon className="size-5" />
          </Link>
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold tracking-wide text-ink-muted">히스토리</p>
            <h1 className="mt-1 break-keep text-2xl font-semibold tracking-tight text-balance text-ink">
              지식 그래프
            </h1>
            <p className="mt-2 text-sm font-medium leading-6 text-ink-muted">
              배운 개념이 어떻게 이어지는지 한눈에 확인해요.
            </p>
          </div>
        </header>

        <p aria-live="polite" className="sr-only">
          {liveText}
        </p>

        {loadState.status === "loading" ? <HistoryGraphSkeleton /> : null}

        {loadState.status === "error" ? (
          <Feedback onRetry={() => setReloadKey((key) => key + 1)} tone="error">
            {loadState.message}
          </Feedback>
        ) : null}

        {loadState.status === "ready" && graph ? (
          graph.nodes.length > 0 && selectedNode ? (
            <>
              <HistoryGraphCanvas
                edges={graph.edges}
                nodes={graph.nodes}
                onSelectNode={setSelectedNodeId}
                relatedNodeIds={relatedNodeIds}
                selectedNodeId={selectedNode.id}
              />
              <NodeDetailCard node={selectedNode} />
            </>
          ) : (
            <EmptyState
              action={<Button onClick={() => router.push("/")}>학습하러 가기</Button>}
              description="오늘의 학습을 완료하면 배운 개념이 그래프에 나타나요."
              title="아직 연결된 개념이 없어요"
            />
          )
        ) : null}

        <div className="sticky bottom-4 mt-auto pt-1">
          <AppTabBar activeTab="history" />
        </div>
      </div>
    </main>
  );
}

function NodeDetailCard({ node }: { node: HistoryGraphNode }) {
  return (
    <section className="rounded-card border border-border bg-surface p-5 shadow-card">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-semibold text-ink-muted">{node.category}</p>
          <h2 className="mt-1 text-xl font-bold tracking-tight text-ink">{node.label}</h2>
        </div>
        <span className="rounded-chip bg-surface-muted px-3 py-1 text-xs font-semibold text-ink-muted">
          {formatLearnedAt(node.learnedAt)}
        </span>
      </div>

      <p className="mt-4 break-keep text-sm font-medium leading-6 text-ink-muted">
        {node.description}
      </p>

      <div className="mt-5">
        <p className="text-xs font-semibold tracking-wide text-ink-muted">관련 스텝</p>
        <div className="mt-2 flex flex-col gap-2">
          {node.relatedSteps.map((step) => (
            <Link
              key={step.stepOrder}
              className="flex min-h-12 items-center gap-3 rounded-control bg-surface-muted px-4 py-3 text-sm font-semibold text-ink"
              href={reviewStartHref(step.stepOrder, step.topic)}
            >
              <span className="grid size-8 shrink-0 place-items-center rounded-chip bg-surface text-xs text-ink-muted">
                {step.stepOrder}
              </span>
              <span className="min-w-0 flex-1 truncate">{step.topic}</span>
              <span className="text-xs text-ink-muted">복습</span>
              <ChevronRightIcon className="size-4 shrink-0 text-ink-muted" />
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

function HistoryGraphSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-96 rounded-card" />
      <Skeleton className="h-64 rounded-card" />
    </div>
  );
}

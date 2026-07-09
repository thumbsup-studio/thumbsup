"use client";

import { useMemo, useState } from "react";
import { DisconnectedNodesIcon, PlayIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import {
  filterNodesByQuery,
  getEdgesForNodes,
  getNodesForCategory,
} from "@/features/atlas/atlas-logic";
import { AtlasCanvas } from "@/features/atlas/components/atlas-canvas";
import { AtlasHeader } from "@/features/atlas/components/atlas-header";
import { AtlasSearch } from "@/features/atlas/components/atlas-search";
import { AtlasStatsRow } from "@/features/atlas/components/atlas-stats";
import { CategoryFilter } from "@/features/atlas/components/category-filter";
import { ConceptSheet } from "@/features/atlas/components/concept-sheet";
import type { AtlasData } from "@/features/atlas/types";
import { useAppToast } from "@/providers/app-toast-provider";

type AtlasPageProps = {
  data: AtlasData;
};

export function AtlasPage({ data }: AtlasPageProps) {
  const { showToast } = useAppToast();
  const [activeCategoryId, setActiveCategoryId] = useState(data.categories[0]?.id ?? "");
  const [query, setQuery] = useState("");
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);

  const activeCategory =
    data.categories.find((category) => category.id === activeCategoryId) ?? data.categories[0];

  const visibleNodes = useMemo(
    () => filterNodesByQuery(getNodesForCategory(data, activeCategoryId), query),
    [data, activeCategoryId, query],
  );
  const visibleEdges = useMemo(
    () => getEdgesForNodes(data.edges, visibleNodes),
    [data.edges, visibleNodes],
  );
  const selectedNode = visibleNodes.find((node) => node.id === selectedNodeId) ?? null;

  function handleSelectCategory(categoryId: string) {
    setActiveCategoryId(categoryId);
    setSelectedNodeId(null);
  }

  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <AtlasHeader
          onBack={() => showToast({ message: "이전 화면은 준비 중입니다." })}
          onShare={() => showToast({ message: "공유는 준비 중입니다." })}
        />

        <div>
          <p className="text-xs font-semibold tracking-wide text-ink-muted">ATLAS</p>
          <h2 className="mt-1 break-keep text-2xl font-semibold tracking-tight text-balance text-ink">
            배운 개념이 연결될수록, 내 공부가 보입니다.
          </h2>
        </div>

        <AtlasStatsRow stats={data.stats} />

        <AtlasSearch onChange={setQuery} value={query} />

        <CategoryFilter
          activeCategoryId={activeCategoryId}
          categories={data.categories}
          onSelect={handleSelectCategory}
        />

        {visibleNodes.length > 0 && activeCategory ? (
          <AtlasCanvas
            edges={visibleEdges}
            nodes={visibleNodes}
            onSelectNode={setSelectedNodeId}
            recentlyExpanded={activeCategory.recentlyExpanded}
            selectedNodeId={selectedNodeId}
            title={`${activeCategory.label} 영역`}
          />
        ) : (
          <EmptyState
            action={
              <Button onClick={() => showToast({ message: "퀴즈는 준비 중입니다." })}>
                <PlayIcon className="mr-2" />
                퀴즈 시작하기
              </Button>
            }
            description="첫 퀴즈를 풀면 학습한 개념이 그래프에 노드로 나타나요."
            icon={<DisconnectedNodesIcon />}
            title="아직 연결된 개념이 없어요"
            tone="dark"
          />
        )}

        {selectedNode ? (
          <ConceptSheet
            node={selectedNode}
            onReview={() => showToast({ message: "복습은 준비 중입니다." })}
          />
        ) : null}
      </div>
    </main>
  );
}

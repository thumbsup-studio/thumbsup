import type { HistoryGraphNode, HistoryGraphResponse } from "@thumbsup/api";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AccessibilityInfo,
  ActivityIndicator,
  Pressable,
  ScrollView,
  Text,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { isGraphData, loadGraphHtml, readCachedGraph, writeCachedGraph } from "./graph-storage";
import { GraphWebView } from "./graph-webview";

type ViewMode = "graph" | "list";

type HistoryGraphViewProps = {
  cacheKey: string | null;
  fetchGraph(): Promise<HistoryGraphResponse>;
  initialViewMode?: ViewMode;
  loadHtml?: () => Promise<string>;
  readCache?: (cacheKey: string) => Promise<HistoryGraphResponse | null>;
  writeCache?: (cacheKey: string, graph: HistoryGraphResponse) => void;
};

function NodeCard({ node, selected }: { node: HistoryGraphNode; selected: boolean }) {
  return (
    <View
      accessible
      accessibilityLabel={`${node.label}, ${node.learnedAt ? "학습 완료" : "학습 중"}`}
      className={`rounded-mobile-control border p-4 ${
        selected ? "border-primary bg-surface" : "border-border bg-surface-muted"
      }`}
    >
      <View className="flex-row items-center justify-between gap-3">
        <Text className="flex-1 text-base font-bold text-ink">{node.label}</Text>
        <Text className={node.learnedAt ? "text-xs text-success" : "text-xs text-primary"}>
          {node.learnedAt ? "학습 완료" : "학습 중"}
        </Text>
      </View>
      {node.description[0] ? (
        <Text className="mt-2 text-sm leading-5 text-ink-muted">{node.description[0]}</Text>
      ) : null}
    </View>
  );
}

export function HistoryGraphView({
  cacheKey,
  fetchGraph,
  initialViewMode,
  loadHtml = loadGraphHtml,
  readCache = readCachedGraph,
  writeCache = writeCachedGraph,
}: HistoryGraphViewProps) {
  const [mode, setMode] = useState<ViewMode>(initialViewMode ?? "graph");
  const [graph, setGraph] = useState<HistoryGraphResponse | null>(null);
  const [html, setHtml] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    setFeedback(null);
    const [htmlResult, graphResult] = await Promise.allSettled([loadHtml(), fetchGraph()]);
    if (htmlResult.status === "fulfilled") setHtml(htmlResult.value);
    else {
      setMode("list");
      setFeedback("그래프 화면을 열 수 없어 목록으로 보여드려요.");
    }

    if (graphResult.status === "fulfilled" && isGraphData(graphResult.value)) {
      setGraph(graphResult.value);
      setSelectedId(graphResult.value.nodes[0]?.id ?? null);
      try {
        if (cacheKey) writeCache(cacheKey, graphResult.value);
      } catch {
        // 캐시는 부가 기능이므로 저장 실패가 최신 그래프 표시를 막지 않게 한다.
      }
    } else {
      const cached = cacheKey ? await readCache(cacheKey) : null;
      setGraph(cached);
      setSelectedId(cached?.nodes[0]?.id ?? null);
      setFeedback(
        cached
          ? "오프라인 상태라 마지막으로 저장한 그래프를 보여드려요."
          : "그래프를 불러오지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요.",
      );
    }
    setLoading(false);
  }, [cacheKey, fetchGraph, loadHtml, readCache, writeCache]);

  useEffect(() => {
    if (initialViewMode) return;
    void AccessibilityInfo.isScreenReaderEnabled().then((enabled) => {
      if (enabled) setMode("list");
    });
  }, [initialViewMode]);

  useEffect(() => {
    void load();
  }, [load]);

  const selectedNode = graph?.nodes.find((node) => node.id === selectedId) ?? null;
  const learnedCount = useMemo(
    () => graph?.nodes.filter((node) => node.learnedAt !== null).length ?? 0,
    [graph],
  );

  return (
    <SafeAreaView className="flex-1 bg-bg">
      <ScrollView contentContainerClassName="gap-5 px-5 pb-10 pt-6">
        <View className="gap-1">
          <Text className="text-xs font-bold uppercase tracking-widest text-primary">
            Learning atlas
          </Text>
          <Text accessibilityRole="header" className="text-3xl font-extrabold text-ink">
            지식 그래프
          </Text>
          <Text className="text-sm leading-5 text-ink-muted">
            학습한 개념과 다음에 이어질 개념을 한눈에 확인하세요.
          </Text>
        </View>

        {feedback ? (
          <View
            accessibilityRole="alert"
            className="rounded-mobile-control border border-border bg-surface p-4"
          >
            <Text className="text-sm text-ink">{feedback}</Text>
          </View>
        ) : null}

        <View className="flex-row gap-3">
          <View className="flex-1 rounded-mobile-control bg-surface p-4">
            <Text className="text-xs text-ink-muted">전체 개념</Text>
            <Text className="mt-1 text-2xl font-extrabold text-ink">
              {graph?.nodes.length ?? 0}
            </Text>
          </View>
          <View className="flex-1 rounded-mobile-control bg-surface p-4">
            <Text className="text-xs text-ink-muted">학습 완료</Text>
            <Text className="mt-1 text-2xl font-extrabold text-success">{learnedCount}</Text>
          </View>
        </View>

        <View className="flex-row rounded-mobile-control bg-surface-muted p-1">
          {(["graph", "list"] as const).map((item) => (
            <Pressable
              key={item}
              accessibilityRole="tab"
              accessibilityState={{ selected: mode === item }}
              className={`min-h-11 flex-1 items-center justify-center rounded-mobile-control ${
                mode === item ? "bg-surface" : "bg-surface-muted"
              }`}
              onPress={() => setMode(item)}
            >
              <Text
                className={`font-semibold ${mode === item ? "text-primary" : "text-ink-muted"}`}
              >
                {item === "graph" ? "그래프 보기" : "목록 보기"}
              </Text>
            </Pressable>
          ))}
        </View>

        {loading ? (
          <View accessibilityRole="progressbar" className="h-80 items-center justify-center">
            <ActivityIndicator size="large" />
            <Text className="mt-3 text-sm text-ink-muted">지식 지도를 불러오는 중</Text>
          </View>
        ) : graph && graph.nodes.length > 0 ? (
          mode === "graph" && html ? (
            <>
              <GraphWebView
                data={graph}
                html={html}
                onFailure={() => {
                  setMode("list");
                  setFeedback("그래프를 표시하지 못해 목록으로 전환했어요.");
                }}
                onNodePress={setSelectedId}
              />
              {selectedNode ? <NodeCard node={selectedNode} selected /> : null}
            </>
          ) : (
            <View accessibilityRole="list" className="gap-3">
              {graph.nodes.map((node) => (
                <NodeCard key={node.id} node={node} selected={node.id === selectedId} />
              ))}
            </View>
          )
        ) : (
          <View className="items-center rounded-mobile-card border border-border bg-surface px-6 py-10">
            <Text className="text-lg font-bold text-ink">아직 연결된 개념이 없어요</Text>
            <Text className="mt-2 text-center text-sm text-ink-muted">
              문제를 풀면 학습한 개념이 이곳에 연결됩니다.
            </Text>
            {feedback ? (
              <Pressable
                accessibilityRole="button"
                className="mt-5 min-h-12 justify-center rounded-mobile-control bg-primary px-6"
                onPress={() => void load()}
              >
                <Text className="font-semibold text-primary-fg">다시 시도</Text>
              </Pressable>
            ) : null}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

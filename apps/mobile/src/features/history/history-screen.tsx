import { ApiError, type HistoryGraphNode, NetworkError } from "@thumbsup/api";
import { router } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, RefreshControl, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { useApi } from "../../lib/api/api-provider";

type LoadState =
  | { status: "loading" }
  | { status: "error"; message: string }
  | { status: "ready"; nodes: HistoryGraphNode[] };

const dateFormatter = new Intl.DateTimeFormat("ko-KR", {
  month: "long",
  day: "numeric",
});

function formatLearnedAt(value: string | null) {
  if (!value) return "학습일 없음";
  return dateFormatter.format(new Date(value));
}

function getDescriptionItems(node: HistoryGraphNode) {
  const occurrences = new Map<string, number>();
  return node.description.map((description) => {
    const occurrence = occurrences.get(description) ?? 0;
    occurrences.set(description, occurrence + 1);
    return { description, key: `${node.id}-${description}-${occurrence}` };
  });
}

function getLoadErrorMessage(error: unknown) {
  if (error instanceof NetworkError) {
    return error.reason === "timeout"
      ? "요청 시간이 초과됐어요. 잠시 후 다시 시도해 주세요."
      : "네트워크에 연결할 수 없어요. 연결을 확인한 뒤 다시 시도해 주세요.";
  }
  return "지식 기록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.";
}

export default function HistoryScreen() {
  const { client, restoreSession } = useApi();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const requestIdRef = useRef(0);

  const load = useCallback(
    async (refresh = false) => {
      const requestId = ++requestIdRef.current;
      if (refresh) setRefreshing(true);
      else setState({ status: "loading" });

      try {
        const graph = await client.getHistoryGraph();
        if (requestId !== requestIdRef.current) return;
        setState({ status: "ready", nodes: graph.nodes });
        setSelectedNodeId((current) =>
          graph.nodes.some((node) => node.id === current) ? current : (graph.nodes[0]?.id ?? null),
        );
      } catch (error) {
        if (requestId !== requestIdRef.current) return;
        if (error instanceof ApiError && error.status === 401) {
          await restoreSession();
          return;
        }
        setState({ status: "error", message: getLoadErrorMessage(error) });
      } finally {
        if (requestId === requestIdRef.current) setRefreshing(false);
      }
    },
    [client, restoreSession],
  );

  useEffect(() => {
    void load();
    return () => {
      requestIdRef.current += 1;
    };
  }, [load]);

  if (state.status === "loading") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg px-5">
        <ActivityIndicator accessibilityLabel="히스토리 불러오는 중" size="large" />
        <Text className="mt-3 text-sm text-ink-muted">배운 개념을 불러오는 중이에요.</Text>
      </SafeAreaView>
    );
  }

  if (state.status === "error") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg px-5">
        <View
          accessibilityLiveRegion="assertive"
          accessibilityRole="alert"
          className="w-full max-w-sm rounded-mobile-card border border-danger bg-surface p-5"
        >
          <Text accessibilityRole="header" className="text-xl font-bold text-ink">
            히스토리를 불러오지 못했어요
          </Text>
          <Text className="mt-2 leading-6 text-ink-muted">{state.message}</Text>
          <Pressable
            accessibilityRole="button"
            className="mt-5 min-h-12 items-center justify-center rounded-mobile-control bg-primary px-4"
            onPress={() => void load()}
          >
            <Text className="font-bold text-primary-fg">다시 시도</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top", "left", "right"]}>
      <FlatList
        contentContainerClassName="flex-grow px-5 pb-6 pt-6"
        data={state.nodes}
        keyExtractor={(node) => node.id}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={() => void load(true)} />
        }
        ListHeaderComponent={
          <View className="mb-5 gap-2">
            <Text className="text-xs font-semibold tracking-wide text-ink-muted">히스토리</Text>
            <Text accessibilityRole="header" className="text-3xl font-extrabold text-ink">
              배운 개념
            </Text>
            <Text className="leading-6 text-ink-muted">
              개념을 선택해 설명과 다시 풀 수 있는 스텝을 확인해요.
            </Text>
            <Pressable
              accessibilityRole="link"
              className="mt-2 min-h-12 items-center justify-center rounded-mobile-control border border-border bg-surface px-4"
              onPress={() => router.push("/history/graph")}
            >
              <Text className="font-semibold text-primary">지식 그래프로 보기</Text>
            </Pressable>
          </View>
        }
        ListEmptyComponent={
          <View className="flex-1 items-center justify-center px-2 py-6">
            <Text accessibilityRole="header" className="text-xl font-bold text-ink">
              아직 배운 개념이 없어요
            </Text>
            <Text className="mt-2 text-center leading-6 text-ink-muted">
              오늘의 학습을 완료하면 배운 개념이 여기에 나타나요.
            </Text>
            <Pressable
              accessibilityRole="button"
              className="mt-5 min-h-12 w-full items-center justify-center rounded-mobile-control bg-primary px-4"
              onPress={() => router.push("/(tabs)")}
            >
              <Text className="font-bold text-primary-fg">학습하러 가기</Text>
            </Pressable>
          </View>
        }
        renderItem={({ item }) => {
          const selected = item.id === selectedNodeId;
          return (
            <View className="mb-3 overflow-hidden rounded-mobile-card border border-border bg-surface">
              <Pressable
                accessibilityHint="개념 설명과 관련 스텝을 펼칩니다"
                accessibilityRole="button"
                accessibilityState={{ expanded: selected, selected }}
                className="min-h-16 flex-row items-center gap-3 px-5 py-4"
                onPress={() => setSelectedNodeId(selected ? null : item.id)}
              >
                <View className="size-3 rounded-chip bg-primary" />
                <View className="min-w-0 flex-1">
                  <Text className="font-bold text-ink">{item.label}</Text>
                  <Text className="mt-1 text-xs text-ink-muted">
                    {item.category} · {formatLearnedAt(item.learnedAt)}
                  </Text>
                </View>
                <Text className="text-sm font-semibold text-primary">
                  {selected ? "접기" : "보기"}
                </Text>
              </Pressable>
              {selected ? <NodeDetails node={item} /> : null}
            </View>
          );
        }}
      />
    </SafeAreaView>
  );
}

function NodeDetails({ node }: { node: HistoryGraphNode }) {
  return (
    <View className="gap-4 border-t border-border bg-surface-muted px-5 py-4">
      <View className="gap-2">
        {getDescriptionItems(node).map(({ description, key }) => (
          <Text className="leading-6 text-ink-muted" key={key}>
            {description}
          </Text>
        ))}
      </View>
      <View className="gap-2">
        <Text className="text-xs font-semibold tracking-wide text-ink-muted">관련 스텝</Text>
        {node.relatedSteps.length === 0 ? (
          <Text className="text-sm text-ink-muted">연결된 복습 스텝이 없어요.</Text>
        ) : (
          node.relatedSteps.map((step) => (
            <Pressable
              accessibilityHint="이 스텝을 첫 문제부터 다시 풉니다"
              accessibilityRole="link"
              className="min-h-12 flex-row items-center rounded-mobile-control bg-surface px-4 py-3"
              key={`${node.id}-${step.stepOrder}`}
              onPress={() =>
                router.push({
                  pathname: "/play",
                  params: { slot: "1", step: String(step.stepOrder), topic: step.topic },
                })
              }
            >
              <Text className="mr-3 text-sm font-bold text-primary">STEP {step.stepOrder}</Text>
              <Text className="min-w-0 flex-1 text-sm font-semibold text-ink">{step.topic}</Text>
              <Text className="text-xs text-ink-muted">복습</Text>
            </Pressable>
          ))
        )}
      </View>
    </View>
  );
}

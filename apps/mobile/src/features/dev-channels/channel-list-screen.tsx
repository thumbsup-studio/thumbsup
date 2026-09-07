import { useLocalSearchParams, useRouter } from "expo-router";
import * as Updates from "expo-updates";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { fetchPrChannels, type PrChannel } from "./channel-client";
import { useStagingUpdates } from "./staging-update-provider";

function formattedDate(value: string): string {
  return new Intl.DateTimeFormat("ko-KR", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export interface ChannelCardProps {
  channel: PrChannel;
  currentRuntimeVersion: string | null;
  disabled: boolean;
  onPress: () => void;
}

export function ChannelCard({
  channel,
  currentRuntimeVersion,
  disabled,
  onPress,
}: ChannelCardProps) {
  const compatible = channel.runtimeVersion === currentRuntimeVersion;
  return (
    <Pressable
      accessibilityRole="button"
      className={`rounded-card border bg-surface p-5 ${
        compatible ? "border-border" : "border-danger"
      }`}
      disabled={disabled || !compatible}
      onPress={onPress}
    >
      <View className="flex-row items-start justify-between gap-3">
        <View className="flex-1">
          <Text className="text-lg font-bold text-ink">PR #{channel.prNumber}</Text>
          <Text className="mt-1 text-base font-semibold text-ink">{channel.title}</Text>
        </View>
        <View
          className={`rounded-control px-3 py-1 ${compatible ? "bg-primary" : "bg-surface-muted"}`}
        >
          <Text className={`text-xs font-bold ${compatible ? "text-primary-fg" : "text-danger"}`}>
            {compatible ? "호환됨" : "새 바이너리 필요"}
          </Text>
        </View>
      </View>
      <Text className="mt-4 text-sm text-ink-muted">{channel.branch}</Text>
      <Text className="mt-1 text-sm text-ink-muted">커밋 {channel.commit.slice(0, 8)}</Text>
      <Text className="mt-1 text-sm text-ink-muted">{formattedDate(channel.createdAt)}</Text>
      <Text className="mt-1 text-sm text-ink-muted">runtime {channel.runtimeVersion}</Text>
    </Pressable>
  );
}

export default function ChannelListScreen() {
  const router = useRouter();
  const { pr } = useLocalSearchParams<{ pr?: string }>();
  const { switching, switchTo } = useStagingUpdates();
  const [channels, setChannels] = useState<PrChannel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const deepLinkPr = useMemo(() => (pr && /^\d+$/.test(pr) ? Number(pr) : null), [pr]);

  const load = useCallback(async (signal?: AbortSignal) => {
    setLoading(true);
    setError(null);
    try {
      setChannels(await fetchPrChannels(signal));
    } catch (cause) {
      if (!signal?.aborted) {
        setError(cause instanceof Error ? cause.message : "채널 목록을 불러오지 못했습니다.");
      }
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    void load(controller.signal);
    return () => controller.abort();
  }, [load]);

  useEffect(() => {
    if (loading || deepLinkPr === null) return;
    const channel = channels.find((candidate) => candidate.prNumber === deepLinkPr);
    if (channel && channel.runtimeVersion === Updates.runtimeVersion)
      void switchTo(channel.prNumber);
  }, [channels, deepLinkPr, loading, switchTo]);

  return (
    <SafeAreaView className="flex-1 bg-bg">
      <View className="flex-row items-center gap-4 border-b border-border px-5 py-4">
        <Pressable
          accessibilityLabel="뒤로 가기"
          accessibilityRole="button"
          onPress={() => router.back()}
        >
          <Text className="text-base font-bold text-primary">뒤로</Text>
        </Pressable>
        <View>
          <Text className="text-xl font-bold text-ink">PR 채널</Text>
          <Text className="text-sm text-ink-muted">
            runtime {Updates.runtimeVersion ?? "알 수 없음"}
          </Text>
        </View>
      </View>
      {loading ? (
        <View className="flex-1 items-center justify-center gap-3">
          <ActivityIndicator size="large" />
          <Text className="text-ink-muted">채널을 불러오는 중…</Text>
        </View>
      ) : error ? (
        <View className="flex-1 items-center justify-center gap-4 px-6">
          <Text accessibilityRole="alert" className="text-center text-danger">
            {error}
          </Text>
          <Pressable
            accessibilityRole="button"
            className="rounded-control bg-primary px-5 py-3"
            onPress={() => void load()}
          >
            <Text className="font-bold text-primary-fg">다시 시도</Text>
          </Pressable>
        </View>
      ) : (
        <FlatList
          contentContainerClassName="gap-4 p-5 pb-28"
          data={channels}
          keyExtractor={(channel) => String(channel.prNumber)}
          ListEmptyComponent={
            <Text className="py-12 text-center text-ink-muted">열 수 있는 PR 채널이 없습니다.</Text>
          }
          renderItem={({ item }) => (
            <ChannelCard
              channel={item}
              currentRuntimeVersion={Updates.runtimeVersion}
              disabled={switching}
              onPress={() => void switchTo(item.prNumber)}
            />
          )}
        />
      )}
    </SafeAreaView>
  );
}

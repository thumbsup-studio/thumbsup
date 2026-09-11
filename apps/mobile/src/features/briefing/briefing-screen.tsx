import { ApiError, NetworkError, type QuizStepBriefingResponse } from "@thumbsup/api";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { ScreenLoading, ScreenState } from "../../components/screen-state";
import { useApi } from "../../lib/api/api-provider";
import { useConnectivity } from "../../lib/connectivity/connectivity-provider";
import { useForegroundRefresh } from "../../lib/lifecycle/use-foreground-refresh";

export type BriefingViewState =
  | { status: "missing-course" }
  | { status: "loading" }
  | { status: "offline" }
  | { status: "error"; reason: "network" | "timeout" }
  | { status: "success"; briefing: QuizStepBriefingResponse };

export function BriefingScreen({ courseId }: { courseId?: number }) {
  const router = useRouter();
  const { client, restoreSession } = useApi();
  const isOnline = useConnectivity();
  const [state, setState] = useState<BriefingViewState>(
    courseId ? { status: "loading" } : { status: "missing-course" },
  );
  const requestId = useRef(0);

  const load = useCallback(async () => {
    if (!courseId) {
      setState({ status: "missing-course" });
      return;
    }
    const currentRequest = ++requestId.current;
    if (!isOnline) {
      setState({ status: "offline" });
      return;
    }
    setState({ status: "loading" });
    try {
      const briefing = await client.getNextStepBriefing(courseId);
      if (currentRequest === requestId.current) setState({ status: "success", briefing });
    } catch (error) {
      if (currentRequest !== requestId.current) return;
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
        return;
      }
      if (error instanceof ApiError && error.code === "QUIZ_STEP_BRIEFING_NOT_AVAILABLE") {
        router.replace({ pathname: "/play", params: { courseId: String(courseId) } });
        return;
      }
      if (error instanceof ApiError && error.code === "QUIZ_STEP_COMPLETED") {
        router.replace({ pathname: "/(tabs)/course", params: { courseId: String(courseId) } });
        return;
      }
      if (error instanceof ApiError && (error.status === 403 || error.code === "QUIZ_NOT_FOUND")) {
        router.replace("/(tabs)/course");
        return;
      }
      setState({
        status: "error",
        reason: error instanceof NetworkError && error.reason === "timeout" ? "timeout" : "network",
      });
    }
  }, [client, courseId, isOnline, restoreSession, router]);

  useEffect(() => {
    void load();
    return () => {
      requestId.current += 1;
    };
  }, [load]);
  useForegroundRefresh(() => void load());

  return <BriefingScreenView courseId={courseId} onRetry={() => void load()} state={state} />;
}

export function BriefingScreenView({
  courseId,
  onRetry,
  state,
}: {
  courseId?: number;
  onRetry: () => void;
  state: BriefingViewState;
}) {
  const router = useRouter();
  const [expanded, setExpanded] = useState(false);

  if (state.status === "loading") {
    return (
      <StateShell>
        <ScreenLoading label="브리핑을 불러오는 중" />
      </StateShell>
    );
  }

  if (state.status === "missing-course") {
    return (
      <StateShell>
        <ScreenState
          actionLabel="코스 보러 가기"
          description="코스에서 풀 수 있는 스텝을 다시 선택해 주세요."
          kind="empty"
          onAction={() => router.replace("/(tabs)/course")}
          title="학습할 코스를 찾지 못했어요"
        />
      </StateShell>
    );
  }

  if (state.status === "offline") {
    return (
      <StateShell>
        <ScreenState
          description="인터넷 연결을 확인한 뒤 다시 시도해 주세요."
          kind="offline"
          onAction={onRetry}
          title="오프라인 상태예요"
        />
      </StateShell>
    );
  }

  if (state.status === "error") {
    return (
      <StateShell>
        <ScreenState
          description={
            state.reason === "timeout"
              ? "응답이 늦어 요청을 멈췄어요. 잠시 후 다시 시도해 주세요."
              : "네트워크 연결을 확인한 뒤 다시 시도해 주세요."
          }
          kind="error"
          onAction={onRetry}
          title="브리핑을 불러오지 못했어요"
        />
      </StateShell>
    );
  }

  const blocks = [...state.briefing.blocks].sort((a, b) => a.displayOrder - b.displayOrder);
  const visibleBlocks = expanded ? blocks : blocks.slice(0, 1);
  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top", "bottom", "left", "right"]}>
      <ScrollView
        className="flex-1"
        contentContainerClassName="flex-grow gap-5 px-5 py-6"
        keyboardDismissMode="on-drag"
      >
        <View>
          <Text className="text-xs font-semibold text-ink-muted">
            STEP {state.briefing.stepOrder} · 문제 전 워밍업
          </Text>
          <Text accessibilityRole="header" className="mt-1 text-2xl font-bold text-ink">
            {state.briefing.topic}
          </Text>
        </View>

        <View className="gap-4 rounded-mobile-card border border-border bg-surface p-5">
          <Text className="text-lg font-bold text-ink">핵심 요약</Text>
          <Text className="text-base leading-6 text-ink">{state.briefing.summary}</Text>
          <View accessibilityLabel="브리핑 상세 내용" className="gap-3" nativeID="briefing-content">
            {visibleBlocks.map((block) => (
              <View
                className="rounded-mobile-control bg-surface-muted p-4"
                key={`${block.displayOrder}-${block.heading}`}
              >
                <Text className="font-bold text-ink">{block.heading}</Text>
                <Text className="mt-2 leading-5 text-ink-muted">{block.content}</Text>
              </View>
            ))}
          </View>
        </View>

        {blocks.length > 1 ? (
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ expanded }}
            className="min-h-12 items-center justify-center self-center rounded-mobile-control bg-surface-muted px-5 py-3"
            onPress={() => setExpanded((current) => !current)}
          >
            <Text className="font-semibold text-ink">
              {expanded ? "간단히 보기" : "자세히 읽기"}
            </Text>
          </Pressable>
        ) : null}

        <Pressable
          accessibilityRole="button"
          className="mt-auto min-h-12 items-center justify-center rounded-mobile-control bg-primary px-5 py-3"
          onPress={() =>
            router.push({
              pathname: "/play",
              params: {
                courseId: String(courseId ?? state.briefing.courseId),
                stepId: String(state.briefing.quizStepId),
              },
            })
          }
        >
          <Text className="text-base font-semibold text-primary-fg">문제 풀기</Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

function StateShell({ children }: { children: React.ReactNode }) {
  return (
    <SafeAreaView
      className="flex-1 justify-center bg-bg px-5"
      edges={["top", "bottom", "left", "right"]}
    >
      {children}
    </SafeAreaView>
  );
}

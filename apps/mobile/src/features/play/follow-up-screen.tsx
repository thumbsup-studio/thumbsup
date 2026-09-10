import { ApiError, type FollowUpQuestionDetail, NetworkError } from "@thumbsup/api";
import { getProgressPercent } from "@thumbsup/core/play-logic";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { ScreenState } from "../../components/screen-state";
import { useApi } from "../../lib/api/api-provider";
import { useConnectivity } from "../../lib/connectivity/connectivity-provider";
import { AnnotatedParagraph } from "./annotated-text";

export type FollowUpRouteContext = {
  correct: boolean;
  correctStreak: number;
  courseId?: number;
  currentNumber: number;
  followUpQuestionId?: number;
  quizId?: number;
  totalCount: number;
};

type LoadState =
  | { status: "loading" }
  | { status: "offline" }
  | { status: "not-ready" }
  | { status: "error"; message: string }
  | { status: "ready"; data: FollowUpQuestionDetail };

const difficultyLabels = { EASY: "난이도 하", MEDIUM: "난이도 중", HARD: "난이도 상" } as const;

export function FollowUpScreen(context: FollowUpRouteContext) {
  const { client, restoreSession } = useApi();
  const isOnline = useConnectivity();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const requestId = useRef(0);

  const load = useCallback(async () => {
    if (!context.followUpQuestionId) {
      setState({ status: "error", message: "꼬리 질문 번호가 올바르지 않아요." });
      return;
    }
    const currentRequest = ++requestId.current;
    if (!isOnline) {
      setState({ status: "offline" });
      return;
    }
    setState({ status: "loading" });
    try {
      const data = await client.getFollowUpQuestion(context.followUpQuestionId);
      if (currentRequest === requestId.current) setState({ status: "ready", data });
    } catch (error) {
      if (currentRequest !== requestId.current) return;
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
        return;
      }
      if (error instanceof ApiError && error.code === "FOLLOW_UP_DETAIL_NOT_FOUND") {
        setState({ status: "not-ready" });
        return;
      }
      setState({
        status: "error",
        message:
          error instanceof NetworkError && error.reason === "timeout"
            ? "응답이 늦어 꼬리 질문을 불러오지 못했어요."
            : "꼬리 질문을 불러오지 못했어요.",
      });
    }
  }, [client, context.followUpQuestionId, isOnline, restoreSession]);

  useEffect(() => {
    void load();
    return () => {
      requestId.current += 1;
    };
  }, [load]);

  const router = useRouter();
  if (state.status === "loading") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg">
        <ActivityIndicator accessibilityLabel="꼬리 질문을 불러오는 중" size="large" />
      </SafeAreaView>
    );
  }
  if (state.status !== "ready") {
    const notReady = state.status === "not-ready";
    return (
      <SafeAreaView className="flex-1 justify-center bg-bg px-5">
        <ScreenState
          actionLabel={notReady ? "해설로 돌아가기" : undefined}
          description={
            notReady
              ? "조금만 기다려 주시면 곧 만나볼 수 있어요."
              : state.status === "offline"
                ? "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
                : state.message
          }
          kind={notReady ? "empty" : state.status === "offline" ? "offline" : "error"}
          onAction={notReady ? () => router.back() : () => void load()}
          title={
            notReady
              ? "꼬리 질문을 준비 중이에요"
              : state.status === "offline"
                ? "오프라인 상태예요"
                : "꼬리 질문을 불러오지 못했어요"
          }
        />
      </SafeAreaView>
    );
  }
  return <FollowUpScreenView context={context} data={state.data} />;
}

export function FollowUpScreenView({
  context,
  data,
}: {
  context: FollowUpRouteContext;
  data: FollowUpQuestionDetail;
}) {
  const router = useRouter();
  const [revealed, setRevealed] = useState(false);
  const isLastQuestion = context.currentNumber >= context.totalCount;

  return (
    <SafeAreaView className="flex-1 bg-bg">
      <ScrollView contentContainerClassName="flex-grow gap-4 px-4 py-5">
        <View className="rounded-card border border-border bg-surface p-4">
          <View className="flex-row items-center gap-3">
            <Pressable
              accessibilityLabel="해설로 돌아가기"
              accessibilityRole="button"
              className="size-11 items-center justify-center rounded-chip bg-surface-muted"
              onPress={() => router.back()}
            >
              <Text className="text-2xl text-ink">‹</Text>
            </Pressable>
            <View className="min-w-0 flex-1">
              <Text className="text-xs font-semibold text-ink-muted">
                {data.sourceQuizNumber}번 문제에서 이어짐
              </Text>
              <Text accessibilityRole="header" className="text-base font-bold text-ink">
                꼬리 질문
              </Text>
            </View>
            <Text className="rounded-chip border border-border bg-surface px-3 py-2 text-xs font-bold text-ink">
              {difficultyLabels[data.difficulty]}
            </Text>
          </View>
          <View
            accessibilityLabel={`꼬리 질문 진행률 ${getProgressPercent(context.currentNumber - 1, context.totalCount)}퍼센트`}
            accessibilityRole="progressbar"
            accessibilityValue={{ max: context.totalCount, min: 0, now: context.currentNumber }}
            className="mt-4 h-2 overflow-hidden rounded-chip bg-border"
          >
            <View
              className="h-2 rounded-chip bg-primary"
              style={{
                width: `${getProgressPercent(context.currentNumber - 1, context.totalCount)}%`,
              }}
            />
          </View>
        </View>

        <View className="flex-1 rounded-card border border-border bg-surface-muted p-5">
          <View className="rounded-card border border-primary bg-surface p-5">
            <Text className="text-sm font-bold text-primary">꼬리 질문</Text>
            <Text accessibilityRole="header" className="mt-3 text-xl font-black leading-8 text-ink">
              {data.question}
            </Text>
          </View>

          <View className="mt-3 rounded-card bg-surface p-5">
            <Text className="text-xs font-bold text-primary">한 줄 답</Text>
            {revealed ? (
              <View className="mt-3">
                <AnnotatedParagraph
                  node={data.oneLineAnswer}
                  keywords={data.keywords.map((keyword) => ({
                    keyword: keyword.keyword,
                    description: keyword.description,
                  }))}
                />
              </View>
            ) : (
              <View className="mt-4 items-center py-5">
                <Text className="text-2xl text-ink-muted">◌</Text>
                <Text className="mt-2 text-center text-sm font-semibold text-ink-muted">
                  먼저 스스로 답을 떠올려 보세요.
                </Text>
              </View>
            )}
          </View>

          <View className={`mt-6 gap-3 ${revealed ? "" : "opacity-40"}`}>
            <Text className="font-bold text-ink">상세 정리</Text>
            {data.blocks.map((block) => (
              <View
                className="rounded-control border border-border bg-surface p-4"
                key={`${block.label}-${block.content.text}`}
              >
                <Text className="font-bold text-ink">{block.label}</Text>
                {revealed ? (
                  <View className="mt-2">
                    <AnnotatedParagraph
                      node={block.content}
                      keywords={data.keywords.map((keyword) => ({
                        keyword: keyword.keyword,
                        description: keyword.description,
                      }))}
                    />
                  </View>
                ) : (
                  <Text className="mt-2 text-ink-muted">답을 확인하면 상세 내용이 보여요.</Text>
                )}
              </View>
            ))}
          </View>

          <View className="mt-auto gap-3 pt-6">
            {revealed ? (
              <>
                <Pressable
                  accessibilityLabel="해설로 돌아가기"
                  accessibilityRole="button"
                  className="min-h-12 items-center justify-center rounded-control bg-primary"
                  onPress={() => router.back()}
                >
                  <Text className="font-bold text-primary-fg">해설로 돌아가기</Text>
                </Pressable>
                <Pressable
                  accessibilityLabel={
                    isLastQuestion ? (context.courseId ? "코스 목록으로" : "홈으로") : "다음 문제로"
                  }
                  accessibilityRole="button"
                  className="min-h-12 items-center justify-center rounded-control border border-border bg-surface"
                  onPress={() =>
                    router.replace(
                      isLastQuestion
                        ? context.courseId
                          ? "/(tabs)/course"
                          : "/(tabs)"
                        : {
                            pathname: "/play",
                            params: context.courseId ? { courseId: String(context.courseId) } : {},
                          },
                    )
                  }
                >
                  <Text className="font-bold text-ink">
                    {isLastQuestion
                      ? context.courseId
                        ? "코스 목록으로"
                        : "홈으로"
                      : "다음 문제로"}
                  </Text>
                </Pressable>
              </>
            ) : (
              <>
                <Pressable
                  accessibilityRole="button"
                  className="min-h-12 items-center justify-center rounded-control bg-primary"
                  onPress={() => setRevealed(true)}
                >
                  <Text className="font-bold text-primary-fg">답 확인하기</Text>
                </Pressable>
                <Pressable
                  accessibilityRole="button"
                  className="min-h-12 items-center justify-center rounded-control border border-border bg-surface"
                  onPress={() =>
                    router.replace({
                      pathname: "/play",
                      params: context.courseId ? { courseId: String(context.courseId) } : {},
                    })
                  }
                >
                  <Text className="font-semibold text-ink-muted">이 질문 건너뛰기</Text>
                </Pressable>
              </>
            )}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

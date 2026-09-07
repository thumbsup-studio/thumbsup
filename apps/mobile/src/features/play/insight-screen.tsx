import { ApiError, NetworkError, type QuizExplanationResponse } from "@thumbsup/api";
import { getCelebration } from "@thumbsup/core/celebration-logic";
import {
  type CompletionSummary,
  clampCompletion,
  isPerfectCompletion,
} from "@thumbsup/core/completion-params";
import {
  comboVisibleFrom,
  difficultyLabels,
  getInsightQuestionKindLabel,
} from "@thumbsup/core/quiz-shared";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { ScreenState } from "../../components/screen-state";
import { useApi } from "../../lib/api/api-provider";
import { useConnectivity } from "../../lib/connectivity/connectivity-provider";
import { AnnotatedParagraph } from "./annotated-text";
import { CelebrationParticles } from "./celebration-particles";
import { useReducedMotion } from "./use-reduced-motion";

export type InsightRouteContext = {
  completion?: CompletionSummary | null;
  correct: boolean;
  correctStreak: number;
  courseId?: number;
  quizId?: number;
  review?: { slot: number; step: number; topic: string };
  wasRetry: boolean;
};

type LoadState =
  | { status: "loading" }
  | { status: "offline" }
  | { status: "error"; message: string }
  | { status: "ready"; explanation: QuizExplanationResponse };

export function InsightScreen(context: InsightRouteContext) {
  const { client, restoreSession } = useApi();
  const isOnline = useConnectivity();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const requestId = useRef(0);

  const load = useCallback(async () => {
    if (!context.quizId) {
      setState({ status: "error", message: "해설에 필요한 문제 번호가 없어요." });
      return;
    }
    const currentRequest = ++requestId.current;
    if (!isOnline) {
      setState({ status: "offline" });
      return;
    }
    setState({ status: "loading" });
    try {
      const explanation = await client.getQuizExplanation(context.quizId);
      if (currentRequest === requestId.current) setState({ status: "ready", explanation });
    } catch (error) {
      if (currentRequest !== requestId.current) return;
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
        return;
      }
      setState({
        status: "error",
        message:
          error instanceof NetworkError && error.reason === "timeout"
            ? "응답이 늦어 해설을 불러오지 못했어요."
            : "해설을 불러오지 못했어요.",
      });
    }
  }, [client, context.quizId, isOnline, restoreSession]);

  useEffect(() => {
    void load();
    return () => {
      requestId.current += 1;
    };
  }, [load]);

  if (state.status === "loading") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg">
        <ActivityIndicator accessibilityLabel="해설을 불러오는 중" size="large" />
      </SafeAreaView>
    );
  }
  if (state.status === "offline" || state.status === "error") {
    return (
      <SafeAreaView className="flex-1 justify-center bg-bg px-5">
        <ScreenState
          description={
            state.status === "offline"
              ? "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
              : state.message
          }
          kind={state.status === "offline" ? "offline" : "error"}
          onAction={() => void load()}
          title={state.status === "offline" ? "오프라인 상태예요" : "해설을 불러오지 못했어요"}
        />
      </SafeAreaView>
    );
  }
  return <InsightScreenView context={context} explanation={state.explanation} />;
}

export function InsightScreenView({
  context,
  explanation,
}: {
  context: InsightRouteContext;
  explanation: QuizExplanationResponse;
}) {
  const router = useRouter();
  const reduceMotion = useReducedMotion();
  const combo = context.review ? 0 : context.correctStreak;
  const celebration = getCelebration({
    combo,
    correct: context.correct,
    difficulty: explanation.difficulty,
    prefersReducedMotion: reduceMotion,
    quizId: context.quizId ?? 0,
    wasRetry: context.wasRetry,
  });
  const completion = context.completion
    ? clampCompletion(context.completion, explanation.totalCount)
    : null;
  const perfect = completion ? isPerfectCompletion(completion, explanation.totalCount) : false;
  const primaryFollowUp =
    explanation.followUpQuestions.find((question) => question.isPrimary) ??
    explanation.followUpQuestions[0];

  return (
    <SafeAreaView className="flex-1 bg-bg">
      <CelebrationParticles
        praise={celebration.praise}
        visible={celebration.tier === "confetti" || perfect}
      />
      <ScrollView contentContainerClassName="gap-4 px-4 py-5">
        <View className="rounded-card border border-border bg-surface p-4">
          <View className="flex-row items-center gap-3">
            <Pressable
              accessibilityLabel={context.review ? "코스로 돌아가기" : "문제로 돌아가기"}
              accessibilityRole="button"
              className="size-11 items-center justify-center rounded-chip bg-surface-muted"
              onPress={() => router.back()}
            >
              <Text className="text-2xl text-ink">‹</Text>
            </Pressable>
            <View className="min-w-0 flex-1">
              <Text className="text-xs font-semibold text-ink-muted">
                {explanation.courseTitle}
              </Text>
              <Text accessibilityRole="header" className="text-base font-bold text-ink">
                {explanation.unitTitle}
              </Text>
            </View>
            <Text
              className={`rounded-chip px-3 py-2 text-xs font-bold ${context.correct ? "bg-success text-primary-fg" : "bg-danger text-primary-fg"}`}
            >
              {context.correct ? "정답" : "오답"}
            </Text>
          </View>
          <Text className="mt-4 text-xs font-semibold text-ink-muted">
            {explanation.currentNumber}/{explanation.totalCount} ·{" "}
            {difficultyLabels[explanation.difficulty]}
          </Text>
        </View>

        <View className="rounded-card border border-border bg-surface-muted p-5">
          <View
            accessibilityLiveRegion="polite"
            className={`rounded-control p-4 ${context.correct ? "bg-success" : "bg-danger"}`}
          >
            <Text className="text-lg font-black text-primary-fg">{celebration.praise}</Text>
            {celebration.comboCount >= comboVisibleFrom ? (
              <Text className="mt-1 font-bold text-primary-fg">
                {celebration.comboCount}연속 정답
              </Text>
            ) : null}
          </View>
          <Text className="mt-5 text-xs font-bold text-ink-muted">
            {getInsightQuestionKindLabel(explanation.type)}
          </Text>
          <Text accessibilityRole="header" className="mt-2 text-xl font-black leading-7 text-ink">
            {explanation.questionText}
          </Text>

          {!context.correct ? (
            <View className="mt-4 rounded-control border border-danger bg-surface p-4">
              <Text className="mb-2 font-bold text-danger">왜 틀렸는지</Text>
              <AnnotatedParagraph
                node={explanation.wrongAnswerExplanation}
                keywords={explanation.keywords}
              />
            </View>
          ) : null}

          <View className="mt-5 gap-3">
            <Text className="text-lg font-black text-ink">핵심 3줄</Text>
            {explanation.explanationSummary.map((item, index) => (
              <View className="flex-row rounded-control bg-surface p-4" key={item.text}>
                <Text className="mr-3 font-black text-primary">{index + 1}</Text>
                <View className="flex-1">
                  <AnnotatedParagraph node={item} keywords={explanation.keywords} />
                </View>
              </View>
            ))}
          </View>

          {explanation.explanationExample ? (
            <View className="mt-4 rounded-control bg-surface p-4">
              <Text className="mb-2 font-bold text-ink">실무에서는</Text>
              <AnnotatedParagraph
                node={explanation.explanationExample}
                keywords={explanation.keywords}
              />
            </View>
          ) : null}

          {completion ? (
            <View className="mt-5 rounded-card border border-primary bg-surface p-5">
              <Text className="text-lg font-black text-ink">한 세션을 완주했어요</Text>
              <Text className="mt-2 text-ink-muted">
                {completion.answered === explanation.totalCount
                  ? `${completion.answered}문제 중 ${completion.correct}문제 정답 · 최고 ${completion.bestCombo}연속`
                  : `최고 ${completion.bestCombo}연속 정답`}
              </Text>
            </View>
          ) : null}

          <View className="mt-6 gap-3">
            {!context.review && primaryFollowUp ? (
              <Pressable
                accessibilityRole="button"
                className="min-h-12 items-center justify-center rounded-control border border-primary bg-surface px-4"
                onPress={() =>
                  router.push({
                    pathname: "/follow-up",
                    params: {
                      fq: String(primaryFollowUp.followUpQuestionId),
                      quizId: String(context.quizId ?? ""),
                      correct: String(context.correct),
                      streak: String(context.correctStreak),
                      ...(context.courseId ? { courseId: String(context.courseId) } : {}),
                      current: String(explanation.currentNumber),
                      total: String(explanation.totalCount),
                    },
                  })
                }
              >
                <Text className="font-bold text-primary">꼬리 질문 보기</Text>
              </Pressable>
            ) : null}
            <Pressable
              accessibilityRole="button"
              className="min-h-12 items-center justify-center rounded-control bg-primary px-4"
              onPress={() => navigateNext(router, context, explanation)}
            >
              <Text className="font-bold text-primary-fg">
                {context.review
                  ? context.review.slot >= explanation.totalCount
                    ? "복습 완료"
                    : "다음 문제"
                  : completion
                    ? context.courseId
                      ? "코스 목록으로"
                      : "홈으로"
                    : "다음 문제 풀기"}
              </Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function navigateNext(
  router: ReturnType<typeof useRouter>,
  context: InsightRouteContext,
  explanation: QuizExplanationResponse,
) {
  if (context.review) {
    if (context.review.slot >= explanation.totalCount) {
      router.replace({
        pathname: "/history/done",
        params: { step: String(context.review.step), topic: context.review.topic },
      });
    } else {
      router.replace({
        pathname: "/play",
        params: {
          step: String(context.review.step),
          slot: String(context.review.slot + 1),
          topic: context.review.topic,
        },
      });
    }
    return;
  }
  if (context.completion) {
    router.replace(context.courseId ? "/(tabs)/course" : "/(tabs)");
    return;
  }
  router.replace({
    pathname: "/play",
    params: context.courseId ? { courseId: String(context.courseId) } : {},
  });
}

import { ApiError, NetworkError, type QuizNextResponse, type RetryHint } from "@thumbsup/api";
import { normalizeKeywordAnswer } from "@thumbsup/core/play-logic";
import {
  comboVisibleFrom,
  difficultyLabels,
  getPlayQuestionKindLabel,
  shuffleChoices,
} from "@thumbsup/core/quiz-shared";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  AccessibilityInfo,
  ActivityIndicator,
  KeyboardAvoidingView,
  Pressable,
  ScrollView,
  Text,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { ScreenState } from "../../components/screen-state";
import { useApi } from "../../lib/api/api-provider";
import { useConnectivity } from "../../lib/connectivity/connectivity-provider";
import {
  type AnswerDraft,
  BlankQuestion,
  CodeReadingQuestion,
  DescriptiveQuestion,
  MatchingQuestion,
  OxQuestion,
} from "./question-components";
import { emptySession, type PlaySession, readSession, recordAnswer } from "./session-progress";

export type PlayRouteContext = {
  courseId?: number;
  quizStepId?: number;
  review?: { slot: number; step: number; topic: string };
};

type LoadState =
  | { status: "loading" }
  | { status: "offline" }
  | { status: "error"; message: string }
  | { status: "ready"; quiz: QuizNextResponse };

export function PlayScreen({ courseId, quizStepId, review }: PlayRouteContext) {
  const router = useRouter();
  const { client, restoreSession } = useApi();
  const isOnline = useConnectivity();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [draft, setDraft] = useState<AnswerDraft>(null);
  const [session, setSession] = useState<PlaySession>(emptySession);
  const [requestedHint, setRequestedHint] = useState<string | null>(null);
  const [hintError, setHintError] = useState<string | null>(null);
  const [retryHint, setRetryHint] = useState<RetryHint | null>(null);
  const [hasUsedRetry, setHasUsedRetry] = useState(false);
  const [isHintLoading, setHintLoading] = useState(false);
  const [isSubmitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const requestId = useRef(0);

  const load = useCallback(async () => {
    const currentRequest = ++requestId.current;
    if (!isOnline) {
      setState({ status: "offline" });
      return;
    }
    setState({ status: "loading" });
    setDraft(null);
    setRequestedHint(null);
    setHintError(null);
    setRetryHint(null);
    setHasUsedRetry(false);
    setSubmitError(null);
    try {
      const quiz = review
        ? await client.getStepQuiz(review.step, review.slot)
        : quizStepId
          ? await client.getNextQuizForStep(quizStepId)
          : await client.getNextQuiz(courseId);
      const restored = review ? emptySession : await readSession(quiz.stepOrder);
      if (currentRequest !== requestId.current) return;
      setSession(restored);
      setState({ status: "ready", quiz });
    } catch (error) {
      if (currentRequest !== requestId.current) return;
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
        return;
      }
      if (
        quizStepId &&
        error instanceof ApiError &&
        (error.status === 403 ||
          error.code === "QUIZ_STEP_NOT_CURRENT" ||
          error.code === "QUIZ_STEP_COMPLETED")
      ) {
        router.replace({
          pathname: "/play",
          params: courseId ? { courseId: String(courseId) } : {},
        });
        return;
      }
      setState({
        status: "error",
        message:
          error instanceof NetworkError && error.reason === "timeout"
            ? "응답이 늦어 문제를 불러오지 못했어요."
            : "문제를 불러오지 못했어요.",
      });
    }
  }, [client, courseId, isOnline, quizStepId, restoreSession, review, router]);

  useEffect(() => {
    void load();
    return () => {
      requestId.current += 1;
    };
  }, [load]);

  const quiz = state.status === "ready" ? state.quiz : null;
  const displayedChoices = useMemo(() => {
    const choices = quiz?.choices ?? [];
    return review ? shuffleChoices(choices) : choices;
  }, [quiz, review]);
  const submitEnabled = quiz
    ? canSubmitAnswer(quiz, draft) && !isSubmitting && !isHintLoading
    : false;

  async function showHint() {
    if (!quiz || requestedHint || isHintLoading || isSubmitting || hasUsedRetry) return;
    setHintLoading(true);
    setHintError(null);
    try {
      const result = await client.requestQuizHint(quiz.quizId);
      setRequestedHint(result.hint);
      AccessibilityInfo.announceForAccessibility(`힌트. ${result.hint}`);
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) await restoreSession();
      else setHintError("힌트를 불러오지 못했어요.");
    } finally {
      setHintLoading(false);
    }
  }

  async function submitAnswer() {
    if (!quiz || !submitEnabled) return;
    setSubmitting(true);
    setSubmitError(null);
    try {
      const result = await client.submitQuizAnswer(quiz.quizId, getSubmittedAnswers(quiz, draft));
      if (!result.isCorrect && quiz.difficulty !== "EASY" && !hasUsedRetry && result.retryHint) {
        setHasUsedRetry(true);
        setRetryHint(result.retryHint);
        setDraft(null);
        AccessibilityInfo.announceForAccessibility("오답이에요. 힌트를 보고 한 번 더 풀어 보세요.");
        return;
      }

      const nextSession = review
        ? emptySession
        : await recordAnswer(quiz.stepOrder, result.isCorrect);
      setSession(nextSession);
      const isLastQuestion = quiz.slotOrder >= quiz.totalCount;
      if (isLastQuestion && !review) {
        void client.apiRequest("/mascot/feed", { method: "POST" }).catch(() => undefined);
      }
      router.push({
        pathname: "/insight",
        params: buildInsightParams({
          courseId,
          correct: result.isCorrect,
          isLastQuestion,
          quiz,
          review,
          session: nextSession,
          wasRetry: hasUsedRetry && result.isCorrect,
        }),
      });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) await restoreSession();
      else setSubmitError("정답을 확인하지 못했어요. 입력한 답은 그대로 두었어요.");
    } finally {
      setSubmitting(false);
    }
  }

  if (state.status === "loading") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg">
        <ActivityIndicator accessibilityLabel="문제를 불러오는 중" size="large" />
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
          title={state.status === "offline" ? "오프라인 상태예요" : "문제를 불러오지 못했어요"}
        />
      </SafeAreaView>
    );
  }

  return (
    <PlayScreenView
      context={{ courseId, quizStepId, review }}
      displayedChoices={displayedChoices}
      draft={draft}
      hasUsedRetry={hasUsedRetry}
      hintError={hintError}
      isHintLoading={isHintLoading}
      isSubmitting={isSubmitting}
      onDraftChange={setDraft}
      onHint={() => void showHint()}
      onSubmit={() => void submitAnswer()}
      quiz={state.quiz}
      requestedHint={requestedHint}
      retryHint={retryHint}
      session={session}
      submitEnabled={submitEnabled}
      submitError={submitError}
    />
  );
}

export function PlayScreenView({
  context,
  displayedChoices,
  draft,
  hasUsedRetry,
  hintError,
  isHintLoading,
  isSubmitting,
  onDraftChange,
  onHint,
  onSubmit,
  quiz,
  requestedHint,
  retryHint,
  session,
  submitEnabled,
  submitError,
}: {
  context: PlayRouteContext;
  displayedChoices: QuizNextResponse["choices"] extends infer _T
    ? NonNullable<QuizNextResponse["choices"]>
    : never;
  draft: AnswerDraft;
  hasUsedRetry: boolean;
  hintError: string | null;
  isHintLoading: boolean;
  isSubmitting: boolean;
  onDraftChange: (draft: AnswerDraft) => void;
  onHint: () => void;
  onSubmit: () => void;
  quiz: QuizNextResponse;
  requestedHint: string | null;
  retryHint: RetryHint | null;
  session: PlaySession;
  submitEnabled: boolean;
  submitError: string | null;
}) {
  const router = useRouter();
  const comboVisible = !context.review && session.combo >= comboVisibleFrom;
  const progressSegments = Array.from(
    { length: quiz.totalCount },
    (_, index) => `progress-${index + 1}`,
  );

  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top", "bottom", "left", "right"]}>
      <KeyboardAvoidingView behavior="padding" className="flex-1">
        <ScrollView
          className="flex-1"
          keyboardShouldPersistTaps="handled"
          contentContainerClassName="flex-grow gap-4 px-5 py-6"
          keyboardDismissMode="on-drag"
        >
          <View className="rounded-mobile-card border border-border bg-surface p-5">
            <View className="flex-row items-center gap-3">
              <Pressable
                accessibilityLabel={
                  context.courseId || context.review ? "코스 목록으로 돌아가기" : "홈으로 돌아가기"
                }
                accessibilityRole="button"
                className="size-11 items-center justify-center rounded-mobile-control bg-surface-muted"
                onPress={() =>
                  router.replace(context.courseId || context.review ? "/(tabs)/course" : "/(tabs)")
                }
              >
                <Text className="text-2xl text-ink">‹</Text>
              </Pressable>
              <View className="min-w-0 flex-1">
                <Text className="text-xs font-semibold text-ink-muted">
                  {context.review ? "복습" : "오늘의 학습"}
                </Text>
                <Text accessibilityRole="header" className="text-base font-bold text-ink">
                  {context.review?.topic || "문제 풀기"}
                </Text>
              </View>
              <Text className="text-sm font-bold text-ink">
                {quiz.slotOrder}/{quiz.totalCount}
              </Text>
            </View>
            <View
              accessibilityLabel={`${quiz.totalCount}문제 중 ${quiz.slotOrder}번째`}
              accessibilityRole="progressbar"
              accessibilityValue={{ max: quiz.totalCount, min: 0, now: quiz.slotOrder - 1 }}
              className="mt-4 h-2 flex-row gap-1"
            >
              {progressSegments.map((segment, index) => (
                <View
                  className={`h-2 flex-1 rounded-chip ${index < quiz.slotOrder - 1 ? (comboVisible ? "bg-accent" : "bg-primary") : "bg-border"}`}
                  key={segment}
                />
              ))}
            </View>
          </View>

          <View className="flex-1 rounded-mobile-card border border-border bg-surface-muted p-5">
            {retryHint ? (
              <View
                accessibilityLiveRegion="polite"
                className="mb-4 rounded-mobile-control bg-surface p-4"
              >
                <Text className="font-semibold leading-6 text-ink">
                  오답이에요. 힌트를 보고 한 번 더 풀어 보세요.
                </Text>
              </View>
            ) : null}
            <Text className="text-xs font-bold text-ink-muted">
              {getMobileQuestionLabel(quiz)} · {difficultyLabels[quiz.difficulty]}
            </Text>
            <Text
              accessibilityRole="header"
              className="mt-2 text-2xl font-black leading-8 text-ink"
            >
              {quiz.questionText}
            </Text>
            {requestedHint ? (
              <View
                accessibilityLiveRegion="polite"
                className="mt-4 rounded-mobile-control bg-surface p-4"
              >
                <Text className="text-xs font-bold text-ink-muted">힌트</Text>
                <Text className="mt-2 font-semibold leading-6 text-ink">{requestedHint}</Text>
              </View>
            ) : null}

            <View className="my-6 flex-1 justify-center">
              <QuestionRenderer
                choices={displayedChoices}
                draft={draft}
                isLocked={isSubmitting}
                onDraftChange={onDraftChange}
                quiz={quiz}
                retryHint={retryHint}
              />
            </View>

            {hintError || submitError ? (
              <Text
                accessibilityLiveRegion="assertive"
                accessibilityRole="alert"
                className="mb-3 text-sm font-semibold text-danger"
              >
                {hintError ?? submitError}
              </Text>
            ) : null}
          </View>
        </ScrollView>
        <View className="flex-row gap-3 border-t border-border bg-bg px-5 py-3">
          <Pressable
            accessibilityRole="button"
            accessibilityState={{
              disabled: Boolean(requestedHint) || isSubmitting || hasUsedRetry,
            }}
            className="min-h-12 flex-1 items-center justify-center rounded-mobile-control border border-border bg-surface px-3"
            disabled={Boolean(requestedHint) || isSubmitting || hasUsedRetry}
            onPress={onHint}
          >
            <Text className="font-semibold text-ink-muted">
              {isHintLoading ? "불러오는 중" : requestedHint ? "힌트 확인함" : "힌트 보기"}
            </Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ disabled: !submitEnabled }}
            className={`min-h-12 flex-1 items-center justify-center rounded-mobile-control px-3 ${submitEnabled ? "bg-primary" : "bg-border"}`}
            disabled={!submitEnabled}
            onPress={onSubmit}
          >
            <Text
              className={submitEnabled ? "font-bold text-primary-fg" : "font-bold text-ink-muted"}
            >
              {isSubmitting ? "채점 중" : "정답 확인"}
            </Text>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function QuestionRenderer({
  choices,
  draft,
  isLocked,
  onDraftChange,
  quiz,
  retryHint,
}: {
  choices: NonNullable<QuizNextResponse["choices"]>;
  draft: AnswerDraft;
  isLocked: boolean;
  onDraftChange: (draft: AnswerDraft) => void;
  quiz: QuizNextResponse;
  retryHint: RetryHint | null;
}) {
  if (quiz.type === "OX") {
    return <OxQuestion disabled={isLocked} draft={draft} onDraftChange={onDraftChange} />;
  }
  if (quiz.type === "MULTIPLE_CHOICE") {
    const props = {
      choices,
      disabled: isLocked,
      draft,
      eliminatedChoiceId: retryHint?.eliminatedChoiceId,
      onDraftChange,
    };
    return quiz.codeSnippet ? (
      <CodeReadingQuestion code={quiz.codeSnippet} {...props} />
    ) : (
      <MatchingQuestion {...props} />
    );
  }
  const inputProps = {
    blankHints: retryHint?.blankHints ?? null,
    disabled: isLocked,
    draft: Array.isArray(draft) ? draft : [],
    onDraftChange,
  };
  return quiz.codeSnippet || (quiz.blankCount ?? 1) > 1 ? (
    <BlankQuestion blankCount={quiz.blankCount ?? 1} code={quiz.codeSnippet} {...inputProps} />
  ) : (
    <DescriptiveQuestion {...inputProps} />
  );
}

export function getMobileQuestionLabel(quiz: QuizNextResponse) {
  if (quiz.type === "MULTIPLE_CHOICE") return quiz.codeSnippet ? "코드 리딩" : "매칭";
  if (quiz.type === "KEYWORD_BLANK")
    return quiz.codeSnippet || (quiz.blankCount ?? 1) > 1 ? "빈칸" : "서술형";
  return getPlayQuestionKindLabel(quiz.type);
}

function canSubmitAnswer(quiz: QuizNextResponse, draft: AnswerDraft) {
  if (quiz.type === "OX") return typeof draft === "boolean";
  if (quiz.type === "MULTIPLE_CHOICE") return typeof draft === "string" && draft.length > 0;
  return (
    Array.isArray(draft) &&
    draft.length === (quiz.blankCount ?? 1) &&
    draft.every((answer) => normalizeKeywordAnswer(answer).length > 0)
  );
}

function getSubmittedAnswers(quiz: QuizNextResponse, draft: AnswerDraft) {
  if (quiz.type === "OX") return [draft === true ? "O" : "X"];
  if (quiz.type === "MULTIPLE_CHOICE") return [String(draft ?? "")];
  return Array.isArray(draft) ? draft.map((answer) => answer.trim()) : [];
}

function buildInsightParams({
  correct,
  courseId,
  isLastQuestion,
  quiz,
  review,
  session,
  wasRetry,
}: {
  correct: boolean;
  courseId?: number;
  isLastQuestion: boolean;
  quiz: QuizNextResponse;
  review?: PlayRouteContext["review"];
  session: PlaySession;
  wasRetry: boolean;
}) {
  return {
    quizId: String(quiz.quizId),
    correct: String(correct),
    streak: String(session.combo),
    ...(wasRetry ? { retry: "1" } : {}),
    ...(courseId ? { courseId: String(courseId) } : {}),
    ...(isLastQuestion && !review
      ? {
          done: "1",
          c: String(session.correct),
          bc: String(session.bestCombo),
          a: String(session.answered),
        }
      : {}),
    ...(review
      ? { step: String(review.step), slot: String(review.slot), topic: review.topic }
      : {}),
  };
}

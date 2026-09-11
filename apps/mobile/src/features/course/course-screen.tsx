import { ApiError, type CourseItem, type CourseStep, NetworkError } from "@thumbsup/api";
import { tokens } from "@thumbsup/tokens";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { LayoutAnimation, Pressable, ScrollView, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { ChevronRightIcon, LockIcon } from "../../components/icons";
import { ScreenLoading, ScreenState } from "../../components/screen-state";
import { useApi } from "../../lib/api/api-provider";
import { useConnectivity } from "../../lib/connectivity/connectivity-provider";
import { useForegroundRefresh } from "../../lib/lifecycle/use-foreground-refresh";
import { useReducedMotion } from "../play/use-reduced-motion";

export type CourseViewState =
  | { status: "loading" }
  | { status: "offline" }
  | { status: "error"; reason: "network" | "timeout" }
  | { status: "success"; courses: CourseItem[] };

function defaultOpenCourseId(courses: CourseItem[], requested?: number): number | null {
  if (requested && courses.some((course) => course.courseId === requested)) return requested;
  return (
    courses.find((course) => course.steps.some((step) => step.state === "SOLVABLE"))?.courseId ??
    null
  );
}

export function CourseScreen({ initialOpenCourseId }: { initialOpenCourseId?: number }) {
  const { client, restoreSession } = useApi();
  const isOnline = useConnectivity();
  const [state, setState] = useState<CourseViewState>({ status: "loading" });
  const [openCourseId, setOpenCourseId] = useState<number | null>(null);
  const requestId = useRef(0);
  const hasLoaded = useRef(false);

  const load = useCallback(async () => {
    const currentRequest = ++requestId.current;
    if (!isOnline) {
      setState({ status: "offline" });
      return;
    }
    setState({ status: "loading" });
    try {
      const response = await client.getCourses();
      if (currentRequest === requestId.current) {
        setState({ status: "success", courses: response.items });
        setOpenCourseId((current) => {
          if (
            hasLoaded.current &&
            (current === null || response.items.some((course) => course.courseId === current))
          ) {
            return current;
          }
          return defaultOpenCourseId(response.items, initialOpenCourseId);
        });
        hasLoaded.current = true;
      }
    } catch (error) {
      if (currentRequest !== requestId.current) return;
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
        return;
      }
      setState({
        status: "error",
        reason: error instanceof NetworkError && error.reason === "timeout" ? "timeout" : "network",
      });
    }
  }, [client, initialOpenCourseId, isOnline, restoreSession]);

  useEffect(() => {
    void load();
    return () => {
      requestId.current += 1;
    };
  }, [load]);
  useForegroundRefresh(() => void load());

  return (
    <CourseScreenView
      onRetry={() => void load()}
      onToggle={(courseId) =>
        setOpenCourseId((current) => (current === courseId ? null : courseId))
      }
      openCourseId={openCourseId}
      state={state}
    />
  );
}

export function CourseScreenView({
  onRetry,
  onToggle,
  openCourseId,
  state,
}: {
  onRetry: () => void;
  onToggle: (courseId: number) => void;
  openCourseId: number | null;
  state: CourseViewState;
}) {
  const router = useRouter();
  const reduceMotion = useReducedMotion();

  if (state.status === "loading") {
    return (
      <SafeAreaView className="flex-1 bg-bg" edges={["top", "left", "right"]}>
        <ScreenLoading label="코스 목록을 불러오는 중" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top", "left", "right"]}>
      <ScrollView
        className="flex-1"
        contentContainerClassName="flex-grow gap-5 px-5 py-6"
        keyboardDismissMode="on-drag"
      >
        <View>
          <Text className="text-xs font-semibold text-ink-muted">코스</Text>
          <Text accessibilityRole="header" className="mt-1 text-2xl font-semibold text-ink">
            원하는 코스를 선택해{"\n"}학습을 시작해보세요.
          </Text>
        </View>

        {state.status === "offline" ? (
          <ScreenState
            description="인터넷 연결을 확인한 뒤 다시 시도해 주세요."
            kind="offline"
            onAction={onRetry}
            title="오프라인 상태예요"
          />
        ) : null}
        {state.status === "error" ? (
          <ScreenState
            description={
              state.reason === "timeout"
                ? "응답이 늦어 요청을 멈췄어요. 잠시 후 다시 시도해 주세요."
                : "잠시 후 다시 시도해 주세요."
            }
            kind="error"
            onAction={onRetry}
            title="코스 목록을 불러오지 못했어요"
          />
        ) : null}
        {state.status === "success" && state.courses.length === 0 ? (
          <ScreenState
            actionLabel="홈으로 가기"
            description="코스가 준비되면 여기에 표시돼요."
            kind="empty"
            onAction={() => router.push("/(tabs)")}
            title="등록된 코스가 없어요"
          />
        ) : null}
        {state.status === "success" && state.courses.length > 0 ? (
          <View accessibilityLabel={`코스 ${state.courses.length}개`} className="gap-4">
            {state.courses.map((course) => (
              <CourseCard
                course={course}
                isOpen={openCourseId === course.courseId}
                key={course.courseId}
                onOpenStep={(step) => {
                  if (step.state === "SOLVABLE") {
                    router.push({
                      pathname: "/briefing",
                      params: { courseId: String(course.courseId) },
                    });
                  } else if (step.state === "COMPLETED") {
                    router.push({
                      pathname: "/play",
                      params: { slot: "1", step: String(step.stepOrder), topic: step.topic },
                    });
                  }
                }}
                onToggle={() => {
                  if (!reduceMotion)
                    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
                  onToggle(course.courseId);
                }}
              />
            ))}
          </View>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

function CourseCard({
  course,
  isOpen,
  onOpenStep,
  onToggle,
}: {
  course: CourseItem;
  isOpen: boolean;
  onOpenStep: (step: CourseStep) => void;
  onToggle: () => void;
}) {
  const completed =
    course.steps.length > 0 && course.steps.every((step) => step.state === "COMPLETED");
  return (
    <View className="overflow-hidden rounded-mobile-card border border-border bg-surface">
      <Pressable
        accessibilityHint="코스의 스텝 목록을 펼치거나 접습니다"
        accessibilityRole="button"
        accessibilityState={{ expanded: isOpen }}
        className="min-h-16 flex-row items-center justify-between gap-3 p-5"
        onPress={onToggle}
      >
        <View className="min-w-0 flex-1">
          <Text className="text-xs font-semibold text-ink-muted">{course.category}</Text>
          <Text className="mt-1 text-lg font-bold text-ink">{course.title}</Text>
        </View>
        {completed ? (
          <Text className="rounded-chip bg-badge px-2 py-1 text-xs font-bold text-badge-fg">
            완주
          </Text>
        ) : null}
        <Text className="rounded-chip bg-surface-muted px-2 py-1 text-xs font-semibold text-ink-muted">
          스텝 {course.steps.length}개
        </Text>
        <View style={{ transform: [{ rotate: isOpen ? "90deg" : "0deg" }] }}>
          <ChevronRightIcon height={20} width={20} />
        </View>
      </Pressable>
      {isOpen ? (
        <View className="border-t border-border">
          {course.steps.map((step, index) => (
            <StepRow
              displayOrder={index + 1}
              key={step.stepOrder}
              onPress={() => onOpenStep(step)}
              step={step}
            />
          ))}
        </View>
      ) : null}
    </View>
  );
}

function StepRow({
  displayOrder,
  onPress,
  step,
}: {
  displayOrder: number;
  onPress: () => void;
  step: CourseStep;
}) {
  const isLocked = step.state === "LOCKED";
  const stateLabel =
    step.state === "COMPLETED" ? "완료" : step.state === "SOLVABLE" ? "풀기" : "잠김";
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: isLocked }}
      className={`min-h-16 flex-row items-center gap-4 border-b border-border p-5 ${isLocked ? "opacity-60" : ""}`}
      disabled={isLocked}
      onPress={onPress}
    >
      <View
        className={
          isLocked
            ? "h-11 w-11 items-center justify-center rounded-mobile-control bg-surface-muted"
            : "h-11 w-11 items-center justify-center rounded-mobile-control bg-primary"
        }
      >
        {isLocked ? (
          <LockIcon height={17} width={17} />
        ) : (
          <Text className="font-bold text-primary-fg">{displayOrder}</Text>
        )}
      </View>
      <View className="min-w-0 flex-1">
        <Text className="text-xs font-semibold text-ink-muted">
          STEP {displayOrder} · {step.estimatedMinutes}분
        </Text>
        <Text
          className={isLocked ? "mt-1 font-semibold text-ink-muted" : "mt-1 font-semibold text-ink"}
        >
          {step.topic}
        </Text>
      </View>
      <Text className="rounded-chip bg-surface-muted px-2 py-1 text-xs font-semibold text-ink-muted">
        {stateLabel}
      </Text>
      {!isLocked ? (
        <ChevronRightIcon color={tokens.color["ink-muted"]} height={18} width={18} />
      ) : null}
    </Pressable>
  );
}

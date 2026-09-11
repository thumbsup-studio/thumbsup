import { ApiError, NetworkError } from "@thumbsup/api";
import { mobileTypography, tokens } from "@thumbsup/tokens";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { Pressable, ScrollView, Text, useWindowDimensions, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import Svg, { Circle } from "react-native-svg";

import { type CharacterMood, ChevronRightIcon, DogIcon } from "../../components/icons";
import { ScreenLoading, ScreenState } from "../../components/screen-state";
import { useApi } from "../../lib/api/api-provider";
import { useConnectivity } from "../../lib/connectivity/connectivity-provider";
import { useForegroundRefresh } from "../../lib/lifecycle/use-foreground-refresh";
import { TrackedPressable } from "../observability/interaction";

type HomeResponse = {
  streakDays: number;
  points: number;
  todayCompleted: boolean;
  courses: Array<{
    courseId: number;
    courseTitle: string;
    unitId: number;
    unitTitle: string;
    order: number;
    completedCount: number;
    totalCount: number;
    estimatedMinutes: number;
    completed: boolean;
  }>;
};

type MascotResponse = { name: string; fullness: number };

export type HomeData = {
  streakDays: number;
  character: MascotResponse;
  courses: Array<{
    courseId: number;
    title: string;
    subtitle: string;
    progress: number;
    total: number;
    completed: boolean;
    durationLabel: string;
  }>;
};

export type HomeViewState =
  | { status: "loading" }
  | { status: "offline" }
  | { status: "error"; reason: "network" | "timeout" }
  | { status: "success"; data: HomeData };

function mapHome(home: HomeResponse, mascot: MascotResponse): HomeData {
  return {
    streakDays: home.streakDays,
    character: mascot,
    courses: home.courses.map((course) => ({
      completed: course.completed,
      courseId: course.courseId,
      durationLabel: `${course.estimatedMinutes}분이면 끝나요`,
      progress: course.completedCount,
      subtitle: course.unitTitle,
      title: course.courseTitle,
      total: course.totalCount,
    })),
  };
}

function welcomeCopy(now = new Date()) {
  const hour = Number(
    new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      hour12: false,
      timeZone: "Asia/Seoul",
    }).format(now),
  );
  return hour < 13 ? "출근하며 한 문제," : "자기 전에 한 문제,";
}

function mascotMood(fullness: number): CharacterMood {
  if (fullness >= 70) return "happy";
  if (fullness >= 30) return "neutral";
  return "hungry";
}

export function HomeScreen() {
  const { client, restoreSession } = useApi();
  const isOnline = useConnectivity();
  const [state, setState] = useState<HomeViewState>({ status: "loading" });
  const requestId = useRef(0);

  const load = useCallback(async () => {
    const currentRequest = ++requestId.current;
    if (!isOnline) {
      setState({ status: "offline" });
      return;
    }
    setState({ status: "loading" });
    try {
      const [home, mascot] = await Promise.all([
        client.apiRequest<HomeResponse>("/home"),
        client.apiRequest<MascotResponse>("/mascot"),
      ]);
      if (currentRequest === requestId.current) {
        setState({ status: "success", data: mapHome(home, mascot) });
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
  }, [client, isOnline, restoreSession]);

  useEffect(() => {
    void load();
    return () => {
      requestId.current += 1;
    };
  }, [load]);
  useForegroundRefresh(() => void load());

  return <HomeScreenView onRetry={() => void load()} state={state} />;
}

export function HomeScreenView({ onRetry, state }: { onRetry: () => void; state: HomeViewState }) {
  const router = useRouter();

  if (state.status === "loading") {
    return (
      <StateShell>
        <ScreenLoading label="홈 정보를 불러오는 중" />
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
              : "잠시 후 다시 시도해 주세요."
          }
          kind="error"
          onAction={onRetry}
          title="홈 정보를 불러오지 못했어요"
        />
      </StateShell>
    );
  }

  const { data } = state;
  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top", "left", "right"]}>
      <ScrollView
        className="flex-1"
        contentContainerClassName="gap-5 px-5 py-6"
        keyboardDismissMode="on-drag"
      >
        <View className="gap-3">
          <View className="min-w-0 flex-1">
            <Text
              accessibilityRole="header"
              className="font-semibold text-ink"
              style={mobileTypography.homeTitle}
            >
              {welcomeCopy()}
            </Text>
            <Text className="font-semibold text-ink-muted" style={mobileTypography.homeTitle}>
              오늘도 이어가요.
            </Text>
          </View>
          <View
            accessibilityLabel={`연속 학습 ${data.streakDays > 0 ? `${data.streakDays}일` : "오늘 시작"}`}
            className="self-start flex-row items-center gap-2 rounded-chip bg-surface-muted px-3 py-1.5"
          >
            <Text className="font-medium text-ink-muted" style={mobileTypography.badge}>
              연속 학습
            </Text>
            <Text className="font-semibold text-primary" style={mobileTypography.badge}>
              {data.streakDays > 0 ? `${data.streakDays}일` : "오늘 시작"}
            </Text>
          </View>
        </View>

        <MascotCard {...data.character} />

        <View className="gap-3">
          <View>
            <Text accessibilityRole="header" className="text-2xl font-semibold text-ink">
              최근 학습 코스
            </Text>
            <Text className="mt-1 text-sm leading-5 text-ink-muted">
              최근에 푼 순서로 최대 10개까지 보여드려요.{"\n"}전체 코스는 코스 탭에서 볼 수 있어요.
            </Text>
          </View>
          {data.courses.length > 0 ? (
            <CourseCarousel
              courses={data.courses}
              onOpen={(course) =>
                router.push(
                  course.completed
                    ? { pathname: "/(tabs)/course", params: { courseId: String(course.courseId) } }
                    : { pathname: "/briefing", params: { courseId: String(course.courseId) } },
                )
              }
            />
          ) : (
            <ScreenState
              actionLabel="코스 보러 가기"
              description="코스가 준비되면 여기에 표시돼요."
              kind="empty"
              onAction={() => router.push("/(tabs)/course")}
              title="최근 학습 코스가 없어요"
            />
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function StateShell({ children }: { children: React.ReactNode }) {
  return (
    <SafeAreaView className="flex-1 justify-center bg-bg px-5" edges={["top", "left", "right"]}>
      {children}
    </SafeAreaView>
  );
}

function MascotCard({ fullness, name }: MascotResponse) {
  const clamped = Math.min(100, Math.max(0, Math.round(fullness)));
  const radius = 28;
  const circumference = 2 * Math.PI * radius;
  return (
    <View
      accessibilityLabel={`캐릭터 ${name}, 포만감 ${clamped}%`}
      className="items-center gap-2 rounded-mobile-card border border-border bg-surface p-5"
    >
      <View className="h-36 w-36 items-center justify-center">
        <Svg
          accessibilityElementsHidden
          height={144}
          importantForAccessibility="no-hide-descendants"
          style={{ position: "absolute", transform: [{ rotate: "-90deg" }] }}
          viewBox="0 0 64 64"
          width={144}
        >
          <Circle
            cx={32}
            cy={32}
            fill="none"
            r={radius}
            stroke={tokens.color["surface-muted"]}
            strokeWidth={5}
          />
          <Circle
            cx={32}
            cy={32}
            fill="none"
            r={radius}
            stroke={tokens.color.primary}
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - clamped / 100)}
            strokeLinecap="round"
            strokeWidth={5}
          />
        </Svg>
        <DogIcon height={112} mood={mascotMood(clamped)} width={112} />
      </View>
      <Text className="text-lg font-semibold text-ink">{name}</Text>
      <Text className="text-sm font-semibold text-ink">포만감 {clamped}%</Text>
    </View>
  );
}

function CourseCarousel({
  courses,
  onOpen,
}: {
  courses: HomeData["courses"];
  onOpen: (course: HomeData["courses"][number]) => void;
}) {
  const { width } = useWindowDimensions();
  const cardWidth = Math.max(280, width - 40);
  const scrollRef = useRef<ScrollView>(null);
  const [activeIndex, setActiveIndex] = useState(0);

  return (
    <View>
      <ScrollView
        accessibilityLabel="최근 학습 코스"
        horizontal
        onMomentumScrollEnd={(event) =>
          setActiveIndex(Math.round(event.nativeEvent.contentOffset.x / cardWidth))
        }
        pagingEnabled
        ref={scrollRef}
        showsHorizontalScrollIndicator={false}
      >
        {courses.map((course) => (
          <View key={course.courseId} style={{ width: cardWidth }}>
            <View className="min-h-64 rounded-mobile-card bg-primary p-5">
              {course.completed ? (
                <Text className="self-end rounded-chip bg-badge px-3 py-1 text-sm font-bold text-badge-fg">
                  완주
                </Text>
              ) : null}
              <Text className="text-sm font-medium text-primary-fg">{course.title}</Text>
              <Text className="mt-2 text-2xl font-semibold text-primary-fg">{course.subtitle}</Text>
              <Text
                accessibilityLabel={
                  course.completed
                    ? `총 ${course.total}개 스텝 완주`
                    : `총 ${course.total}개 스텝 중 ${course.progress + 1}번째 진행중`
                }
                className="mb-5 mt-6 text-sm text-primary-fg"
              >
                {course.completed ? course.total : course.progress + 1}/{course.total} ·{" "}
                {course.durationLabel}
              </Text>
              <TrackedPressable
                accessibilityLabel={course.completed ? "복습하기" : "시작하기"}
                accessibilityRole="button"
                className="mt-auto min-h-12 flex-row items-center justify-center gap-2 rounded-mobile-control bg-surface px-4 py-3"
                onPress={() => onOpen(course)}
              >
                <Text className="font-semibold text-primary">
                  {course.completed ? "복습하기" : "시작하기"}
                </Text>
                <ChevronRightIcon color={tokens.color.primary} height={18} width={18} />
              </TrackedPressable>
            </View>
          </View>
        ))}
      </ScrollView>
      {courses.length > 1 ? (
        <View
          accessibilityLabel={`${courses.length}개 코스 중 ${activeIndex + 1}번째`}
          className="mt-3 flex-row justify-center gap-2"
        >
          {courses.map((course, index) => (
            <Pressable
              accessibilityLabel={`${index + 1}번째 코스로 이동`}
              accessibilityRole="button"
              className={
                index === activeIndex
                  ? "h-2 w-5 rounded-chip bg-primary"
                  : "h-2 w-2 rounded-chip bg-border"
              }
              key={course.courseId}
              onPress={() => {
                setActiveIndex(index);
                scrollRef.current?.scrollTo({ animated: true, x: index * cardWidth });
              }}
            />
          ))}
        </View>
      ) : null}
    </View>
  );
}

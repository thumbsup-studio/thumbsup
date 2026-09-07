import { Redirect, router, useLocalSearchParams } from "expo-router";
import { Pressable, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default function ReviewSummaryScreen() {
  const params = useLocalSearchParams<{ step?: string | string[]; topic?: string | string[] }>();
  const stepValue = first(params.step);
  const step = Number(stepValue);
  const topic = first(params.topic) ?? "복습한 스텝";

  if (!Number.isInteger(step) || step < 1) {
    return <Redirect href="/(tabs)/course" />;
  }

  return (
    <SafeAreaView className="flex-1 bg-bg px-5 py-6">
      <View className="flex-1 items-center justify-center">
        <View
          accessibilityElementsHidden
          className="size-20 items-center justify-center rounded-card bg-surface-muted"
          importantForAccessibility="no-hide-descendants"
        >
          <Text className="text-4xl text-success">✓</Text>
        </View>
        <Text className="mt-5 text-xs font-semibold tracking-wide text-ink-muted">
          STEP {step} 복습 완료
        </Text>
        <Text
          accessibilityRole="header"
          className="mt-2 text-center text-3xl font-extrabold text-ink"
        >
          {topic}
        </Text>
      </View>
      <View className="gap-3 pb-2">
        <Pressable
          accessibilityRole="button"
          className="min-h-12 items-center justify-center rounded-control bg-primary px-5"
          onPress={() => router.replace("/(tabs)/course")}
        >
          <Text className="font-bold text-primary-fg">코스로 돌아가기</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          className="min-h-12 items-center justify-center rounded-control border border-border bg-surface px-5"
          onPress={() =>
            router.push({
              pathname: "/play",
              params: { slot: "1", step: String(step), topic },
            })
          }
        >
          <Text className="font-bold text-ink">다시 풀기</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

import { router } from "expo-router";
import { Pressable, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

export default function HistoryGraphScreen() {
  return (
    <SafeAreaView className="flex-1 bg-bg px-6 py-10">
      <View className="flex-1 items-center justify-center">
        <Text accessibilityRole="header" className="text-center text-3xl font-extrabold text-ink">
          지식 그래프
        </Text>
        <Text className="mt-3 text-center leading-6 text-ink-muted">
          개념 사이의 연결을 보여 주는 화면을 준비하고 있어요.
        </Text>
        <Pressable
          accessibilityRole="button"
          className="mt-6 min-h-12 w-full max-w-sm items-center justify-center rounded-control bg-primary px-5"
          onPress={() => router.replace("/(tabs)/history")}
        >
          <Text className="font-bold text-primary-fg">히스토리 목록으로</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

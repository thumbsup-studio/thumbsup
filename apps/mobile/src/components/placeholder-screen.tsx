import { Text, View } from "react-native";

export function PlaceholderScreen({ title }: { title: string }) {
  return (
    <View className="flex-1 items-center justify-center bg-bg px-6">
      <Text className="text-2xl font-bold text-ink">{title}</Text>
      <Text className="mt-2 text-center text-base text-ink-muted">모바일 화면 준비 중</Text>
    </View>
  );
}

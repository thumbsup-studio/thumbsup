import { Text, View } from "react-native";

export function AuthFeedback({ title, description }: { title: string; description: string }) {
  return (
    <View
      accessibilityLiveRegion="assertive"
      accessibilityRole="alert"
      className="rounded-control border border-danger bg-surface-muted p-4"
    >
      <Text className="font-semibold text-danger">{title}</Text>
      <Text className="mt-1 text-sm text-ink-muted">{description}</Text>
    </View>
  );
}

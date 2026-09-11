import { Text, View } from "react-native";

export function AuthBrand({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <View className="items-center gap-3">
      <View
        accessible={false}
        className="h-16 w-16 items-center justify-center rounded-mobile-control bg-primary"
      >
        <Text className="text-3xl" accessibilityElementsHidden importantForAccessibility="no">
          👍
        </Text>
      </View>
      <View className="items-center gap-1">
        <Text accessibilityRole="header" className="text-3xl font-extrabold text-ink">
          {title}
        </Text>
        <Text className="text-center text-base text-ink-muted">{subtitle}</Text>
      </View>
    </View>
  );
}

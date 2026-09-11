import { ActivityIndicator, Pressable, Text } from "react-native";

export function AuthButton({
  label,
  loadingLabel,
  loading,
  onPress,
}: {
  label: string;
  loadingLabel: string;
  loading: boolean;
  onPress(): void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ busy: loading, disabled: loading }}
      className={`min-h-12 flex-row items-center justify-center gap-2 rounded-mobile-control bg-primary px-4 ${
        loading ? "opacity-60" : ""
      }`}
      disabled={loading}
      onPress={onPress}
    >
      {loading ? <ActivityIndicator color="white" /> : null}
      <Text className="text-base font-bold text-primary-fg">{loading ? loadingLabel : label}</Text>
    </Pressable>
  );
}

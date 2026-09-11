import { ActivityIndicator, Pressable, Text, View } from "react-native";

import { AlertCircleIcon, WifiOffIcon } from "./icons";

type ScreenStateProps = {
  description: string;
  kind: "empty" | "error" | "offline";
  onAction?: () => void;
  actionLabel?: string;
  title: string;
};

export function ScreenState({
  actionLabel = "다시 시도",
  description,
  kind,
  onAction,
  title,
}: ScreenStateProps) {
  const Icon = kind === "offline" ? WifiOffIcon : AlertCircleIcon;
  return (
    <View
      accessibilityLiveRegion="polite"
      accessibilityRole={kind === "empty" ? "summary" : "alert"}
      className="items-center gap-3 rounded-mobile-card border border-border bg-surface p-5"
    >
      <Icon height={32} width={32} />
      <Text className="text-center text-xl font-bold text-ink">{title}</Text>
      <Text className="text-center text-sm leading-5 text-ink-muted">{description}</Text>
      {onAction ? (
        <Pressable
          accessibilityRole="button"
          className="min-h-12 items-center justify-center rounded-mobile-control bg-primary px-5 py-3"
          onPress={onAction}
        >
          <Text className="font-semibold text-primary-fg">{actionLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function ScreenLoading({ label }: { label: string }) {
  return (
    <View
      accessibilityLabel={label}
      accessibilityRole="progressbar"
      className="flex-1 items-center justify-center gap-3 py-16"
    >
      <ActivityIndicator size="large" />
      <Text className="text-sm font-medium text-ink-muted">{label}</Text>
    </View>
  );
}

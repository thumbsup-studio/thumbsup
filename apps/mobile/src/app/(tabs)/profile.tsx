import { useState } from "react";
import { ActivityIndicator, Pressable, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useApi } from "../../lib/api/api-provider";

export default function ProfileScreen() {
  const { logout, profile } = useApi();
  const [loading, setLoading] = useState(false);

  async function handleLogout() {
    if (loading) return;
    setLoading(true);
    try {
      await logout();
    } finally {
      setLoading(false);
    }
  }

  return (
    <SafeAreaView className="flex-1 bg-bg px-6 py-10">
      <View className="flex-1 gap-6">
        <Text accessibilityRole="header" className="text-3xl font-extrabold text-ink">
          프로필
        </Text>
        <View className="rounded-card border border-border bg-surface p-6">
          <Text className="text-sm text-ink-muted">로그인 계정</Text>
          <Text className="mt-1 text-lg font-semibold text-ink">{profile?.email ?? "사용자"}</Text>
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ busy: loading, disabled: loading }}
          className="min-h-12 flex-row items-center justify-center gap-2 rounded-control border border-danger bg-surface"
          disabled={loading}
          onPress={() => void handleLogout()}
        >
          {loading ? <ActivityIndicator /> : null}
          <Text className="font-semibold text-danger">{loading ? "로그아웃 중…" : "로그아웃"}</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

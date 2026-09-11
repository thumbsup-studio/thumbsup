import { ApiError, type MyProfile, NetworkError } from "@thumbsup/api";
import { router } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { useApi } from "../../lib/api/api-provider";
import { useDialogTelemetry } from "../observability/interaction";
import { FeedbackModal } from "./feedback-modal";

const SETTING_ITEMS = [
  { key: "account", label: "계정 설정" },
  { key: "notifications", label: "알림" },
  { key: "goals", label: "학습 목표" },
] as const;

type ProfileState =
  | { status: "loading" }
  | { status: "error"; message: string }
  | { status: "ready"; profile: MyProfile };

function getProfileErrorMessage(error: unknown) {
  if (error instanceof NetworkError) {
    return error.reason === "timeout"
      ? "요청 시간이 초과됐어요. 잠시 후 다시 시도해 주세요."
      : "네트워크 연결을 확인한 뒤 다시 시도해 주세요.";
  }
  return "잠시 후 다시 시도해 주세요.";
}

export default function ProfileScreen() {
  const { client, logout, profile, restoreSession } = useApi();
  const [state, setState] = useState<ProfileState>(
    profile ? { status: "ready", profile } : { status: "loading" },
  );
  const [feedbackOpen, setFeedbackOpen] = useState(false);
  const [logoutOpen, setLogoutOpen] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);
  const requestIdRef = useRef(0);

  const load = useCallback(async () => {
    const requestId = ++requestIdRef.current;
    if (!profile) setState({ status: "loading" });
    try {
      const nextProfile = await client.getMyProfile();
      if (requestId !== requestIdRef.current) return;
      setState({ status: "ready", profile: nextProfile });
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
        return;
      }
      setState({ status: "error", message: getProfileErrorMessage(error) });
    }
  }, [client, profile, restoreSession]);

  useEffect(() => {
    void load();
    return () => {
      requestIdRef.current += 1;
    };
  }, [load]);

  async function confirmLogout() {
    if (loggingOut) return;
    setLoggingOut(true);
    try {
      await logout();
      setLogoutOpen(false);
      router.replace("/(auth)/login");
    } finally {
      setLoggingOut(false);
    }
  }

  async function submitFeedback(content: string) {
    try {
      const result = await client.sendFeedback(content);
      Alert.alert("의견을 보냈어요", "소중한 의견 고마워요. 잘 전달했어요.");
      return result;
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        await restoreSession();
      }
      throw error;
    }
  }

  if (state.status === "loading") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg px-5">
        <ActivityIndicator accessibilityLabel="프로필 불러오는 중" size="large" />
      </SafeAreaView>
    );
  }

  if (state.status === "error") {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-bg px-5">
        <View
          accessibilityLiveRegion="assertive"
          accessibilityRole="alert"
          className="w-full max-w-sm rounded-mobile-card border border-danger bg-surface p-5"
        >
          <Text accessibilityRole="header" className="text-xl font-bold text-ink">
            프로필을 불러오지 못했어요
          </Text>
          <Text className="mt-2 leading-6 text-ink-muted">{state.message}</Text>
          <Pressable
            accessibilityRole="button"
            className="mt-5 min-h-12 items-center justify-center rounded-mobile-control bg-primary px-4"
            onPress={() => void load()}
          >
            <Text className="font-bold text-primary-fg">다시 시도</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  const initial = state.profile.email.trim().charAt(0).toUpperCase() || "?";

  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top"]}>
      <ScrollView contentContainerClassName="grow gap-5 px-5 pb-6 pt-6">
        <Text accessibilityRole="header" className="text-3xl font-extrabold text-ink">
          프로필
        </Text>
        <View className="items-center rounded-mobile-card border border-border bg-surface p-5">
          <View
            accessibilityElementsHidden
            className="size-20 items-center justify-center rounded-chip bg-primary"
            importantForAccessibility="no-hide-descendants"
          >
            <Text className="text-3xl font-extrabold text-primary-fg">{initial}</Text>
          </View>
          <Text className="mt-4 text-center text-lg font-bold text-ink">{state.profile.email}</Text>
          <Text className="mt-1 text-sm text-ink-muted">
            {state.profile.role === "ADMIN" ? "관리자 계정" : "일반 계정"}
          </Text>
        </View>

        <View className="overflow-hidden rounded-mobile-card border border-border bg-surface">
          {SETTING_ITEMS.map((item) => (
            <Pressable
              accessibilityHint="준비 중인 기능입니다"
              accessibilityRole="button"
              className="min-h-14 flex-row items-center border-b border-border px-5 py-4"
              key={item.key}
              onPress={() => Alert.alert("준비 중", `${item.label}은 준비 중입니다.`)}
            >
              <Text className="flex-1 font-semibold text-ink">{item.label}</Text>
              <Text className="text-ink-muted">›</Text>
            </Pressable>
          ))}
          <Pressable
            accessibilityRole="button"
            className="min-h-14 flex-row items-center px-5 py-4"
            onPress={() => setFeedbackOpen(true)}
          >
            <Text className="flex-1 font-semibold text-ink">의견 보내기</Text>
            <Text className="text-ink-muted">›</Text>
          </Pressable>
        </View>

        <Pressable
          accessibilityRole="button"
          className="min-h-14 items-center justify-center rounded-mobile-control bg-danger px-5"
          onPress={() => setLogoutOpen(true)}
        >
          <Text className="font-bold text-primary-fg">로그아웃</Text>
        </Pressable>
        <Text className="mt-auto text-center text-xs text-ink-muted">Thumbs Up</Text>
      </ScrollView>

      <FeedbackModal
        onClose={() => setFeedbackOpen(false)}
        onSubmit={submitFeedback}
        open={feedbackOpen}
      />
      <LogoutModal
        loading={loggingOut}
        onCancel={() => setLogoutOpen(false)}
        onConfirm={() => void confirmLogout()}
        open={logoutOpen}
      />
    </SafeAreaView>
  );
}

function LogoutModal({
  loading,
  onCancel,
  onConfirm,
  open,
}: {
  loading: boolean;
  onCancel(): void;
  onConfirm(): void;
  open: boolean;
}) {
  useDialogTelemetry(open, "로그아웃 확인");
  return (
    <Modal
      animationType="fade"
      onRequestClose={loading ? undefined : onCancel}
      transparent
      visible={open}
    >
      <View accessibilityViewIsModal className="flex-1 items-center justify-center bg-ink/40 px-6">
        <View className="w-full max-w-sm rounded-mobile-card bg-surface p-5">
          <Text accessibilityRole="header" className="text-center text-2xl font-extrabold text-ink">
            로그아웃할까요?
          </Text>
          <Text className="mt-2 text-center leading-6 text-ink-muted">
            다시 이용하려면 이메일로 로그인해야 해요.
          </Text>
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ busy: loading, disabled: loading }}
            className="mt-6 min-h-12 flex-row items-center justify-center gap-2 rounded-mobile-control bg-danger px-5"
            disabled={loading}
            onPress={onConfirm}
          >
            {loading ? <ActivityIndicator color="white" /> : null}
            <Text className="font-bold text-primary-fg">
              {loading ? "로그아웃 중…" : "로그아웃"}
            </Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ disabled: loading }}
            className="mt-3 min-h-12 items-center justify-center rounded-mobile-control border border-border px-5"
            disabled={loading}
            onPress={onCancel}
          >
            <Text className="font-bold text-ink">취소</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

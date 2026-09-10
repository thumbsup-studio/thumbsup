import { ApiError, NetworkError } from "@thumbsup/api";
import { validateEmail, validatePassword } from "@thumbsup/core/auth-validation";
import { router } from "expo-router";
import { useRef, useState } from "react";
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  Text,
  type TextInput,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { AuthBrand } from "../../components/auth/auth-brand";
import { AuthButton } from "../../components/auth/auth-button";
import { AuthFeedback } from "../../components/auth/auth-feedback";
import { AuthInput } from "../../components/auth/auth-input";
import { useApi } from "../../lib/api/api-provider";

const FAIL_MESSAGE = "이메일 또는 비밀번호를 다시 확인하고 재시도해 주세요.";

export default function LoginScreen() {
  const { login } = useApi();
  const passwordRef = useRef<TextInput>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function submit() {
    if (loading) return;
    setErrorMessage(null);
    if (validateEmail(email) || validatePassword(password)) {
      setErrorMessage(FAIL_MESSAGE);
      return;
    }
    setLoading(true);
    try {
      await login(email.trim(), password);
      router.replace("/(tabs)");
    } catch (error) {
      if (error instanceof ApiError) setErrorMessage(FAIL_MESSAGE);
      else if (error instanceof NetworkError) {
        setErrorMessage(
          error.reason === "timeout"
            ? "요청 시간이 초과됐어요. 잠시 후 다시 시도해 주세요."
            : "네트워크에 연결할 수 없어요. 연결을 확인한 뒤 다시 시도해 주세요.",
        );
      } else setErrorMessage("로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <SafeAreaView className="flex-1 bg-bg">
      <KeyboardAvoidingView
        className="flex-1"
        behavior={Platform.OS === "ios" ? "padding" : "height"}
      >
        <ScrollView
          contentContainerClassName="flex-grow justify-center px-6 py-10"
          keyboardShouldPersistTaps="handled"
        >
          <View className="mx-auto w-full max-w-sm gap-8">
            <AuthBrand title="Thumbs Up" subtitle="매일 한 문제, CS 감각이 쌓입니다." />
            <View className="gap-5 rounded-card border border-border bg-surface p-6">
              <AuthInput
                label="이메일"
                value={email}
                onChangeText={setEmail}
                editable={!loading}
                keyboardType="email-address"
                autoCapitalize="none"
                autoComplete="email"
                returnKeyType="next"
                placeholder="you@example.com"
                onSubmitEditing={() => passwordRef.current?.focus()}
              />
              <View className="gap-1.5">
                <AuthInput
                  ref={passwordRef}
                  label="비밀번호"
                  password
                  value={password}
                  onChangeText={setPassword}
                  editable={!loading}
                  autoComplete="current-password"
                  returnKeyType="done"
                  placeholder="8자 이상 입력"
                  onSubmitEditing={() => void submit()}
                />
                <Pressable
                  accessibilityRole="button"
                  className="self-end p-2"
                  onPress={() => Alert.alert("알림", "비밀번호 찾기는 아직 준비 중이에요.")}
                >
                  <Text className="text-sm font-medium text-ink-muted">비밀번호를 잊으셨나요?</Text>
                </Pressable>
              </View>
              {errorMessage ? (
                <AuthFeedback title="로그인에 실패했어요" description={errorMessage} />
              ) : null}
              <AuthButton
                label={errorMessage ? "다시 로그인" : "로그인"}
                loadingLabel="로그인 중…"
                loading={loading}
                onPress={() => void submit()}
              />
            </View>
            <View className="items-center gap-3">
              <Pressable accessibilityRole="link" onPress={() => router.push("/(auth)/signup")}>
                <Text className="text-sm text-ink-muted">
                  계정이 없으신가요? <Text className="font-semibold text-primary">회원가입</Text>
                </Text>
              </Pressable>
              <Text className="text-center text-xs text-ink-muted">
                계속하면 이용약관과 개인정보 처리방침에 동의하게 됩니다.
              </Text>
              <View className="flex-row gap-4">
                {["이용약관", "개인정보 처리방침", "도움말"].map((label) => (
                  <Pressable
                    key={label}
                    accessibilityLabel={label}
                    accessibilityRole="link"
                    onPress={() => Alert.alert("알림", `${label}은 아직 준비 중이에요.`)}
                  >
                    <Text className="text-xs text-ink-muted underline">{label}</Text>
                  </Pressable>
                ))}
              </View>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

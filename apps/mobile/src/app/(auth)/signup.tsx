import { ApiError, ErrorCode, NetworkError } from "@thumbsup/api";
import {
  validateEmail,
  validatePassword,
  validatePasswordConfirm,
} from "@thumbsup/core/auth-validation";
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

type FieldErrors = { email?: string; password?: string; confirm?: string };
type FormError = { title: string; description: string };

export default function SignupScreen() {
  const { signup } = useApi();
  const passwordRef = useRef<TextInput>(null);
  const confirmRef = useRef<TextInput>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState<FormError | null>(null);

  async function submit() {
    if (loading) return;
    setFieldErrors({});
    setFormError(null);
    const emailError = validateEmail(email);
    const passwordError = validatePassword(password);
    const confirmError = validatePasswordConfirm(password, confirm);
    if (emailError || passwordError || confirmError) {
      setFieldErrors({
        email: emailError ?? undefined,
        password: passwordError ?? undefined,
        confirm: confirmError ?? undefined,
      });
      setFormError({
        title: "입력값을 다시 확인해 주세요",
        description: "표시된 항목을 수정해 주세요.",
      });
      return;
    }
    if (!agreed) {
      setFormError({
        title: "약관 동의가 필요해요",
        description: "이용약관 및 개인정보 처리방침에 동의해 주세요.",
      });
      return;
    }

    setLoading(true);
    try {
      await signup(email.trim(), password);
      router.replace("/(tabs)");
    } catch (error) {
      if (error instanceof ApiError && error.is(ErrorCode.USER_EMAIL_DUPLICATED)) {
        setFieldErrors({ email: "이미 가입된 이메일이에요." });
        setFormError({
          title: "이미 가입된 이메일이에요",
          description: "다른 이메일로 시도하거나 로그인해 주세요.",
        });
      } else if (error instanceof ApiError && error.is(ErrorCode.INVALID_INPUT)) {
        const mapped: FieldErrors = {};
        for (const item of error.fieldErrors ?? []) {
          if (item.field === "email") mapped.email = item.reason;
          if (item.field === "password") mapped.password = item.reason;
        }
        setFieldErrors(mapped);
        setFormError({ title: "입력값을 다시 확인해 주세요", description: error.message });
      } else if (error instanceof NetworkError) {
        setFormError({
          title:
            error.reason === "timeout" ? "요청 시간이 초과됐어요" : "네트워크에 연결할 수 없어요",
          description:
            error.reason === "timeout"
              ? "잠시 후 다시 시도해 주세요."
              : "연결을 확인한 뒤 다시 시도해 주세요.",
        });
      } else {
        setFormError({
          title: "가입에 실패했어요",
          description: error instanceof Error ? error.message : "잠시 후 다시 시도해 주세요.",
        });
      }
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
          contentContainerClassName="flex-grow px-6 py-6"
          keyboardShouldPersistTaps="handled"
        >
          <View className="mx-auto w-full max-w-sm">
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="로그인으로 돌아가기"
              className="mb-4 min-h-11 min-w-11 self-start items-center justify-center"
              onPress={() => router.back()}
            >
              <Text className="text-3xl text-ink">‹</Text>
            </Pressable>
            <View className="gap-8">
              <AuthBrand title="회원가입" subtitle="가입하고 CS 학습을 시작하세요." />
              <View className="gap-5 rounded-card border border-border bg-surface p-6">
                <AuthInput
                  label="이메일"
                  value={email}
                  onChangeText={setEmail}
                  error={fieldErrors.email}
                  editable={!loading}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoComplete="email"
                  returnKeyType="next"
                  placeholder="you@example.com"
                  onSubmitEditing={() => passwordRef.current?.focus()}
                />
                <AuthInput
                  ref={passwordRef}
                  label="비밀번호"
                  password
                  value={password}
                  onChangeText={setPassword}
                  error={fieldErrors.password}
                  editable={!loading}
                  autoComplete="new-password"
                  returnKeyType="next"
                  placeholder="8자 이상 72자 이하"
                  onSubmitEditing={() => confirmRef.current?.focus()}
                />
                <AuthInput
                  ref={confirmRef}
                  label="비밀번호 확인"
                  password
                  value={confirm}
                  onChangeText={setConfirm}
                  error={fieldErrors.confirm}
                  editable={!loading}
                  autoComplete="new-password"
                  returnKeyType="done"
                  placeholder="비밀번호를 다시 입력"
                  onSubmitEditing={() => void submit()}
                />
                <Pressable
                  accessibilityRole="checkbox"
                  accessibilityState={{ checked: agreed, disabled: loading }}
                  className="min-h-11 flex-row items-center gap-3"
                  disabled={loading}
                  onPress={() => setAgreed((value) => !value)}
                >
                  <View
                    className={`h-5 w-5 items-center justify-center rounded border ${
                      agreed ? "border-primary bg-primary" : "border-border bg-surface"
                    }`}
                  >
                    {agreed ? <Text className="text-xs font-bold text-primary-fg">✓</Text> : null}
                  </View>
                  <Text className="flex-1 text-sm text-ink-muted">
                    <Text className="font-semibold text-primary">(필수)</Text> 이용약관 및 개인정보
                    처리방침에 동의합니다.
                  </Text>
                </Pressable>
                <View className="flex-row gap-4 pl-8">
                  {["이용약관", "개인정보 처리방침"].map((label) => (
                    <Pressable
                      key={label}
                      accessibilityRole="link"
                      onPress={() => Alert.alert("알림", `${label}은 아직 준비 중이에요.`)}
                    >
                      <Text className="text-sm text-ink underline">{label}</Text>
                    </Pressable>
                  ))}
                </View>
                {formError ? (
                  <AuthFeedback title={formError.title} description={formError.description} />
                ) : null}
                <AuthButton
                  label="가입하기"
                  loadingLabel="가입 중…"
                  loading={loading}
                  onPress={() => void submit()}
                />
              </View>
              <Pressable
                accessibilityRole="link"
                className="self-center"
                onPress={() => router.replace("/(auth)/login")}
              >
                <Text className="text-sm text-ink-muted">
                  이미 계정이 있으신가요? <Text className="font-semibold text-primary">로그인</Text>
                </Text>
              </Pressable>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

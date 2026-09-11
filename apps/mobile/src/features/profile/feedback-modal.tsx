import { ApiError, NetworkError } from "@thumbsup/api";
import { useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  Keyboard,
  Modal,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  View,
} from "react-native";

import { useDialogTelemetry } from "../observability/interaction";

const MAX_LENGTH = 1000;

type FeedbackModalProps = {
  open: boolean;
  onClose(): void;
  onSubmit(content: string): Promise<unknown>;
};

function getErrorMessage(error: unknown) {
  if (error instanceof ApiError) return error.message;
  if (error instanceof NetworkError) {
    return error.reason === "timeout"
      ? "요청 시간이 초과됐어요. 잠시 후 다시 시도해 주세요."
      : "네트워크 연결을 확인한 뒤 다시 시도해 주세요.";
  }
  return "전송에 실패했어요. 잠시 후 다시 시도해 주세요.";
}

export function FeedbackModal({ open, onClose, onSubmit }: FeedbackModalProps) {
  useDialogTelemetry(open, "의견 보내기");
  const inputRef = useRef<TextInput>(null);
  const [content, setContent] = useState("");
  const [sending, setSending] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const trimmed = content.trim();

  useEffect(() => {
    const show = Keyboard.addListener("keyboardDidShow", (event) =>
      setKeyboardHeight(event.endCoordinates.height),
    );
    const hide = Keyboard.addListener("keyboardDidHide", () => setKeyboardHeight(0));
    return () => {
      show.remove();
      hide.remove();
    };
  }, []);
  const canSend = trimmed.length > 0 && content.length <= MAX_LENGTH && !sending;

  useEffect(() => {
    if (open) {
      setErrorMessage(null);
      const timeout = setTimeout(() => inputRef.current?.focus(), 100);
      return () => clearTimeout(timeout);
    }
    return undefined;
  }, [open]);

  async function submit() {
    if (!canSend) return;
    setSending(true);
    setErrorMessage(null);
    try {
      await onSubmit(trimmed);
      setContent("");
      onClose();
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setSending(false);
    }
  }

  return (
    <Modal
      animationType="fade"
      transparent
      onRequestClose={sending ? undefined : onClose}
      visible={open}
    >
      <View
        accessibilityViewIsModal
        className="flex-1 items-center justify-center bg-ink/40 px-5 py-8"
        style={{ paddingBottom: keyboardHeight + 32 }}
      >
        <Pressable
          accessibilityLabel="의견 보내기 닫기"
          accessibilityRole="button"
          className="absolute inset-0"
          disabled={sending}
          onPress={onClose}
        />
        <View className="w-full max-w-sm max-h-full rounded-mobile-dialog bg-bg p-5">
          <ScrollView keyboardShouldPersistTaps="handled" bounces={false}>
            <View className="flex-row items-center justify-between">
              <Text accessibilityRole="header" className="text-2xl font-extrabold text-ink">
                의견 보내기
              </Text>
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ disabled: sending }}
                className="min-h-12 min-w-12 items-center justify-center"
                disabled={sending}
                onPress={onClose}
              >
                <Text className="font-semibold text-ink-muted">닫기</Text>
              </Pressable>
            </View>
            <Text className="mt-2 leading-6 text-ink-muted">
              서비스에 바라는 점이나 불편한 점을 자유롭게 남겨 주세요.
            </Text>
            <TextInput
              accessibilityLabel="의견 내용"
              className="mt-4 h-28 rounded-mobile-control border border-border bg-surface p-4 text-base text-ink"
              editable={!sending}
              maxLength={MAX_LENGTH}
              multiline
              onChangeText={setContent}
              placeholder="의견을 입력해 주세요"
              ref={inputRef}
              textAlignVertical="top"
              value={content}
            />
            <Text className="mt-2 text-right text-xs text-ink-muted">
              {content.length}/{MAX_LENGTH}
            </Text>
            {errorMessage ? (
              <Text
                accessibilityLiveRegion="assertive"
                accessibilityRole="alert"
                className="mt-3 text-sm font-semibold text-danger"
              >
                {errorMessage}
              </Text>
            ) : null}
            <Pressable
              accessibilityRole="button"
              accessibilityState={{ busy: sending, disabled: !canSend }}
              className={`mt-4 min-h-12 flex-row items-center justify-center gap-2 rounded-mobile-control bg-primary px-5 ${
                canSend ? "" : "opacity-60"
              }`}
              disabled={!canSend}
              onPress={() => void submit()}
            >
              {sending ? <ActivityIndicator color="white" /> : null}
              <Text className="font-bold text-primary-fg">{sending ? "보내는 중…" : "보내기"}</Text>
            </Pressable>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

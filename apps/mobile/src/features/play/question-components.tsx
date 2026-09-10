import type { QuizChoice, RetryHintBlank } from "@thumbsup/api";
import { memo } from "react";
import { Pressable, Text, TextInput, View } from "react-native";

export type AnswerDraft = boolean | string | string[] | null;

const optionLabels = ["A", "B", "C", "D"];

type ChoiceKeycapProps = {
  accessibilityLabel: string;
  children: React.ReactNode;
  disabled?: boolean;
  onPress: () => void;
  selected: boolean;
  tone?: "default" | "yes" | "no";
};

export function ChoiceKeycap({
  accessibilityLabel,
  children,
  disabled = false,
  onPress,
  selected,
  tone = "default",
}: ChoiceKeycapProps) {
  const bottomClass = selected
    ? tone === "yes"
      ? "bg-ox-o"
      : tone === "no"
        ? "bg-ox-x"
        : "bg-primary"
    : "bg-border";
  const faceClass = selected
    ? tone === "yes"
      ? "border-ox-o bg-surface"
      : tone === "no"
        ? "border-ox-x bg-surface"
        : "border-primary bg-surface"
    : "border-border bg-surface";

  return (
    <View className={`rounded-control pb-1 ${bottomClass}`}>
      <Pressable
        accessibilityLabel={accessibilityLabel}
        accessibilityRole="radio"
        accessibilityState={{ checked: selected, disabled }}
        className={`min-h-14 flex-row items-center rounded-control border px-4 py-3 ${faceClass}`}
        disabled={disabled}
        onPress={onPress}
        style={({ pressed }) => ({ transform: [{ translateY: pressed ? 4 : 0 }] })}
      >
        {children}
      </Pressable>
    </View>
  );
}

export const OxQuestion = memo(function OxQuestion({
  disabled,
  draft,
  onDraftChange,
}: {
  disabled: boolean;
  draft: AnswerDraft;
  onDraftChange: (draft: AnswerDraft) => void;
}) {
  return (
    <View
      accessibilityLabel="O 또는 X 선택"
      accessibilityRole="radiogroup"
      className="flex-row gap-3"
    >
      <View className="flex-1">
        <ChoiceKeycap
          accessibilityLabel="O, 맞다"
          disabled={disabled}
          onPress={() => onDraftChange(true)}
          selected={draft === true}
          tone="yes"
        >
          <Text className="w-full text-center text-5xl font-black text-success">O</Text>
        </ChoiceKeycap>
      </View>
      <View className="flex-1">
        <ChoiceKeycap
          accessibilityLabel="X, 아니다"
          disabled={disabled}
          onPress={() => onDraftChange(false)}
          selected={draft === false}
          tone="no"
        >
          <Text className="w-full text-center text-5xl font-black text-danger">X</Text>
        </ChoiceKeycap>
      </View>
    </View>
  );
});

function ChoiceList({
  choices,
  disabled,
  draft,
  eliminatedChoiceId,
  onDraftChange,
}: {
  choices: QuizChoice[];
  disabled: boolean;
  draft: AnswerDraft;
  eliminatedChoiceId?: number | null;
  onDraftChange: (draft: AnswerDraft) => void;
}) {
  return (
    <View accessibilityLabel="선택지" accessibilityRole="radiogroup" className="gap-3">
      {choices.map((choice, index) => {
        const selected = draft === String(choice.choiceId);
        const eliminated = eliminatedChoiceId === choice.choiceId;
        return (
          <View className={eliminated ? "opacity-40" : undefined} key={choice.choiceId}>
            <ChoiceKeycap
              accessibilityLabel={`${optionLabels[index] ?? index + 1}. ${choice.content}${eliminated ? ", 소거된 오답" : ""}`}
              disabled={disabled || eliminated}
              onPress={() => onDraftChange(String(choice.choiceId))}
              selected={selected}
            >
              <View
                className={`size-7 items-center justify-center rounded-chip ${selected ? "bg-primary" : "bg-ink"}`}
              >
                <Text className="text-xs font-bold text-primary-fg">
                  {optionLabels[index] ?? index + 1}
                </Text>
              </View>
              <Text
                className={`ml-3 flex-1 font-semibold leading-6 text-ink ${eliminated ? "line-through" : ""}`}
              >
                {choice.content}
              </Text>
            </ChoiceKeycap>
          </View>
        );
      })}
    </View>
  );
}

export function MatchingQuestion(props: React.ComponentProps<typeof ChoiceList>) {
  return <ChoiceList {...props} />;
}

function CodeBlock({ code }: { code: string }) {
  return (
    <View
      accessible
      accessibilityLabel="문제 코드"
      className="mb-4 rounded-control bg-graph-bg p-4"
    >
      <Text className="font-mono text-sm leading-6 text-graph-fg">{code}</Text>
    </View>
  );
}

export function CodeReadingQuestion({
  code,
  ...props
}: React.ComponentProps<typeof ChoiceList> & { code: string }) {
  return (
    <View>
      <CodeBlock code={code} />
      <ChoiceList {...props} />
    </View>
  );
}

function maskBlankHint(hint: RetryHintBlank) {
  return `${hint.revealedPrefix}${" ○".repeat(Math.max(0, hint.answerLength - 1))} (${hint.answerLength}글자)`;
}

function KeywordInputs({
  blankCount,
  blankHints,
  disabled,
  draft,
  multiline,
  onDraftChange,
}: {
  blankCount: number;
  blankHints: RetryHintBlank[] | null;
  disabled: boolean;
  draft: string[];
  multiline: boolean;
  onDraftChange: (draft: AnswerDraft) => void;
}) {
  return (
    <View className="gap-3">
      {Array.from({ length: blankCount }, (_, index) => {
        const slot = index + 1;
        const hint = blankHints?.find((item) => item.slotOrder === slot);
        return (
          <View key={slot}>
            <View className="mb-2 flex-row items-center gap-2">
              <Text className="text-sm font-bold text-ink">
                {multiline ? "내 답" : `핵심 키워드 ${slot}`}
              </Text>
              {hint ? (
                <Text className="rounded-chip bg-warning px-2 py-1 text-xs font-semibold text-ink">
                  힌트 {maskBlankHint(hint)}
                </Text>
              ) : null}
            </View>
            <TextInput
              accessibilityLabel={multiline ? "서술형 답안" : `핵심 키워드 ${slot}`}
              accessibilityRole="text"
              autoCapitalize="none"
              autoCorrect={false}
              className={`rounded-control border border-border bg-surface px-4 py-3 text-base font-semibold text-ink ${multiline ? "min-h-28" : "min-h-12"}`}
              editable={!disabled}
              multiline={multiline}
              onChangeText={(value) => {
                const next = Array.from(
                  { length: blankCount },
                  (_, draftIndex) => draft[draftIndex] ?? "",
                );
                next[index] = value;
                onDraftChange(next);
              }}
              placeholder={multiline ? "생각한 답을 적어 보세요" : "키워드를 입력하세요"}
              textAlignVertical={multiline ? "top" : "center"}
              value={draft[index] ?? ""}
            />
          </View>
        );
      })}
    </View>
  );
}

export function DescriptiveQuestion(
  props: Omit<React.ComponentProps<typeof KeywordInputs>, "blankCount" | "multiline">,
) {
  return <KeywordInputs {...props} blankCount={1} multiline />;
}

export function BlankQuestion({
  code,
  ...props
}: Omit<React.ComponentProps<typeof KeywordInputs>, "multiline"> & { code?: string | null }) {
  return (
    <View>
      {code ? <CodeBlock code={code} /> : null}
      <KeywordInputs {...props} multiline={false} />
    </View>
  );
}

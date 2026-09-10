import { forwardRef, useState } from "react";
import { Pressable, Text, TextInput, type TextInputProps, View } from "react-native";

type AuthInputProps = TextInputProps & {
  label: string;
  error?: string;
  password?: boolean;
};

export const AuthInput = forwardRef<TextInput, AuthInputProps>(function AuthInput(
  { label, error, password = false, ...props },
  ref,
) {
  const [passwordVisible, setPasswordVisible] = useState(false);

  return (
    <View className="gap-1.5">
      <Text className="text-sm font-semibold text-ink">{label}</Text>
      <View
        className={`min-h-12 flex-row items-center rounded-control border bg-surface px-4 ${
          error ? "border-danger" : "border-border"
        }`}
      >
        <TextInput
          ref={ref}
          {...props}
          accessibilityLabel={label}
          accessibilityRole="text"
          accessibilityHint={error}
          className="min-h-12 flex-1 text-base text-ink"
          secureTextEntry={password && !passwordVisible}
        />
        {password ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={passwordVisible ? "비밀번호 숨기기" : "비밀번호 표시"}
            className="min-h-11 min-w-11 items-center justify-center"
            disabled={props.editable === false}
            onPress={() => setPasswordVisible((visible) => !visible)}
          >
            <Text className="text-sm font-semibold text-primary">
              {passwordVisible ? "숨김" : "표시"}
            </Text>
          </Pressable>
        ) : null}
      </View>
      {error ? (
        <Text accessibilityRole="alert" className="text-sm text-danger">
          {error}
        </Text>
      ) : null}
    </View>
  );
});

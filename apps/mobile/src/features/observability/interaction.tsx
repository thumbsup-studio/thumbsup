import { usePathname } from "expo-router";
import { useCallback, useEffect, useRef } from "react";
import { type GestureResponderEvent, Pressable, type PressableProps } from "react-native";

const MAX_LABEL_LENGTH = 60;

export type InteractionReporter = (
  action: "tap" | "dialog",
  role: string,
  label: string,
  screen: string,
) => void;

/**
 * 기본값은 아무것도 하지 않는다. 실제 전송은 `ObservabilityProvider`가 있는 앱에서만
 * 등록된다. 이렇게 두면 화면 컴포넌트가 AsyncStorage·expo-updates 같은 네이티브 모듈을
 * 끌어오지 않아 화면 테스트가 그대로 가볍다.
 */
let reporter: InteractionReporter = () => undefined;

export function setInteractionReporter(next: InteractionReporter): void {
  reporter = next;
}

/**
 * 라벨은 화면에 보이는 문구라 대개 안전하지만, 사용자 값이 끼어든 라벨(이메일, 전화번호,
 * 주문번호 등)이 그대로 전송되면 안 된다. 페이로드에 넣기 전에 지운다.
 */
export function sanitizeLabel(value: string): string {
  return value
    .replace(/[^\s@]+@[^\s@]+\.[^\s@]+/g, "<email>")
    .replace(/\d{4,}/g, "<num>")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, MAX_LABEL_LENGTH);
}

/** 수집은 부가 기능이다. 전송이 실패해도 화면 동작에 영향을 주지 않는다. */
function report(action: "tap" | "dialog", role: string, label: string, screen: string): void {
  try {
    reporter(action, role, sanitizeLabel(label), screen);
  } catch {
    // 수집 실패는 삼킨다.
  }
}

type RequiredAccessibility = {
  accessibilityRole: NonNullable<PressableProps["accessibilityRole"]>;
  accessibilityLabel: string;
};

export type TrackedPressableProps = Omit<
  PressableProps,
  "accessibilityRole" | "accessibilityLabel"
> &
  RequiredAccessibility;

/**
 * role과 label을 요구하는 Pressable. 탭을 누를 때마다 화면 경로와 함께 자동으로 수집한다.
 * 화면 코드는 로그 호출을 따로 쓰지 않고 이 컴포넌트를 쓰기만 하면 된다.
 */
export function TrackedPressable({ onPress, ...props }: TrackedPressableProps) {
  const screen = usePathname();
  const { accessibilityLabel, accessibilityRole } = props;

  const handlePress = useCallback(
    (event: GestureResponderEvent) => {
      report("tap", accessibilityRole, accessibilityLabel, screen);
      onPress?.(event);
    },
    [accessibilityLabel, accessibilityRole, onPress, screen],
  );

  return <Pressable {...props} onPress={handlePress} />;
}

/**
 * 다이얼로그·바텀시트가 열릴 때 한 번만 기록한다. 닫혔다 다시 열리면 다시 기록한다.
 * 화면 전환 없이 뜨는 UI는 `usePathname()`만으로는 드러나지 않아 따로 남긴다.
 */
export function useDialogTelemetry(visible: boolean, label: string): void {
  const screen = usePathname();
  const reported = useRef(false);

  useEffect(() => {
    if (!visible) {
      reported.current = false;
      return;
    }
    if (reported.current) return;
    reported.current = true;
    report("dialog", "alert", label, screen);
  }, [label, screen, visible]);
}

import { fireEvent, render, waitFor } from "@testing-library/react-native";
import { Text } from "react-native";

import {
  sanitizeLabel,
  setInteractionReporter,
  TrackedPressable,
  useDialogTelemetry,
} from "./interaction";

jest.mock("expo-router", () => ({ usePathname: () => "/(tabs)/profile" }));

const reportInteractionMock = jest.fn();

beforeEach(() => {
  reportInteractionMock.mockReset();
  setInteractionReporter(reportInteractionMock);
});

describe("sanitizeLabel", () => {
  it("이메일과 긴 숫자를 지운다", () => {
    expect(sanitizeLabel("qa-mobile@thumbsup.studio 로그아웃")).toBe("<email> 로그아웃");
    expect(sanitizeLabel("주문 20260910 확인")).toBe("주문 <num> 확인");
  });

  it("공백을 정리하고 60자로 자른다", () => {
    expect(sanitizeLabel("  다음   문제  ")).toBe("다음 문제");
    expect(sanitizeLabel("가".repeat(80))).toHaveLength(60);
  });
});

describe("TrackedPressable", () => {
  it("탭하면 role·label·화면 경로를 함께 기록한다", async () => {
    const onPress = jest.fn();
    const screen = await render(
      <TrackedPressable accessibilityLabel="로그아웃" accessibilityRole="button" onPress={onPress}>
        <Text>로그아웃</Text>
      </TrackedPressable>,
    );

    fireEvent.press(screen.getByRole("button", { name: "로그아웃" }));

    expect(onPress).toHaveBeenCalledTimes(1);
    expect(reportInteractionMock).toHaveBeenCalledWith(
      "tap",
      "button",
      "로그아웃",
      "/(tabs)/profile",
    );
  });

  it("라벨에 섞인 개인정보는 지운 뒤 보낸다", async () => {
    const screen = await render(
      <TrackedPressable
        accessibilityLabel="qa@thumbsup.studio 계정 설정"
        accessibilityRole="button"
      >
        <Text>계정 설정</Text>
      </TrackedPressable>,
    );

    fireEvent.press(screen.getByRole("button", { name: "qa@thumbsup.studio 계정 설정" }));

    expect(reportInteractionMock).toHaveBeenCalledWith(
      "tap",
      "button",
      "<email> 계정 설정",
      "/(tabs)/profile",
    );
  });

  it("기록이 실패해도 탭 동작을 막지 않는다", async () => {
    reportInteractionMock.mockImplementationOnce(() => {
      throw new Error("network");
    });
    const onPress = jest.fn();
    const screen = await render(
      <TrackedPressable accessibilityLabel="다시 시도" accessibilityRole="button" onPress={onPress}>
        <Text>다시 시도</Text>
      </TrackedPressable>,
    );

    fireEvent.press(screen.getByRole("button", { name: "다시 시도" }));

    expect(onPress).toHaveBeenCalledTimes(1);
  });
});

function Dialog({ open }: { open: boolean }) {
  useDialogTelemetry(open, "의견 보내기");
  return <Text>{open ? "열림" : "닫힘"}</Text>;
}

describe("useDialogTelemetry", () => {
  it("열릴 때 한 번만 기록하고, 닫았다 다시 열면 또 기록한다", async () => {
    const screen = await render(<Dialog open={false} />);
    expect(reportInteractionMock).not.toHaveBeenCalled();

    await screen.rerender(<Dialog open={true} />);
    await waitFor(() => expect(reportInteractionMock).toHaveBeenCalledTimes(1));
    expect(reportInteractionMock).toHaveBeenCalledWith(
      "dialog",
      "alert",
      "의견 보내기",
      "/(tabs)/profile",
    );

    await screen.rerender(<Dialog open={true} />);
    expect(reportInteractionMock).toHaveBeenCalledTimes(1);

    await screen.rerender(<Dialog open={false} />);
    await screen.rerender(<Dialog open={true} />);
    await waitFor(() => expect(reportInteractionMock).toHaveBeenCalledTimes(2));
  });
});

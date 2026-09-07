import { fireEvent, render } from "@testing-library/react-native";

import { ChannelCard } from "./channel-list-screen";

jest.mock("expo-updates", () => ({ runtimeVersion: "0.1.0" }));
jest.mock("expo-router", () => ({
  useLocalSearchParams: () => ({}),
  useRouter: () => ({ back: jest.fn() }),
}));

const channel = {
  prNumber: 349,
  title: "채널 선택기",
  branch: "feat/349-mobile-channel-picker",
  commit: "abcdef123456",
  createdAt: "2026-09-08T02:00:00.000Z",
  runtimeVersion: "0.1.0",
};

describe("ChannelCard", () => {
  it("호환되는 PR 전환을 허용한다", async () => {
    const onPress = jest.fn();
    const screen = await render(
      <ChannelCard
        channel={channel}
        currentRuntimeVersion="0.1.0"
        disabled={false}
        onPress={onPress}
      />,
    );

    fireEvent.press(screen.getByRole("button"));
    expect(screen.getByText("호환됨")).toBeTruthy();
    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it("runtimeVersion이 다르면 새 바이너리를 안내하고 전환을 차단한다", async () => {
    const onPress = jest.fn();
    const screen = await render(
      <ChannelCard
        channel={channel}
        currentRuntimeVersion="0.2.0"
        disabled={false}
        onPress={onPress}
      />,
    );

    fireEvent.press(screen.getByRole("button"));
    expect(screen.getByText("새 바이너리 필요")).toBeTruthy();
    expect(onPress).not.toHaveBeenCalled();
  });
});

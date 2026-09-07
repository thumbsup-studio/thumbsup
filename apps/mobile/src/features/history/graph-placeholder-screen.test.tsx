import { fireEvent, render } from "@testing-library/react-native";
import { router } from "expo-router";

import HistoryGraphScreen from "./graph-placeholder-screen";

jest.mock("expo-router", () => ({
  router: { replace: jest.fn() },
}));

describe("HistoryGraphScreen", () => {
  it("그래프 후속 이슈 안내와 목록 복귀를 제공한다", async () => {
    const screen = await render(<HistoryGraphScreen />);

    expect(screen.getByText("개념 사이의 연결을 보여 주는 화면을 준비하고 있어요.")).toBeTruthy();
    await fireEvent.press(screen.getByText("히스토리 목록으로"));
    expect(jest.mocked(router).replace).toHaveBeenCalledWith("/(tabs)/history");
  });
});

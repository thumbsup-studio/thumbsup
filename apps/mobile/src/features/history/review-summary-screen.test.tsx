import { fireEvent, render } from "@testing-library/react-native";
import { router, useLocalSearchParams } from "expo-router";

import ReviewSummaryScreen from "./review-summary-screen";

jest.mock("expo-router", () => ({
  Redirect: () => null,
  router: { push: jest.fn(), replace: jest.fn() },
  useLocalSearchParams: jest.fn(),
}));

const mockedRouter = jest.mocked(router);
const mockedUseLocalSearchParams = jest.mocked(useLocalSearchParams);

describe("ReviewSummaryScreen", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedUseLocalSearchParams.mockReturnValue({ step: "3", topic: "전송 계층" });
  });

  it("완료 내용을 보여 주고 코스 복귀와 다시 풀기를 제공한다", async () => {
    const screen = await render(<ReviewSummaryScreen />);

    expect(screen.getByText("STEP 3 복습 완료")).toBeTruthy();
    expect(screen.getByText("전송 계층")).toBeTruthy();

    await fireEvent.press(screen.getByText("코스로 돌아가기"));
    expect(mockedRouter.replace).toHaveBeenCalledWith("/(tabs)/course");

    await fireEvent.press(screen.getByText("다시 풀기"));
    expect(mockedRouter.push).toHaveBeenCalledWith({
      pathname: "/play",
      params: { slot: "1", step: "3", topic: "전송 계층" },
    });
  });
});

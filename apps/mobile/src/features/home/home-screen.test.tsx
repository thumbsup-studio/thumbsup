import { render } from "@testing-library/react-native";

import { HomeScreenView } from "./home-screen";

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: jest.fn(), replace: jest.fn() }),
}));

describe("HomeScreenView", () => {
  it("최근 코스가 없으면 빈 상태와 코스 이동 동작을 보여준다", async () => {
    const screen = await render(
      <HomeScreenView
        onRetry={jest.fn()}
        state={{
          status: "success",
          data: { character: { fullness: 20, name: "보리" }, courses: [], streakDays: 0 },
        }}
      />,
    );

    expect(screen.getByText("최근 학습 코스가 없어요")).toBeTruthy();
    expect(screen.getByRole("button", { name: "코스 보러 가기" })).toBeTruthy();
  });
});

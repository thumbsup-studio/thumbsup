import { fireEvent, render } from "@testing-library/react-native";

import { CourseScreenView } from "./course-screen";

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: jest.fn(), replace: jest.fn() }),
}));

describe("CourseScreenView", () => {
  it("오류 상태에서 재시도를 제공한다", async () => {
    const onRetry = jest.fn();
    const screen = await render(
      <CourseScreenView
        onRetry={onRetry}
        onToggle={jest.fn()}
        openCourseId={null}
        state={{ reason: "network", status: "error" }}
      />,
    );

    await fireEvent.press(screen.getByRole("button", { name: "다시 시도" }));
    expect(screen.getByText("코스 목록을 불러오지 못했어요")).toBeTruthy();
    expect(onRetry).toHaveBeenCalledTimes(1);
  });
});

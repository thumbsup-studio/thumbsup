import { fireEvent, render } from "@testing-library/react-native";

import { BriefingScreenView } from "./briefing-screen";

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: jest.fn(), replace: jest.fn() }),
}));

describe("BriefingScreenView", () => {
  it("브리핑 상세 내용을 펼친다", async () => {
    const screen = await render(
      <BriefingScreenView
        courseId={1}
        onRetry={jest.fn()}
        state={{
          status: "success",
          briefing: {
            blocks: [
              { content: "첫 내용", displayOrder: 1, heading: "개념", type: "CONCEPT" },
              { content: "둘째 내용", displayOrder: 2, heading: "예시", type: "EXAMPLE" },
            ],
            courseId: 1,
            quizStepId: 3,
            stepOrder: 2,
            summary: "핵심 내용",
            topic: "운영체제",
          },
        }}
      />,
    );

    expect(screen.queryByText("둘째 내용")).toBeNull();
    await fireEvent.press(screen.getByRole("button", { name: "자세히 읽기" }));
    expect(screen.getByText("둘째 내용")).toBeTruthy();
  });
});

import { render } from "@testing-library/react-native";

import { PlaceholderScreen } from "./placeholder-screen";

describe("PlaceholderScreen", () => {
  it("renders the requested route title", async () => {
    const { getByText } = await render(<PlaceholderScreen title="홈" />);

    expect(getByText("홈")).toBeTruthy();
    expect(getByText("모바일 화면 준비 중")).toBeTruthy();
  });
});

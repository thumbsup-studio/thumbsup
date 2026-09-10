import { fireEvent, render, waitFor } from "@testing-library/react-native";
import { router } from "expo-router";

import { useApi } from "../../lib/api/api-provider";
import ProfileScreen from "./profile-screen";

jest.mock("expo-router", () => ({
  router: { push: jest.fn(), replace: jest.fn() },
  usePathname: () => "/(tabs)/profile",
}));
jest.mock("../../lib/api/api-provider", () => ({ useApi: jest.fn() }));

const mockedUseApi = jest.mocked(useApi);
const mockedRouter = jest.mocked(router);

function mockApi() {
  const profile = { email: "learner@example.com", role: "USER" as const };
  const getMyProfile = jest.fn().mockResolvedValue(profile);
  const sendFeedback = jest.fn().mockResolvedValue({ id: 1 });
  const logout = jest.fn().mockResolvedValue(undefined);

  mockedUseApi.mockReturnValue({
    client: { getMyProfile, sendFeedback } as never,
    profile,
    sessionStatus: "authenticated",
    login: jest.fn(),
    signup: jest.fn(),
    logout,
    restoreSession: jest.fn(),
  });
  return { logout, sendFeedback };
}

describe("ProfileScreen", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("피드백을 입력해 API로 제출한다", async () => {
    const { sendFeedback } = mockApi();
    const screen = await render(<ProfileScreen />);

    expect(await screen.findByText("learner@example.com")).toBeTruthy();
    await fireEvent.press(screen.getByText("의견 보내기"));
    await fireEvent.changeText(screen.getByLabelText("의견 내용"), "  좋은 앱이에요  ");
    await fireEvent.press(screen.getByText("보내기"));

    await waitFor(() => expect(sendFeedback).toHaveBeenCalledWith("좋은 앱이에요"));
  });

  it("확인 뒤 로그아웃하고 로그인 화면으로 이동한다", async () => {
    const { logout } = mockApi();
    const screen = await render(<ProfileScreen />);

    await screen.findByText("learner@example.com");
    await fireEvent.press(screen.getAllByText("로그아웃")[0]);
    await fireEvent.press(screen.getAllByText("로그아웃").at(-1) as never);

    await waitFor(() => expect(logout).toHaveBeenCalledTimes(1));
    expect(mockedRouter.replace).toHaveBeenCalledWith("/(auth)/login");
  });
});

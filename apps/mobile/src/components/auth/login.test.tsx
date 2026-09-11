import { fireEvent, render, waitFor } from "@testing-library/react-native";
import { router } from "expo-router";
import LoginScreen from "../../app/(auth)/login";
import { useApi } from "../../lib/api/api-provider";

jest.mock("expo-router", () => ({ router: { replace: jest.fn(), push: jest.fn() } }));
jest.mock("../../lib/api/api-provider", () => ({ useApi: jest.fn() }));

it("비밀번호 키보드 제출로 로그인하고 홈으로 이동한다", async () => {
  const login = jest.fn().mockResolvedValue(undefined);
  jest.mocked(useApi).mockReturnValue({ login } as never);
  const screen = await render(<LoginScreen />);
  await fireEvent.changeText(screen.getByLabelText("이메일"), "learner@example.com");
  await fireEvent.changeText(screen.getByLabelText("비밀번호"), "password123");
  await fireEvent(screen.getByLabelText("비밀번호"), "submitEditing");
  await waitFor(() => expect(login).toHaveBeenCalledWith("learner@example.com", "password123"));
  expect(router.replace).toHaveBeenCalledWith("/(tabs)");
});

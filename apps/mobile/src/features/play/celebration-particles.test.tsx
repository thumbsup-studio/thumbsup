import { render } from "@testing-library/react-native";
import { CelebrationParticles } from "./celebration-particles";
import { useReducedMotion } from "./use-reduced-motion";

jest.mock("react-native-reanimated", () => ({
  __esModule: true,
  default: { View: require("react-native").View },
  cancelAnimation: jest.fn(),
  Easing: { out: jest.fn(), quad: jest.fn() },
  useAnimatedStyle: () => ({}),
  useSharedValue: () => ({ value: 0 }),
  withTiming: jest.fn(),
}));
jest.mock("./use-reduced-motion", () => ({ useReducedMotion: jest.fn() }));

it("축하 조건이 충족되어도 모션 줄이기에서는 입자를 표시하지 않는다", async () => {
  jest.mocked(useReducedMotion).mockReturnValue(true);
  const screen = await render(<CelebrationParticles praise="3연속 정답" visible />);
  expect(screen.queryAllByText("●")).toHaveLength(0);
});

it("축하 조건이 충족되면 입자를 표시하고 조건이 사라지면 제거한다", async () => {
  jest.mocked(useReducedMotion).mockReturnValue(false);
  const screen = await render(<CelebrationParticles praise="3연속 정답" visible />);
  expect(screen.getAllByText("●", { includeHiddenElements: true })).toHaveLength(2);
  await screen.rerender(<CelebrationParticles praise="" visible={false} />);
  expect(screen.queryAllByText("●")).toHaveLength(0);
});

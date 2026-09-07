import { fireEvent, render, waitFor } from "@testing-library/react-native";
import { router } from "expo-router";

import { useApi } from "../../lib/api/api-provider";
import HistoryScreen from "./history-screen";

jest.mock("expo-router", () => ({
  router: { push: jest.fn(), replace: jest.fn() },
}));
jest.mock("../../lib/api/api-provider", () => ({ useApi: jest.fn() }));

const mockedUseApi = jest.mocked(useApi);
const mockedRouter = jest.mocked(router);

describe("HistoryScreen", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("배운 개념 목록과 상세를 보여 주고 관련 스텝 복습으로 이동한다", async () => {
    const getHistoryGraph = jest.fn().mockResolvedValue({
      edges: [],
      nodes: [
        {
          id: "network",
          label: "TCP 연결",
          description: ["신뢰성 있는 전송을 제공합니다."],
          learnedAt: "2026-09-08T00:00:00Z",
          category: "네트워크",
          relatedSteps: [{ stepOrder: 3, topic: "전송 계층" }],
        },
      ],
    });
    mockedUseApi.mockReturnValue({
      client: { getHistoryGraph } as never,
      profile: null,
      sessionStatus: "authenticated",
      login: jest.fn(),
      signup: jest.fn(),
      logout: jest.fn(),
      restoreSession: jest.fn(),
    });

    const screen = await render(<HistoryScreen />);

    expect(await screen.findByText("TCP 연결")).toBeTruthy();
    expect(screen.getByText("신뢰성 있는 전송을 제공합니다.")).toBeTruthy();
    await fireEvent.press(screen.getByText("전송 계층"));
    expect(mockedRouter.push).toHaveBeenCalledWith({
      pathname: "/play",
      params: { slot: "1", step: "3", topic: "전송 계층" },
    });
  });

  it("빈 히스토리에서 학습 진입점을 제공한다", async () => {
    mockedUseApi.mockReturnValue({
      client: { getHistoryGraph: jest.fn().mockResolvedValue({ edges: [], nodes: [] }) } as never,
      profile: null,
      sessionStatus: "authenticated",
      login: jest.fn(),
      signup: jest.fn(),
      logout: jest.fn(),
      restoreSession: jest.fn(),
    });

    const screen = await render(<HistoryScreen />);

    expect(await screen.findByText("아직 배운 개념이 없어요")).toBeTruthy();
    await fireEvent.press(screen.getByText("학습하러 가기"));
    await waitFor(() => expect(mockedRouter.push).toHaveBeenCalledWith("/(tabs)"));
  });
});

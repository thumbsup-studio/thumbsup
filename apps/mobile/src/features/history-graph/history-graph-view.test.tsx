import { fireEvent, render, waitFor } from "@testing-library/react-native";

import { HistoryGraphView } from "./history-graph-view";

jest.mock("expo-asset", () => ({ Asset: { fromModule: jest.fn() } }));
jest.mock("expo-file-system", () => ({
  File: jest.fn(),
  Paths: { document: "file:///documents" },
}));
jest.mock("react-native-webview", () => {
  const React = jest.requireActual("react");
  const { View } = jest.requireActual("react-native");
  return {
    __esModule: true,
    default: (props: Record<string, unknown>) => React.createElement(View, props),
  };
});

const graph = {
  nodes: [
    {
      id: "network",
      label: "네트워크",
      description: ["컴퓨터 간 통신의 기본 원리를 이해했어요."],
      learnedAt: "2026-09-08T00:00:00Z",
      category: "CS",
      relatedSteps: [],
    },
    {
      id: "tcp",
      label: "TCP",
      description: ["신뢰할 수 있는 전송을 학습 중이에요."],
      learnedAt: null,
      category: "CS",
      relatedSteps: [],
    },
  ],
  edges: [{ source: "network", target: "tcp" }],
};

describe("HistoryGraphView", () => {
  it("목록 대안에서 개념과 학습 상태를 읽을 수 있다", async () => {
    const writeCache = jest.fn();
    const screen = await render(
      <HistoryGraphView
        cacheKey="learner@example.com"
        fetchGraph={async () => graph}
        initialViewMode="list"
        loadHtml={async () => "<html></html>"}
        readCache={async () => null}
        writeCache={writeCache}
      />,
    );

    await waitFor(() => expect(screen.getByText("네트워크")).toBeTruthy());
    expect(screen.getByText("TCP")).toBeTruthy();
    expect(screen.getAllByText("학습 완료")).toHaveLength(2);
    expect(screen.getByText("학습 중")).toBeTruthy();
    expect(writeCache).toHaveBeenCalledWith("learner@example.com", graph);

    fireEvent.press(screen.getAllByRole("tab")[0]);
    await waitFor(() => expect(screen.getByLabelText(/지식 그래프\. 두 손가락/)).toBeTruthy());
  });
});

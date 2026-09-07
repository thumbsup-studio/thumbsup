import { render, waitFor } from "@testing-library/react-native";
import { Text } from "react-native";
import { ObservabilityProvider } from "./observability";

jest.mock("@react-native-async-storage/async-storage", () => ({
  __esModule: true,
  default: {
    getItem: jest.fn().mockResolvedValue(null),
    setItem: jest.fn().mockResolvedValue(undefined),
    removeItem: jest.fn().mockResolvedValue(undefined),
  },
}));
jest.mock("@react-native-community/netinfo", () => ({
  addEventListener: jest.fn(() => jest.fn()),
}));
jest.mock("expo-constants", () => ({
  __esModule: true,
  default: {
    expoConfig: {
      version: "0.1.0",
      extra: { updatesUrl: "https://updates.example.com", updateChannel: "production" },
    },
  },
}));
jest.mock("expo-device", () => ({ modelName: "Pixel 9" }));
jest.mock("expo-updates/build/ExpoUpdates", () => ({
  __esModule: true,
  default: {
    updateId: "update-1",
    runtimeVersion: "0.1.0",
    channel: "production",
    isEmergencyLaunch: true,
    launchDuration: 240,
  },
}));

describe("ObservabilityProvider", () => {
  it("첫 화면 렌더와 emergency launch를 업데이트 정보와 함께 전송한다", async () => {
    const fetchMock = jest.fn().mockResolvedValue({ ok: true, status: 202 });
    global.fetch = fetchMock;

    render(
      <ObservabilityProvider>
        <Text>첫 화면</Text>
      </ObservabilityProvider>,
    );

    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2));
    const requests = fetchMock.mock.calls.map(([url, options]) => ({
      url,
      payload: JSON.parse(options.body),
    }));
    expect(requests).toEqual(
      expect.arrayContaining([
        {
          url: "https://updates.example.com/api/telemetry/launch",
          payload: expect.objectContaining({
            type: "launch",
            updateId: "update-1",
            runtimeVersion: "0.1.0",
            channel: "production",
            appVersion: "0.1.0",
            deviceModel: "Pixel 9",
            success: true,
            isEmergencyLaunch: true,
            launchDuration: 240,
          }),
        },
        {
          url: "https://updates.example.com/api/telemetry/emergency",
          payload: expect.objectContaining({
            type: "emergency",
            updateId: "update-1",
            isEmergencyLaunch: true,
          }),
        },
      ]),
    );
  });
});

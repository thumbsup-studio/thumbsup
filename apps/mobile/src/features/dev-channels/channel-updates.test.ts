import * as SecureStore from "expo-secure-store";
import * as Updates from "expo-updates";

let mockEmergencyLaunch = false;

jest.mock("expo-updates", () => ({
  get isEmergencyLaunch() {
    return mockEmergencyLaunch;
  },
  setUpdateRequestHeadersOverride: jest.fn(),
  checkForUpdateAsync: jest.fn(),
  fetchUpdateAsync: jest.fn(),
  reloadAsync: jest.fn(),
}));
jest.mock("expo-secure-store", () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

import { leavePr, recoverEmergencyLaunch, switchToPr } from "./channel-updates";

const mockSetHeaders = jest.mocked(Updates.setUpdateRequestHeadersOverride);
const mockCheck = jest.mocked(Updates.checkForUpdateAsync);
const mockFetch = jest.mocked(Updates.fetchUpdateAsync);
const mockReload = jest.mocked(Updates.reloadAsync);
const mockSetItem = jest.mocked(SecureStore.setItemAsync);
const mockDeleteItem = jest.mocked(SecureStore.deleteItemAsync);

describe("PR 채널 전환", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockEmergencyLaunch = false;
    mockCheck.mockResolvedValue({ isAvailable: true } as Awaited<
      ReturnType<typeof Updates.checkForUpdateAsync>
    >);
    mockFetch.mockResolvedValue({ isNew: true } as Awaited<
      ReturnType<typeof Updates.fetchUpdateAsync>
    >);
    mockReload.mockResolvedValue(undefined);
    mockSetItem.mockResolvedValue(undefined);
    mockDeleteItem.mockResolvedValue(undefined);
  });

  it("PR 헤더로 업데이트를 받은 뒤 다시 로드한다", async () => {
    await switchToPr(349);

    expect(mockSetHeaders).toHaveBeenCalledWith({
      "expo-channel-name": "pr-349",
    });
    expect(mockFetch).toHaveBeenCalledTimes(1);
    expect(mockSetItem).toHaveBeenCalledWith("thumbsup.staging.active-pr", "349");
    expect(mockReload).toHaveBeenCalledTimes(1);
  });

  it("staging 헤더로 복귀한다", async () => {
    await leavePr();

    expect(mockSetHeaders).toHaveBeenCalledWith({
      "expo-channel-name": "staging",
    });
    expect(mockDeleteItem).toHaveBeenCalled();
  });

  it("확인 또는 다운로드 실패 시 staging 헤더와 저장 상태를 복구한다", async () => {
    mockFetch.mockRejectedValueOnce(new Error("network"));

    await expect(switchToPr(349)).rejects.toThrow("network");
    expect(mockSetHeaders).toHaveBeenLastCalledWith({
      "expo-channel-name": "staging",
    });
    expect(mockDeleteItem).toHaveBeenCalled();
    expect(mockReload).not.toHaveBeenCalled();
  });

  it("emergency launch를 감지하면 확인 실패에도 staging 헤더로 복구한다", async () => {
    mockEmergencyLaunch = true;
    mockCheck.mockRejectedValueOnce(new Error("offline"));

    await expect(recoverEmergencyLaunch()).resolves.toBe(true);
    expect(mockSetHeaders).toHaveBeenCalledWith({ "expo-channel-name": "staging" });
    expect(mockDeleteItem).toHaveBeenCalled();
    expect(mockReload).not.toHaveBeenCalled();
  });
});

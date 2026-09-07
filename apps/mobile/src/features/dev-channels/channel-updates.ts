import * as SecureStore from "expo-secure-store";
import * as Updates from "expo-updates";

const ACTIVE_PR_KEY = "thumbsup.staging.active-pr";

export async function readActivePr(): Promise<number | null> {
  const value = await SecureStore.getItemAsync(ACTIVE_PR_KEY);
  if (!value || !/^\d+$/.test(value)) return null;
  return Number(value);
}

async function selectChannel(channel: string, activePr: number | null): Promise<void> {
  Updates.setUpdateRequestHeadersOverride({ "expo-channel-name": channel });
  try {
    const check = await Updates.checkForUpdateAsync();
    if (!check.isAvailable) throw new Error("이 채널에 받을 수 있는 업데이트가 없습니다.");
    await Updates.fetchUpdateAsync();
    if (activePr === null) await SecureStore.deleteItemAsync(ACTIVE_PR_KEY);
    else await SecureStore.setItemAsync(ACTIVE_PR_KEY, String(activePr));
    await Updates.reloadAsync();
  } catch (error) {
    Updates.setUpdateRequestHeadersOverride({ "expo-channel-name": "staging" });
    await SecureStore.deleteItemAsync(ACTIVE_PR_KEY);
    throw error;
  }
}

export function switchToPr(prNumber: number): Promise<void> {
  return selectChannel(`pr-${prNumber}`, prNumber);
}

export function leavePr(): Promise<void> {
  return selectChannel("staging", null);
}

export async function recoverEmergencyLaunch(): Promise<boolean> {
  if (!Updates.isEmergencyLaunch) return false;
  Updates.setUpdateRequestHeadersOverride({ "expo-channel-name": "staging" });
  await SecureStore.deleteItemAsync(ACTIVE_PR_KEY);
  try {
    const check = await Updates.checkForUpdateAsync();
    if (check.isAvailable) {
      await Updates.fetchUpdateAsync();
      await Updates.reloadAsync();
    }
  } catch {
    // 내장 번들에서 계속 실행하되 다음 업데이트 요청은 staging으로 유지한다.
  }
  return true;
}

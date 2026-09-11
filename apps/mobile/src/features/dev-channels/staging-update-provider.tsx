import { useRouter } from "expo-router";
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { Alert, Pressable, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { leavePr, readActivePr, recoverEmergencyLaunch, switchToPr } from "./channel-updates";

interface StagingUpdateContextValue {
  activePr: number | null;
  switching: boolean;
  switchTo: (prNumber: number) => Promise<void>;
  leave: () => Promise<void>;
}

const StagingUpdateContext = createContext<StagingUpdateContextValue | null>(null);

export function useStagingUpdates(): StagingUpdateContextValue {
  const value = useContext(StagingUpdateContext);
  if (!value) throw new Error("useStagingUpdates must be used inside StagingUpdateProvider");
  return value;
}

export function StagingUpdateProvider({ children }: { children: ReactNode }) {
  const [activePr, setActivePr] = useState<number | null>(null);
  const [switching, setSwitching] = useState(false);
  const insets = useSafeAreaInsets();
  const router = useRouter();

  useEffect(() => {
    let mounted = true;
    void (async () => {
      const recovered = await recoverEmergencyLaunch();
      if (!mounted) return;
      if (recovered) {
        setActivePr(null);
        Alert.alert(
          "안정 채널로 복구했어요",
          "PR 번들을 실행하지 못해 staging 채널로 돌아왔습니다.",
        );
        return;
      }
      setActivePr(await readActivePr());
    })();
    return () => {
      mounted = false;
    };
  }, []);

  const switchTo = useCallback(async (prNumber: number) => {
    setSwitching(true);
    try {
      await switchToPr(prNumber);
    } catch {
      setActivePr(null);
      Alert.alert(
        "PR 번들을 열지 못했어요",
        "staging 채널로 복구했습니다. 네트워크를 확인하고 다시 시도해 주세요.",
      );
    } finally {
      setSwitching(false);
    }
  }, []);

  const leave = useCallback(async () => {
    setSwitching(true);
    try {
      await leavePr();
    } catch {
      setActivePr(null);
      Alert.alert(
        "staging 업데이트를 받지 못했어요",
        "헤더는 staging으로 복구했습니다. 네트워크 연결 뒤 앱을 다시 실행해 주세요.",
      );
    } finally {
      setSwitching(false);
    }
  }, []);

  const value = useMemo<StagingUpdateContextValue>(
    () => ({ activePr, switching, switchTo, leave }),
    [activePr, leave, switchTo, switching],
  );

  return (
    <StagingUpdateContext.Provider value={value}>
      {children}
      {activePr !== null ? (
        <View
          className="absolute left-4 right-4 flex-row items-center justify-between rounded-mobile-card bg-ink px-4 py-3"
          style={{ bottom: insets.bottom + 16 }}
        >
          <Pressable
            accessibilityLabel={`PR #${activePr} 채널 목록 열기`}
            accessibilityRole="button"
            className="flex-1"
            onPress={() => router.push("/dev/channels")}
          >
            <Text className="font-bold text-primary-fg">PR #{activePr} 실행 중</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            className="rounded-mobile-control bg-surface px-4 py-2"
            disabled={switching}
            onPress={() => void value.leave()}
          >
            <Text className="font-bold text-ink">{switching ? "복귀 중…" : "나가기"}</Text>
          </Pressable>
        </View>
      ) : null}
    </StagingUpdateContext.Provider>
  );
}

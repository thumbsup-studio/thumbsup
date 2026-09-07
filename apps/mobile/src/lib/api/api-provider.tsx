import { type ApiClient, createApiClient, type MyProfile } from "@thumbsup/api";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { AppState } from "react-native";

import { secureTokenStorage } from "./secure-token-storage";

type SessionStatus = "restoring" | "authenticated" | "unauthenticated";

type ApiContextValue = {
  client: ApiClient;
  profile: MyProfile | null;
  sessionStatus: SessionStatus;
  login(email: string, password: string): Promise<void>;
  signup(email: string, password: string): Promise<void>;
  logout(): Promise<void>;
  restoreSession(): Promise<void>;
};

const ApiContext = createContext<ApiContextValue | null>(null);

function getApiUrl(): string {
  const value = process.env.EXPO_PUBLIC_API_URL?.trim();
  if (!value) throw new Error("EXPO_PUBLIC_API_URL이 설정되지 않았습니다.");
  return value;
}

export function ApiProvider({ children }: PropsWithChildren) {
  const client = useMemo(
    () => createApiClient({ baseUrl: getApiUrl(), tokenStorage: secureTokenStorage }),
    [],
  );
  const [sessionStatus, setSessionStatus] = useState<SessionStatus>("restoring");
  const [profile, setProfile] = useState<MyProfile | null>(null);

  const restoreSession = useCallback(async () => {
    setSessionStatus("restoring");
    try {
      const accessToken = await secureTokenStorage.getAccess();
      if (!accessToken) throw new Error("저장된 세션이 없습니다.");
      const restoredProfile = await client.getMyProfile();
      setProfile(restoredProfile);
      setSessionStatus("authenticated");
    } catch {
      await secureTokenStorage.clear();
      setProfile(null);
      setSessionStatus("unauthenticated");
    }
  }, [client]);

  useEffect(() => {
    void restoreSession();
  }, [restoreSession]);

  useEffect(() => {
    if (sessionStatus !== "authenticated") return;
    const subscription = AppState.addEventListener("change", (nextState) => {
      if (nextState === "active") void restoreSession();
    });
    return () => subscription.remove();
  }, [restoreSession, sessionStatus]);

  const login = useCallback(
    async (email: string, password: string) => {
      await client.login(email, password);
      let nextProfile: MyProfile | null = null;
      try {
        nextProfile = await client.getMyProfile();
      } catch {
        // 로그인 자체가 성공했다면 역할 조회 실패와 분리해 일반 사용자 화면으로 진행한다.
      }
      setProfile(nextProfile);
      setSessionStatus("authenticated");
    },
    [client],
  );

  const signup = useCallback(
    async (email: string, password: string) => {
      await client.signup(email, password);
      setProfile({ email, role: "USER" });
      setSessionStatus("authenticated");
    },
    [client],
  );

  const logout = useCallback(async () => {
    await client.logout();
    setProfile(null);
    setSessionStatus("unauthenticated");
  }, [client]);

  const value = useMemo(
    () => ({ client, profile, sessionStatus, login, signup, logout, restoreSession }),
    [client, profile, sessionStatus, login, signup, logout, restoreSession],
  );

  return <ApiContext.Provider value={value}>{children}</ApiContext.Provider>;
}

export function useApi() {
  const value = useContext(ApiContext);
  if (!value) throw new Error("useApi는 ApiProvider 안에서 사용해야 합니다.");
  return value;
}

import NetInfo from "@react-native-community/netinfo";
import { createContext, type PropsWithChildren, useContext, useEffect, useState } from "react";

const ConnectivityContext = createContext(true);

export function ConnectivityProvider({ children }: PropsWithChildren) {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(
    () =>
      NetInfo.addEventListener((state) => {
        setIsOnline(state.isConnected !== false && state.isInternetReachable !== false);
      }),
    [],
  );

  return <ConnectivityContext.Provider value={isOnline}>{children}</ConnectivityContext.Provider>;
}

export function useConnectivity(): boolean {
  return useContext(ConnectivityContext);
}

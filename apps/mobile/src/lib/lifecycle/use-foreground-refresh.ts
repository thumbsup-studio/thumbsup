import { useEffect, useRef } from "react";
import { AppState } from "react-native";

export function useForegroundRefresh(refresh: () => void) {
  const refreshRef = useRef(refresh);
  refreshRef.current = refresh;

  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextState) => {
      if (nextState === "active") refreshRef.current();
    });
    return () => subscription.remove();
  }, []);
}

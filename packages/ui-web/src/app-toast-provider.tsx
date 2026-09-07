"use client";

import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

type ToastTone = "default" | "error";

type ToastPayload = {
  message: string;
  tone?: ToastTone;
  durationMs?: number;
};

type ToastState = {
  id: number;
  message: string;
  tone: ToastTone;
  durationMs: number;
};

type ToastContextValue = {
  showToast: (payload: ToastPayload) => void;
};

const DEFAULT_DURATION_MS = 3000;

const ToastContext = createContext<ToastContextValue | null>(null);

export function AppToastProvider({ children }: PropsWithChildren) {
  const [toast, setToast] = useState<ToastState | null>(null);
  const timerRef = useRef<number | null>(null);
  const nextIdRef = useRef(1);

  useEffect(() => {
    if (!toast) {
      return;
    }

    timerRef.current = window.setTimeout(() => {
      setToast((currentToast) => {
        if (!currentToast || currentToast.id !== toast.id) {
          return currentToast;
        }

        return null;
      });
    }, toast.durationMs);

    return () => {
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
      }
    };
  }, [toast]);

  const value = useMemo<ToastContextValue>(
    () => ({
      showToast: ({ message, tone = "default", durationMs = DEFAULT_DURATION_MS }) => {
        if (timerRef.current !== null) {
          window.clearTimeout(timerRef.current);
        }

        setToast({
          id: nextIdRef.current++,
          message,
          tone,
          durationMs,
        });
      },
    }),
    [],
  );

  const toastClassName =
    toast?.tone === "error"
      ? "border-danger/30 bg-danger/10 text-ink shadow-card"
      : "border-border bg-surface text-ink shadow-card";

  return (
    <ToastContext.Provider value={value}>
      {children}
      {toast ? (
        <div className="pointer-events-none fixed inset-x-0 bottom-24 z-50 flex justify-center px-4">
          <div
            aria-live="polite"
            className={`w-full max-w-sm rounded-control border px-4 py-3 text-sm font-medium ${toastClassName}`}
            data-tone={toast.tone}
            role={toast.tone === "error" ? "alert" : "status"}
          >
            {toast.message}
          </div>
        </div>
      ) : null}
    </ToastContext.Provider>
  );
}

export function useAppToast() {
  const value = useContext(ToastContext);

  if (!value) {
    throw new Error("useAppToast must be used within AppToastProvider");
  }

  return value;
}

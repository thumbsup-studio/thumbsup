import type { HistoryGraphResponse } from "@thumbsup/api";
import { useCallback, useEffect, useRef, useState } from "react";
import { Text, View } from "react-native";
import WebView, { type WebViewMessageEvent, type WebViewNavigation } from "react-native-webview";

const GRAPH_ORIGIN = "https://graph.local";
const PROTOCOL_VERSION = 1;
const READY_TIMEOUT_MS = 3_000;
const MAX_BRIDGE_MESSAGE_BYTES = 16 * 1024;

type GraphWebViewProps = {
  data: HistoryGraphResponse;
  html: string;
  onFailure(): void;
  onNodePress(nodeId: string): void;
};

type RendererMessage = {
  type: "READY" | "RENDERED" | "NODE_PRESS" | "ERROR";
  version: number;
  payload?: { nodeId?: string; code?: string };
};

function isAllowedNavigation(url: string): boolean {
  return url === "about:blank" || url === GRAPH_ORIGIN || url.startsWith(`${GRAPH_ORIGIN}/`);
}

function parseRendererMessage(raw: string): RendererMessage | null {
  if (raw.length > MAX_BRIDGE_MESSAGE_BYTES) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== "object") return null;
    const message = value as Partial<RendererMessage>;
    if (message.version !== PROTOCOL_VERSION) return null;
    if (!["READY", "RENDERED", "NODE_PRESS", "ERROR"].includes(message.type ?? "")) return null;
    return message as RendererMessage;
  } catch {
    return null;
  }
}

export function GraphWebView({ data, html, onFailure, onNodePress }: GraphWebViewProps) {
  const webViewRef = useRef<WebView>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (ready) return;
    const timer = setTimeout(onFailure, READY_TIMEOUT_MS);
    return () => clearTimeout(timer);
  }, [onFailure, ready]);

  const sendGraph = useCallback(() => {
    webViewRef.current?.postMessage(
      JSON.stringify({ type: "GRAPH_DATA", version: PROTOCOL_VERSION, payload: data }),
    );
  }, [data]);

  useEffect(() => {
    if (ready) sendGraph();
  }, [ready, sendGraph]);

  const handleMessage = useCallback(
    (event: WebViewMessageEvent) => {
      const message = parseRendererMessage(event.nativeEvent.data);
      if (!message) return;
      if (message.type === "READY") {
        setReady(true);
        return;
      }
      if (message.type === "NODE_PRESS" && typeof message.payload?.nodeId === "string") {
        onNodePress(message.payload.nodeId);
        return;
      }
      if (message.type === "ERROR") onFailure();
    },
    [onFailure, onNodePress],
  );

  return (
    <View className="h-80 overflow-hidden rounded-mobile-card bg-graph-surface">
      {!ready ? (
        <View className="absolute inset-0 z-10 items-center justify-center">
          <Text className="text-sm font-semibold text-graph-fg-muted">
            그래프 엔진을 준비하는 중
          </Text>
        </View>
      ) : null}
      <WebView
        ref={webViewRef}
        accessibilityLabel="지식 그래프. 두 손가락으로 이동하고 확대할 수 있습니다."
        allowFileAccess={false}
        allowUniversalAccessFromFileURLs={false}
        allowsLinkPreview={false}
        bounces={false}
        cacheEnabled={false}
        domStorageEnabled={false}
        incognito
        javaScriptEnabled
        javaScriptCanOpenWindowsAutomatically={false}
        mediaPlaybackRequiresUserAction
        mixedContentMode="never"
        onContentProcessDidTerminate={onFailure}
        onError={onFailure}
        onHttpError={onFailure}
        onMessage={handleMessage}
        onShouldStartLoadWithRequest={(request: WebViewNavigation) =>
          isAllowedNavigation(request.url)
        }
        originWhitelist={[GRAPH_ORIGIN]}
        setSupportMultipleWindows={false}
        sharedCookiesEnabled={false}
        source={{ html, baseUrl: `${GRAPH_ORIGIN}/` }}
        textInteractionEnabled={false}
        thirdPartyCookiesEnabled={false}
      />
    </View>
  );
}

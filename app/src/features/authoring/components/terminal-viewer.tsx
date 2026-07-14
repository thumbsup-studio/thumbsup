"use client";

import "@xterm/xterm/css/xterm.css";
import type { Terminal } from "@xterm/xterm";
import { useEffect, useRef } from "react";

export type TerminalHandle = { write: (line: string) => void };

/**
 * 잡 실행 로그를 실시간으로 밀어넣는 터미널. 부모는 `onReady`로 받은 handle.write로만 제어하는
 * 명령형 인터페이스 — xterm 인스턴스 자체는 바깥에 노출하지 않는다.
 * xterm은 브라우저 전용(DOM 의존) 라이브러리라 SSR을 피하려고 useEffect 안에서 동적 import한다.
 */
export function TerminalViewer({ onReady }: { onReady: (handle: TerminalHandle) => void }) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let term: Terminal | undefined;
    let disposed = false;

    void (async () => {
      const [{ Terminal }, { FitAddon }] = await Promise.all([
        import("@xterm/xterm"),
        import("@xterm/addon-fit"),
      ]);
      if (disposed || !containerRef.current) return;

      term = new Terminal({
        convertEol: true,
        fontSize: 12,
        disableStdin: true,
        cursorBlink: false,
        theme: { background: "#1a1b26", foreground: "#c0caf5" }, // design-ok — xterm theme은 JS 객체라 토큰 사용 불가
      });
      const fit = new FitAddon();
      term.loadAddon(fit);
      term.open(containerRef.current);
      fit.fit();

      onReady({ write: (line) => term?.write(`${line}\r\n`) });
    })();

    return () => {
      disposed = true;
      term?.dispose();
    };
  }, [onReady]);

  return (
    <div
      ref={containerRef}
      role="log"
      className="h-80 w-full overflow-hidden rounded-control bg-graph-bg"
      aria-label="잡 실행 로그 터미널"
    />
  );
}

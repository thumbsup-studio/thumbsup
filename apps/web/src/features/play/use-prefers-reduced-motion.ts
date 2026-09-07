"use client";

import { useEffect, useState } from "react";

const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

/**
 * OS의 "모션 줄이기" 설정을 읽는다.
 *
 * SSR과 jsdom에는 matchMedia가 없으므로 false(모션 허용)로 시작하고 마운트 후 맞춘다.
 * 첫 렌더에서 값이 틀려도 문제가 없는 이유: 이 값은 사용자가 [정답 확인]을 누른 뒤에야
 * 쓰이는데, 그 시점엔 이미 이펙트가 돌아 실제 값이 들어와 있다.
 */
export function usePrefersReducedMotion(): boolean {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    if (typeof window.matchMedia !== "function") {
      return undefined;
    }

    const mediaQuery = window.matchMedia(REDUCED_MOTION_QUERY);
    setPrefersReducedMotion(mediaQuery.matches);

    function handleChange(event: MediaQueryListEvent) {
      setPrefersReducedMotion(event.matches);
    }

    mediaQuery.addEventListener("change", handleChange);

    return () => {
      mediaQuery.removeEventListener("change", handleChange);
    };
  }, []);

  return prefersReducedMotion;
}

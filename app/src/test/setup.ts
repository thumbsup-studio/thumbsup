import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

process.env.NEXT_PUBLIC_API_URL = "https://thumbsup-api.duckdns.org";

class MockIntersectionObserver implements IntersectionObserver {
  readonly root: Element | Document | null = null;
  readonly rootMargin = "";
  readonly thresholds: ReadonlyArray<number> = [];

  disconnect() {}
  observe() {}
  takeRecords() {
    return [];
  }
  unobserve() {}
}

class MockResizeObserver implements ResizeObserver {
  disconnect() {}
  observe() {}
  unobserve() {}
}

globalThis.IntersectionObserver = MockIntersectionObserver;
globalThis.ResizeObserver = MockResizeObserver;

/**
 * jsdom에는 matchMedia가 없다. 기본값은 `matches: false`(모션 허용) —
 * 실제 사용자 대부분이 그렇고, 모션을 끈 경로는 각 테스트가 명시적으로 덮어쓴다.
 */
function createMatchMedia(matches: boolean) {
  return (query: string): MediaQueryList =>
    ({
      addEventListener: () => {},
      addListener: () => {},
      dispatchEvent: () => false,
      matches,
      media: query,
      onchange: null,
      removeEventListener: () => {},
      removeListener: () => {},
    }) as MediaQueryList;
}

/** 테스트에서 모션 줄이기 상태를 바꿀 때 쓴다. */
export function setPrefersReducedMotion(matches: boolean) {
  window.matchMedia = createMatchMedia(matches);
}

setPrefersReducedMotion(false);

afterEach(() => {
  setPrefersReducedMotion(false);
});

afterEach(() => {
  cleanup();
});

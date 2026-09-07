import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

process.env.NEXT_PUBLIC_API_URL = "https://thumbsup-api.duckdns.org";

// Node 22의 불완전한 전역 Web Storage가 jsdom 구현을 가리는 환경에서도 테스트를 결정적으로 유지한다.
if (typeof window.localStorage.clear !== "function") {
  const valuesByStorage = new WeakMap<Storage, Map<string, string>>();
  const valuesFor = (storage: Storage) => {
    let values = valuesByStorage.get(storage);
    if (!values) {
      values = new Map();
      valuesByStorage.set(storage, values);
    }
    return values;
  };
  Object.defineProperties(Storage.prototype, {
    clear: {
      configurable: true,
      value(this: Storage) {
        valuesFor(this).clear();
      },
    },
    getItem: {
      configurable: true,
      value(this: Storage, key: string) {
        return valuesFor(this).get(key) ?? null;
      },
    },
    key: {
      configurable: true,
      value(this: Storage, index: number) {
        return [...valuesFor(this).keys()][index] ?? null;
      },
    },
    length: {
      configurable: true,
      get(this: Storage) {
        return valuesFor(this).size;
      },
    },
    removeItem: {
      configurable: true,
      value(this: Storage, key: string) {
        valuesFor(this).delete(key);
      },
    },
    setItem: {
      configurable: true,
      value(this: Storage, key: string, value: string) {
        valuesFor(this).set(key, value);
      },
    },
  });
  Object.defineProperty(window, "localStorage", {
    configurable: true,
    value: Object.create(Storage.prototype) as Storage,
  });
}

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

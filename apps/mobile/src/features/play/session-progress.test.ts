import { describe, expect, it, vi } from "vitest";

vi.mock("@react-native-async-storage/async-storage", () => ({
  __esModule: true,
  default: {
    getItem: vi.fn(),
    removeItem: vi.fn(),
    setItem: vi.fn(),
  },
}));

import {
  applyAnswer,
  emptySession,
  readSession,
  recordAnswer,
  resetSession,
  type SessionStorage,
} from "./session-progress";

function createStorage(initial: Record<string, string> = {}): SessionStorage {
  const values = new Map(Object.entries(initial));
  return {
    getItem: vi.fn(async (key) => values.get(key) ?? null),
    removeItem: vi.fn(async (key) => {
      values.delete(key);
    }),
    setItem: vi.fn(async (key, value) => {
      values.set(key, value);
    }),
  };
}

describe("모바일 학습 세션 복원", () => {
  it("정답과 오답을 웹과 같은 누적 규칙으로 반영한다", () => {
    const first = applyAnswer(emptySession, true);
    expect(applyAnswer(first, false)).toEqual({ answered: 2, correct: 1, combo: 0, bestCombo: 1 });
  });

  it("AsyncStorage에 채점 결과를 저장하고 재실행 뒤 복원한다", async () => {
    const storage = createStorage();
    await recordAnswer(3, true, storage);
    await recordAnswer(3, true, storage);
    expect(await readSession(3, storage)).toEqual({
      answered: 2,
      correct: 2,
      combo: 2,
      bestCombo: 2,
    });
  });

  it("깨진 값은 빈 세션으로 복구하고 재시작할 수 있다", async () => {
    const storage = createStorage({ "thumbsup:play-session:4": "{broken" });
    expect(await readSession(4, storage)).toEqual(emptySession);
    await resetSession(4, storage);
    expect(await readSession(4, storage)).toEqual(emptySession);
  });
});

import type { Mock } from "vitest";
import type { TokenStorage, Tokens } from "../src";

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function envelope(code: string, data: unknown = null, message = "OK") {
  return { code, message, data, meta: null };
}

export type MemoryTokenStorage = TokenStorage & {
  get(): Tokens | null;
};

export function createMemoryTokenStorage(initial: Tokens | null = null): MemoryTokenStorage {
  let tokens = initial;
  return {
    get: () => tokens,
    getAccess: () => tokens?.accessToken ?? null,
    getRefresh: () => tokens?.refreshToken ?? null,
    set: (nextTokens) => {
      tokens = nextTokens;
    },
    clear: () => {
      tokens = null;
    },
  };
}

export function callInit(mock: Mock, index: number) {
  return mock.mock.calls[index]?.[1] as {
    headers: Record<string, string>;
    body?: string;
    method?: string;
  };
}

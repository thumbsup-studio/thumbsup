import type { TokenStorage, Tokens } from "@thumbsup/api";
import * as SecureStore from "expo-secure-store";

export const ACCESS_TOKEN_KEY = "thumbsup.access-token";
export const REFRESH_TOKEN_KEY = "thumbsup.refresh-token";

export const secureTokenStorage: TokenStorage = {
  getAccess() {
    return SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
  },
  getRefresh() {
    return SecureStore.getItemAsync(REFRESH_TOKEN_KEY);
  },
  async set(tokens: Tokens) {
    await Promise.all([
      SecureStore.setItemAsync(ACCESS_TOKEN_KEY, tokens.accessToken),
      SecureStore.setItemAsync(REFRESH_TOKEN_KEY, tokens.refreshToken),
    ]);
  },
  async clear() {
    await Promise.all([
      SecureStore.deleteItemAsync(ACCESS_TOKEN_KEY),
      SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY),
    ]);
  },
};

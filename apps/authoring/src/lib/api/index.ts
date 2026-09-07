import { createApiClient, createWebTokenStorage } from "@thumbsup/api";

const DEFAULT_API_URL = "https://thumbsup-api.duckdns.org";

export const tokenStore = createWebTokenStorage();
export const apiClient = createApiClient({
  baseUrl: process.env.NEXT_PUBLIC_API_URL || DEFAULT_API_URL,
  tokenStorage: tokenStore,
});

export const { apiRequest, apiUrl, getMyProfile, login } = apiClient;
export * from "@thumbsup/api";

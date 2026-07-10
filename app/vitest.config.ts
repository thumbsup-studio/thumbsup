import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    // API 클라이언트(client.ts)는 모듈 로드 시 process.env.NEXT_PUBLIC_API_URL로 BASE_URL을 정한다.
    // Vite는 NEXT_PUBLIC_ 접두 변수를 .env.local에서 process.env로 넣어주지 않아, 테스트 환경엔
    // 명시적으로 base URL을 주입해야 apiRequest가 동작한다(값은 fetch 목킹이라 실제 주소 무관).
    env: {
      NEXT_PUBLIC_API_URL: "http://localhost:8080",
    },
  },
});

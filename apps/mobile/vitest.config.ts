import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["app.config.test.ts", "scripts/**/*.test.mjs", "src/**/*.test.ts"],
    environment: "node",
  },
});

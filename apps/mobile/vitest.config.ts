import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["app.config.test.ts"],
    environment: "node",
  },
});

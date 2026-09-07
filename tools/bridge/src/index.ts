import { createClaudeAdapter } from "./adapters/claude.js";
import { createCodexAdapter } from "./adapters/codex.js";
import { createGeminiAdapter } from "./adapters/gemini.js";
import type { CliAdapter } from "./adapters/types.js";
import { BridgeApi } from "./api.js";
import { type BridgeCli, loadConfig, saveConfig } from "./config.js";
import { runLogin } from "./login.js";
import { runLoop } from "./runner.js";

function adapterFor(cli: BridgeCli): CliAdapter {
  switch (cli) {
    case "CLAUDE":
      return createClaudeAdapter();
    case "CODEX":
      return createCodexAdapter();
    case "GEMINI":
      return createGeminiAdapter();
  }
}

async function main(): Promise<void> {
  const [subcommand] = process.argv.slice(2);

  if (subcommand === "login") {
    await runLogin();
    return;
  }

  const config = loadConfig();
  const api = new BridgeApi(config, (updated) => saveConfig(updated));
  const adapter = adapterFor(config.cli);

  console.log(`thumbsup-bridge 시작 — 서버: ${config.serverUrl}, CLI: ${config.cli}`);
  console.log("Ctrl+C로 종료");

  const controller = new AbortController();
  process.on("SIGINT", () => {
    console.log("\n종료 신호 수신 — 진행 중인 잡을 마치고 종료합니다...");
    controller.abort();
  });

  await runLoop({ api, adapter }, controller.signal);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});

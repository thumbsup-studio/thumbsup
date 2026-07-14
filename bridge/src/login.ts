import { stdin, stdout } from "node:process";
import { createInterface } from "node:readline/promises";
import { CONFIG_PATH, saveConfig, type BridgeCli, type BridgeConfig } from "./config.js";

/** app/src/lib/api/client.ts의 DEFAULT_API_URL과 동일한 배포 API 기본값. */
const DEFAULT_SERVER_URL = "https://thumbsup-api.duckdns.org";

const CLI_CHOICES: Record<string, BridgeCli> = { "1": "CLAUDE", "2": "CODEX", "3": "GEMINI" };

/**
 * 대화형 로그인. 서버 URL·이메일·비밀번호(내부 도구라 평문 입력 허용)·CLI를 입력받아
 * POST /auth/login 호출 후 결과를 saveConfig로 저장한다.
 */
export async function runLogin(configPath: string = CONFIG_PATH): Promise<void> {
  const rl = createInterface({ input: stdin, output: stdout });
  try {
    const serverUrlInput = await rl.question(`서버 URL (기본값: ${DEFAULT_SERVER_URL}): `);
    const serverUrl = (serverUrlInput.trim() || DEFAULT_SERVER_URL).replace(/\/+$/, "");
    const email = await rl.question("이메일: ");
    const password = await rl.question("비밀번호: ");

    let cli: BridgeCli | undefined;
    while (!cli) {
      const choice = (await rl.question("CLI 선택 (1: CLAUDE, 2: CODEX, 3: GEMINI): ")).trim();
      cli = CLI_CHOICES[choice];
      if (!cli) stdout.write("1, 2, 3 중에서 선택해주세요.\n");
    }

    const res = await fetch(`${serverUrl}/api/v1/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const envelope = (await res.json()) as { code: string; message: string; data: { accessToken: string; refreshToken: string } };
    if (!res.ok) {
      throw new Error(`로그인에 실패했습니다: ${envelope.message}`);
    }

    const config: BridgeConfig = {
      serverUrl,
      cli,
      accessToken: envelope.data.accessToken,
      refreshToken: envelope.data.refreshToken,
    };
    saveConfig(config, configPath);
    stdout.write(`로그인 성공. 설정을 저장했습니다: ${configPath}\n`);
  } finally {
    rl.close();
  }
}

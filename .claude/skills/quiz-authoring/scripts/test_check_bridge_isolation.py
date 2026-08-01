#!/usr/bin/env python3
"""check_bridge_isolation.py 테스트.

의존성 없이 `python3 test_check_bridge_isolation.py`로 실행한다.
합성 픽스처를 tmp에 만들어, 규약을 깨뜨렸을 때 실제로 잡히는지 확인한다.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_bridge_isolation import main, run  # noqa: E402

GOOD_SPAWN = """
export const BLOCKED_ENV_KEYS = [
  "ANTHROPIC_API_KEY",
  "OPENAI_API_KEY",
  "GOOGLE_API_KEY",
  "GEMINI_API_KEY",
  "GOOGLE_APPLICATION_CREDENTIALS",
] as const;

export function sanitizedEnv(base = process.env) {
  const env = { ...base };
  for (const key of BLOCKED_ENV_KEYS) delete env[key];
  return env;
}
"""

GOOD_CLAUDE = """
import { tmpdir } from "node:os";
import { sanitizedEnv } from "./spawn.js";

export function createClaudeAdapter(opts = {}) {
  const subprocess = execa(opts.bin ?? "claude", [
    "-p", prompt,
    "--output-format", "stream-json",
    "--verbose",
    "--json-schema", JSON.stringify(outputSchema),
    "--tools", "",
    "--strict-mcp-config",
    "--setting-sources", "",
    "--disable-slash-commands",
    "--system-prompt", MINIMAL_SYSTEM_PROMPT,
  ], { cwd: tmpdir(), env: sanitizedEnv(), extendEnv: false, reject: false });
}
"""

GOOD_CODEX = """
import { sanitizedEnv } from "./spawn.js";
export function createCodexAdapter(opts = {}) {
  return execa(opts.bin ?? "codex", ["exec", "--json", prompt],
    { env: sanitizedEnv(), extendEnv: false, reject: false });
}
"""


class BridgeIsolationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.adapters = self.tmp / "src" / "adapters"
        self.adapters.mkdir(parents=True)
        self.write("spawn.ts", GOOD_SPAWN)
        self.write("claude.ts", GOOD_CLAUDE)
        self.write("codex.ts", GOOD_CODEX)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, name: str, body: str) -> None:
        (self.adapters / name).write_text(body, encoding="utf-8")

    # --- 정상 ---

    def test_통과하는_기준_픽스처(self):
        self.assertEqual(run(self.tmp).errors, [])

    def test_통과시_종료코드_0(self):
        self.assertEqual(main(["--bridge-dir", str(self.tmp), "--quiet"]), 0)

    # --- BLOCKED_ENV_KEYS ---

    def test_차단키가_하나라도_빠지면_잡는다(self):
        self.write("spawn.ts", GOOD_SPAWN.replace('  "GEMINI_API_KEY",\n', ""))
        errors = run(self.tmp).errors
        self.assertTrue(any("GEMINI_API_KEY" in e for e in errors), errors)

    def test_차단키_배열_선언이_사라지면_잡는다(self):
        self.write("spawn.ts", "export function sanitizedEnv(b) { return b; }")
        errors = run(self.tmp).errors
        self.assertTrue(any("BLOCKED_ENV_KEYS" in e for e in errors), errors)

    # --- env 정제 짝 ---

    def test_extendEnv_true로_바뀌면_잡는다(self):
        self.write("claude.ts", GOOD_CLAUDE.replace("extendEnv: false", "extendEnv: true"))
        errors = run(self.tmp).errors
        self.assertTrue(any("extendEnv" in e for e in errors), errors)

    def test_sanitizedEnv를_안쓰면_잡는다(self):
        self.write("codex.ts", GOOD_CODEX.replace("sanitizedEnv()", "process.env"))
        errors = run(self.tmp).errors
        self.assertTrue(any("codex.ts" in e for e in errors), errors)

    # --- claude 격리 플래그 ---

    def test_격리_플래그가_빠지면_잡는다(self):
        self.write("claude.ts", GOOD_CLAUDE.replace('"--disable-slash-commands",\n', ""))
        errors = run(self.tmp).errors
        self.assertTrue(any("--disable-slash-commands" in e for e in errors), errors)

    def test_tools_플래그가_빠지면_잡는다(self):
        self.write("claude.ts", GOOD_CLAUDE.replace('"--tools", "",\n', ""))
        errors = run(self.tmp).errors
        self.assertTrue(any("--tools" in e for e in errors), errors)

    def test_cwd_tmpdir이_빠지면_잡는다(self):
        self.write("claude.ts", GOOD_CLAUDE.replace("cwd: tmpdir(), ", ""))
        errors = run(self.tmp).errors
        self.assertTrue(any("cwd" in e for e in errors), errors)

    # --- --bare 금지 ---

    def test_bare_플래그가_들어오면_잡는다(self):
        self.write("claude.ts", GOOD_CLAUDE.replace('"-p", prompt,', '"--bare", "-p", prompt,'))
        errors = run(self.tmp).errors
        self.assertTrue(any("--bare" in e for e in errors), errors)

    def test_주석에_적힌_bare는_오탐하지_않는다(self):
        """실제 claude.ts는 '--bare는 쓰지 않는다'를 주석으로 설명한다.

        단순 부분문자열 검색이 이 설명을 위반으로 잡던 회귀를 고정한다.
        """
        self.write(
            "claude.ts",
            '// --bare는 쓰지 않는다: OAuth·키체인까지 차단해 구독 인증이 깨진다.\n'
            "/* 블록 주석 안의 --bare 도 마찬가지다. */\n" + GOOD_CLAUDE,
        )
        self.assertEqual(run(self.tmp).errors, [])

    def test_문자열_안의_슬래시두개는_주석으로_잘리지_않는다(self):
        self.write(
            "claude.ts",
            GOOD_CLAUDE.replace(
                '"-p", prompt,',
                '"-p", prompt, // 참고 https://example.com/--bare\n    ',
            ),
        )
        # URL은 주석 안에 있으므로 위반이 아니다. 플래그 검사도 그대로 통과해야 한다.
        self.assertEqual(run(self.tmp).errors, [])

    def test_주석을_지워도_플래그_검사는_유효하다(self):
        self.write("claude.ts", "// --tools 를 설명하는 주석\n" + GOOD_CLAUDE.replace('"--tools", "",\n', ""))
        errors = run(self.tmp).errors
        self.assertTrue(any("--tools" in e for e in errors), errors)

    def test_위반시_종료코드_1(self):
        self.write("claude.ts", GOOD_CLAUDE.replace('"--strict-mcp-config",\n', ""))
        self.assertEqual(main(["--bridge-dir", str(self.tmp), "--quiet"]), 1)

    # --- 검사 자체 실패 ---

    def test_bridge_디렉토리가_없으면_종료코드_2(self):
        self.assertEqual(main(["--bridge-dir", str(self.tmp / "없음"), "--quiet"]), 2)

    def test_읽을_수_없는_파일이면_종료코드_2(self):
        """읽기 실패는 '위반 발견'(1)이 아니라 '검사 불성립'(2)이어야 구분이 된다.

        권한 조작(chmod 000)은 root로 돌면 무력화되므로 CI에서 불안정하다. 대신
        비UTF-8 바이트로 read_text를 깨뜨려 플랫폼·권한과 무관하게 재현한다.
        """
        (self.adapters / "spawn.ts").write_bytes(b"\xff\xfe import { sanitizedEnv }")
        self.assertEqual(main(["--bridge-dir", str(self.tmp), "--quiet"]), 2)

    def test_소스파일이_없으면_잡는다(self):
        (self.adapters / "claude.ts").unlink()
        self.assertTrue(run(self.tmp).errors)

    # --- 회귀: 실제 레포 ---

    def test_실제_bridge_디렉토리가_규약을_지킨다(self):
        real = Path(__file__).resolve().parents[4] / "bridge"
        if not real.is_dir():
            self.skipTest(f"레포 bridge/ 없음: {real}")
        self.assertEqual(run(real).errors, [], "실제 bridge/가 격리 규약을 위반하고 있다")


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""브리지 구독 유지·격리 규약 정적 검사.

`bridge/`의 격리 플래그와 API 키 차단은 지우면 조용히 망가진다 — 테스트는 통과하고
잡도 성공하는데, 개인 구독 대신 API 종량 과금으로 새거나(비용) 운영자 개인 환경을
상속해 팀원마다 생성 결과가 달라진다(재현성). 실측으로 "1+1" 한 줄이 45,416토큰 →
616토큰까지 벌어진 항목이라 리뷰에서 눈으로 잡기엔 위험이 크다.

그래서 스킬 문서의 "제거 금지" 산문을 실행 가능한 게이트로 옮겼다.

    python3 check_bridge_isolation.py [--bridge-dir PATH] [--quiet]

종료 코드: 0 통과 / 1 위반 / 2 검사 자체 실패(파일 없음 등)
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# spawn.ts가 자식 env에서 반드시 제거해야 하는 키.
# 하나라도 빠지면 그 제공자의 API 키가 살아남아 구독 대신 종량 과금으로 흐른다.
REQUIRED_BLOCKED_ENV_KEYS = [
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
    "GOOGLE_API_KEY",
    "GEMINI_API_KEY",
    "GOOGLE_APPLICATION_CREDENTIALS",
]

# claude 어댑터가 반드시 넘겨야 하는 격리 인자.
# 없으면 운영자의 툴·MCP·설정소스·슬래시커맨드·시스템프롬프트가 통째로 상속된다.
REQUIRED_CLAUDE_FLAGS = [
    "--tools",
    "--strict-mcp-config",
    "--setting-sources",
    "--disable-slash-commands",
    "--system-prompt",
]


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    checks: list[str] = field(default_factory=list)

    def ok(self, msg: str) -> None:
        self.checks.append(f"  OK   {msg}")

    def fail(self, msg: str, detail: str) -> None:
        self.checks.append(f"  FAIL {msg}")
        self.errors.append(f"{msg}\n       → {detail}")


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_comments(src: str) -> str:
    """TS 소스에서 주석만 제거하고 문자열 리터럴은 보존한다.

    브리지 소스는 "--bare는 쓰지 않는다" 처럼 금지 항목을 주석으로 설명한다.
    단순 부분문자열 검색은 그 설명을 위반으로 오탐하므로, 문자열/주석을 구분해야 한다.
    (`https://` 의 `//` 가 주석으로 잘리지 않도록 문자열 안은 건너뛴다.)
    """
    out: list[str] = []
    i, n = 0, len(src)
    quote: str | None = None

    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        if quote:
            if ch == "\\":  # 이스케이프는 다음 문자까지 통째로
                out.append(src[i : i + 2])
                i += 2
                continue
            if ch == quote:
                quote = None
            out.append(ch)
            i += 1
            continue

        if ch in "\"'`":
            quote = ch
            out.append(ch)
            i += 1
            continue

        if ch == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue

        if ch == "/" and nxt == "*":
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                i += 1
            i += 2
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def check_blocked_env_keys(spawn_src: str, report: Report) -> None:
    """spawn.ts의 BLOCKED_ENV_KEYS가 필수 키를 전부 담고 있는지."""
    match = re.search(
        r"BLOCKED_ENV_KEYS\s*=\s*\[(.*?)\]", spawn_src, re.DOTALL
    )
    if not match:
        report.fail(
            "spawn.ts: BLOCKED_ENV_KEYS 배열",
            "선언을 찾지 못했다. 이름이 바뀌었다면 이 스크립트도 함께 고쳐라.",
        )
        return

    declared = set(re.findall(r'"([A-Z_]+)"', match.group(1)))
    missing = [k for k in REQUIRED_BLOCKED_ENV_KEYS if k not in declared]
    if missing:
        report.fail(
            "spawn.ts: BLOCKED_ENV_KEYS 필수 키",
            f"누락됨 {missing} — 이 키가 자식 env에 남으면 개인 구독 대신 API 과금이 나간다.",
        )
    else:
        report.ok(f"spawn.ts: BLOCKED_ENV_KEYS {len(REQUIRED_BLOCKED_ENV_KEYS)}종 모두 존재")


def check_sanitized_env_usage(adapters: dict[str, str], report: Report) -> None:
    """모든 어댑터가 sanitizedEnv()와 extendEnv:false를 짝으로 쓰는지.

    extendEnv를 끄지 않으면 execa가 process.env를 다시 병합해 정제가 무효가 된다.
    """
    for name, src in adapters.items():
        has_sanitized = "sanitizedEnv()" in src
        has_extend_false = re.search(r"extendEnv\s*:\s*false", src) is not None
        if has_sanitized and has_extend_false:
            report.ok(f"{name}: sanitizedEnv() + extendEnv:false")
        else:
            lacking = []
            if not has_sanitized:
                lacking.append("sanitizedEnv() 미사용")
            if not has_extend_false:
                lacking.append("extendEnv:false 없음")
            report.fail(
                f"{name}: env 정제",
                f"{' / '.join(lacking)} — 둘은 짝이어야 정제가 유효하다.",
            )


def check_claude_flags(claude_src: str, report: Report) -> None:
    """claude 어댑터의 격리 플래그 전수 + cwd:tmpdir()."""
    missing = [f for f in REQUIRED_CLAUDE_FLAGS if f'"{f}"' not in claude_src]
    if missing:
        report.fail(
            "claude.ts: 격리 플래그",
            f"누락됨 {missing} — 없으면 운영자 개인 환경을 상속한다(실측 45,416토큰 vs 616토큰).",
        )
    else:
        report.ok(f"claude.ts: 격리 플래그 {len(REQUIRED_CLAUDE_FLAGS)}종 모두 존재")

    if re.search(r"cwd\s*:\s*tmpdir\(\)", claude_src):
        report.ok("claude.ts: cwd=tmpdir() (프로젝트 CLAUDE.md·AGENTS.md 미상속)")
    else:
        report.fail(
            "claude.ts: cwd=tmpdir()",
            "cwd를 지정하지 않으면 실행 디렉토리의 CLAUDE.md/AGENTS.md를 상속한다.",
        )


def check_no_bare_flag(sources: dict[str, str], report: Report) -> None:
    """--bare 금지. OAuth·키체인을 읽지 않아 구독 인증이 깨진다."""
    offenders = [name for name, src in sources.items() if "--bare" in src]
    if offenders:
        report.fail(
            "--bare 금지",
            f"{offenders}에서 발견 — OAuth·키체인을 읽지 않아 구독 인증이 깨지고 "
            "ANTHROPIC_API_KEY를 요구하게 된다.",
        )
    else:
        report.ok("--bare 미사용")


def run(bridge_dir: Path) -> Report:
    report = Report()
    adapters_dir = bridge_dir / "src" / "adapters"

    spawn_path = adapters_dir / "spawn.ts"
    claude_path = adapters_dir / "claude.ts"
    for path in (spawn_path, claude_path):
        if not path.is_file():
            report.fail("파일 존재", f"{path} 를 찾을 수 없다.")
            return report

    # 주석은 금지 항목을 설명하느라 그 문자열을 그대로 담고 있다 — 코드만 검사한다.
    adapters = {
        p.name: strip_comments(_read(p))
        for p in sorted(adapters_dir.glob("*.ts"))
        if p.name not in {"spawn.ts", "types.ts"}
    }
    spawn_src = strip_comments(_read(spawn_path))

    check_blocked_env_keys(spawn_src, report)
    check_sanitized_env_usage(adapters, report)
    check_claude_flags(strip_comments(_read(claude_path)), report)
    check_no_bare_flag({**adapters, "spawn.ts": spawn_src}, report)
    return report


def default_bridge_dir() -> Path:
    # .claude/skills/quiz-authoring/scripts/ → 레포 루트는 4단계 위
    return Path(__file__).resolve().parents[4] / "bridge"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="브리지 격리·구독 유지 규약 검사")
    parser.add_argument("--bridge-dir", type=Path, default=None)
    parser.add_argument("--quiet", action="store_true", help="실패했을 때만 출력")
    args = parser.parse_args(argv)

    bridge_dir = args.bridge_dir or default_bridge_dir()
    if not bridge_dir.is_dir():
        print(f"검사 실패: bridge 디렉토리를 찾을 수 없다 — {bridge_dir}", file=sys.stderr)
        return 2

    # 읽기 실패(권한·삭제 경합·비UTF-8)를 그대로 터뜨리면 스택트레이스와 함께 종료 코드 1이 되어
    # "위반 발견"과 구분되지 않는다. 검사 자체가 성립하지 않은 것이므로 2로 명시한다.
    try:
        report = run(bridge_dir)
    except (OSError, UnicodeDecodeError) as e:
        print(f"검사 실패: 소스 파일을 읽을 수 없다 — {e}", file=sys.stderr)
        return 2

    if not args.quiet or report.errors:
        print(f"브리지 격리 검사 — {bridge_dir}")
        print("\n".join(report.checks))

    if report.errors:
        print("\n위반 " + str(len(report.errors)) + "건:\n", file=sys.stderr)
        for e in report.errors:
            print(f"  - {e}", file=sys.stderr)
        print(
            "\n이 플래그들은 비용·재현성 때문에 붙어 있다. 지우기 전에 "
            ".claude/skills/quiz-authoring/references/bridge.md 를 읽어라.",
            file=sys.stderr,
        )
        return 1

    if not args.quiet:
        print("\n통과 — 구독 유지·격리 규약 이상 없음")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

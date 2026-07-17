# thumbsup-bridge

팀원 노트북에서 서버 잡 큐를 폴링해 claude-code/codex/gemini CLI를 **개인 구독 세션으로 헤드리스 실행**하고, 로그를 서버로 중계하며 결과 JSON을 제출하는 로컬 실행기입니다.

## 설치

```bash
cd bridge
pnpm install
```

## 1회 셋업

브리지는 프롬프트를 만들지 않는 멍청한 실행기입니다 — 프롬프트는 서버가 렌더링해 잡에 실어 보내고, 브리지는 각 CLI를 **여러분의 개인 구독 세션**으로 그대로 실행합니다. 그래서 실행 전에 CLI별 구독 로그인이 먼저 되어 있어야 합니다.

1. 사용할 CLI에 맞춰 구독 로그인 1회:
   - Claude: `claude setup-token`
   - Codex: `codex login`
   - Gemini: `gemini` (최초 실행 시 뜨는 안내를 따라 로그인)
2. thumbsup 서버 로그인 + 브리지 설정 저장:
   ```bash
   pnpm start login
   ```
   서버 URL·이메일·비밀번호·사용할 CLI(1: CLAUDE, 2: CODEX, 3: GEMINI)를 물어보고 `~/.thumbsup/bridge.json`에 저장합니다.

## 실행

```bash
pnpm start
```

서버 잡 큐를 주기적으로 폴링하다가 잡이 오면 설정된 CLI로 실행하고, 진행 로그를 서버로 배치 전송하며, 끝나면 결과(또는 실패 사유)를 제출합니다. `Ctrl+C`로 종료하면 **진행 중인 잡을 마친 뒤** 멈춥니다.

## 구독 유지 규칙 (반드시 지킬 것)

이 도구의 존재 이유는 팀원의 개인 구독을 그대로 쓰기 위함입니다. 아래를 어기면 개인 구독 대신 API 종량 과금으로 새어나갑니다.

- 자식 프로세스 환경변수에서 `ANTHROPIC_API_KEY` · `OPENAI_API_KEY` · `GOOGLE_API_KEY` · `GEMINI_API_KEY` · `GOOGLE_APPLICATION_CREDENTIALS`를 절대 설정하지 마세요(브리지가 내부적으로 이 키들을 제거하고 실행하지만, 셸 프로파일 등에 전역으로 심어두면 다른 도구에도 영향을 줄 수 있습니다).
- `claude` 실행 시 `--bare` 플래그를 쓰지 마세요 — `CLAUDE_CODE_OAUTH_TOKEN`을 읽지 않아 구독 인증이 깨집니다.

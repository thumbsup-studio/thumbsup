# thumbsup-pm-bot

Slack 지정 채널을 수집하고 명세 근거 Q&A에 답하는 PM 봇 (Phase 1 — 읽기 전용).
설계: `../docs/superpowers/specs/2026-07-19-pm-bot-design.md`

## 준비
1. Slack 앱 (Socket Mode ON) — Bot Token Scopes: `channels:history` `channels:read` `chat:write` `reactions:read` `users:read`, Event Subscriptions: `message.channels` `app_mention`
2. `.env` — `.env.example` 참고 (`SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`)
3. `pm-bot.config.json` — `pm-bot.config.example.json` 참고 (채널 ID·명세 경로)
4. `claude` CLI 로그인 상태 (개인 구독)

## 실행
```bash
pnpm install
pnpm start          # 포그라운드
pm2 start "pnpm start" --name pm-bot   # 상주
```

## 동작 확인 (수동 e2e)
1. 지정 채널에 일반 메시지 → `sqlite3 pm-bot.sqlite 'select * from messages'`에 반영
2. `@PM봇 F-45 스펙 뭐야?` 멘션 → 스레드에 근거 포함 답변
3. 봇 종료 → 채널에 메시지 2개 → 재기동 → 백필 로그에 신규 2건, DB 반영 확인

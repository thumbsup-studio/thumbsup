# thumbsup-pm-bot

Slack 지정 채널을 수집하고 명세 근거 Q&A에 답하는 PM 봇 (Phase 1 — 읽기 전용).
설계: `../docs/superpowers/specs/2026-07-19-pm-bot-design.md`

## 준비
1. Slack 앱 — `slack-app-manifest.yml`을 https://api.slack.com/apps 의 `From an app manifest`로 붙여넣기(스코프·이벤트·Socket Mode 일괄 설정). 수동 설정 시 Bot Token Scopes: `app_mentions:read` `channels:history` `channels:read` `chat:write` `reactions:read` `users:read`, Event Subscriptions: `app_mention` `message.channels`
2. `.env` — `.env.example` 참고 (`SLACK_BOT_TOKEN`=`xoxb-`, `SLACK_APP_TOKEN`=`xapp-`. app token은 `connections:write` 스코프 필요)
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
2. `@pm-bot #63 어떻게 설계됐어?` 멘션 → 스레드에 근거 포함 답변 (멘션은 `@pm-bot` — display_name은 ASCII만 가능)
3. 봇 종료 → 채널에 메시지 2개 → 재기동 → 백필 로그에 신규 2건, DB 반영 확인

## 알려진 제약 (Phase 1)
- 봇이 꺼진 동안 **기존 스레드**(마지막 백필 이전에 시작된 스레드)에 달린 새 답글은 백필이 수집하지 못한다 (`conversations.history`가 스레드 답글을 반환하지 않는 구조적 한계). Phase 2에서 활성 스레드 재폴링으로 해결 예정.
- 봇이 꺼진 동안 들어온 @멘션 질문은 소급 응답되지 않는다 — 재기동 후 다시 멘션해야 한다 (Phase 2 예정).

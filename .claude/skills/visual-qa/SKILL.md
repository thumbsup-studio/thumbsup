---
name: visual-qa
description: UI 변경 후 로컬에서 AI 시각 QA 실행. 스크린샷 → 엘리스 멀티모달 리뷰 → 리포트 확인. UI 작업 완료 전 자가 점검용, 사용자가 "시각 QA 돌려"라고 할 때도 트리거.
---

# visual-qa — 로컬 AI 시각 QA

1. dev 서버 기동: `cd app && pnpm dev` (별도 터미널/백그라운드)
2. QA 실행:

```bash
cd app && QA_TARGET_URL=http://localhost:3000 \
  ELICE_API_KEY=<키> ELICE_BASE_URL=<엘리스 OpenAI 호환 엔드포인트, /v1까지> \
  pnpm qa:visual
```

3. `app/e2e/qa-report.md` 확인 — 🔴 항목은 수정 후 재실행, 🟡은 판단해서 처리
4. 스크린샷 원본은 `app/e2e/screenshots/`에서 직접 확인

메모: 키가 없으면 스크린샷만 저장되고 리뷰는 스킵된다(그 경우 스크린샷을 직접 눈으로 점검). 검사 라우트 추가는 `app/e2e/qa-routes.ts`에 한 줄 — 새 화면 이슈를 구현하면 그 라우트를 반드시 추가한다. #38 이후 시안이 생기면 `design` 필드에 경로를 지정해 시안 대조 모드로 전환.

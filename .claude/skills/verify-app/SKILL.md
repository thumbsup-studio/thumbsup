---
name: verify-app
description: app/ 코드 변경 후 검증 게이트. app을 수정한 작업을 완료 보고하거나 커밋하기 전 반드시 실행. 사용자가 "검증해", "게이트 돌려"라고 할 때도 트리거.
---

# verify-app — app 품질 게이트

`app/` 디렉터리에서 순서대로 실행. **하나라도 실패하면 수정 후 1번부터 재실행.**

```bash
cd app
pnpm typecheck   # 1. 타입 에러 0개
pnpm lint        # 2. 실패 시 pnpm lint:fix 후 재확인 (수정 diff 검토 필수)
pnpm build       # 3. 프로덕션 빌드 성공
pnpm check:design # 4. 토큰·스토리 규칙 위반 0건
```

## 규칙

- 네 게이트 전부 통과하기 전에는 "완료"라고 보고하지 않는다
- 게이트 실패 상태로 커밋하지 않는다
- `lint:fix`가 만든 변경은 diff를 눈으로 확인한다 (자동 변환이 의미를 바꿀 수 있음)
- check:design 위반(하드코딩 hex·arbitrary value·스토리 누락)이 있으면 완료 아님. 예외는 // design-ok 주석으로만.

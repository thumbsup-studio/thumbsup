# Thumbs Up 모노레포 — 에이전트 규약

학습 앱 모노레포: `app/`(Next.js 프론트) · `server/`(Spring Boot 백엔드 — 예정) · `shared/`(공용 — 예정)

## 필수 규칙

- **main 직접 커밋 금지.** 브랜치: `<type>/<이슈번호>-<슬러그>` (예: `feat/12-like-button`)
- 커밋 전 **`commit` 스킬**, PR 생성 전 **`pr` 스킬** 사용 (형식 강제)
- 커밋 형식: `<type>(<scope>): <한국어 요약> (#이슈)` — scope: `app`|`server`|`shared`
- PR 본문에 `Closes #이슈` 필수, Squash merge
- `app/` 작업 시: [`app/CLAUDE.md`](./app/CLAUDE.md) 규약 + **`next-best-practices` 스킬 필수 로드**
- 작업 완료 보고 전: **`verify-app` 스킬**로 게이트 통과 (app 변경 시)

상세 규약: [CONTRIBUTING.md](./CONTRIBUTING.md)

## 명령어

```bash
cd app && pnpm install && pnpm dev   # http://localhost:3000
cd app && pnpm typecheck && pnpm lint && pnpm build   # 품질 게이트
```

## 구조 참고

- 이슈·라벨·마일스톤 규약: CONTRIBUTING.md §4~6
- PR 자동 리뷰: CodeRabbit (`.coderabbit.yaml`) — `app/**`·`server/**` 경로별 지침
- 사양 문서: `docs/superpowers/specs/`

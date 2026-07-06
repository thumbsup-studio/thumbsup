# thumbsup
Thumbs Up — 학습 앱 모노레포 (app + server)

AI agent skills are shared across clients:
- Claude Code: `.claude/skills/`
- Codex: `.codex/skills/` -> `.claude/skills/` symlink

## 로컬 개발 (app)

사전 요구사항: Node 22 (`.nvmrc`, `nvm use`), pnpm 10 (`corepack enable`)

```bash
cd app
pnpm install
pnpm dev   # http://localhost:3000
```

품질 게이트(머지 전 필수): `pnpm typecheck && pnpm lint && pnpm build`

## CodeRabbit 리뷰

이 저장소는 CodeRabbit를 사용해 Pull Request 단위의 자동 코드 리뷰를 수행한다.

- 목적: PR에서 놓치기 쉬운 구현 결함, 타입/에러 처리, 보안·접근성 이슈를 빠르게 점검한다.
- 적용 범위: `.coderabbit.yaml` 기준으로 PR 변경 파일을 리뷰하며, `app/**`와 `server/**`에 각기 다른 리뷰 지침을 적용한다.
- 제외 범위: 빌드 산출물, 커버리지, `node_modules`, 락파일 등 리뷰 가치가 낮은 경로는 제외한다.

리뷰가 달리면 PR 대화와 Checks에서 CodeRabbit 코멘트를 확인하고, 필요한 수정 커밋을 같은 브랜치에 추가한다. 설정 변경이 필요하면 `.coderabbit.yaml`을 수정하고 관련 문서도 함께 갱신한다.

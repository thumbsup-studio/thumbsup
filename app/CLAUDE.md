# app — Next.js 프론트엔드 규약

스택: Next.js(App Router) · TypeScript strict · Tailwind CSS v4 · Biome · pnpm · Node 22

## 명령어

```bash
pnpm dev         # 개발 서버 (http://localhost:3000)
pnpm typecheck   # tsc --noEmit
pnpm lint        # biome check (자동수정: pnpm lint:fix)
pnpm build       # 프로덕션 빌드
```

## 코드 규약

- **Next.js 작업 전 `next-best-practices` 스킬을 반드시 로드**하고 그 지침을 따른다
- Server Component가 기본. `'use client'`는 상호작용이 필요한 최소 단위 컴포넌트에만
- import alias: `@/*` → `src/*`
- **UI 작업 시 design-system 스킬 필수 로드.** 스타일은 globals.css @theme 토큰·src/components/ui 컴포넌트만 사용(arbitrary value·raw hex 금지, check:design 게이트가 강제)
- API 클라이언트/명세 관련 코드 생성 금지 — #39 이후

## 완료 기준

- `verify-app` 스킬 게이트(typecheck → lint → build → check:design) 전부 통과 후에만 완료 보고
- 게이트 실패 상태로 커밋 금지

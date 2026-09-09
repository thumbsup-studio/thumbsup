# app — Thumbs Up 프론트엔드

Next.js(App Router) · TypeScript · Tailwind CSS v4 · Biome · pnpm

## 실행

```bash
pnpm install
pnpm dev        # http://localhost:3000
```

## 환경변수

- `NEXT_PUBLIC_API_URL`: API 베이스 URL. 미설정 시 배포 API를 사용합니다.
- `NEXT_PUBLIC_AUTHORING_URL`: 별도 배포한 저작 앱의 절대 URL. 운영값은 `https://authoring-thumbsup.vercel.app`이며, 설정하면 기존 `/authoring/*` 요청도 새 origin으로 임시 리다이렉트합니다.

로컬 설정 예시는 [`.env.example`](./.env.example)을 참고하세요.

## 품질 게이트

```bash
pnpm typecheck && pnpm lint && pnpm build
```

규약은 [`CLAUDE.md`](./CLAUDE.md), 레포 공통 규약은 [루트 README](../README.md)·[CONTRIBUTING](../CONTRIBUTING.md) 참고.

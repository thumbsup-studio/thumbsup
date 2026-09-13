# authoring — Thumbs Up 문제 저작 도구

ADMIN 전용 문제 생성·검수·개선·승인 대시보드. Next.js(App Router) · TypeScript · Tailwind CSS v4 · Biome · pnpm

사용자 웹(`apps/web`)과는 **별도 Vercel 프로젝트**로 배포된다. 운영 주소는 `https://authoring-thumbsup.vercel.app`이다.

## 실행

```bash
pnpm install
pnpm dev        # http://localhost:3000
```

`apps/web`도 3000번을 쓰므로 동시에 띄우려면 한쪽에 `pnpm dev -- -p 3001`처럼 포트를 지정한다.

## 환경변수

- `NEXT_PUBLIC_API_URL`: API 베이스 URL. **미설정 시 운영 API(`https://thumbsup-api.duckdns.org`)로 붙는다.**

⚠️ 저작 앱의 승인은 **즉시 라이브에 반영되고 되돌리는 API가 없다.** 로컬에서 개발할 때는 `.env.local`에 `NEXT_PUBLIC_API_URL=http://localhost:8080`을 반드시 넣는다. 안 넣으면 로컬 화면으로 운영 문제를 승인하게 된다. 로컬 서버 기동은 `thumbsup-local-server` 스킬을 참고한다.

설정 예시는 [`.env.example`](./.env.example)에 있다.

## 문제 저작 파이프라인

문제 생성·개선은 팀원 각자의 노트북에서 도는 로컬 브리지(`tools/bridge`)가 개인 AI CLI 구독으로 실행한다. 앱은 잡을 만들고 로그를 받아 보여줄 뿐 브리지와 직접 통신하지 않는다. 브리지 기동과 잡 문제 해결은 **`quiz-authoring` 스킬**이 정본이다.

## 품질 게이트

```bash
pnpm typecheck && pnpm lint && pnpm build && pnpm test && pnpm check:design
```

CI(`Authoring CI / authoring-gate`)가 같은 다섯 가지를 돌린다.

## 배포

[`docs/deploy.md`](./docs/deploy.md)가 정본이다. Vercel 프로젝트 설정, CORS 허용 패턴, 도메인 별칭을 다룬다.

규약은 [`CLAUDE.md`](./CLAUDE.md), 레포 공통 규약은 [루트 README](../../README.md)·[CONTRIBUTING](../../CONTRIBUTING.md) 참고.

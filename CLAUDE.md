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
- 사양 문서: `docs/specs/`

## 배포 인프라 현황 (server/AWS, #47)

스펙 원본: [server/docs/ci-requirements.md](./server/docs/ci-requirements.md), [server/docs/env-guide.md](./server/docs/env-guide.md)

- **EC2**: Amazon Linux 2023, `ap-northeast-2`(서울). 탄력적 IP 연결(고정 IP) — 실제 주소는 이 레포가 public이라 문서에 직접 기재하지 않음, GitHub Secrets `EC2_HOST` 또는 AWS 콘솔에서 확인. Docker 설치됨.
- **RDS**: MySQL 8.4.8, 식별자 `thumbs-db`, `ap-northeast-2`. 엔드포인트는 AWS 콘솔에서 확인(공개 문서에 미기재). 퍼블릭 액세스 비활성화 — EC2 보안그룹에서 오는 3306 트래픽만 허용. DB `thumbsup` 생성 완료 (`docker-compose.yml`의 MySQL 8.4와 버전 일치).
- **ECR**: `819743217770.dkr.ecr.ap-northeast-2.amazonaws.com/thumbsup-server`.
- **컨테이너 배포**: `main` 머지 시 GitHub Actions가 `server/Dockerfile`로 이미지 빌드 → ECR 푸시 → EC2에서 pull 후 `docker run --network host`로 기동(포트 8080, 기존 systemd `thumbsup.service`는 폐기·삭제됨).
- **AWS 인증(CI)**: 장기 액세스 키 없이 **OIDC**로 IAM Role 임시 위임. 역할 `arn:aws:iam::819743217770:role/thumbsup-github-actions-role` (신뢰정책: `repo:thumbsup-studio/thumbsup:ref:refs/heads/main`만 허용, 정책 `thumbsup-ecr-push`).
- **EC2 IAM 역할**: `thumbsup-ec2-role` — `thumbsup-parameter-store-read`(SSM Get* + kms:Decrypt, `/thumbsup/*` 한정), `thumbsup-ecr-pull`(ECR 이미지 pull) 정책 연결. 앱이 부팅 시 이 역할로 SSM에서 직접 설정을 읽음(파이프라인은 시크릿을 다루지 않음).
- **리버스 프록시**: Nginx가 80번 포트에서 받아 `127.0.0.1:8080`(컨테이너, host 네트워크)으로 프록시. 설정: `/etc/nginx/conf.d/thumbsup.conf`.
- **API 베이스 URL**: `https://thumbsup-api.duckdns.org/` (DuckDNS 무료 도메인 + Let's Encrypt(certbot) HTTPS 적용, HTTP는 301로 자동 리다이렉트). 인증서는 `/opt/certbot`(pip venv, AL2023엔 dnf 패키지 없음)로 설치, `/etc/cron.d/certbot-renew`로 매일 03:00 자동 갱신(만료 임박 시에만 실제 갱신 수행). 정식 커스텀 도메인 구매 시 이 값 교체 필요(AWS 크레딧은 Route 53 도메인 등록에는 적용 안 됨 — 실비 결제 필요해서 무료인 DuckDNS로 결정).
- **SSM 파라미터** (`/thumbsup/prod/*`): `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`(SecureString), `JWT_SECRET`(SecureString), `CORS_ALLOWED_ORIGIN_PATTERNS`, `SWAGGER_USERNAME`, `SWAGGER_PASSWORD`(SecureString) 등록 완료.
- **CORS**: `SecurityConfig.java`가 `allowedOriginPatterns`+`allowCredentials(true)`로 구현됨(PR #84). 허용 패턴: `https://thumbsup-app.vercel.app`, `https://*-thumbsup.vercel.app` (prod), `http://localhost:3000`(local 프로파일 전용).
- **PR 체크** (`server/**` 변경 시, `.github/workflows/server-ci.yml`): `build-and-test`(Java 21, `./gradlew build`), `gitleaks`. 두 체크 모두 브랜치 보호 규칙에 필수로 등록됨. ⚠️ `on.pull_request.paths`로 필터링하면 서버를 안 건드리는 PR에서 체크가 영원히 대기 상태로 남아 머지가 막히므로, 워크플로우는 모든 PR에서 트리거하고 `dorny/paths-filter`로 job 내부에서 스킵하는 방식 사용.
- **브랜치 보호(main)**: 상태 체크 2개(`build-and-test`, `gitleaks`) 필수, admin 포함 강제 적용. **사람 리뷰 필수 아님** — `ci-requirements.md`엔 "사람 1명 필수"로 문서화되어 있으나 실제 설정과 다름(2026-07-08, 팀 결정으로 미적용). 문서 갱신은 보류 중.

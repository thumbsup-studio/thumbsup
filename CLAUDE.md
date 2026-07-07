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

## 배포 인프라 현황 (server/AWS, #47)

- **EC2**: Amazon Linux 2023, `ap-northeast-2`(서울). 탄력적 IP `54.116.111.87` 연결(고정 IP).
- **RDS**: MySQL, 식별자 `thumbs-db`, `ap-northeast-2`. 엔드포인트 `thumbs-db.c7ue4yacm746.ap-northeast-2.rds.amazonaws.com`. 퍼블릭 액세스 비활성화 — EC2 보안그룹에서 오는 3306 트래픽만 허용.
- **리버스 프록시**: Nginx가 80번 포트에서 받아 `127.0.0.1:8080`(Spring Boot 앱)으로 프록시. 설정: `/etc/nginx/conf.d/thumbsup.conf`.
- **프로세스 관리**: systemd `thumbsup.service` (`ExecStart=/usr/bin/java -jar /home/ec2-user/app/app.jar`). 앱 JAR을 해당 경로에 올리면 `sudo systemctl start thumbsup`.
- **API 베이스 URL**: `http://54.116.111.87/` (도메인 확보 전까지 HTTP만 지원. 도메인 생기면 Let's Encrypt로 HTTPS 추가 예정).
- **CORS**: 프론트 도메인 미확정으로 아직 미설정 — 확정되는 대로 반영 필요.
- **배포 파이프라인**: GitHub Actions → SSH(SCP)로 JAR 전송 → systemd 재시작 방식. GitHub Secrets `EC2_HOST`/`EC2_USER`/`EC2_SSH_KEY` 등록 완료. 워크플로우 초안 `.github/workflows/server-deploy.yml` (Gradle 기준) 작성 완료 — `server/` 프로젝트 실제 구조 나오면 경로·빌드 명령 검증 필요.

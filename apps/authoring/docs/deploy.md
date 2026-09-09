# Authoring 배포 운영 가이드

저작 앱은 사용자 웹과 분리된 Vercel 프로젝트에 배포한다. 운영 주소는 `https://authoring-thumbsup.vercel.app`이다. GitHub Actions는 PR마다 프리뷰를 만들고 `main`에 머지되면 프로덕션을 갱신한다.

## 최초 설정

Vercel 팀 `thumbsup`에 프로젝트 `thumbsup-authoring`을 만든다(2026-09-09 생성 완료). Root Directory는 비워 둔다 — 배포 워크플로우가 `apps/authoring`에서 `vercel build`한 뒤 `.vercel`을 레포 루트로 옮겨 `--prebuilt`로 올리는 방식이라, 사용자 웹 프로젝트와 같이 Root Directory가 없어야 한다. 운영 도메인은 기본 `thumbsup-authoring.vercel.app` 외에 `authoring-thumbsup.vercel.app`을 별칭으로 추가해 정본으로 쓴다(아래 CORS 이유). GitHub 연동 배포는 사용하지 않는다. 배포는 `.github/workflows/authoring-deploy.yml`의 Vercel CLI가 맡는다. 팀원이 프리뷰를 확인할 수 있도록 Deployment Protection의 Require Log In은 꺼야 한다.

GitHub 저장소에는 다음 프로젝트 ID 두 개를 등록한다. 기존 `VERCEL_TOKEN`과 `VERCEL_ORG_ID`는 두 프로젝트에서 함께 사용한다.

- `VERCEL_PROJECT_ID_WEB`: 사용자 웹 Vercel 프로젝트 ID. 전환 중에는 기존 `VERCEL_PROJECT_ID`로 대체된다.
- `VERCEL_PROJECT_ID_AUTHORING`: 저작 앱 Vercel 프로젝트 ID.

사용자 웹 Vercel 프로젝트의 Production·Preview 환경에 `NEXT_PUBLIC_AUTHORING_URL=https://authoring-thumbsup.vercel.app`을 등록하고 다시 배포한다. 이 값이 있으면 ADMIN 로그인과 기존 `/authoring/*` 주소가 새 origin으로 이동한다. 저작 앱은 `NEXT_PUBLIC_API_URL`이 없을 때 운영 API를 기본으로 쓴다. 다른 API를 붙일 때만 해당 Vercel 프로젝트에 값을 추가한다.

## 서버 CORS

운영 CORS 허용 패턴 `https://*-thumbsup.vercel.app`이 정본 도메인 `authoring-thumbsup.vercel.app`과 프리뷰 `thumbsup-authoring-<hash>-thumbsup.vercel.app`을 모두 포함하므로 **SSM 변경 없이 동작한다**(2026-09-09 preflight로 확인: `authoring-thumbsup.vercel.app`은 200, 기본 도메인 `thumbsup-authoring.vercel.app`은 403). 기본 도메인도 허용하려는 경우에만 아래처럼 SSM 파라미터를 갱신한다. 사용자 웹 패턴은 보존한다.

```bash
aws ssm get-parameter --profile thumbsup --region ap-northeast-2 \
  --name "/thumbsup/prod/CORS_ALLOWED_ORIGIN_PATTERNS" \
  --query 'Parameter.Value' --output text

aws ssm put-parameter --profile thumbsup --region ap-northeast-2 \
  --name "/thumbsup/prod/CORS_ALLOWED_ORIGIN_PATTERNS" \
  --type String --overwrite \
  --value "https://thumbsup-app.vercel.app,https://*-thumbsup.vercel.app,https://authoring-thumbsup.vercel.app,https://thumbsup-authoring-*-thumbsup.vercel.app"
```

서버는 부팅할 때 SSM을 읽는다. EC2에서 `sudo docker restart thumbsup-server`로 재시작한 뒤 `https://thumbsup-api.duckdns.org/actuator/health`가 `UP`인지 확인한다. authoring 로그인과 API 요청에서 CORS 오류가 없는지도 점검한다.

## 배포 확인

PR에서는 `Authoring CI / authoring-gate`와 `Authoring Deploy / deploy` 결과를 확인한다. 배포 시크릿이 없는 fork PR에서는 배포 단계를 정상적으로 건너뛴다. 브랜치 보호의 필수 체크에는 `Authoring CI / authoring-gate`를 추가한다.

배포가 끝난 뒤 다음 흐름을 확인한다.

1. ADMIN 계정으로 `/login`에서 로그인하면 `/`로 이동한다.
2. USER 계정은 토큰이 지워지고 로그인 화면에 남는다.
3. 대시보드 상단의 로그아웃을 누르면 `/login`으로 돌아간다.
4. 사용자 웹의 `/authoring`과 `/authoring/drafts/1`이 새 저작 앱의 같은 경로로 307 응답을 보낸다.

## 롤백

authoring 배포에 문제가 생기면 Vercel에서 직전 정상 배포를 Production으로 승격한다. 사용자 웹의 `NEXT_PUBLIC_AUTHORING_URL`도 정상 배포 주소로 바꾸고 웹을 다시 배포한다. 그러면 기존 `/authoring/*` 진입점도 같은 주소를 가리킨다.

origin 분리를 완전히 되돌리려면 `apps/authoring` 분리 변경까지 되돌려 사용자 웹에 `/authoring` 라우트를 복구한다. 이후 `NEXT_PUBLIC_AUTHORING_URL`을 제거하고 웹을 재배포한다. SSM CORS 값에서 authoring 두 패턴을 제거한 다음 서버도 재시작한다. 외부 리다이렉트는 307로 설정했으므로 브라우저에 영구 캐시되지 않는다.

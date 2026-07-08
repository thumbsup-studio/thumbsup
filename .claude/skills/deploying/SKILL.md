---
name: deploying
description: app 배포 파이프라인 이해·운영. main→프로덕션·PR→프리뷰 배포, Vercel CLI 방식, server 배포(server-deploy.yml)와의 구분, 시크릿·프리뷰 URL·시각 QA를 확인할 때. 사용자가 "배포 어떻게 돼", "프리뷰 안 떠"라고 할 때도 트리거.
---

# deploying — app 배포 파이프라인

Vercel에 GitHub Actions로 배포한다 (`.github/workflows/app-deploy.yml`). Git 연동이 아니라 **Vercel CLI** 방식 — thumbsup-studio는 GitHub org라 Vercel 무료 플랜의 Git 연동이 불가(Pro 필요)해서 CLI로 우회한다.

## 트리거

- **main push (`app/**` 변경)** → 프로덕션 배포 (`vercel deploy --prod`)
- **PR (`app/**` 변경)** → 프리뷰 배포 + PR에 프리뷰 URL sticky 코멘트
- **`server/**` 변경** → 이 워크플로우(app-deploy)는 반응하지 않는다(paths 필터가 `app/**`만 감시). 서버는 별도 `server-deploy.yml`이 main push(`server/**`)를 AWS ECR로 배포한다 — app(Vercel)과 완전히 분리된 파이프라인이다.

## 도메인

- 프로덕션: `https://thumbsup-app.vercel.app`
- 프리뷰: `https://*-thumbsup.vercel.app` (배포마다 서브도메인 랜덤)

## 시각 QA (soft gate)

PR 프리뷰를 Playwright로 스크린샷 → 엘리스 멀티모달 모델이 리뷰 → PR sticky 코멘트. 머지를 막지 않는다. `ELICE_API_KEY` 미등록 시 스크린샷만 찍고 리뷰는 스킵. 검사 라우트는 `app/e2e/qa-routes.ts`에서 관리, 로컬 실행은 `visual-qa` 스킬 참고.

## 시크릿·변수

| 이름 | 위치 | 용도 |
|------|------|------|
| `VERCEL_TOKEN`·`VERCEL_ORG_ID`·`VERCEL_PROJECT_ID` | Secrets | CLI 배포 |
| `ELICE_API_KEY` | Secrets | 시각 QA (미등록 시 스킵) |
| `ELICE_QA_BASE_URL` | Secrets | 시각 QA 엔드포인트 (`/v1`까지, public 레포라 Secret) |
| `ELICE_QA_MODEL` | Variables | 시각 QA 모델 ID |

앱 런타임 env(`NEXT_PUBLIC_API_URL` 등)는 Vercel 프로젝트 → Settings → Environment Variables에서 관리. 자세한 표는 [README](../../../README.md) 참고.

## 막힐 때

- 프리뷰가 로그인 페이지로 튕김 → Vercel 프로젝트 Settings → Deployment Protection → Require Log In OFF
- 시크릿 미등록 → deploy 잡이 guard로 우아하게 스킵(배포 안 됨, 실패는 아님)

# 모바일 빌드 파이프라인

2026년 9월 8일 main에 병합된 워크플로우와 아직 구현되지 않은 배포를 구분해 정리했다. 워크플로우 파일이 존재하더라도 AWS 업데이트 서버가 배포되지 않은 현재 상태에서는 staging 업데이트를 실제 기기에 전달할 수 없다.

## 현재 구현

| 구성 | 파일 | 역할 | 현재 상태 |
| --- | --- | --- | --- |
| Mobile CI | `.github/workflows/mobile-ci.yml` | mobile·packages 변경을 감지해 typecheck, lint, test 실행 | 구현됨 |
| PR 번들 빌드 | `.github/workflows/mobile-pr-bundle.yml` | 같은 레포 PR의 iOS·Android Expo 번들과 출처 메타데이터를 GitHub artifact로 생성 | 구현됨 |
| PR 번들 게시 | `.github/workflows/mobile-pr-publish.yml` | 성공한 빌드 artifact를 신뢰된 main 코드로 검증해 S3 PR 채널에 게시하고 딥링크 코멘트 작성 | 구현됨, 인프라 미배포로 운영 불가 |
| PR 번들 정리 | `.github/workflows/mobile-pr-cleanup.yml` | PR 종료 시 채널 인덱스를 먼저 제거하고 S3 객체 삭제 | 구현됨, 인프라 미배포로 운영 불가 |
| 업데이트 서버 CI | `.github/workflows/updates-server-ci.yml` | Lambda·CloudFront CDK와 manifest 서버를 검사 | 구현됨 |
| 업데이트 서버 | `tools/updates-server/` | S3 채널 인덱스에서 호환 번들을 찾아 Expo Updates manifest 제공 | 코드 구현됨, AWS 미배포 |

PR 번들 흐름은 다음과 같다.

```text
PR 생성·갱신
  → Mobile PR Bundle Build
  → GitHub artifact (번들 + runtimeVersion + PR/커밋 출처)
  → Mobile PR Bundle Publish
  → S3 updates/pr-N/... + channels/index.json
  → staging 앱의 PR 채널 선택기

PR 종료
  → Mobile PR Bundle Cleanup
  → channels/index.json에서 채널 제거
  → S3 PR 객체 삭제
```

publish와 cleanup은 PR 코드를 AWS 권한으로 실행하지 않는다. main에서 체크아웃한 도구가 OIDC 역할을 위임받아 처리하며, publish는 workflow run의 PR 번호·커밋과 artifact 메타데이터가 일치할 때만 채널을 노출한다.

## 아직 구현되지 않은 항목

| 항목 | 관련 이슈 | 상태 |
| --- | --- | --- |
| staging 서명 바이너리 | #350 | 예정 |
| 백엔드 개발자용 dev-client S3 배포 | #350 | 예정 |
| production 서명 빌드·스토어 배포 | 후속 이슈 필요 | 예정 |
| 업데이트 서버 AWS 배포 및 실제 CloudFront URL 설정 | 인프라 후속 작업 | 예정 |

현재 `app.config.ts`는 업데이트 도메인이 없으면 `https://updates.thumbsup.invalid`를 사용한다. 이 주소는 의도적으로 통신할 수 없는 placeholder다. staging QA, `MOBILE_DEV_CLIENT_BASE_URL`, production 업데이트를 활성화하려면 먼저 실제 S3·Lambda·CloudFront 배포와 서명 바이너리가 필요하다.

## 로컬에서 확인하는 게이트

```bash
pnpm --filter mobile typecheck
pnpm --filter mobile lint
pnpm --filter mobile test
pnpm --filter mobile prebuild:check
cd apps/mobile && npx expo-doctor
```

CI의 Mobile CI는 앞의 세 명령을 실행한다. `prebuild:check`와 `expo-doctor`는 네이티브 설정을 바꾸거나 Expo SDK를 올릴 때 로컬에서 추가로 실행한다.

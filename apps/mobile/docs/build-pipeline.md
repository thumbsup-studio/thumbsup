# 모바일 빌드 파이프라인

2026년 9월 8일 기준 모바일 CI, PR 업데이트 번들, staging 바이너리, dev-client 흐름을 정리했다. AWS 업데이트 서버와 바이너리 버킷이 아직 배포되지 않아 S3·Expo Updates 경로는 필요한 Variables가 등록된 뒤 활성화된다.

## 현재 구현

| 구성 | 파일 | 역할 | 현재 상태 |
| --- | --- | --- | --- |
| Mobile CI | `.github/workflows/mobile-ci.yml` | mobile·packages 변경을 감지해 typecheck, lint, test 실행 | 구현됨 |
| PR 번들 빌드 | `.github/workflows/mobile-pr-bundle.yml` | 같은 레포 PR의 iOS·Android Expo 번들과 출처 메타데이터를 GitHub artifact로 생성 | 구현됨 |
| PR 번들 게시 | `.github/workflows/mobile-pr-publish.yml` | 성공한 빌드 artifact를 신뢰된 main 코드로 검증해 S3 PR 채널에 게시하고 딥링크 코멘트 작성 | 구현됨, 인프라 미배포로 운영 불가 |
| PR 번들 정리 | `.github/workflows/mobile-pr-cleanup.yml` | PR 종료 시 채널 인덱스를 먼저 제거하고 S3 객체 삭제 | 구현됨, 인프라 미배포로 운영 불가 |
| Staging 바이너리 | `.github/workflows/mobile-staging-binary.yml` | 네이티브 지문 변경 시 Android release APK와 iOS TestFlight archive 생성 | 구현됨, 자격증명·인프라 미등록 시 대체 artifact만 생성 |
| Dev-client | `.github/workflows/mobile-dev-client.yml` | 매주 또는 수동으로 Android debug APK와 iOS 시뮬레이터 ZIP 생성 | 구현됨, 인프라 미등록 시 GitHub artifact만 생성 |
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

## 네이티브 바이너리

`Mobile Staging Binary`는 수동 실행과 main push를 지원한다. main에서는 `app.config.ts`, `package.json`, lockfile, config plugin처럼 네이티브 결과에 영향을 주는 경로가 바뀔 때만 Android·iOS job을 실행한다. Android는 Ubuntu와 JDK 17에서, iOS는 macOS와 Xcode 26.4에서 각각 clean prebuild한다. Ruby 3.3.7, CocoaPods 1.17.0, Fastlane 2.239.0도 고정했다.

배포용 Android Secrets가 모두 있으면 release APK를 만들고 `binaries/staging/<runtimeVersion>/android/app.apk`에 올린다. Secrets가 없으면 debug 서명 APK를 `unsigned` GitHub artifact로만 남긴다. iOS 배포 자격증명이 있으면 App Store archive와 IPA를 만들고 App Store Connect API key까지 있을 때 TestFlight에 업로드한다. 자격증명이 없으면 서명하지 않은 시뮬레이터 앱 ZIP을 artifact로 만든다.

`Mobile Dev Client`는 매주 월요일 00:00 UTC와 수동 실행으로 development 프로필을 빌드한다. Android 결과는 `android/latest.apk`, iOS 결과는 최상위 `.app`을 담은 `ios/latest.zip`이다. S3 Variables가 있으면 다음 위치에 업로드한다.

```text
binaries/dev-client/<runtimeVersion>/android/latest.apk
binaries/dev-client/<runtimeVersion>/android/metadata.json
binaries/dev-client/<runtimeVersion>/ios/latest.zip
binaries/dev-client/<runtimeVersion>/ios/metadata.json
```

`pnpm dev:install`에 넘기는 `MOBILE_DEV_CLIENT_BASE_URL`은 runtimeVersion까지 포함한다. 예를 들어 CDN base URL이 `https://mobile.example.com`이고 runtimeVersion이 `0.1.0`이면 `https://mobile.example.com/binaries/dev-client/0.1.0`을 쓴다. 설치 스크립트가 그 아래의 `android/latest.apk` 또는 `ios/latest.zip`을 찾는다.

모든 artifact의 `metadata.json`에는 실제 Expo public config에서 읽은 `runtimeVersion`, commit, profile, platform, 배포 서명 여부가 들어간다. 네이티브 build number와 versionCode에는 GitHub run number를 넣어 TestFlight 빌드가 겹치지 않게 한다. GitHub artifact 보존 기간은 14일이다. 서명 자격증명 생성·회전·복구 절차와 필요한 Secrets·Variables는 [모바일 서명 자격증명 운영](../../../docs/mobile/signing-credentials.md)에 정리했다.

## 아직 필요한 인프라

| 항목 | 상태 |
| --- | --- |
| Apple·Android 배포 자격증명과 GitHub Secrets 등록 | 사용자 작업 필요 |
| `MOBILE_ARTIFACTS_BUCKET`·`MOBILE_BINARY_PUBLISH_ROLE_ARN` 등록 | 사용자 작업 필요 |
| production 서명 빌드·스토어 배포 | 후속 이슈 필요 |
| 업데이트 서버 AWS 배포와 실제 `MOBILE_UPDATES_URL` 등록 | 인프라 후속 작업 |

현재 `app.config.ts`는 업데이트 도메인이 없으면 `https://updates.thumbsup.invalid`를 사용한다. 이 주소는 의도적으로 통신할 수 없는 placeholder다. staging OTA와 S3 dev-client 설치를 활성화하려면 S3·Lambda·CloudFront를 배포하고 Variables를 등록해야 한다.

## 로컬에서 확인하는 게이트

```bash
pnpm --filter mobile typecheck
pnpm --filter mobile lint
pnpm --filter mobile test
pnpm --filter mobile prebuild:check
cd apps/mobile && npx expo-doctor
```

CI의 Mobile CI는 앞의 세 명령을 실행한다. `prebuild:check`와 `expo-doctor`는 네이티브 설정을 바꾸거나 Expo SDK를 올릴 때 로컬에서 추가로 실행한다. staging·dev-client 워크플로우의 Android·iOS job 자체가 각각 clean native build 검증을 맡는다.

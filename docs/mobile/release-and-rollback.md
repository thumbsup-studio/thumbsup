# 모바일 릴리즈와 롤백

이 문서는 production 바이너리와 OTA 업데이트를 출시하고, 문제가 생겼을 때 되돌리는 절차를 담았다. 스토어 자격증명과 AWS 권한을 가진 관리자가 실행해야 하며 저장소 작업만으로 실제 출시를 완료할 수는 없다.

## 릴리즈 단위와 버전

release-please는 저장소 전체에 `vX.Y.Z` 태그를 하나 만든다. `release-please-config.json`이 `version.txt`, `apps/web/package.json`, `apps/mobile/package.json`을 같은 버전으로 갱신하고, `app.config.ts`는 모바일 `package.json`의 값을 Expo `version`과 `runtimeVersion`으로 쓴다.

`Mobile Production Release`는 GitHub Release가 게시되면 직전 태그와 현재 태그를 비교한다. `apps/mobile/**` 또는 `packages/**`가 바뀐 릴리즈에서만 다음 단계로 넘어간다. 나머지는 변경 경로를 남기고 건너뛴다. `workflow_dispatch`에서 기존 태그를 지정해 다시 검증할 수도 있다.

iOS `buildNumber`와 Android `versionCode`는 `Mobile Staging Binary`의 `github.run_number × 100 + github.run_attempt`을 기본값으로 삼는다. S3의 `binaries/build-number.txt`가 더 크거나 같으면 마지막 값에 1을 더해 예약한다. 이전 실행을 나중에 재실행해도 스토어 번호가 줄거나 겹치지 않는다. S3 변수가 없는 검증 실행은 기본값만 쓰므로 스토어 제출용으로 간주하지 않는다.

## staging 앱과 release candidate

두 바이너리는 쓰임새가 다르다.

- staging 앱은 `studio.thumbsup.staging`, staging 채널을 사용한다. PR 채널을 오가며 기능을 확인하는 내부 도구다.
- release candidate(RC)는 실제 스토어 앱과 같은 `studio.thumbsup`, production 채널을 사용한다. TestFlight 내부 테스트와 Play 내부 테스트 트랙에서 최종 확인한다.

검증 순서는 PR 채널, staging 안정 채널, RC 내부 트랙, production 스토어 순이다. staging 앱 바이너리를 production 앱으로 바꾸어 올릴 수는 없다. `Mobile Staging Binary`의 `mode=release-candidate`가 production 식별자로 AAB와 IPA를 한 번 만들고 S3 `binaries/staging/<runtimeVersion>/`에 보관한다. 모바일 변경을 포함한 Release PR이 main에 합쳐질 때도 RC 모드가 자동으로 선택된다.

RC 빌드에서는 production export를 만들고 `setUpdateRequestHeadersOverride` 문자열이 없는지 검사한다. 관측성은 읽기 전용 Expo Updates 엔트리만 사용하며, `dev/channels`와 `StagingUpdateProvider`는 Metro resolver가 production stub으로 바꾼다. 검사에 실패하면 네이티브 빌드와 스토어 업로드를 시작하지 않는다.

## 스토어 제출

1. Release PR의 모바일 버전과 변경 내역을 확인한 뒤 머지한다.
2. `Mobile Staging Binary` RC 실행에서 Android AAB와 iOS IPA의 `metadata.json`을 확인한다. `profile=release-candidate`, `appEnvironment=production`, release commit, runtimeVersion, SHA-256이 모두 맞아야 한다.
3. TestFlight와 Play 내부 트랙에서 로그인, 핵심 학습 흐름, 업데이트 확인, 재실행을 점검한다.
4. GitHub Release가 게시되면 `Mobile Production Release`가 같은 S3 객체의 SHA-256과 provenance를 확인한다. iOS는 `fastlane deliver`가 내부 테스트에서 확인한 build number를 선택하며 IPA를 다시 올리지 않는다. Android는 `fastlane supply`가 같은 versionCode를 internal에서 production 트랙으로 옮긴다.
5. 자동 실행이 실패했거나 검증만 하려면 Actions에서 같은 태그를 `dry_run=true`로 실행한다. 실제 승격은 `dry_run=false`로 다시 실행한다. 스토어 심사 제출과 공개 시점은 App Store Connect와 Play Console에서 관리자가 결정한다.

## OTA 승격과 점진 배포

RC workflow는 production 설정으로 내보낸 동일 번들을 `staging` 채널에 게시한다. production 릴리즈는 asset을 다시 만들지 않고 S3에서 복사한 뒤 production index의 선두 포인터만 갱신한다.

```bash
pnpm --filter updates-server updates -- promote \
  --bucket "$MOBILE_ARTIFACTS_BUCKET" \
  --from staging --update-id <release-commit-sha> --to production \
  --runtime-version <X.Y.Z> --rollout-percentage 10 --dry-run
```

dry-run은 source index, metadata, runtimeVersion, 복사 대상만 확인하고 S3를 바꾸지 않는다. 실제 실행에서는 `--dry-run`을 뺀다. `rolloutPercentage`는 0부터 100까지 지정하며, 이상이 없으면 같은 updateId를 25, 50, 100 순으로 다시 승격한다. 서버는 처음 접속한 클라이언트에 무작위 `expo-client-id`를 `expo-server-defined-headers`로 내려준다. Expo Updates는 이후 요청에 같은 값을 보낸다. 서버는 이 ID의 SHA-256 버킷으로 새 업데이트와 직전 100% 업데이트를 나눈다. 같은 설치는 재실행해도 같은 그룹에 남는다.

production 앱에는 공개 코드 서명 인증서가 반드시 들어간다. manifest 서버도 production 요청에 `expo-expect-signature`가 없으면 거부하고, SSM SecureString `/thumbsup/prod/updates-signing-private-key`의 private key로 manifest와 rollback directive를 서명한다. private key 원문은 GitHub Secrets나 저장소에 넣지 않는다.

## 롤백과 kill switch

출시 뒤 crash, emergency launch, 로그인 실패가 이전 버전보다 뚜렷하게 늘거나 핵심 흐름이 막히면 신규 승격을 멈춘다. 영향이 OTA 코드에 한정되고 직전 업데이트가 정상이라면 production 포인터를 되돌린다.

```bash
pnpm --filter updates-server updates -- rollback \
  --bucket "$MOBILE_ARTIFACTS_BUCKET" \
  --channel production --to <previous-update-id> --dry-run
```

dry-run 결과와 대상 runtimeVersion을 확인한 뒤 옵션을 빼고 실행한다. 선택한 기존 updateId가 새 포인터가 되며 asset은 복사하거나 다시 빌드하지 않는다.

직전 OTA도 안전하지 않거나 서버가 특정 runtimeVersion의 OTA를 모두 막아야 하면 내장 번들 kill switch를 쓴다.

```bash
pnpm --filter updates-server updates -- rollback \
  --bucket "$MOBILE_ARTIFACTS_BUCKET" \
  --channel production --to embedded --runtime-version <X.Y.Z> \
  --commit-time <ISO-8601> --dry-run
```

실행하면 manifest handler가 Expo Updates 프로토콜 v1의 `rollBackToEmbedded` directive를 서명해 반환한다. 복구 뒤에는 원인, 영향 runtimeVersion, 시작·종료 시각, 선택한 updateId를 장애 기록에 남긴다. 네이티브 결함은 OTA로 해결하지 말고 스토어 긴급 빌드를 새 build number로 제출한다.

## 관리자가 준비할 값

GitHub Environment `mobile-production`에는 승인자와 main/tag 배포 제한을 둔다. Variables에는 `MOBILE_ARTIFACTS_BUCKET`, `MOBILE_BINARY_PUBLISH_ROLE_ARN`, `MOBILE_PRODUCTION_PUBLISH_ROLE_ARN`, `MOBILE_UPDATES_URL`, `MOBILE_APPLE_TEAM_ID`를 등록한다.

Secrets에는 production Android keystore 4종(`MOBILE_PRODUCTION_ANDROID_*`), production iOS 인증서와 provisioning profile 3종(`MOBILE_PRODUCTION_IOS_*`), App Store Connect API key 3종(`MOBILE_ASC_*`), `MOBILE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64`, `MOBILE_UPDATES_CODE_SIGNING_CERTIFICATE_BASE64`를 등록한다. AWS 관리자는 SSM의 `/thumbsup/prod/updates-signing-private-key`와 최소 권한 IAM 역할을 만들고, 스토어 관리자는 앱 레코드·내부 테스트 그룹·심사 정보를 준비한다.

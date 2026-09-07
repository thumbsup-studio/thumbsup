# 모바일 서명 자격증명 운영

백엔드 개발자 3~5명이 staging 앱과 dev-client를 내부에서 쓰는 상황을 기준으로 한다. 대상은 팀이 관리하는 Android 실기기·에뮬레이터와 iOS 실기기·시뮬레이터다. 비밀값과 원본 인증서는 public 레포에 올리지 않고, 권한을 제한한 비밀 저장소와 GitHub Actions Secrets에만 보관한다.

## 내부 배포 방식

- Android staging은 S3의 `binaries/staging/<runtimeVersion>/android/app.apk`를 직접 설치한다. 소규모 팀에서는 Play Console 내부 테스트 트랙보다 배포 절차가 짧다. 동일한 upload keystore를 유지해야 기존 설치본을 업데이트할 수 있다.
- iOS staging은 TestFlight 내부 테스트로 배포한다. ad-hoc 방식은 기기 UDID를 수집하고 provisioning profile을 기기가 바뀔 때마다 다시 만들어야 한다. TestFlight는 App Store Connect 사용자로 등록된 내부 테스터에게 배포하므로 3~5명 팀의 기기 교체와 추가에 더 잘 맞는다.
- dev-client는 Android debug APK와 iOS 시뮬레이터 앱을 GitHub artifact로 남긴다. S3 변수가 있으면 `binaries/dev-client/<runtimeVersion>/<platform>/latest.*`에도 올린다.

## GitHub 설정 목록

Repository settings의 Actions secrets and variables에 아래 값을 등록한다. 파일은 로컬에서 base64 한 줄로 인코딩하고 `gh secret set NAME < encoded.txt`처럼 표준 입력으로 넣는다. 값 자체를 명령 인자나 로그에 남기지 않는다.

| 종류 | 이름 | 내용 |
| --- | --- | --- |
| Secret | `MOBILE_ANDROID_KEYSTORE_BASE64` | Android upload keystore의 base64 |
| Secret | `MOBILE_ANDROID_KEYSTORE_PASSWORD` | keystore 비밀번호 |
| Secret | `MOBILE_ANDROID_KEY_ALIAS` | upload key alias |
| Secret | `MOBILE_ANDROID_KEY_PASSWORD` | upload key 비밀번호 |
| Secret | `MOBILE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Play Console 서비스 계정 JSON. 현재 S3 경로에는 쓰지 않고 향후 Play 배포용으로 보관 |
| Secret | `MOBILE_IOS_CERTIFICATE_P12_BASE64` | Apple Distribution 인증서와 private key가 든 P12의 base64 |
| Secret | `MOBILE_IOS_CERTIFICATE_PASSWORD` | P12 내보내기 비밀번호 |
| Secret | `MOBILE_IOS_PROVISIONING_PROFILE_BASE64` | `studio.thumbsup.staging` App Store provisioning profile의 base64 |
| Secret | `MOBILE_ASC_KEY_ID` | App Store Connect API key ID |
| Secret | `MOBILE_ASC_ISSUER_ID` | App Store Connect issuer ID |
| Secret | `MOBILE_ASC_API_KEY_P8_BASE64` | App Store Connect P8 private key의 base64 |
| Variable | `MOBILE_APPLE_TEAM_ID` | Apple Developer Team ID |
| Variable | `MOBILE_ARTIFACTS_BUCKET` | 모바일 바이너리 S3 버킷 이름 |
| Variable | `MOBILE_BINARY_PUBLISH_ROLE_ARN` | `binaries/*`에만 쓸 수 있는 GitHub OIDC IAM role ARN |
| Variable | `MOBILE_UPDATES_URL` | 배포된 Expo Updates HTTPS base URL. 미설정 시 통신 불가 placeholder 사용 |

자격증명이 빠지면 Android staging은 debug 서명 APK를 `unsigned` artifact로만 남기고 S3 업로드를 생략한다. iOS staging은 시뮬레이터 ZIP으로 대체하고 TestFlight 업로드를 생략한다. S3 변수 두 개가 없으면 GitHub artifact까지만 만든다.

## Android 자격증명

### 생성과 등록

1. 격리된 관리 단말에서 `keytool -genkeypair -v -keystore thumbsup-staging-upload.jks -alias <alias> -keyalg RSA -keysize 4096 -validity 10000`으로 upload keystore를 만든다. 비밀번호는 새로 생성해 비밀 저장소에 기록한다.
2. 원본 JKS를 조직의 암호화된 비밀 저장소와 별도의 오프라인 복구 저장소에 보관한다. 보관 담당자 두 명이 복구 가능 여부와 파일 checksum을 확인한다.
3. JKS를 base64 한 줄로 인코딩해 `MOBILE_ANDROID_KEYSTORE_BASE64`에 넣고, 나머지 세 값을 각각 Secret에 등록한다. 임시 인코딩 파일은 등록 직후 안전하게 삭제한다.
4. 향후 Play 배포를 준비할 때 Google Cloud 서비스 계정을 만들고 Play Console의 API access에서 앱 단위 권한만 부여한다. JSON key는 `MOBILE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`에 등록한 뒤 로컬 사본을 삭제한다. 현재 S3 배포에는 이 계정을 사용하지 않는다.

### 회전과 복구

S3로 직접 배포하는 APK는 설치된 앱과 같은 키로 서명해야 업데이트된다. 정기 회전 대상이 아니므로 keystore 비밀번호만 조직 정책에 따라 바꾸고, 키 자체는 만료 전까지 유지한다. Play upload key는 새 키를 만든 뒤 Play Console의 upload key 재설정 절차를 거쳐 교체할 수 있다.

keystore를 잃으면 암호화 백업에서 복구하고 Secret 네 개를 다시 등록한 뒤 staging 빌드의 서명 인증서 지문을 기존 APK와 비교한다. 백업까지 없으면 S3 설치본은 같은 applicationId로 업데이트할 수 없다. 새 applicationId로 배포해 기존 앱을 제거·재설치해야 한다. Play 배포본은 Play Console의 upload key 복구 절차를 쓴다. 서비스 계정 key가 노출되거나 사라지면 새 JSON key로 배포를 확인한 다음 이전 key를 폐기한다.

## Apple 자격증명

### 생성과 등록

1. Apple Developer의 Certificates에서 Apple Distribution 인증서를 만든다. 관리 단말 Keychain Access에서 CSR을 생성하고, 발급된 인증서와 private key를 비밀번호가 설정된 P12로 내보낸다.
2. Identifiers에서 staging bundle ID `studio.thumbsup.staging`을 확인한다. Profiles에서 App Store 배포 profile을 만들고 앞의 인증서를 연결해 내려받는다.
3. App Store Connect에 같은 bundle ID의 앱을 만들고, Users and Access의 Integrations에서 업로드 전용 API key를 발급한다. 빌드 업로드에 필요한 최소 역할만 부여한다. P8은 한 번만 내려받을 수 있으므로 발급 즉시 암호화 백업을 만든다.
4. P12·provisioning profile·P8을 각각 base64 한 줄로 인코딩해 대응하는 Secrets에 등록한다. Team ID는 `MOBILE_APPLE_TEAM_ID` Variable에 넣는다. 등록 후 평문과 임시 인코딩 파일을 삭제한다.
5. 첫 서명 빌드에서는 GitHub Actions의 archive 서명 로그와 TestFlight 처리 결과를 확인하고, 내부 테스터 그룹에 staging 빌드가 보이는지 검증한다.

### 회전과 복구

Apple Distribution 인증서 만료 30일 전 새 인증서를 발급하고 새 인증서를 포함한 provisioning profile을 만든다. 새 P12와 profile Secrets를 함께 교체해 TestFlight 업로드를 확인한 다음 이전 인증서를 폐기한다. App Store Connect API key는 새 key 세트를 먼저 등록해 업로드 성공을 확인하고 기존 key를 revoke한다.

P12나 profile을 잃으면 Apple Developer에서 유효한 인증서·profile을 다시 내려받거나 새로 발급한다. private key까지 잃었다면 기존 인증서를 revoke하고 새 인증서와 profile을 발급해야 한다. P8은 다시 내려받을 수 없으므로 복구 백업이 없으면 기존 API key를 revoke하고 새 key를 만든다. 교체 작업 중에는 이전 자격증명을 없애기 전에 새 자격증명으로 한 번 빌드해 무중단 여부를 확인한다.

## 접근 통제와 점검

- GitHub Actions의 secret 읽기 권한, Apple Developer의 Certificates 권한, App Store Connect API key 발급 권한, Google Cloud key 관리자 권한을 최소 인원에게만 준다.
- `MOBILE_BINARY_PUBLISH_ROLE_ARN`의 신뢰 정책은 이 레포의 허용된 ref와 두 모바일 워크플로우로 제한하고, 정책은 대상 버킷의 `binaries/*` 쓰기만 허용한다.
- 분기마다 만료일, 마지막 성공 빌드, 백업 복구 가능 여부, 퇴사자 권한 회수를 확인한다. 노출이 의심되면 해당 key를 즉시 폐기하고 새 값으로 교체한 뒤 Actions 로그와 S3 변경 이력을 점검한다.

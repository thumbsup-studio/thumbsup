# Thumbs Up 모바일

Expo SDK 57과 expo-router로 구성한 모바일 앱 셸이다. 네이티브 프로젝트는 저장소에 두지 않고 필요할 때 Expo CNG로 생성한다.

## 준비

루트에서 환경을 준비하고 진단한다.

```bash
pnpm bootstrap
pnpm diagnose
```

`APP_ENV`에는 `development`, `staging`, `production` 가운데 하나를 지정한다. `EXPO_PUBLIC_API_URL`은 필수다. CloudFront 업데이트 도메인이 정해지면 `EXPO_PUBLIC_UPDATES_URL`도 설정하며, 그전에는 `app.config.ts`의 placeholder URL을 쓴다.

자세한 환경 설정과 기기별 네트워크 연결은 [로컬 개발 문서](./docs/local-dev.md)를 참고한다. `pnpm setup`과 `pnpm doctor`는 pnpm 자체 명령이므로 사용하지 않는다.

## 실행

```bash
pnpm dev:install android
pnpm dev
```

현재 Expo SDK 57은 Xcode 26.4 이상이 필요하다. 그보다 낮은 Xcode에서는 Expo Go로 JavaScript 화면을 확인하고, 네이티브 iOS 빌드는 지원 버전에서 다시 검증한다.

## 검증

```bash
pnpm --filter mobile typecheck
pnpm --filter mobile lint
pnpm --filter mobile test
pnpm --filter mobile prebuild:check
cd apps/mobile && npx expo-doctor
```

`prebuild:check`는 iOS와 Android 프로젝트를 생성해 설정을 검증한 뒤 두 디렉터리를 삭제한다.

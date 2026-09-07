# Thumbs Up 모바일

Expo SDK 57과 expo-router로 구성한 모바일 앱 셸이다. 네이티브 프로젝트는 저장소에 두지 않고 필요할 때 Expo CNG로 생성한다.

## 준비

루트에서 Node.js 22와 pnpm 10.11로 의존성을 설치한다.

```bash
pnpm install --frozen-lockfile
cp apps/mobile/.env.example apps/mobile/.env.local
```

`APP_ENV`에는 `development`, `staging`, `production` 가운데 하나를 지정한다. `EXPO_PUBLIC_API_URL`은 필수다. CloudFront 업데이트 도메인이 정해지면 `EXPO_PUBLIC_UPDATES_URL`도 설정하며, 그전에는 `app.config.ts`의 placeholder URL을 쓴다.

## 실행

```bash
pnpm --filter mobile dev
```

개발 빌드는 다음 명령으로 실행한다.

```bash
cd apps/mobile
pnpm exec expo run:ios
pnpm exec expo run:android --device sleepthera_test
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

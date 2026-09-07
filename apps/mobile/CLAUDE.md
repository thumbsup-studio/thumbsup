# 모바일 앱 작업 규약

- Expo SDK와 React Native 버전은 `package.json`에 정확히 고정한다. SDK를 올린 뒤에는 `npx expo install --check`와 `npx expo-doctor`를 함께 실행한다.
- `APP_ENV`와 `EXPO_PUBLIC_API_URL`을 반드시 설정한다. staging·production 빌드의 업데이트 채널은 `APP_ENV`와 일치해야 한다.
- `ios/`와 `android/`는 CNG 산출물이므로 커밋하지 않는다. 네이티브 설정은 Expo config plugin으로 관리한다.
- 스타일은 NativeWind와 `@thumbsup/tokens/nativewind-v4` 프리셋을 사용한다. 토큰에 있는 값을 임의의 색상으로 다시 만들지 않는다.
- 라우트는 `src/app` 아래 expo-router 파일 규칙을 따른다. 앱 루트의 `SafeAreaProvider`와 splash 수명 주기를 유지한다.
- 작업을 마치기 전에 `pnpm --filter mobile typecheck`, `lint`, `test`, `prebuild:check`, `npx expo-doctor`를 실행한다.

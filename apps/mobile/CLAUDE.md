# 모바일 앱 작업 규약

모바일 작업이 처음이라면 `mobile-onboarding` 스킬을 먼저 읽는다. 로컬 실행 절차는 `mobile-local-dev` 스킬이다.

## 개발 문서

- [로컬 개발](./docs/local-dev.md): 환경 설정, dev-client 설치, 기기별 네트워크 연결
- [빌드 파이프라인](./docs/build-pipeline.md): 현재 CI·PR 번들 흐름과 예정된 배포
- [서명 자격증명 운영](../../docs/mobile/signing-credentials.md): Android·Apple 자격증명 생성, 보관, 회전, 복구
- [staging QA](./docs/staging-qa.md): PR 채널 선택기 사용법과 복구 절차

## 로컬 명령

| 명령 | 용도 |
| --- | --- |
| `pnpm bootstrap` | Node.js·pnpm·Watchman을 확인하고 의존성과 `.env.local`을 준비한다. |
| `pnpm diagnose [android\|ios]` | 네이티브 도구, 기기, 포트 8081, API 도달성을 진단한다. 플랫폼을 주면 그 플랫폼만 필수로 본다. |
| `pnpm dev:install android` | 배포된 dev-client 또는 로컬 Android dev 빌드를 설치한다. |
| `pnpm dev:install ios` | 배포된 iOS 시뮬레이터용 dev-client를 설치한다. |
| `pnpm dev` | dev-client용 Metro를 실행한다. |

`pnpm setup`과 `pnpm doctor`는 pnpm 자체 명령이므로 프로젝트 준비에 사용하지 않는다. 각각 `pnpm bootstrap`과 `pnpm diagnose`를 쓴다.

- Expo SDK와 React Native 버전은 `package.json`에 정확히 고정한다. SDK를 올린 뒤에는 `npx expo install --check`와 `npx expo-doctor`를 함께 실행한다.
- `APP_ENV`와 `EXPO_PUBLIC_API_URL`을 반드시 설정한다. staging·production 빌드의 업데이트 채널은 `APP_ENV`와 일치해야 한다.
- `ios/`와 `android/`는 CNG 산출물이므로 커밋하지 않는다. 네이티브 설정은 Expo config plugin으로 관리한다.
- 스타일은 NativeWind와 `@thumbsup/tokens/nativewind-v4` 프리셋을 사용한다. `#111111` 같은 원시 색상값을 스타일에 직접 쓰지 않는다. 새로 필요한 색은 `@thumbsup/tokens`에 추가한 뒤 토큰으로 참조한다.
- 라우트는 `src/app` 아래 expo-router 파일 규칙을 따른다. 앱 루트의 `SafeAreaProvider`와 splash 수명 주기를 유지한다.
- 작업을 마치기 전에 `pnpm --filter mobile typecheck`, `lint`, `test`, `prebuild:check`, `npx expo-doctor`를 실행한다.

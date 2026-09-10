---
name: mobile-local-dev
description: Thumbs Up 모바일 앱의 로컬 환경을 준비하고 dev-client와 Metro를 실행·진단할 때 사용. 사용자가 "앱 어떻게 띄워", "모바일 로컬 실행", "에뮬레이터에서 앱 켜줘", "Metro 안 떠", "dev-client 설치", "모바일 환경 세팅", "iOS 시뮬레이터에서 앱"이라고 할 때 트리거. release·staging QA에는 사용하지 않는다.
---

# 모바일 로컬 개발

Thumbs Up 모바일 앱의 로컬 개발 절차를 실행할 때 이 스킬을 사용한다. 세부 절차와 기기별 지원 상태의 정본은 [`apps/mobile/docs/local-dev.md`](../../../apps/mobile/docs/local-dev.md)다.

## 실행 순서

레포 루트에서 다음 순서로 실행한다.

```bash
pnpm bootstrap
pnpm diagnose
pnpm dev:install android  # 또는 ios
pnpm dev
```

- `bootstrap`: Node.js·pnpm·Watchman을 확인하고 의존성과 `.env.local`을 준비한다.
- `diagnose`: 네이티브 도구, 연결된 기기, 포트 8081, API 도달성을 확인한다.
- `dev:install`: dev-client를 설치한다. 배포 아티팩트가 없으면 Android는 로컬 빌드로 전환한다.
- `dev`: dev-client용 Metro를 실행한다.

## 자주 막히는 지점

- `pnpm setup`과 `pnpm doctor`는 pnpm 10.11의 내장 명령과 충돌한다. 프로젝트 스크립트인 `pnpm bootstrap`과 `pnpm diagnose`를 사용한다. 특히 `pnpm setup`은 셸 설정을 바꾸므로 실행하지 않는다.
- Expo SDK 57의 iOS 네이티브 빌드에는 Xcode 26.4 이상이 필요하다. 설치된 버전은 `pnpm diagnose`의 `Xcode` 항목으로 확인하고, 특정 머신의 버전을 문서에 적지 않는다. 요구 버전에 못 미칠 때만 `cd apps/mobile && pnpm exec expo start`로 Expo Go를 쓴다.
- Android 에뮬레이터에서 호스트에 접속할 때는 `localhost` 대신 `10.0.2.2`를 쓴다. Metro는 `http://10.0.2.2:8081`, 로컬 API는 `http://10.0.2.2:8080`으로 연결한다.
- Metro의 기본 포트는 8081이다. 충돌이 의심되면 `lsof -nP -iTCP:8081 -sTCP:LISTEN`으로 점유 프로세스를 확인한다.
- `.env.local`의 `EXPO_PUBLIC_API_URL`을 바꿨다면 Metro를 다시 시작한다.

## 검증

```bash
pnpm diagnose
pnpm --filter mobile typecheck
pnpm --filter mobile lint
pnpm --filter mobile test
pnpm --filter mobile prebuild:check
```

`diagnose` 결과에서 JDK·Android SDK·포트 8081·API 항목이 통과하는지 확인한다. 기기에서 앱을 띄울 때는 정본 문서의 네트워크 표와 검증 상태를 확인하고, 실기기에서 확인하지 않은 절차를 검증됐다고 보고하지 않는다.

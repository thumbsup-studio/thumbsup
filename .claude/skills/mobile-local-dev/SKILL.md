---
name: mobile-local-dev
description: Thumbs Up 모바일 앱의 로컬 환경을 준비하고 dev-client와 Metro를 실행·진단할 때 사용. 사용자가 "앱 어떻게 띄워", "모바일 로컬 실행", "에뮬레이터에서 앱 켜줘", "Metro 안 떠", "dev-client 설치", "모바일 환경 세팅", "iOS 시뮬레이터에서 앱"이라고 할 때 트리거. release·staging QA에는 사용하지 않는다.
---

# 모바일 로컬 개발

Thumbs Up 모바일 앱의 로컬 개발 절차를 실행할 때 이 스킬을 사용한다. 세부 절차와 기기별 지원 상태의 정본은 [`apps/mobile/docs/local-dev.md`](../../../apps/mobile/docs/local-dev.md)다.

모바일 작업이 처음이라면 `mobile-onboarding` 스킬을 먼저 읽는다 — 툴체인 준비 분기, 앱 실행 방식 세 가지, 코드 구조를 다룬다. 이 스킬은 그 다음의 실행 절차다.

## 준비물

앱이 처음 뜨는 머신이면 [정본 문서의 "준비물"](../../../apps/mobile/docs/local-dev.md#준비물)을 먼저 채운다. Android와 iOS 중 **한쪽만** 갖추면 된다. Android는 JDK 17 이상과 Android SDK·AVD가, iOS는 Xcode 26.4 이상과 시뮬레이터가 필요하다. 특정 머신의 버전이나 AVD 이름을 문서나 보고에 적지 않는다.

## 실행 순서

레포 루트에서 다음 순서로 실행한다.

```bash
pnpm bootstrap
pnpm diagnose android   # 또는 pnpm diagnose ios
pnpm dev:install android
pnpm dev
```

- `bootstrap`: Node.js·pnpm·Watchman을 확인하고 의존성과 `.env.local`을 준비한다.
- `diagnose`: 네이티브 도구, 연결된 기기, 포트 8081, API 도달성을 확인한다. 플랫폼을 인자로 주면 그 플랫폼 도구만 필수로 판정하고, 인자가 없으면 두 플랫폼 중 한쪽이라도 완비됐는지 본다. 실패 항목에는 `→` 조치 한 줄이 붙는다.
- `dev:install`: dev-client를 설치한다. 배포 아티팩트가 없으면 로컬 빌드로 전환한다. 기기가 먼저 연결돼 있어야 한다.
- `dev`: dev-client용 Metro를 실행한다.

## 자주 막히는 지점

- `pnpm setup`과 `pnpm doctor`는 pnpm 10.11의 내장 명령과 충돌한다. 프로젝트 스크립트인 `pnpm bootstrap`과 `pnpm diagnose`를 사용한다. 특히 `pnpm setup`은 셸 설정을 바꾸므로 실행하지 않는다.
- `bootstrap`이 만드는 `.env.local`은 **운영 API를 가리킨다.** 쓰기 요청이 운영 DB에 남으므로 더미 계정만 쓰고, 반복 테스트는 `thumbsup-local-server`로 로컬 서버를 띄워서 한다.
- Android 빌드가 Gradle 단계에서 깨지면 `java -version`을 확인한다. JDK 17 미만이면 실패한다. 서버와 달리 JDK가 자동으로 내려받아지지 않는다.
- Expo SDK 57의 iOS 네이티브 빌드에는 Xcode 26.4 이상이 필요하다. `pnpm diagnose ios`가 하한과 비교해 판정한다. 요구 버전에 못 미칠 때만 `cd apps/mobile && pnpm exec expo start`로 Expo Go를 쓴다.
- 네이티브 의존성이나 `app.config.ts`가 바뀌면 dev-client를 다시 설치한다. JavaScript만 바뀌었으면 Metro 재시작으로 충분하다.
- Android 에뮬레이터에서 호스트에 접속할 때는 `localhost` 대신 `10.0.2.2`를 쓴다. Metro는 `http://10.0.2.2:8081`, 로컬 API는 `http://10.0.2.2:8080`으로 연결한다.
- Metro의 기본 포트는 8081이다. 충돌이 의심되면 `lsof -nP -iTCP:8081 -sTCP:LISTEN`으로 점유 프로세스를 확인한다.
- `.env.local`의 `EXPO_PUBLIC_API_URL`을 바꿨다면 Metro를 다시 시작한다.

## 검증

```bash
pnpm diagnose android   # 또는 ios
pnpm --filter mobile typecheck
pnpm --filter mobile lint
pnpm --filter mobile test
pnpm --filter mobile prebuild:check
```

`diagnose`에서 필수 항목 실패가 0개인지 확인한다. 기기에서 앱을 띄울 때는 정본 문서의 네트워크 표와 검증 상태를 확인하고, 실기기에서 확인하지 않은 절차를 검증됐다고 보고하지 않는다.

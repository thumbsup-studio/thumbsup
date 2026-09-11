---
name: mobile-onboarding
description: 백엔드 개발자가 apps/mobile(Expo·React Native) 작업을 맡을 때의 온보딩 지도. 네이티브 툴체인 준비 분기, Expo Go·dev-client·release 빌드의 구분, 코드 4층 구조와 최소 완전 예제, React가 처음인 사람이 걸리는 지점, 단계별 스킬 라우팅을 안내한다. 규칙 정본은 apps/mobile/CLAUDE.md와 각 문서 링크로 참조. 사용자가 "모바일 처음인데", "앱 어떻게 띄워", "RN 처음이야", "모바일 화면 추가해야 해", "서버만 하다가 앱 맡았어"라고 할 때 트리거.
---

# mobile-onboarding — 백엔드 개발자를 위한 모바일 개발 지도

서버만 하던 사람이 `apps/mobile/` 이슈를 맡았을 때 "무엇을 준비하고, 어디에 코드를 쓰고, 어떤 스킬로 작업하는가". 웹 쪽 같은 지도는 `frontend-onboarding`에 있다. 규칙의 **정본은 `apps/mobile/CLAUDE.md`와 각 문서** — 여기서 규칙을 다시 쓰지 않는다.

Expo SDK 57 / React Native 0.86 / expo-router / NativeWind. `ios/`와 `android/`는 커밋되지 않는다(Expo CNG가 필요할 때 생성).

## 웹과 다른 점부터

모바일은 웹과 달리 **머신에 네이티브 툴체인이 있어야 앱이 뜬다.** `pnpm install` 후 브라우저를 여는 것으로 끝나지 않는다. 이게 가장 큰 진입 장벽이고, 대부분의 막힘이 여기서 생긴다.

준비물 목록과 설치 절차의 정본은 [`apps/mobile/docs/local-dev.md`의 "준비물"](../../../apps/mobile/docs/local-dev.md#준비물)이다. 요지만:

- **Android와 iOS 중 한쪽만 갖추면 된다.** 둘 다 필요하지 않다.
- Android를 고르면 **JDK 17 이상**이 필요하다. 서버는 Gradle이 JDK를 자동으로 받아주지만 앱 빌드는 안 받아준다 — 서버 경험에서 오는 가장 흔한 오해다.
- iOS를 고르면 Xcode 26.4 이상이 필요하다. 못 맞추면 Android로 가는 게 빠르다.
- `pnpm diagnose android` 또는 `pnpm diagnose ios`로 자기 플랫폼만 검사한다. 실패 항목마다 조치 한 줄이 나온다.

```bash
pnpm bootstrap
pnpm diagnose android     # 또는 ios
pnpm dev:install android  # 첫 로컬 빌드는 오래 걸리고 디스크를 많이 쓴다
pnpm dev
```

⚠️ `pnpm bootstrap`이 만드는 `.env.local`은 **운영 API를 가리킨다.** 회원가입·저장이 운영 DB에 남는다. 더미 계정만 쓰고, 쓰기를 반복 테스트하려면 `thumbsup-local-server` 스킬로 로컬 서버를 띄워 주소를 바꾼다.

## 앱을 띄우는 방식이 세 가지다 — 가장 헷갈리는 지점

| 방식 | 무엇인가 | 언제 쓰나 |
| --- | --- | --- |
| **dev-client** | `expo-dev-client`를 넣어 이 프로젝트 전용으로 빌드한 debug 앱 | **평소 개발은 전부 이것.** `pnpm dev:install`로 한 번 설치하고, 이후엔 Metro만 띄워 JS를 갈아 끼운다 |
| **Expo Go** | App Store에서 받는 범용 Expo 런타임 | 네이티브 빌드를 못 할 때의 임시 우회. Xcode 하한에 못 미칠 때 JavaScript 화면만 확인하는 용도 |
| **staging·release 바이너리** | CI가 만드는 서명된 빌드 | QA·배포용. 로컬 개발에 쓰지 않는다 ([staging QA](../../../apps/mobile/docs/staging-qa.md)) |

**생성된 `android/`에서 `./gradlew`를 직접 부르지 않는다.** Gradle 경험이 있으면 습관적으로 그러기 쉬운데, `.env.local`을 빌드에 넘겨주는 것이 Expo CLI라서 직접 호출하면 설정 오류로 깨진다. `pnpm dev:install`을 쓴다.

기억할 규칙 하나: **네이티브 의존성이 바뀌면 dev-client를 다시 설치해야 하고, JavaScript만 바뀌면 Metro 재시작으로 충분하다.** `package.json`에 네이티브 모듈을 추가했거나 `app.config.ts`를 건드렸다면 `pnpm dev:install`부터 다시 한다.

## 코드가 어디 있나

`apps/mobile/src/` 아래 네 곳이다.

| 디렉터리 | 역할 | 서버 비유 |
| --- | --- | --- |
| `src/app/` | expo-router 라우트. **파일 경로가 곧 화면 주소**다 | Controller 껍데기 |
| `src/features/` | 화면 구현체. 실제 코드 대부분 | Service + View |
| `src/components/` | 여러 화면이 공유하는 조각 | 공용 유틸 |
| `src/lib/` | API 세션, 라우트 파라미터, 연결 상태 같은 전역 인프라 | 설정·인터셉터 |

`src/app/` 파일명 규칙만 익히면 라우팅은 끝난다.

- `_layout.tsx` — 그 폴더 하위를 감싸는 껍데기. 주소에 나타나지 않는다
- `(tabs)`, `(auth)` — **괄호는 그룹**이라 주소에 포함되지 않는다. `(tabs)/profile.tsx`의 주소는 `/profile`
- `[number].tsx` — 동적 세그먼트. `useLocalSearchParams()`로 받는다

## 최소 완전 예제 — `briefing` 화면

**새 화면은 이 네 파일을 열어 그대로 모사한다.**

| 파일 | 역할 |
| --- | --- |
| `src/app/briefing.tsx` | 라우트 어댑터 9줄. URL 파라미터를 검증하고 props로 넘긴다. 잘못된 값이면 `<Redirect>` |
| `src/features/briefing/briefing-screen.tsx`의 `BriefingScreen` | 데이터 로딩, 로딩·에러 분기, 다음 화면으로 이동 |
| 같은 파일의 `BriefingScreenView` | 순수 렌더. props로 받은 것만 그린다 |
| `src/features/briefing/briefing-screen.test.tsx` | `BriefingScreenView`에 props를 주입해 테스트. 네트워크 모킹이 필요 없다 |

컨테이너와 뷰를 **한 파일에 두 개 함수로** 나누는 게 이 레포의 관례다. `briefing`·`course`·`home`·`play`·`follow-up`·`insight`가 따른다. `profile`과 `history`는 아직 안 나뉘어 있으니 **예제로 삼지 않는다.**

화면 하나 추가 = 신규 2파일(`src/app/이름.tsx`, `src/features/이름/이름-screen.tsx`) + `src/app/_layout.tsx`의 `<Stack.Protected>` 안에 `<Stack.Screen name="이름" />` 한 줄.

## 서버 개발자가 예상과 다르게 느낄 것

- **API 클라이언트는 앱 안이 아니라 `packages/api`에 있다.** 웹과 모바일이 같은 것을 쓴다. 화면에서는 `useApi()`로 받은 `client`의 메서드를 부른다. envelope 언랩, Bearer 부착, 401 재발급, 타임아웃이 전부 그 안에서 처리되므로 **`fetch()`를 직접 쓰지 않는다.**
- **웹처럼 feature마다 `api.ts`·`types.ts`를 두지 않는다.** 타입은 `@thumbsup/api`에서 바로 가져온다. 웹 구조를 그대로 옮기면 어긋난다.
- **토큰은 `expo-secure-store`에 저장된다.** 웹의 localStorage와 달리 비동기다.
- **`EXPO_PUBLIC_API_URL`이 없으면 앱이 시작 시점에 예외를 던진다.** 웹처럼 기본값 폴백이 없다. 처음 앱을 띄울 때 제일 먼저 만나는 에러가 보통 이것이다.
- **인증 게이트는 래퍼 컴포넌트가 아니라 라우터가 한다.** `src/app/_layout.tsx`의 `<Stack.Protected guard={...}>`가 세션 상태에 따라 화면 묶음 자체를 바꾼다. 세션은 3상태(`restoring`·`authenticated`·`unauthenticated`)이고 `restoring` 동안 스피너가 뜬다.
- **범용 `Button`·`Card`·`Input` 공용 컴포넌트가 모바일엔 없다.** `packages/ui-web`은 이름 그대로 웹 전용이라 못 쓴다. 있는 건 `src/components/screen-state.tsx`(로딩·에러·빈 상태)와 `icons.tsx`뿐이고, 나머지는 화면마다 NativeWind 클래스를 인라인으로 쓴다. 토큰 클래스명(`bg-primary`, `text-ink` 등)은 웹과 같다.

## React Native가 첫 React일 때 걸리는 것

브라우저 상식이 통하지 않는 지점만 모았다. 세부는 코드의 기존 화면을 보고 맞춘다.

- `div`·`span`이 없다. 그리고 **모든 문자열은 `<Text>` 안에 있어야 한다.** 화살표 한 글자도 예외가 아니다. 맨 문자열을 `<View>`에 두면 런타임 에러다.
- **스크롤이 자동이 아니다.** 넘치면 잘린다. `ScrollView`를 직접 감싸고, 긴 목록은 `FlatList`를 쓴다.
- `ScrollView`는 className이 둘이다. `className`은 뷰포트, `contentContainerClassName`은 내용물 — 패딩과 간격은 후자에 넣는다.
- **flex 기본 방향이 세로다.** 가로 배치는 매번 `flex-row`를 붙인다.
- CSS 상속이 없다. 부모에 글자색을 줘도 자식 `Text`에 내려가지 않는다.
- 노치와 홈 인디케이터를 직접 피해야 한다. `SafeAreaView`의 `edges`로 어느 변을 피할지 화면마다 고른다.
- 키보드가 입력창을 가린다. `KeyboardAvoidingView`로 감싸고 iOS·Android 동작이 달라 분기한다.
- `<a>`도 `<button>`도 없다. `Pressable`에 `accessibilityRole`로 역할을 붙인다. **테스트가 이 prop으로 요소를 찾으므로 빼먹으면 테스트가 깨진다.**
- 화면 이동은 명령형 `router.push()`다. **params 값은 전부 문자열이어야 해서 `String()` 캐스팅이 필요하고**, 받는 쪽은 `string | string[] | undefined`를 다시 파싱한다(`src/lib/navigation/route-params.ts`).
- **화면을 벗어나도 진행 중인 요청이 멈추지 않는다.** 기존 화면들은 요청 id 카운터로 늦게 온 응답을 버린다. 새 화면에서도 그 패턴을 따르지 않으면 "뒤로 갔다 오면 화면이 이상해지는" 버그가 생긴다.
- 오프라인을 앱이 직접 감지한다. 요청 전에 `useConnectivity()`로 막는 화면이 있다.

## 테스트는 두 종류가 순서대로 돈다

`pnpm --filter mobile test`는 vitest와 jest를 이어서 실행한다.

- **vitest** — 앱 설정과 `scripts/` 아래 Node 스크립트
- **jest** — `src/` 아래 화면·훅·로직. `@testing-library/react-native`를 쓴다(웹의 `@testing-library/react`와 **패키지가 다르다**)

화면 테스트를 쓴다면 jest 쪽이고, 순수 뷰 컴포넌트에 props를 주입하는 방식이 기존 관례다. `expo-router`는 거의 모든 테스트에서 `jest.mock`으로 갈아 끼운다.

## 작업 순서

1. **이슈 확인·분리** — 앱과 서버 작업은 티켓을 나눈다(CONTRIBUTING §4). 서버 응답에 필요한 데이터가 없으면 서버 이슈를 따로 끊고 **응답 스키마부터 확정**한다.
2. **브랜치** `<type>/<이슈번호>-<슬러그>` — main 직접 커밋 금지.
3. **스킬 로드** — 아래 라우팅 표.
4. **구현** — `briefing` 패턴 모사. 스타일·토큰 규칙은 `apps/mobile/CLAUDE.md`.
5. **검증** — `verify-app`의 모바일 게이트 4종 전부.
6. **커밋·PR** — `commit` 스킬 → `pr` 스킬(`Closes #이슈` 필수, Squash merge).

## 스킬 라우팅

| 상황 | 로드할 스킬 |
| --- | --- |
| 앱을 띄우거나 로컬 환경이 막힐 때 | `mobile-local-dev` (필수) |
| 완료 보고 전 | `verify-app` — typecheck→lint→test→prebuild:check |
| 로컬 서버가 필요할 때 | `thumbsup-local-server` |
| `apps/web` 작업으로 옮겨갈 때 | `frontend-onboarding` |

`frontend-api`·`design-system`·`visual-qa`·`next-best-practices`는 **web 전용이라 모바일에 적용하지 않는다.** 모바일 스타일 규칙의 정본은 `apps/mobile/CLAUDE.md`다.

## 막힐 때

| 증상 | 먼저 확인할 것 |
| --- | --- |
| 앱 시작하자마자 `EXPO_PUBLIC_API_URL` 예외 | `.env.local`이 있는지. `pnpm bootstrap`이 만든다 |
| Android 빌드가 Gradle에서 깨짐 | `java -version`이 17 이상인지. 여러 JDK가 있으면 `JAVA_HOME`이 가리키는 쪽이 쓰인다 |
| `[mobile config] APP_ENV must be ...` | `android/`에서 `./gradlew`를 직접 불렀는지. `.env.local`을 넘겨주는 건 Expo CLI라 `pnpm dev:install android`로 실행해야 한다 |
| 에뮬레이터에서 API가 안 붙음 | localhost 대신 `10.0.2.2`를 썼는지. 바꿨으면 Metro 재시작 |
| 네이티브 모듈을 추가했는데 앱이 죽음 | dev-client를 다시 설치했는지 |
| 기기가 안 보임 | `pnpm diagnose android`의 기기 항목, `adb devices` |
| 포트 충돌 | `lsof -nP -iTCP:8081 -sTCP:LISTEN` |
| 테스트에서 요소를 못 찾음 | `accessibilityRole`을 붙였는지 |

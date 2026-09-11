# 모바일 로컬 개발

macOS에서 백엔드 개발자가 Thumbs Up 앱을 로컬 서버와 연결하는 절차다. 2026년 9월 8일 기준 iOS 시뮬레이터와 Android 에뮬레이터에서 확인했으며, 실기기 절차는 아직 검증하지 못했다.

## 준비물

앱을 처음 띄우는 머신이면 여기부터 읽는다. Android와 iOS 가운데 **쓸 플랫폼 하나만** 갖추면 앱을 띄울 수 있다.

| 준비물 | 필요한 곳 | 설치·확인 |
| --- | --- | --- |
| Node.js 22 이상 | 공통 | `.nvmrc`가 `22`다. nvm을 쓴다면 `nvm use` |
| pnpm 10 | 공통 | `corepack enable`이면 `packageManager` 필드로 자동 선택된다 |
| JDK 17 이상 | Android | `brew install --cask temurin@17` 후 `JAVA_HOME`을 그 경로로 지정 |
| Android Studio + Android SDK | Android | SDK Manager에서 API 35 SDK와 Platform-Tools를 받는다 |
| Android 가상 기기(AVD) 1대 | Android | Device Manager에서 만든다. 이름은 자유 |
| Xcode 26.4 이상 | iOS | App Store에서 설치 후 `xcode-select --install` |
| iOS 시뮬레이터 런타임 | iOS | Xcode를 한 번 실행하고 Settings의 Components에서 받는다 |
| Watchman | 선택 | `brew install watchman`. 파일 변경 감지가 안정된다 |

### JDK는 직접 설치해야 한다

서버(`server/`)는 Gradle toolchain이 JDK를 자동으로 내려받아서 Java 설치가 필요 없다([FE→서버 가이드](../../../docs/frontend-server-dev-guide.md)). **Android 앱 빌드는 그렇지 않다.** 생성되는 Gradle 래퍼가 Gradle 9.x를 쓰고 이 버전은 JDK 17 이상에서만 동작하므로, 머신에 JDK가 직접 깔려 있어야 한다. JDK 8이나 11만 있으면 빌드가 Gradle 단계에서 실패한다.

### Android SDK 경로 설정

Android Studio는 SDK를 기본적으로 `~/Library/Android/sdk`에 둔다. 셸 설정 파일에 다음을 추가한다.

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

`ANDROID_HOME`을 설정하지 않아도 `pnpm diagnose`는 위 기본 경로를 찾아본다. 다른 위치에 설치했다면 반드시 설정한다.

### AVD 만들기

Android Studio의 **Device Manager → Create Virtual Device**에서 아무 phone 프로필이나 고르고, 시스템 이미지는 **API 35(Android 15)** 를 받는다. 앱의 `compileSdk`·`targetSdk`가 35라서 그보다 낮은 이미지는 피한다. 이름은 무엇이든 상관없고 문서의 어떤 절차도 특정 AVD 이름에 의존하지 않는다.

만든 AVD는 Device Manager에서 실행하거나 터미널에서 띄운다.

```bash
emulator -list-avds          # 만들어 둔 이름 확인
emulator -avd <이름> &       # 실행
adb devices                  # device로 뜨는지 확인
```

## 빠른 시작

레포 루트에서 다음 명령을 실행한다.

```bash
pnpm bootstrap
pnpm diagnose android   # 또는 pnpm diagnose ios
pnpm dev:install android
pnpm dev
```

`pnpm bootstrap`은 Node.js 22 이상, pnpm 10, Watchman 설치 여부를 표시하고 `pnpm install --frozen-lockfile`을 실행한다. `apps/mobile/.env.local`이 없으면 `.env.example`을 복사하며, 이미 있는 파일은 덮어쓰지 않는다.

⚠️ **그렇게 만들어진 `.env.local`의 `EXPO_PUBLIC_API_URL`은 운영 API(`https://thumbsup-api.duckdns.org`)를 가리킨다. 운영 DB에 그대로 쓰인다.** 회원가입·저장 같은 쓰기 동작은 개발용 더미 계정으로만 하고 실명·실이메일을 넣지 않는다. 쓰기를 반복 테스트할 때는 아래 [로컬 백엔드 실행](#로컬-백엔드-실행)으로 바꿔서 한다. 앱은 이 값이 비어 있으면 시작 시점에 예외를 던지므로 값을 지우면 안 된다.

`pnpm setup`과 `pnpm doctor`는 pnpm 10.11의 내장 명령이며 프로젝트 스크립트보다 먼저 실행된다. 앱 준비에는 각각 `pnpm bootstrap`과 `pnpm diagnose`를 사용한다. 특히 `pnpm setup`은 셸 설정 파일을 수정하므로 실행하지 않는다.

### `pnpm diagnose` 읽는 법

`pnpm diagnose`는 JDK 버전, Android SDK, AVD와 연결된 기기, Xcode 버전, iOS 시뮬레이터, 포트 8081, `EXPO_PUBLIC_API_URL` 도달성, Watchman을 확인한다. 실패한 항목에는 `→`로 시작하는 조치 한 줄이 함께 나온다.

플랫폼을 인자로 주면 판정 기준이 달라진다.

| 실행 | 필수로 보는 것 |
| --- | --- |
| `pnpm diagnose android` | JDK 17 이상, Android SDK, AVD, 연결된 기기 |
| `pnpm diagnose ios` | Xcode 26.4 이상, iOS 시뮬레이터 |
| `pnpm diagnose` | 포트·API에 더해 **두 플랫폼 중 최소 한쪽**이 완비됐는지 |

Android만 쓸 계획이라면 Xcode가 없어도 `pnpm diagnose android`는 통과한다. 반대도 같다. 포트 8081과 `EXPO_PUBLIC_API_URL`은 어느 경우에도 필수다.

포트 8081 검사는 **Metro가 이미 떠 있으면 통과한다.** 점유자가 Metro인지 `/status` 응답으로 확인하고, Metro가 아닌 프로세스가 물고 있을 때만 실패로 판정한다. 개발 중에 진단을 다시 돌려도 Metro를 내릴 필요가 없다.

## dev-client 설치

dev-client 워크플로우가 S3에 배포되려면 `MOBILE_ARTIFACTS_BUCKET`과 `MOBILE_BINARY_PUBLISH_ROLE_ARN` 등록이 필요하다. `MOBILE_DEV_CLIENT_BASE_URL`이 아직 없다면 `pnpm dev:install android`는 `expo run:android`로 로컬 빌드를 만들어 설치한다.

```bash
pnpm dev:install android
```

로컬 빌드는 **에뮬레이터나 실기기가 이미 연결돼 있어야** 한다. `pnpm diagnose android`의 `Android 에뮬레이터/기기` 항목이 통과하는지 먼저 확인한다.

⚠️ **생성된 `android/`에서 `./gradlew`를 직접 부르지 않는다.** `app.config.ts`가 `APP_ENV`와 `EXPO_PUBLIC_API_URL`을 프로세스 환경변수에서 읽는데, `.env.local`을 읽어 넘겨주는 건 Expo CLI다. Gradle을 직접 호출하면 빌드 막바지의 `createDebugUpdatesResources` 단계에서 `[mobile config] APP_ENV must be development, staging, or production`으로 깨진다. Gradle에 익숙한 사람이 습관적으로 빠지는 함정이다. 꼭 직접 불러야 한다면 두 값을 셸에 내보낸 뒤 실행한다.

첫 Android 로컬 빌드는 Gradle 배포본과 의존성을 모두 내려받으므로 오래 걸리고 디스크를 많이 쓴다. 캐시가 빈 상태에서 측정했을 때 `~/.gradle`이 약 4.7GB까지 커졌고 debug APK 자체도 약 270MB였다. 디스크를 6GB 이상 비워 두고 시작한다. 소요 시간은 머신에 따라 크게 달라지지만 십여 분을 잡는 게 안전하고, 두 번째 빌드부터는 캐시를 재사용해 훨씬 빠르다. NDK는 앱이 네이티브 소스를 직접 빌드하지 않으면 내려받지 않는다.

S3 배포를 활성화한 뒤에는 `.env.local`이 아니라 명령을 실행하는 셸에 아티팩트 URL을 설정한다. URL은 `binaries/dev-client/<runtimeVersion>`까지 포함해야 한다. 스크립트가 그 아래의 `android/latest.apk` 또는 `ios/latest.zip`을 내려받아 설치한다.

```bash
MOBILE_DEV_CLIENT_BASE_URL=https://<아티팩트-호스트>/binaries/dev-client/0.1.0 pnpm dev:install android
MOBILE_DEV_CLIENT_BASE_URL=https://<아티팩트-호스트>/binaries/dev-client/0.1.0 pnpm dev:install ios
```

iOS URL에는 압축을 풀었을 때 최상위에 `.app` 하나가 있는 ZIP이 필요하다. iOS 실기기 staging 배포는 TestFlight 내부 테스트를 사용한다.

`MOBILE_DEV_CLIENT_BASE_URL`이 없으면 `dev:install`은 로컬 네이티브 빌드로 대체한다. Android는 `expo run:android`, iOS는 `expo run:ios`를 쓴다.

Expo SDK 57의 iOS 네이티브 빌드에는 Xcode 26.4 이상이 필요하다. 특정 머신의 버전을 여기에 적지 않는다 — `pnpm diagnose ios`의 `Xcode` 항목으로 확인한다. 요구 버전에 못 미치면 아래처럼 Expo Go로 JavaScript 화면만 검증하고, 네이티브 빌드는 Xcode를 올린 뒤 다시 확인한다.

```bash
cd apps/mobile
pnpm exec expo start
```

## Metro 실행

dev-client를 설치한 뒤 레포 루트에서 Metro를 띄운다.

```bash
pnpm dev
```

이 명령은 `expo start --dev-client`를 실행한다. 같은 LAN의 실기기에서 접속하려면 다음 명령으로 연결 방식을 명시한다.

```bash
pnpm --filter mobile dev -- --lan
```

## 로컬 백엔드 실행

서버 실행에 필요한 AWS `thumbsup` 프로필과 `/thumbsup/local/*` SSM 접근 권한을 먼저 준비한다. 시크릿 값은 문서나 셸 출력에 남기지 않는다.

```bash
cd server
export AWS_PROFILE=thumbsup
export AWS_REGION=ap-northeast-2
docker compose up -d mysql
./gradlew bootRun
```

다른 터미널에서 상태를 확인한다.

```bash
curl -fsS http://localhost:8080/actuator/health
```

서버가 준비되면 기기에 맞춰 `apps/mobile/.env.local`의 `EXPO_PUBLIC_API_URL`을 바꾸고 Metro를 다시 시작한다. 실기기에서 LAN IP로 붙을 때 Spring Boot는 `0.0.0.0`에서 요청을 받아야 한다. 기본 설정이 달라졌다면 `SERVER_ADDRESS=0.0.0.0 ./gradlew bootRun`으로 실행한다.

## 기기별 네트워크

`<LAN_IP>`는 Mac의 Wi-Fi 주소다. `ipconfig getifaddr en0`으로 확인할 수 있다.

| 대상 | Metro 연결 | `.env.local`의 API URL | 준비 명령 | 검증 상태 |
| --- | --- | --- | --- | --- |
| iOS 시뮬레이터 | `http://localhost:8081` | `http://localhost:8080` | Expo Go를 열고 Metro 안내에 따라 접속 | Expo Go로 검증 |
| iOS 실기기 | `pnpm --filter mobile dev -- --lan` 후 `http://<LAN_IP>:8081` | `http://<LAN_IP>:8080` | Mac과 같은 LAN, 서버 `0.0.0.0` 바인딩 | 미검증 |
| Android 에뮬레이터 | dev-client에서 `http://10.0.2.2:8081` | `http://10.0.2.2:8080` | Device Manager에서 만든 AVD 실행 | 검증 |
| Android 실기기(LAN) | `pnpm --filter mobile dev -- --lan` 후 `http://<LAN_IP>:8081` | `http://<LAN_IP>:8080` | 같은 LAN, 서버 `0.0.0.0` 바인딩 | 미검증 |
| Android 실기기(USB) | `http://localhost:8081` | `http://localhost:8080` | 아래 `adb reverse` 두 줄 실행 | 미검증 |

USB 연결은 호스트 포트를 기기의 localhost로 전달한다.

```bash
adb reverse tcp:8081 tcp:8081
adb reverse tcp:8080 tcp:8080
```

환경변수를 바꾸면 Metro를 종료하고 다시 실행해야 번들에 새 API URL이 들어간다. Android 에뮬레이터에서 localhost는 에뮬레이터 자신을 가리키므로 반드시 `10.0.2.2`를 쓴다.

## 종료와 문제 해결

Metro는 `Ctrl+C`로 끝내고 로컬 DB는 다음 명령으로 내린다.

```bash
cd server
docker compose down
```

- 포트 8081 충돌은 `lsof -nP -iTCP:8081 -sTCP:LISTEN`으로 프로세스를 확인한다.
- Android 기기가 보이지 않으면 `adb devices`와 Android Studio Device Manager를 확인한다.
- Android 빌드가 Gradle 단계에서 깨지면 `java -version`이 17 이상인지 본다. 여러 JDK가 깔려 있으면 `JAVA_HOME`이 가리키는 쪽이 쓰인다.
- `[mobile config] APP_ENV must be ...`로 깨졌다면 `./gradlew`를 직접 부른 것이다. `pnpm dev:install android`로 실행한다.
- API 진단이 실패하면 `.env.local`의 주소, 서버 health, 방화벽을 순서대로 확인한다.
- 로컬 HTTP 연결이 Android에서 차단되면 생성된 development 네이티브 설정을 확인한다. `ios/`와 `android/`는 CNG 산출물이므로 커밋하지 않는다.

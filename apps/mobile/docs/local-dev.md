# 모바일 로컬 개발

macOS에서 백엔드 개발자가 Thumbs Up 앱을 로컬 서버와 연결하는 절차다. 2026년 9월 8일 기준 iOS 시뮬레이터와 Android 에뮬레이터에서 확인했으며, 실기기 절차는 아직 검증하지 못했다.

## 빠른 시작

레포 루트에서 다음 명령을 실행한다.

```bash
pnpm bootstrap
pnpm diagnose
pnpm dev:install android
pnpm dev
```

`pnpm bootstrap`은 Node.js 22 이상, pnpm 10, Watchman 설치 여부를 표시하고 `pnpm install --frozen-lockfile`을 실행한다. `apps/mobile/.env.local`이 없으면 `.env.example`을 복사하며, 이미 있는 파일은 덮어쓰지 않는다. Watchman은 선택 사항이지만 macOS에서 파일 변경 감지를 안정적으로 쓰려면 설치를 권장한다.

`pnpm setup`과 `pnpm doctor`는 pnpm 10.11의 내장 명령이며 프로젝트 스크립트보다 먼저 실행된다. 앱 준비에는 각각 `pnpm bootstrap`과 `pnpm diagnose`를 사용한다. 특히 `pnpm setup`은 셸 설정 파일을 수정하므로 실행하지 않는다.

`pnpm diagnose`는 JDK, Android SDK, Android AVD와 연결된 기기, Xcode, 설치된 iOS 시뮬레이터, 포트 8081, `EXPO_PUBLIC_API_URL`을 확인한다. JDK·Android SDK·포트·API에 문제가 있으면 종료 코드 1을 반환하고, 기기·Xcode·Watchman이 없으면 경고만 남긴다.

## dev-client 설치

dev-client 배포를 맡은 #350은 아직 구현되지 않았다. 따라서 `MOBILE_DEV_CLIENT_BASE_URL`도 설정되어 있지 않으며, 현재 `pnpm dev:install android`는 `expo run:android`로 로컬 빌드를 만들어 설치한다.

```bash
pnpm dev:install android
```

#350이 배포된 뒤에는 `.env.local`이 아니라 명령을 실행하는 셸에 아티팩트 URL을 설정한다. 스크립트가 Android의 `android/latest.apk` 또는 iOS 시뮬레이터의 `ios/latest.zip`을 내려받아 설치한다.

```bash
MOBILE_DEV_CLIENT_BASE_URL=https://<아티팩트-호스트>/dev-client pnpm dev:install android
MOBILE_DEV_CLIENT_BASE_URL=https://<아티팩트-호스트>/dev-client pnpm dev:install ios
```

iOS URL에는 압축을 풀었을 때 최상위에 `.app` 하나가 있는 ZIP이 필요하다. IPA를 실기기에 설치하는 흐름은 #350에서 서명·기기 등록 방식이 결정된 뒤 추가한다.

현재 이 머신의 Xcode는 26.0.1이다. Expo SDK 57의 `expo run:ios`가 컴파일 오류로 끝나므로 iOS 네이티브 빌드는 Xcode 26.4로 업그레이드한 뒤 다시 확인해야 한다. 그전에는 아래처럼 Expo Go를 사용한다.

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

서버가 준비되면 기기에 맞춰 `apps/mobile/.env.local`의 `EXPO_PUBLIC_API_URL`을 바꾸고 Metro를 다시 시작한다. 실기기에서 LAN IP로 붙일 때 Spring Boot는 `0.0.0.0`에서 요청을 받아야 한다. 기본 설정이 달라졌다면 `SERVER_ADDRESS=0.0.0.0 ./gradlew bootRun`으로 실행한다.

## 기기별 네트워크

`<LAN_IP>`는 Mac의 Wi-Fi 주소다. `ipconfig getifaddr en0`으로 확인할 수 있다.

| 대상 | Metro 연결 | `.env.local`의 API URL | 준비 명령 | 검증 상태 |
| --- | --- | --- | --- | --- |
| iOS 시뮬레이터 | `http://localhost:8081` | `http://localhost:8080` | Expo Go를 열고 Metro 안내에 따라 접속 | Expo Go로 검증 |
| iOS 실기기 | `pnpm --filter mobile dev -- --lan` 후 `http://<LAN_IP>:8081` | `http://<LAN_IP>:8080` | Mac과 같은 LAN, 서버 `0.0.0.0` 바인딩 | 미검증 |
| Android 에뮬레이터 | dev-client에서 `http://10.0.2.2:8081` | `http://10.0.2.2:8080` | `sleepthera_test` AVD 실행 | 검증 |
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
- API 진단이 실패하면 `.env.local`의 주소, 서버 health, 방화벽을 순서대로 확인한다.
- 로컬 HTTP 연결이 Android에서 차단되면 생성된 development 네이티브 설정을 확인한다. `ios/`와 `android/`는 CNG 산출물이므로 커밋하지 않는다.

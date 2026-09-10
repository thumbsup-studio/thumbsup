# Mobile Maestro E2E

이 디렉터리는 웹 마이그레이션 기준선의 사용자 라우트 12개를 iOS 시뮬레이터와 Android 에뮬레이터에서 확인한다. 정상 경로는 로컬 Spring Boot 서버와 Flyway 코스 시드를 그대로 사용하며, 테스트에서 `testID`를 쓰거나 정상 API를 모킹하지 않는다.

## 구성

- `config.yaml`: `${APP_ID}`를 받는 Maestro 워크스페이스 설정
- `flows/atoms`: 로그인, 홈 진입, 한 문제 풀이, 로그아웃 원자 플로우
- `flows/routes`: 사용자 라우트 12개의 독립 플로우
- `flows/mobile-native`: 가상 기기에서 실행하는 모바일 고유 회귀
- `flows/device-only`: 연결된 실기기에서만 확인하는 항목
- `generators/play-path.mjs`: 기준 상태 모델에서 최대 6개의 play 경로와 실행 플로우 생성
- `scripts/seed-account.mjs`: 공개 signup API를 이용한 멱등 계정 생성
- `scripts/run-rotation.mjs`: Android 회전 전후 Maestro 검증 래퍼

선택자는 접근성 라벨, 접근성 role이 만든 네이티브 의미, 화면에 보이는 text만 사용한다. 로그인 화면처럼 레이블과 입력 필드가 모두 `이메일`, `비밀번호`로 노출되는 경우에는 문구를 바꾸지 않고 `index: 1`로 입력 필드를 고른다.

## 로컬 준비와 실행

Maestro 2.1.0을 기준으로 한다. 앱은 development dev-client가 아니라 staging 프로파일의 Release 구성으로 빌드해야 한다. dev-client의 우측 상단 플로팅 메뉴가 의견 보내기 시트의 닫기 버튼과 겹쳐 실제 E2E 동작을 방해하기 때문이다.

서버는 `server/docker-compose.yml`의 MySQL과 서버 이미지를 사용해 `local` 프로파일로 띄운다. Android 앱의 API URL은 `http://10.0.2.2:8080`, iOS 앱은 `http://localhost:8080`이다. 계정은 다음처럼 준비한다.

```bash
export E2E_EMAIL="maestro-local@thumbsup.invalid"
export E2E_PASSWORD="로컬에서만-정한-8자이상-값"
export E2E_API_URL="http://localhost:8080"
node apps/mobile/e2e/scripts/seed-account.mjs
```

가상 기기와 Release 앱이 이미 준비된 뒤에는 아래처럼 실행한다. development 프로파일 앱을 검사할 때만 app id와 scheme을 development 값으로 바꾼다.

```bash
export APP_ID="studio.thumbsup.staging"
export APP_SCHEME="thumbsup-staging"
maestro test -e APP_ID="$APP_ID" -e APP_SCHEME="$APP_SCHEME" \
  -e E2E_EMAIL="$E2E_EMAIL" -e E2E_PASSWORD="$E2E_PASSWORD" \
  apps/mobile/e2e/flows/smoke.yaml
```

development 프로파일의 app id는 `studio.thumbsup.dev`, scheme은 `thumbsup-dev`다. CI는 매 실행마다 임시 이메일과 비밀번호를 생성하며 GitHub Secrets에 계정 값을 저장하지 않는다.

## play 상태 모델 경로

`play-path.mjs`는 `packages/core/src/play-logic.ts`의 제출·채점 함수와 `mock-play-session.ts`의 `ox`, `multiple-choice`, `keyword-blank` 구성을 확인한 뒤 정답·오답과 힌트 사용 여부를 조합한다. 현재는 실행 시간을 제한하기 위해 6개 경로만 만든다.

```bash
node apps/mobile/e2e/generators/play-path.mjs
node apps/mobile/e2e/generators/play-path.mjs --check
```

생성물은 `play-paths.generated.json`과 `flows/routes/play.generated.yaml`이다. `PLAY_PATH`를 지정하지 않으면 `ox-correct`를 실행한다. 다른 경로는 해당 종류의 문제가 현재 화면에 준비된 상태에서 `PLAY_PATH`로 선택한다. 이 생성 방식은 play에만 적용하며, 나머지 라우트는 화면 계약이 분명하게 보이도록 손으로 관리한다.

## CI 범위

`.github/workflows/mobile-e2e.yml`은 KST 03:00 야간 실행, 수동 실행, PR 실행을 지원한다. 수동 실행은 Android, iOS, 양쪽 중 하나를 고른다. 일반 PR은 `apps/mobile/**` 또는 `packages/**`가 바뀌었을 때 로그인과 홈만 확인하고, `e2e` 라벨이 붙은 PR은 전체 라우트와 가상 기기 항목을 실행한다. 두 job은 JUnit XML과 Maestro debug·스크린샷 디렉터리를 artifact로 남긴다.

이 워크플로우는 브랜치 보호 필수 체크로 등록하지 않는다. Android 회전은 전체 실행에서 `run-rotation.mjs`가 가로와 세로를 각각 확인한다. `xcrun simctl`에는 지원되는 화면 회전 명령이 없으므로 iOS 회전은 수동이다.

## 모바일 고유 항목

- Android 뒤로 가기는 Maestro `back`, iOS 뒤로 가기는 화면 왼쪽 2%에서 90%까지 edge swipe를 사용한다. iOS에서 `back`은 실제로 화면을 바꾸지 않으므로 쓰지 않는다.
- background 복귀는 `stopApp` 뒤 `launchApp.clearState: false`로 SecureStore 세션과 기존 화면 복원을 확인한다.
- 키보드 플로우는 의견 입력 뒤 `hideKeyboard`를 호출하고 제출 버튼과 닫기 버튼을 확인한다. 키보드가 열린 동안 보내기 버튼이 보여야 한다는 단계는 알려진 버그가 해결되기 전까지 주석 처리했다.
- Android 오프라인은 `setAirplaneMode`로 로그인 네트워크 오류를 확인한다. iOS 시뮬레이터에는 airplane mode가 없어 수동 네트워크 조절이 필요하다.
- 15초 timeout은 서버 지연을 안전하게 주입하는 전용 공개 계약이 없어 현재 수동이다. 정상 API를 모킹해서 대신 통과시키지 않는다.
- safe area와 font loading은 첫 화면의 상단 제목, 본문, 하단 탭이 모두 노출되는지 반자동으로 확인한다. 픽셀 단위 겹침과 글꼴 모양은 artifact를 함께 본다.

## 실기기에서 실행

`flows/device-only`는 실제 푸시 도착, Wi-Fi와 셀룰러 사이의 실제 네트워크 전환, 성능과 글꼴 렌더링 증빙을 위한 시작점이다. CI에서는 이 디렉터리를 실행하지 않는다. 기기를 연결하고 올바른 Release 앱을 설치한 다음 필요한 시스템 동작을 사람이 수행하면서 해당 플로우를 실행한다.

```bash
maestro --device "<실기기 ID>" test \
  -e APP_ID="$APP_ID" -e E2E_EMAIL="$E2E_EMAIL" -e E2E_PASSWORD="$E2E_PASSWORD" \
  apps/mobile/e2e/flows/device-only
```

실기기 클라우드 팜이나 네이티브 계층을 직접 조작해야 하는 범위가 생기면 Appium을 후보로 검토한다. 이번 게이트에는 도입하지 않으며 Maestro의 가상 기기 범위와 실기기 수동 증빙을 먼저 유지한다.

## 기준선 판정표 매핑

`자동`은 플로우가 결과를 직접 assert한다는 뜻이고, `반자동`은 플로우 결과와 JUnit·화면 artifact를 함께 확인한다는 뜻이다. 자동화되지 않은 항목은 이유를 적었다.

| 웹 경로 | 화면 | 상태 | API·인증 | 접근성 | 모바일 고유 |
| --- | --- | --- | --- | --- | --- |
| `/` | 자동: `routes/home.yaml` | 자동: 로딩 후 최근 코스 | 반자동: 로그인 후 home·mascot 콘텐츠 | 자동: `check:a11y`와 홈 text | 반자동: `safe-area-font.yaml` |
| `/login` | 자동: `routes/login.yaml` | 반자동: `offline-android.yaml`; timeout 수동 | 자동: `atoms/login.yaml` | 자동: 입력 label·role 정적 검사 | 자동: iOS 저장 다이얼로그 optional 처리 |
| `/signup` | 자동: `routes/signup.yaml` | 자동: 빈 입력 검증 오류 | 반자동: 실제 생성은 `seed-account.mjs` | 자동: 입력·체크박스 정적 검사 | 반자동: 키보드 레이아웃 artifact |
| `/course` | 자동: `routes/course.yaml` | 자동: 로딩 후 코스 개수 | 반자동: 실제 courses 응답이 있어야 통과 | 자동: 코스·스텝 role 정적 검사 | 반자동: safe area와 하단 탭 |
| `/briefing` | 자동: `routes/briefing.yaml` | 자동: 로딩 후 핵심 요약 | 반자동: 실제 next-step briefing | 자동: 펼침·문제 풀기 role 검사 | 자동: Android back, iOS edge swipe |
| `/play` | 자동: `routes/play.generated.yaml` | 반자동: 문제·힌트·채점 전이 | 반자동: 실제 quiz·hint·answer 응답 | 자동: 답안·버튼 label과 disabled 상태 | 반자동: background·회전·safe area |
| `/insight` | 자동: `routes/insight.yaml` | 자동: 채점 후 핵심 3줄 | 반자동: 실제 explanation 응답 | 자동: 이동 버튼 label·role 검사 | 자동: 플랫폼별 back 플로우에서 동선 확인 |
| `/follow-up` | 자동: `routes/follow-up.yaml` | 자동: 상세 로딩 후 답 확인 | 반자동: 실제 follow-up 응답 | 자동: 버튼·키워드 role 검사 | 반자동: back 목적지와 artifact |
| `/history` | 자동: `routes/history.yaml` | 자동: 로딩 후 목록 또는 빈 상태 | 반자동: 실제 history graph 응답 | 자동: 목록 항목·복습 링크 검사 | 반자동: WebView 대체 화면 artifact |
| `/history/graph` | 자동: `routes/history-graph.yaml` | 자동: 그래프/목록 전환 컨트롤 | 반자동: 인증된 graph 응답; 웹 redirect와의 호환 판단은 수동 | 자동: tab label·role 검사 | 반자동: 그래프 렌더링 artifact |
| `/history/done` | 자동: `routes/history-done.yaml` | 자동: 정적 완료 화면 | 자동: 인증 세션 뒤 deep link | 자동: 두 CTA label·role 검사 | 반자동: deep link와 back 동선 |
| `/profile` | 자동: `routes/profile.yaml` | 자동: 프로필 로딩 후 이메일 | 반자동: 실제 auth/me; 로그아웃은 `atoms/logout.yaml` | 자동: 설정·의견·로그아웃 role 검사 | 자동: `background.yaml`, 반자동: `keyboard.yaml` |

정적 검사만으로 스크린리더 읽기 순서, 모달 포커스 트랩, reduce motion의 체감 결과를 판정할 수는 없다. 해당 항목은 가상 기기 artifact 또는 실기기 수동 증빙이 필요하다.

## 테스트 배치 점검

현재 `*.test.ts`의 순수 로직 테스트는 Vitest가 맡고, `*.test.tsx` 화면 테스트는 jest-expo와 `@testing-library/react-native`가 맡는다. `pnpm test`가 `vitest run && jest --runInBand` 순서로 둘을 실행하며, 이 원칙에서 벗어난 파일이 없어 이번 작업에서는 테스트 파일을 옮기지 않았다.

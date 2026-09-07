# OTA 업데이트 관측성 운영 가이드

셀프호스팅 OTA는 EAS 대시보드를 제공하지 않는다. 잘못된 번들을 빠르게 찾고 되돌릴 수 있도록 앱 실행, 크래시, emergency launch를 자체 수집한다. 이 문서는 수집 계약과 운영 기준을 정리한다.

## 수집 흐름

앱은 `EXPO_PUBLIC_UPDATES_URL`을 기준으로 다음 엔드포인트에 JSON을 보낸다.

| 이벤트 | 엔드포인트 | 발생 시점 |
| --- | --- | --- |
| launch | `POST /api/telemetry/launch` | JS 첫 화면의 React commit이 끝났을 때. ErrorBoundary 또는 전역 오류가 먼저 발생하면 실패로 기록 |
| crash | `POST /api/telemetry/crash` | React ErrorBoundary가 오류를 잡거나 전역 `ErrorUtils` 핸들러가 호출됐을 때 |
| emergency | `POST /api/telemetry/emergency` | `Updates.isEmergencyLaunch`가 `true`인 시작 시점. staging에서는 #349의 안정 채널 복구와 함께 실행 |

모든 이벤트에는 발생 시각, 앱 버전, `runtimeVersion`, `updateId`, channel, 플랫폼, 기기 모델을 넣는다. launch에는 성공 여부, `isEmergencyLaunch`, `launchDuration`을 추가한다. crash는 오류 이름과 메시지, 스택 상위 20줄, fatal 여부를 담는다. embedded 또는 개발 실행처럼 값이 없는 경우 `updateId`와 `runtimeVersion`은 `null`이다.

전송 실패는 앱 실행을 막지 않는다. 실패한 이벤트는 AsyncStorage에 최대 50건까지 저장하고 네트워크가 다시 연결되면 한 번만 재시도한다. 재시도도 실패한 이벤트는 버려서 무한 전송과 저장소 증가를 막는다.

수집 Lambda는 경로와 이벤트 종류가 일치하는지 수동으로 검증한다. 요청 본문은 16 KiB로 제한하고 요청 출처별로 분당 60건까지만 받는다. Lambda 동시 실행 수도 5개로 제한한다. channel에는 영문자·숫자·점·밑줄·하이픈만 허용한다. 유효한 이벤트는 `telemetry/<yyyy-mm-dd>/<channel>/<uuid>.json`에 저장한다.

## 보관과 개인정보

S3 lifecycle은 `telemetry/` 객체와 이전 버전을 30일 뒤 삭제한다. 이 기간이면 배포 직후 이상 징후와 최근 업데이트 추세를 확인할 수 있고, 필요 이상의 기기 정보를 오래 보관하지 않는다.

사용자 ID, 광고 ID, 설치 ID, IP 주소, 이메일, 토큰은 페이로드에 넣지 않는다. 기기 모델은 제조사가 공개한 모델명만 기록하며 개별 기기를 식별하는 값은 수집하지 않는다. 오류 메시지와 스택에도 사용자 입력이나 인증 정보가 들어가지 않도록 새 오류를 만들 때 주의한다.

## 일일 리포트

AWS 자격 증명이 있는 운영 환경에서는 다음 명령으로 UTC 날짜 하루치를 읽는다.

```bash
pnpm --filter updates-server telemetry:report -- --date 2026-09-08 --bucket thumbsup-mobile-artifacts
```

로컬 저장소를 점검할 때는 `--bucket` 대신 `--store-dir <경로>`를 쓴다. 결과 표는 channel과 updateId별 launch 성공·실패, emergency, crash, 채택률을 보여준다. 채택률은 같은 channel의 전체 launch 중 해당 updateId가 차지한 비율이다.

## rollback 판단 기준

새 updateId를 배포한 뒤 리포트를 계속 확인한다. 다음 조건 중 하나라도 충족하면 해당 channel 포인터를 직전 정상 updateId로 즉시 rollback한다.

- launch 실패율이 5%를 초과한다. 계산식은 `launch 실패 / 전체 launch`다.
- crash율이 2%를 초과한다. 계산식은 `crash / 전체 launch`다.
- emergency launch가 1건 이상 발생한다.

표본이 적더라도 이 기준을 그대로 적용한다. 특히 emergency launch는 #331 스파이크에서 불량 번들이 첫 재실행에도 다시 실행된 뒤 두 번째 재실행에서 감지됐으므로 한 건만 확인해도 기다리지 않는다. rollback 뒤에는 같은 runtimeVersion의 정상 번들로 launch 성공률이 회복됐는지 확인하고, 문제 updateId를 다시 가리키지 않도록 발행 기록을 남긴다.

## 2차 옵션

현재 단계는 외부 SaaS 없이 S3 기반으로 운영한다. 사용자 수가 늘어 오류 그룹화, 릴리스 비교, 알림 자동화가 필요해지면 Sentry를 2차 옵션으로 검토한다. 도입하더라도 `updateId`, `runtimeVersion`, channel을 release·tag에 연결하고 개인정보 비수집 원칙과 보관 기간을 다시 검토해야 한다.

<!-- HUMANIZE-SUMMARY
원본/윤문본: 2,421자 / 2,435자, 변경률 1.0%
탐지: A-11 1→0, E-2 1→0, H-1 1→0
자체검증: 6/6 통과
등급: B — S1 잔존 없음, 운영 가이드의 표·수치·기술 용어는 보존
주요 변경: "판단하기 위한 근거를 만든다" → "잘못된 번들을 빠르게 찾고 되돌릴 수 있도록"; 반복 종결어미 일부 조정
-->

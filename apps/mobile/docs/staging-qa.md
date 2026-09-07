# 모바일 staging QA

staging 앱은 각 PR에서 만든 Expo 번들을 골라 실행한다. 다만 2026년 9월 8일 현재 업데이트 서버와 staging 서명 바이너리가 배포되지 않아 아래 절차를 실제 기기에서 사용할 수 없다. #349에 병합된 화면 동작을 기준으로 썼으며, 인프라 배포 뒤 다시 검증해야 한다.

## 채널 선택

1. staging 앱을 실행한다. 이 기능은 `APP_ENV=staging` 빌드에만 포함된다.
2. PR의 `Mobile PR Bundle Publish`가 남긴 `thumbsup-staging://pr/<PR번호>` 링크를 staging 앱에서 연다.
3. PR 채널 화면에서 PR 번호, 제목, 브랜치, 커밋, 생성 시각, runtimeVersion을 확인한다.
4. `호환됨` 배지가 붙은 PR을 누른다. 앱이 `pr-<PR번호>` 채널로 헤더를 바꾸고 업데이트를 내려받은 뒤 다시 시작한다.
5. 화면 아래 `PR #N 실행 중` 배지로 현재 채널을 확인한다.

앱의 runtimeVersion과 PR 번들이 다르면 `새 바이너리 필요`로 표시되고 선택할 수 없다. 이때는 PR 코드와 호환되는 staging 바이너리가 배포될 때까지 기다린다.

## staging으로 돌아가기

화면 아래 배지에서 `나가기`를 누르면 요청 헤더를 `staging`으로 되돌리고 안정 채널 업데이트를 받은 뒤 앱을 다시 시작한다. 다운로드에 실패해도 헤더와 저장된 PR 상태는 staging으로 복구되며, 네트워크 연결 뒤 앱을 다시 열어 재시도할 수 있다.

PR 번들이 시작 단계에서 크래시해 Expo Updates가 emergency launch를 감지하면 앱은 저장된 PR 상태를 지우고 staging 채널로 복구를 시도한다. 업데이트를 받지 못해도 내장 번들로 실행하며 다음 요청의 채널은 staging으로 유지한다.

## 배포 전 확인 사항

- `EXPO_PUBLIC_UPDATES_URL`을 실제 CloudFront 주소로 설정한다.
- staging 채널에 현재 runtimeVersion과 맞는 안정 업데이트를 먼저 게시한다.
- staging 서명 바이너리를 대상 시뮬레이터나 등록된 기기에 설치한다.
- PR 번들 build·publish가 성공하고 봇 코멘트의 딥링크가 생성됐는지 확인한다.
- QA가 끝나 PR을 닫으면 cleanup workflow가 채널과 S3 객체를 제거했는지 확인한다.

현재는 이 조건을 충족하는 배포가 없으므로 채널 선택기 코드는 단위 테스트로만 검증됐다. 실제 staging QA 완료로 기록하면 안 된다.

# Expo Updates 서버

Expo Updates 프로토콜 v1 manifest를 동적으로 만들고, 번들과 에셋을 같은 CloudFront 도메인에서 내려주는 CDK 스택이다. 스택 이름은 `ThumbsupUpdatesServer`, 리전은 `ap-northeast-2`로 고정했다. AWS 계정은 코드에 넣지 않고 `CDK_DEFAULT_ACCOUNT`에서 읽는다.

## 구조

```text
Expo 앱
  │  GET /api/manifest* (Updates 헤더)
  ▼
CloudFront ── CloudFront Function (요청 Host 보존)
  ├─ /api/manifest* ── OAC(SigV4) ── Lambda Function URL (AWS_IAM)
  │                                      ├─ channels/index.json 조회
  │                                      ├─ metadata·asset 조회
  │                                      └─ 선택 사항: SSM 서명 키 조회
  └─ /updates/* ───── OAC ──────────── 비공개 S3
       Cache-Control: public, max-age=31536000, immutable
```

S3 버킷 `thumbsup-mobile-artifacts`는 모든 공개 접근을 차단한다. CloudFront만 OAC로 객체를 읽고, Lambda Function URL도 CloudFront OAC의 서명된 요청만 받는다. manifest 경로에는 캐시를 쓰지 않으며 `Cache-Control: no-cache`를 반환한다. `/updates/*` 응답은 1년 immutable 캐시를 강제한다.

## 아티팩트 형식

채널 인덱스는 `channels/index.json`에 둔다. 채널별 배열에서 요청한 `runtimeVersion`과 호환되는 항목을 찾고, 그중 `createdAt`이 가장 최신인 항목을 배포 대상으로 삼는다.

```json
{
  "channels": {
    "production": [
      {
        "updateId": "b15ed6d8-f39b-04ad-a248-fa3b95fd7e0e",
        "runtimeVersion": "1",
        "createdAt": "2026-09-08T00:00:00.000Z"
      }
    ]
  }
}
```

업데이트 파일은 `updates/<channel>/<updateId>/` 아래에 둔다. `metadata.json`은 Expo 공식 `custom-expo-updates-server` fixture와 같은 `fileMetadata.ios`·`fileMetadata.android` 구조를 쓴다.

```json
{
  "version": 0,
  "bundler": "metro",
  "fileMetadata": {
    "ios": {
      "bundle": "bundles/ios.js",
      "assets": [{ "path": "assets/icon", "ext": "png" }]
    },
    "android": {
      "bundle": "bundles/android.js",
      "assets": [{ "path": "assets/icon", "ext": "png" }]
    }
  },
  "extra": { "expoClient": { "runtimeVersion": "1" } }
}
```

롤백하려면 채널의 최신 항목을 아래 형태로 바꾼다. 롤백 directive는 프로토콜 v1이면서 `multipart/mixed`를 허용한 요청에만 응답한다.

```json
{
  "type": "rollback",
  "runtimeVersion": "1",
  "createdAt": "2026-09-08T01:00:00.000Z",
  "commitTime": "2026-09-07T00:00:00.000Z"
}
```

## 검증과 배포

이 PR에서는 synth까지만 검증한다. 실제 AWS 리소스를 만들거나 바꾸는 `cdk deploy`는 사용자가 비용과 변경 사항을 확인한 뒤 실행해야 한다.

```bash
pnpm install --frozen-lockfile
pnpm --filter updates-server typecheck
pnpm --filter updates-server test
pnpm --filter updates-server build
pnpm --filter updates-server synth

export CDK_DEFAULT_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
pnpm --filter updates-server exec cdk diff --app "tsx bin/updates-server.ts"
# diff와 대상 계정을 확인한 사용자가 실행
pnpm --filter updates-server exec cdk deploy --app "tsx bin/updates-server.ts"
```

코드 서명을 쓰려면 `/thumbsup/prod/updates-signing-private-key` SecureString 파라미터에 RSA private key PEM을 넣는다. Lambda에는 파라미터 하나를 읽는 권한만 있다. 클라이언트 인증서와 key ID `main` 설정은 함께 배포해야 한다. 서명을 요구한 요청에서 키가 없으면 400을 반환한다.

배포 출력의 `UpdatesBaseUrl` 뒤에 `/api/manifest`를 붙여 Expo 앱의 업데이트 URL로 설정한다. 아티팩트를 먼저 업로드하고 `channels/index.json`을 마지막에 교체해야 한다. 그래야 클라이언트가 업로드 중인 업데이트를 읽지 않는다.

## 예상 비용

아래 값은 배포 전 규모를 가늠하기 위한 계산이다. 2026년 9월 공개 요금표를 참고했으며 세금, 환율, 로그 보관료와 무효화 요청은 뺐다. AWS 무료 사용량이나 CloudFront 정액제를 적용하면 실제 청구액은 더 낮을 수 있다.

가정은 월간 사용자 10,000명, 사용자당 하루 manifest 확인 1회, 월 2회 업데이트, 업데이트 크기 20MB, S3 저장량 10GB, Lambda 256MB·평균 100ms다. 한 달 manifest 요청은 30만 회, 다운로드는 약 400GB다.

- Lambda: `300,000 × 0.025GB-s × $0.0000166667 + 300,000 × $0.20/1,000,000`으로 약 **$0.19/월**이다. 무료 사용량 안이면 $0이다.
- CloudFront: 한국을 포함한 아시아 전송료를 예시 단가 $0.12/GB, HTTPS 요청을 $0.012/10,000건으로 잡으면 약 **$48.4/월**이다. 캐시 적중과 무료 사용량·선택한 요금제에 따라 가장 크게 달라지는 항목이다.
- S3: Standard 저장 단가를 예시 $0.025/GB-월로 잡으면 10GB가 **$0.25/월**이다. Lambda가 manifest마다 인덱스·metadata·파일을 읽는 GET 비용은 asset 수에 따라 추가된다.

무료 사용량을 빼지 않은 단순 합계는 약 **$48.84/월**이다. 배포 후 Cost Explorer에서 `AWS Lambda`, `Amazon CloudFront`, `Amazon Simple Storage Service`를 태그별로 한 달간 측정한 다음 이 추정치를 실측값으로 교체한다. 최신 단가는 [AWS Lambda 요금](https://aws.amazon.com/lambda/pricing/), [CloudFront 요금](https://aws.amazon.com/cloudfront/pricing/), [S3 요금](https://aws.amazon.com/s3/pricing/)에서 확인한다.

## 롤백

콘텐츠 문제는 새 `rollback` 항목을 `channels/index.json`의 최신 항목으로 올려 내장 업데이트로 되돌린다. 잘못된 채널 변경만 취소할 때는 직전 정상 인덱스를 다시 업로드한다. immutable URL의 파일은 덮어쓰지 않고 새 `updateId`를 발급해야 한다.

인프라 변경을 되돌릴 때는 이전 Git 커밋에서 `cdk diff`를 확인하고 사용자가 `cdk deploy`를 실행한다. 버킷의 `RemovalPolicy`는 `RETAIN`이므로 스택을 삭제해도 아티팩트는 남는다. CloudFront 배포를 지우기 전에 앱의 업데이트 URL을 정상 배포로 돌리고, 보존된 버킷 삭제는 별도 승인 절차로 처리한다.

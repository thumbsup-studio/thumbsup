# 모바일 PR 번들 publish 파이프라인

PR 코드를 AWS 권한과 분리해 staging 업데이트를 배포하는 절차다. IAM 역할과 GitHub Environment는 저장소 밖의 보안 설정이므로 이 PR에서 만들지 않는다. 아래 정책을 검토한 뒤 관리자가 직접 적용해야 한다.

## 동작 흐름

1. `Mobile PR Bundle Build`가 `pull_request`에서 실행된다. 이 작업에는 `contents: read`만 있고 AWS OIDC 토큰이나 쓰기 권한은 없다.
2. 빌드 작업은 iOS·Android를 포함한 Expo export를 만들고, runtimeVersion·commit·PR 번호·브랜치·제목·생성 시각을 담은 `metadata.json`과 `dist/`를 GitHub artifact로 올린다. Expo CLI 57은 `--platform ios,android`를 지원하지 않으므로 `--platform all`을 한 번 실행하고 publish 단계에서 iOS·Android 메타데이터를 필수로 검증한다.
3. 기본 브랜치에 있는 `Mobile PR Bundle Publish`가 `workflow_run`으로 성공한 빌드를 받는다. 같은 저장소의 PR인지 확인한 뒤 보호된 `mobile-staging-publish` Environment에서 OIDC 역할을 위임받는다. fork PR은 artifact까지만 만들고 publish하지 않는다.
4. publish 스크립트는 artifact의 PR 번호와 commit을 신뢰된 `workflow_run` payload와 대조한다. asset을 `updates/pr-<번호>/<commit>/`에 먼저 올리고 `metadata.json`을 해당 prefix에서 마지막으로 올린 다음 `channels/index.json`에 채널을 등록한다.
5. `channels/index.json`은 현재 ETag를 `If-Match`로 보내 갱신한다. 다른 PR이 먼저 썼다면 새 index를 다시 읽어 최대 6번 재시도하므로 lost update가 발생하지 않는다. 최초 파일 생성도 `If-None-Match: *`를 사용한다.
6. publish가 끝나면 봇이 기존 안내 코멘트를 찾아 갱신하거나 새로 작성한다. 딥링크는 `thumbsup-staging://pr/<번호>`다.
7. PR이 닫히면 `Mobile PR Bundle Cleanup`이 index에서 `pr-<번호>` 채널을 먼저 내리고 해당 update prefix를 삭제한다. 권한이 있는 workflow 정의는 PR merge ref가 아니라 기본 브랜치에서 읽어야 하므로 이벤트는 `pull_request_target: closed`를 사용하고 PR 코드는 체크아웃하지 않는다. 삭제 권한은 publish 역할과 분리한다. 버전이 남더라도 S3 lifecycle이 PR update의 현재·이전 버전을 30일 뒤 만료시킨다.

동일 PR의 publish와 cleanup은 모두 `pr-publish-<번호>` concurrency group을 쓴다. 새 push가 들어오면 이전 publish는 취소되고, cleanup은 실행 중인 publish가 끝난 뒤 시작한다.

## 권한 경계

PR에서 체크아웃한 코드는 export와 GitHub artifact 업로드만 할 수 있다. AWS 자격 증명을 받는 workflow는 항상 `main`의 파일을 체크아웃하며 PR head 코드를 실행하지 않는다. 내려받은 artifact는 다음 항목을 검사하기 전까지 신뢰하지 않는다.

- PR 번호와 commit이 `workflow_run` payload와 일치하는가
- iOS·Android bundle이 모두 있는가
- export metadata의 경로가 절대 경로나 `..`를 포함하지 않는가
- 실제 업로드 키가 `updates/pr-<번호>/<commit>/` 아래에만 생기는가

S3 정책도 같은 경계를 강제한다. publish 역할은 PR prefix와 `channels/index.json`만 읽거나 쓸 수 있고, production·binary prefix 및 삭제 작업에는 접근하지 못한다. cleanup 역할은 PR prefix 삭제와 index 갱신만 허용한다. 버킷 전체 목록 조회도 `updates/pr-*` prefix 조건으로 제한한다.

## 관리자가 만들어야 할 AWS 역할

OIDC provider `token.actions.githubusercontent.com`은 기존 계정 설정을 재사용한다. 아래 예시는 현재 계정 `819743217770`, 저장소 ID `1289852286`, 버킷 `thumbsup-mobile-artifacts`를 기준으로 작성했다.

### publish 역할

역할 이름은 `thumbsup-mobile-staging-publish`로 만든다. 권한 정책은 다음과 같다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadChannelIndexForConditionalWrite",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::thumbsup-mobile-artifacts/channels/index.json"
    },
    {
      "Sid": "PublishPullRequestUpdates",
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": [
        "arn:aws:s3:::thumbsup-mobile-artifacts/updates/pr-*",
        "arn:aws:s3:::thumbsup-mobile-artifacts/channels/index.json"
      ]
    }
  ]
}
```

trust policy는 Environment subject뿐 아니라 저장소 ID, workflow 이름, `main` ref를 함께 확인한다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::819743217770:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:thumbsup-studio/thumbsup:environment:mobile-staging-publish",
          "token.actions.githubusercontent.com:repository_id": "1289852286",
          "token.actions.githubusercontent.com:workflow": "Mobile PR Bundle Publish",
          "token.actions.githubusercontent.com:ref": "refs/heads/main"
        }
      }
    }
  ]
}
```

### cleanup 역할

삭제 권한을 publish에서 떼어 내기 위해 `thumbsup-mobile-staging-cleanup` 역할을 별도로 만든다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAndUpdateChannelIndex",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::thumbsup-mobile-artifacts/channels/index.json"
    },
    {
      "Sid": "ListPullRequestUpdatesOnly",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::thumbsup-mobile-artifacts",
      "Condition": {
        "StringLike": {
          "s3:prefix": "updates/pr-*"
        }
      }
    },
    {
      "Sid": "DeletePullRequestUpdatesOnly",
      "Effect": "Allow",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::thumbsup-mobile-artifacts/updates/pr-*"
    }
  ]
}
```

cleanup 역할의 trust policy는 publish와 같은 구조에서 Environment와 workflow만 바꾼다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::819743217770:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:thumbsup-studio/thumbsup:environment:mobile-staging-cleanup",
          "token.actions.githubusercontent.com:repository_id": "1289852286",
          "token.actions.githubusercontent.com:workflow": "Mobile PR Bundle Cleanup",
          "token.actions.githubusercontent.com:ref": "refs/heads/main"
        }
      }
    }
  ]
}
```

`job_workflow_ref`는 reusable workflow를 특정할 때 유용하다. 이번 구성은 reusable workflow가 아니다. 기존 server 배포도 같은 GitHub OIDC provider를 사용하므로 저장소 전체 subject customization은 하지 않는다. AWS가 지원하는 `environment` 기반 `sub`, `workflow`, `ref`, 변경되지 않는 `repository_id`를 함께 제한한다. 나중에 reusable workflow로 옮긴다면 기존 OIDC 역할의 trust policy를 함께 이관하는 별도 작업에서 `job_workflow_ref`를 포함한 custom subject를 검토한다.

## GitHub Environment 설정

저장소 Settings → Environments에서 다음 두 Environment를 만든다.

| Environment | 변수 | 값 |
| --- | --- | --- |
| `mobile-staging-publish` | `MOBILE_ARTIFACTS_BUCKET` | `thumbsup-mobile-artifacts` |
| `mobile-staging-publish` | `MOBILE_STAGING_PUBLISH_ROLE_ARN` | `arn:aws:iam::819743217770:role/thumbsup-mobile-staging-publish` |
| `mobile-staging-cleanup` | `MOBILE_ARTIFACTS_BUCKET` | `thumbsup-mobile-artifacts` |
| `mobile-staging-cleanup` | `MOBILE_STAGING_CLEANUP_ROLE_ARN` | `arn:aws:iam::819743217770:role/thumbsup-mobile-staging-cleanup` |

두 Environment 모두 deployment branch를 `main`만 허용하도록 설정한다. 같은 저장소의 PR은 자동 publish하고 fork PR은 workflow 조건에서 제외하므로 required reviewer는 두지 않는다. 관리자 승인 없이 Environment나 Actions workflow를 바꾸지 못하도록 `main` 브랜치 보호와 CODEOWNERS를 유지한다. 조직 정책상 매 publish마다 승인이 필요하면 `mobile-staging-publish`에 required reviewer를 추가하되, cleanup에는 추가하지 않아야 닫힌 PR이 자동으로 정리된다.

GitHub REST API로 설정할 때의 본문은 다음과 같다. 각 Environment 생성 후 deployment branch policy API로 `main` 패턴을 하나 추가한다.

```json
{
  "wait_timer": 0,
  "prevent_self_review": false,
  "reviewers": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
```

Environment 생성은 다음 endpoint에 위 JSON을 `PUT`하고, branch policy는 아래 JSON을 `POST`한다.

```text
PUT /repos/thumbsup-studio/thumbsup/environments/{environment_name}
POST /repos/thumbsup-studio/thumbsup/environments/{environment_name}/deployment-branch-policies
```

```json
{
  "name": "main",
  "type": "branch"
}
```

설정 후에는 같은 저장소 PR 한 건으로 build artifact 생성, OIDC 위임, S3 업로드, sticky comment 갱신을 확인한다. 이어 PR을 닫아 index에서 채널이 사라지고 `updates/pr-<번호>/` 객체가 삭제되는지 점검한다. fork PR에서는 build까지만 성공하고 publish job이 skipped인지 확인한다.

## 참고 자료

- [GitHub Actions OIDC reference](https://docs.github.com/en/actions/reference/security/oidc)
- [GitHub Actions workflow_run event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run)
- [AWS IAM OIDC condition keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html#condition-keys-wif)

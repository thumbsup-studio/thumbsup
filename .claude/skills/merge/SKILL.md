---
name: merge
description: Thumbs Up 레포의 기존 GitHub PR을 main에 병합하기 전 최종 검증하거나 실제로 squash merge할 때 사용. 사용자가 "머지해", "merge까지 완료", "PR 병합", "병합 전 최종 확인"처럼 요청하면 최신 main 재확인·rebase, 새 CI와 CodeRabbit 결과, server Flyway 순서와 운영 업그레이드 경로, squash merge, main 배포·health 및 이슈 정리까지 처리한다. "머지 가능한지 확인"은 검증만 하고, 실제 병합은 명시적 병합 요청이 있을 때만 한다.
---

# 안전한 PR 머지

GitHub의 `mergeable`만 믿지 않는다. 머지 안전성의 **대부분**(PR 필수·리뷰·CI green)은 main ruleset과 형제 스킬(`pr`·`commit`·`releasing`·`verify-app`·`deploying`)이 이미 처리한다. 이 스킬의 **고유 임무는 동시 머지로 인한 Flyway 순서 사고를 막는 것**이다 — 낮은 버전 migration이 이미 더 높은 버전에 도달한 운영 DB에 뒤늦게 들어가면, Flyway가 기동 시 이를 out-of-order로 판정해 서버가 내려간다. 그래서 먼저 migration 여부로 분기하고, 검증한 head만 squash merge한 뒤 실제 배포까지 확인한다.

## 권한 모드를 먼저 고정한다

- **검증 모드**: 소스·Git refs·GitHub·운영 상태를 변경하지 않고 판정만 보고한다. 원격 OID는 `git ls-remote`/GitHub API로 읽고, checkout·build가 필요하면 기존 repo 밖 임시 clone에서 수행한다. rebase·push·thread 답변/resolve·라벨 변경·merge·배포 재실행을 하지 않는다.
- **병합 모드**: 사용자가 실제 병합을 명시한 경우에만 진입한다. unrelated code 수정, 타인/fork 브랜치 force-push, 운영 DB 수동 변경은 허가하지 않는다.
- `--admin`, `--auto`, 일반 `--force`, 필수 체크 우회는 사용하지 않는다.

## 1. PR·불변 대상을 기록하고 분기한다

1. PR 번호, `baseRefName/baseRefOid`, `headRefName/headRefOid`, draft·fork 여부, author, 연결 이슈를 조회한다. 제목이 `pr`/Conventional Commit 규칙을 따르고 본문에 `Closes #이슈`가 있는지 확인한다.
2. base가 `main`이 아니면 중지한다. PR이 없으면 blocker로 보고하고, 사용자가 PR 생성까지 요청한 경우에만 `pr` 스킬로 넘긴다. Release PR이면 `releasing` 스킬을 함께 적용한다.
3. 검증에 사용한 base/head OID를 이후 모든 결과와 함께 기록한다. dirty worktree의 사용자 변경은 건드리지 않는다.
4. **분기 — 이 PR이 DB migration/Flyway 설정을 건드리나?** (값싼 체크. 사용자가 "Flyway"라고 말하지 않아도 여기서 잡는다.)

   ```bash
   gh pr view <PR번호> --repo thumbsup-studio/thumbsup --json files --jq '.files[].path'
   ```

   아래 중 하나라도 해당하거나 실패 로그에 Flyway가 나오면 **Flyway 경로**다.
   - `server/src/main/resources/db/migration/**`
   - `spring.flyway.*`, migration location, datasource/Flyway 초기화 설정
   - Flyway dependency·plugin·callback, `JavaMigration` 구현

   - 해당 없음 → **2A 일반 머지**
   - 해당 있음 → **2B Flyway 머지** (2A의 server 게이트에 추가 게이트를 얹는다)

## 2A. 일반 머지 (migration 없음)

**일반 머지 기본** — 브랜치를 최신 main에 rebase(up-to-date), 충돌·리뷰 thread 해결, 관련 CI green을 갖춘 뒤 [공통 — 머지 직전 재고정 & 실행](#공통--머지-직전-재고정--실행)에서 검증한 head를 squash한다. rebase·squash의 구체 실행은 공통 섹션에 있고, 여기서 반복하지 않는다.

변경 경로별 게이트는 형제 스킬에 위임한다.

- `app/**`: `verify-app`의 로컬 게이트 + App CI `gate` + 프리뷰/시각 QA(`deploying`).
- `server/**`: `server`에서 `./gradlew --no-daemon spotlessCheck build` + Server CI `build-and-test`·`gitleaks`.
- `.github/workflows/**`·`.coderabbit.yaml`·배포/검증 스크립트: YAML/스크립트를 직접 리뷰한다(trigger·permissions·path filter·secret guard). **변경된 workflow가 자기 자신을 검사했을 것이라고 가정하지 않는다.**

필수 체크뿐 아니라 변경 경로로 트리거된 관련 체크가 전부 green이어야 한다. unresolved thread는 검증 모드에서 blocker로 보고만, 병합 모드에서는 해결하거나 근거를 답변한 뒤 resolve한다. 수정 후에는 새 head OID로 게이트를 처음부터 다시 실행한다.

→ **[공통 — 머지 직전 재고정 & 실행]**으로 진행한다.

## 2B. Flyway 머지 (migration 있음)

먼저 [Flyway 머지 기준](references/flyway.md)을 전부 읽는다. 2A의 server 게이트(gradle·CI)도 그대로 적용한다.

```bash
python3 .claude/skills/merge/scripts/check_flyway_order.py --base <검증_BASE_OID> --head <검증_HEAD_OID>
python3 .claude/skills/merge/scripts/check_open_pr_migrations.py \
  --base <검증_BASE_OID> --head <검증_HEAD_OID> --current-pr <PR번호>
```

스크립트의 PASS는 **정적 구조 검사만** 통과했다는 뜻이다. 다음도 모두 확인하되, **운영 접근이 없어 확인 못 하는 항목은 검증했다고 하지 말고 "미검증"으로 보고한 뒤 사람 확인을 받는다.**

- 기존 migration 수정·삭제·rename 없음, 새 버전·내용 중복 없음
- open PR 전체의 migration 버전·내용과 겹치거나 교차하지 않음 (server↔server 동시 머지의 순서 꼬임을 여기서 막는다)
- 실행 중인 main `Deploy Server`가 없고 운영 중인 server SHA/history가 명확함
- clean install과 **실제 baseline 코드 → 후보 코드** 동일 DB 증분 업그레이드 모두 통과
- history checksum 유지, failed 0, 후보 버전 1회 success, 재기동 시 신규 적용 0
- DDL/DML의 lock·데이터 손실·부분 실패 위험과 데이터 후조건 검수 완료
- 애플리케이션 health와 영향 API 검증 완료

이미 main에 들어간 migration rename은 운영 history에서 이전 버전이 success/failed 모두 absent임을 read-only 증거로 입증한 경우만 예외 검사한다. 예외 옵션은 운영 증거·open PR 검사·baseline 업그레이드 검증을 대신하지 않는다.

```bash
python3 .claude/skills/merge/scripts/check_flyway_order.py \
  --base <검증_BASE_OID> --head <검증_HEAD_OID> \
  --allow-renamed-version <운영에 적용되지 않은 이전 버전>
```

→ **[공통 — 머지 직전 재고정 & 실행]**으로 진행한다.

## 공통 — 머지 직전 재고정 & 실행

동시 머지로 main이 움직였을 수 있으므로, 머지 직전 상태를 다시 고정한다.

1. 최신 main OID를 다시 읽는다: 검증 모드 `git ls-remote origin refs/heads/main`, 병합 모드 `git fetch origin main`.
2. **base OID가 검증값과 달라졌으면** 소유·clean 브랜치를 `origin/main`에 rebase하고 해당 경로(2A/2B) 게이트를 **처음부터 반복**한다. 이전 head의 성공 결과를 재사용하지 않는다. (app 머지가 main을 전진시킨 경우가 여기 걸린다.)
3. head OID가 CI·리뷰를 통과한 OID와 같은지 확인한다. Flyway PR이면 운영 history·main 최고 버전·open PR migration도 다시 조회한다.
4. **base 최신성 보장 방식.** strict(up-to-date) 보호나 merge queue가 있으면 그 메커니즘이 base 최신성을 보장한다. **둘 다 없으면(현재 이 레포가 그렇다)** 위 1~2의 머지 직전 재확인이 그 보장을 사람이 대신 수행하는 것이다 — base가 움직였으면 중단하고 재검증한다. `--match-head-commit`은 head만 고정하고 base 변경은 막지 못하므로 이 재확인이 유일한 안전장치다.
5. rebase push가 필요하면 기록한 원격 head를 lease 예상값으로 직접 고정한다. 일반 `--force-with-lease`를 쓰지 않는다. 타인/fork/소유권 불명 브랜치는 owner에게 rebase를 요청한다.

   ```bash
   git push \
     --force-with-lease=refs/heads/<브랜치>:<기록_REMOTE_HEAD_OID> \
     origin HEAD:refs/heads/<브랜치>
   ```

6. 검증한 head만 squash merge한다.

   ```bash
   gh pr merge <PR번호> --squash --match-head-commit <검증한_HEAD_OID>
   ```

   - merge queue가 있으면 queue 규칙으로 넣고 실제 `MERGED`까지 기다린다. Flyway PR은 queue에서 더 낮은 range가 먼저이고 후보가 모든 더 높은 range보다 앞인지 확인한다.
   - CLI 오류가 나도 원격 머지가 먼저 성공했을 수 있다. 재시도 전에 `state`, `mergedAt`, `mergeCommit`을 확인한다.
   - 원격 브랜치는 현재 작업에서 생성·관리했고 소유권이 명확한 경우에만 머지 성공 후 삭제한다. 타인/fork 브랜치는 남겨 owner에게 인계한다.

## 배포된 커밋과 이슈를 확인한다

1. merge commit이 `origin/main`에 포함됐는지 확인한다.
2. merge commit SHA에 결박된 워크플로우만 추적한다.
   - **server**: run의 `headSha`와 배포 `IMAGE_TAG`가 merge SHA인지, Deploy step 성공, 겹친 main 배포 없음을 확인한다. 운영 컨테이너 image tag/digest도 해당 이미지와 일치하는지 read-only로 확인한 뒤 공개 health를 연속 확인한다.
   - **app**: guard로 skip된 성공을 배포 성공으로 보지 않는다. 실제 Vercel deploy step, production URL, deployment metadata의 commit SHA, 핵심 경로를 확인한다.
   - **Release PR**: release-please 성공 후 manifest/version, `vX.Y.Z` tag, GitHub Release를 확인한다.
3. 동일 workflow의 이전·후속 main run이 겹쳤으면 모두 종료될 때까지 기다리고 최종 배포 SHA를 다시 확인한다.
4. 실패하면 완료 처리하지 않고 원인을 먼저 분류한다. 코드·migration 회귀면 이슈를 reopen/`status: in-progress`로 되돌리고 hotfix PR에 전체 게이트를 적용한다. runner·cloud·secret 등 인프라 장애면 제품 이슈 상태를 자동 변경하지 않는다.
5. 운영 장애는 즉시 알린다. 서버 rollback은 DB backward compatibility를 확인하고 별도 운영 승인을 받은 뒤 수행한다. 일반 merge 권한으로 운영 DB나 배포를 임의 복구하지 않는다.
6. 성공하면 이슈 Closed, 프로젝트 Done, `status: review` 제거를 확인한다.

## 최종 보고

- PR URL, squash merge commit, 검증한 base/head OID
- 분기 결과(일반/Flyway)와 관련 CI·리뷰, 브랜치 보호/queue 상태
- Flyway 변경 시 main·운영·후보·open PR 버전, clean/upgrade 검증, 데이터 후조건
- merge SHA에 결박된 배포 run과 운영 health
- 이슈·프로젝트·브랜치 정리 상태

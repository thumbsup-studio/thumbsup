# Flyway 머지 기준

## 핵심 불변식

1. 운영 `flyway_schema_history`를 최종 진실로 취급한다. 레포 main의 최고 버전만으로 운영 상태를 추측하지 않는다.
2. 적용된 migration은 수정·삭제·rename하지 않는다. 변경은 더 높은 버전의 forward migration으로 추가한다.
3. 새 migration은 최신 main과 운영의 최고 성공 버전보다 커야 한다.
4. clean DB 전체 적용과 기존 main 스키마에서의 증분 적용을 서로 다른 검증으로 실행한다.
5. 동시 open PR의 migration 버전도 하나의 대기열로 취급한다.
6. 새 migration이 기존 또는 같은 PR의 다른 migration과 바이트 단위로 같으면 중복 실행으로 취급한다.

## 왜 두 종류의 검증이 필요한가

PR #164에서는 `120000` migration이 clean DB에서 정상 적용됐지만, 운영은 먼저 배포된 `130000`에 도달해 있었다. Flyway는 운영 기동 시 낮은 미적용 버전을 out-of-order로 판정했고 서버가 내려갔다. PR #168은 운영 history에서 `120000`이 실행되지 않았음을 확인한 뒤 이를 `135000`으로 옮겨, 당시 후행 PR의 `140000` 앞에 배치했다.

따라서 `./gradlew build`나 빈 DB 적용만으로 순서 안전성을 증명할 수 없다.

## 정적 검사와 open PR 검사

먼저 최신 main을 fetch하고 정적 스크립트를 실행한다.

```bash
git fetch origin main
python3 .claude/skills/merge/scripts/check_flyway_order.py \
  --base <검증_BASE_OID> --head <검증_HEAD_OID>
```

open PR의 migration 파일은 GitHub API로 확인한다.

```bash
gh pr list --state open --base main --limit 100 --json number,headRefName,headRefOid
gh api repos/thumbsup-studio/thumbsup/pulls/<PR번호>/files --paginate
python3 .claude/skills/merge/scripts/check_open_pr_migrations.py \
  --base <검증_BASE_OID> --head <검증_HEAD_OID> --current-pr <PR번호>
```

`status`, `filename`, `previous_filename`을 확인한다.

- 같은 버전이 둘 이상이면 block한다.
- 여러 PR의 버전 구간이 서로 교차하면 merge 순서를 확정하거나 한쪽을 renumber하기 전까지 block한다.
- 현재 PR이 더 낮은 연속 구간이면 현재 PR을 먼저 merge하고 후행 PR에 최신 main rebase를 인계한다.
- open PR 검사는 merge 직전에 다시 실행한다.
- 스크립트가 각 open PR의 head를 files 조회 전후로 다시 확인한다. head가 움직였으면 전체 검사를 재실행한다.
- main의 `Deploy Server`가 실행 중이면 완료될 때까지 기다린다. 현재 main 배포가 실패했다면 최신 main이 아니라 최신 성공 배포 SHA 또는 운영 history를 증분 baseline으로 사용한다.

## MySQL 8.4 증분 검증

**로컬 Docker로 대부분 수행 가능한 검증이다**(2~9단계). 단 운영 상태에 의존하는 입력 — 운영 MySQL의 실제 patch/digest, 운영 `flyway_schema_history`의 최고 성공 버전 — 은 **접근 권한이 있을 때만** 확인된다. 접근이 안 되면 그 항목을 **"미검증"으로 명시 보고하고, 운영 최고 성공 버전을 사람에게 확인받은 뒤** 진행한다. **확인하지 못한 것을 검증했다고 보고하지 않는다.**

가능하면 운영 MySQL의 실제 patch 또는 digest를 고정해 검증한다. `mysql:8.4` 같은 floating tag만 썼다면 운영 패리티라고 보고하지 않는다. 별도 project/volume으로 깨끗하게 시작하고 종료 시 제거한다.

1. baseline SHA를 정한다(운영/CI 접근 필요 — 불가하면 위 원칙대로 사람에게 확인받는다). 일반 PR은 최신 성공 `Deploy Server`의 SHA가 base와 같은 server tree인지 확인한다. 현재 main 배포가 실패한 hotfix는 최신 **성공** 배포 SHA 또는 운영 history를 사용한다.
2. baseline SHA의 detached worktree를 만들고 그 코드·Flyway 설정으로 빈 DB를 기동한다. 후보 코드에 target만 걸어 base를 흉내 내지 않는다.
3. baseline history의 전체 success, failed 0, max, version·checksum 목록을 저장하고 종료한다.
4. DB volume은 유지한 채 후보 worktree의 코드로 기동한다.
5. 기존 history 행·checksum이 유지되고 후보 migration만 예상 순서로 정확히 한 번 적용됐는지, history failed 0 / 후보 success / 예상 max인지 확인한다.
6. 같은 후보를 한 번 더 기동해 새로 적용되는 migration이 0개이고 health가 계속 `UP`인지 확인한다.
7. 별도 빈 DB에는 후보 전체를 처음부터 적용해 clean install도 확인한다.
8. helper table·임시 데이터가 남지 않았는지 확인한다.
9. 데이터 migration이면 영향 행 수, 불변식, API 응답을 별도로 전수 검증한다.

후보가 Flyway 설정, DB driver, datasource 초기화, migration location을 바꾸면 설정 차이 자체를 별도 위험으로 리뷰한다.

운영 history가 필요한 rename 사고에서는 다음을 추가 확인한다.

- 이전 버전 행이 success/failed 모두 absent
- 현재 운영 최고 버전이 success
- 실패가 migrate 실행 전 validation 단계에서 발생
- MySQL 비트랜잭션 DDL이나 helper table의 부분 실행 흔적 없음

## SQL 의미와 운영 위험 검수

정적 스크립트는 버전과 바이트 중복만 검사한다. 신규 SQL을 직접 읽고 다음을 판정한다.

- `DROP`/`TRUNCATE`, 대량 `DELETE`/`UPDATE`, column type 축소, `NOT NULL`·unique 추가의 데이터 손실 가능성
- MySQL DDL lock과 예상 테이블 크기, 배포 health timeout 안에 끝나는지
- 비트랜잭션 DDL 중간 실패 후 재시도 안전성, helper cleanup, 결정적 처리 순서
- 백업·forward recovery·rollback 전략과 배포 실패 시 서비스 복구 방법
- 운영 데이터 분포를 반영한 precondition/postcondition 쿼리 (운영 read 접근 필요 — 불가하면 미검증으로 보고하고 사람에게 확인받는다)

데이터 손실이나 운영 DB 수동 변경이 필요하면 일반 merge 권한으로 진행하지 말고 사용자에게 영향과 복구안을 제시해 별도 승인을 받는다.

## 실패 유형별 대응

| 증상 | 판단 | 대응 |
|---|---|---|
| 낮은 미적용 버전(out-of-order) | main rebase 또는 동시 PR 순서 누락 | `outOfOrder=true`를 켜지 말고 더 높은 안전한 버전으로 재배치. 이미 main이면 운영 history absent 증거 필수 |
| checksum mismatch | 적용된 SQL이 변경됨 | 원본을 복원하고 새 forward migration 작성 |
| failed history 행 | 비트랜잭션 DDL의 부분 적용 가능 | 스키마·helper 상태를 먼저 대조. 명시적 운영 승인 없이 repair 금지 |
| duplicate version | 동시 PR 충돌 | 한 PR을 renumber하고 둘 다 최신 main에서 재검증 |
| 다른 버전, 동일 SQL | 같은 migration이 중복 머지됨 | 신규 파일을 제거하고 두 PR의 의도·후조건을 대조 |
| clean DB 성공, 운영 실패 | 증분 경로 미검증 | main target DB에서 같은 DB 업그레이드 검증 추가 |

`spring.flyway.out-of-order=true`, history 직접 수정, `flyway repair`, 운영 DB 수동 DDL은 자동 복구 수단이 아니다. 정확한 history와 부분 적용 상태를 확인하고 사용자의 운영 변경 승인을 받은 경우에만 별도 절차로 수행한다.

현재 server 배포는 새 컨테이너 health를 확인하기 전에 기존 컨테이너를 중지한다. Flyway 기동 실패가 곧 외부 502로 이어질 수 있으므로 Actions 성공 여부와 별개로 공개 health를 확인한다.

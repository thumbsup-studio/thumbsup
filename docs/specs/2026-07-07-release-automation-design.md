# 릴리즈 자동화 + 배포·릴리즈 스킬 문서화 디자인 — #78

- **날짜**: 2026-07-07
- **상태**: 승인됨 (구현 전)
- **관련 이슈**: [#78](https://github.com/thumbsup-studio/thumbsup/issues/78)
- **선행**: #46(앱 배포 인프라 — 완료), #33(스캐폴딩 — 완료)

## 배경과 목표

배포 인프라(#46)는 완성됐지만 **버전·릴리즈 체계가 전혀 없다** — git 태그 0개, GitHub Release 0개, CHANGELOG 없음. 또 repo에 프로덕션 링크가 노출돼 있지 않고, server 작업자가 "배포가 왜 안 도나"를 헷갈릴 여지가 있다. 이 네 가지를 정비한다.

1. **프로덕션 링크** — repo About + README에 `https://thumbsup-app.vercel.app` 노출
2. **릴리즈 자동화** — release-please로 main 머지 시 CHANGELOG·버전을 모으고, Release PR 머지 시 git 태그 + GitHub Release 생성
3. **배포/릴리즈 스킬 문서화** — 사람·에이전트가 읽는 절차 문서 2개
4. **server 배포 제외 명문화** — 규약 문서화 (코드 변경 없음)

## 결정 기록

| 결정 | 선택 | 근거 |
|------|------|------|
| 릴리즈 도구 | **release-please** (googleapis/release-please-action@v4) | 이미 Conventional Commits 사용 → 궁합. Release PR로 사람이 최종 검토(MVP 안전), '머지 시 노트 채움' 요구에 정확히 부합 |
| 버전 단위 | **저장소 통합 버전 하나** | app만 배포되고 server는 시작 단계 → 단순. 필요 시 컴포넌트별 분리 가능 |
| 첫 버전 | **0.1.0** (현재 app/package.json 값 유지) | 인프라 구축 단계, 소급 정리 불필요 |
| package.json bump | **동기화함** (release-please extra-files) | 사용자 결정 — 통합 버전과 app/package.json version을 일치시킴 |
| 하네스 | **실행 하네스 (A)** — release-please.yml(신규) + app-deploy.yml(기존) | 검증 CI(B)는 현 규모에 YAGNI. paths·guard로 이미 방어됨 |
| server 배포 제외 | **문서 명문화만** | app-deploy.yml이 이미 `paths: app/**`라 server 변경은 배포 미트리거 — 코드 변경 불필요 |

## 1. 프로덕션 링크

- `gh repo edit thumbsup-studio/thumbsup --homepage https://thumbsup-app.vercel.app` → repo "About"에 링크
- README 최상단(제목 바로 아래)에 한 줄: `**프로덕션**: https://thumbsup-app.vercel.app`

## 2. 릴리즈 자동화 (release-please)

### 파일 3개

```
.github/workflows/release-please.yml   # main push 시 release-please-action@v4
release-please-config.json             # 단일 패키지 "."
.release-please-manifest.json          # {".": "0.1.0"}  (버전의 단일 진실 소스)
version.txt                            # 0.1.0  (simple 타입이 관리하는 버전 파일)
```

**version.txt 관련 (검증된 사실)**: `release-type: "simple"`은 루트 `version.txt`를 버전 파일로 관리한다(공식 문서 확인). 통합 버전 저장소에서 이 파일이 "저장소 전체 버전"의 물리적 소스가 되어 오히려 자연스럽다. `app/package.json`의 version은 `extra-files`로 여기에 **미러링**된다(단일 소스=version.txt/manifest, app/package.json은 파생).

**`release-please-config.json`** (핵심 구조):
```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "changelog-path": "CHANGELOG.md",
      "include-component-in-tag": false,
      "extra-files": [
        { "type": "json", "path": "app/package.json", "jsonpath": "$.version" }
      ]
    }
  }
}
```
- `release-type: "simple"` — 언어 비종속(모노레포에 Next.js+Spring 혼재). CHANGELOG·버전 파일만 관리, 언어별 빌드 가정 없음
- `include-component-in-tag: false` — 태그가 `v0.1.0` 형식(컴포넌트 접두어 없음, 통합 버전)
- `extra-files` — 릴리즈 시 `app/package.json`의 `version`도 함께 bump(사용자 결정)

**`.release-please-manifest.json`**:
```json
{ ".": "0.1.0" }
```

### 워크플로우 `release-please.yml`

```yaml
name: Release Please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

### 동작 (2단계)

1. main에 `feat`/`fix` 등 머지 → release-please가 **"chore(main): release 0.2.0" Release PR**을 자동 생성/갱신. CHANGELOG에 커밋 노트가 쌓이고 `app/package.json` version이 bump됨(PR 안에서).
2. Release PR을 사람이 머지 → **git 태그 `v0.2.0` + GitHub Release**(노트 게시).

### 버전 규칙 (Conventional Commits 표준)

| 커밋 | 버전 영향 |
|------|-----------|
| `feat:` | minor (0.1.0 → 0.2.0) |
| `fix:` | patch (0.1.0 → 0.1.1) |
| `feat!:` / `BREAKING CHANGE:` | major (0.1.0 → 1.0.0) |
| `chore:`/`docs:`/`refactor:`/`test:` | 버전 미변경 (CHANGELOG "Other" 그룹) |

### 배포와의 관계

**독립.** 배포(app-deploy.yml)는 main push마다(`app/**` 변경 시), 릴리즈는 release-please가 태그·노트만 관리 — 서로 안 엮어 단순하게 둔다. release-please는 기본 `GITHUB_TOKEN`(contents·PR write)으로 충분.

## 3. 스킬 문서화 (2개)

관심사가 달라 분리한다.

**`.claude/skills/deploying/SKILL.md`** — 배포 파이프라인:
- main→프로덕션, PR(`app/**`)→프리뷰, Vercel CLI 방식(Git 연동 아님)
- **server는 배포 대상 아님** (app-deploy는 `app/**`만 반응)
- 시크릿(VERCEL_*·ELICE_*), 프리뷰 URL, 시각 QA 연계
- 프로덕션/프리뷰 도메인 패턴

**`.claude/skills/releasing/SKILL.md`** — 릴리즈 흐름:
- Release PR 확인 → 머지 → 태그·GitHub Release 생성 절차
- 버전 규칙(feat→minor 등), Conventional Commits와의 관계
- 통합 버전 체계, `app/package.json` 동기화 설명

두 스킬 모두 `.codex/skills` 심링크 경유로 Codex에도 노출(기존 패턴).

## 4. server 배포 제외 명문화

- **코드 변경 없음** — `app-deploy.yml`이 이미 `paths: app/**`라 `server/**` 변경은 배포 미트리거
- CONTRIBUTING.md에 한 줄: "app-deploy는 `app/**` 변경에만 반응한다. server 작업은 Vercel 배포 대상이 아니며, 서버 배포는 #47에서 별도로 다룬다."

## 검증 계획

- **release-please.yml**: `npx yaml-lint`로 워크플로우 문법 검증
- **config/manifest 동작 검증 (핵심 게이트)**: 구현 시 release-please를 로컬 dry-run으로 돌려 두 가지를 반드시 확인 — (a) `simple` 타입이 `version.txt`를 정상 생성/관리하는가, (b) `extra-files`가 `app/package.json`의 `$.version`을 실제로 bump하는가. 로컬 dry-run이 인증 등으로 어려우면, 이 PR 머지 후 첫 Release PR에서 CHANGELOG·version.txt·app/package.json 세 곳이 모두 갱신되는지 관찰하는 것으로 대체(실질 검증). **dry-run에서 extra-files가 simple 타입과 호환되지 않으면 → `release-type`을 유지하되 app/package.json 동기화만 별도 처리하거나 사용자에게 에스컬레이션**
- 실질 검증: 이 PR 머지 후 main에서 release-please가 첫 Release PR을 생성하는지 관찰
- **프로덕션 링크**: `gh repo view --json homepageUrl`로 반영 확인, README 렌더
- **스킬**: SKILL.md frontmatter(name/description) 유효, `.codex/skills` 심링크 노출, 참조 경로 실재
- **CONTRIBUTING**: 문구 추가 확인

## 범위 제외

- 검증 하네스(B) — 규약 준수 검사 CI. 현 규모 YAGNI
- app·server 컴포넌트별 분리 버전 — 통합 버전으로 시작, 필요 시 후속
- 릴리즈-배포 연동(태그 시점 배포 등) — 독립 유지
- npm publish/배포 아티팩트 — 웹앱이라 불필요

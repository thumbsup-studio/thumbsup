---
name: releasing
description: 릴리즈(버전·태그·GitHub Release·CHANGELOG) 처리. release-please Release PR 확인·머지, 버전 규칙(feat→minor 등), Conventional Commits와의 관계를 알아야 할 때. 사용자가 "릴리즈 어떻게 해", "버전 어떻게 올라가"라고 할 때도 트리거.
---

# releasing — release-please 릴리즈

릴리즈는 `release-please`가 자동화한다 (`.github/workflows/release-please.yml`). 저장소 **통합 버전**(컴포넌트 접두어 없는 `vX.Y.Z` 태그) — app·server 공통 단일 버전.

> **현재 비활성.** 워크플로우는 수동 트리거(`workflow_dispatch`)로만 있고 자동 실행되지 않는다. 기본 GITHUB_TOKEN으로는 Release PR 생성이 차단되고, 봇이 만든 PR은 필수 체크(server-ci 등)를 트리거하지 못해 머지도 막히기 때문이다. **활성화**하려면 사람 신원의 전용 토큰(fine-grained PAT 또는 GitHub App)을 `RELEASE_PLEASE_TOKEN` 시크릿으로 등록하고, 워크플로우의 push 트리거·`token:` 입력 주석을 해제한 뒤, 앵커 태그(`gh release create v0.1.0 --target main`)를 먼저 만든다(태그가 없으면 첫 실행이 과거 커밋 전체를 미릴리즈로 잡는다). 활성화 절차는 워크플로우 파일 상단 주석에 정리돼 있다. 아래 흐름은 활성화 후 기준.

## 흐름 (2단계)

1. **main에 `feat`/`fix` 등이 머지되면** → release-please가 **"chore(main): release X.Y.Z" Release PR**을 자동 생성/갱신한다. 이 PR 안에서 CHANGELOG·`version.txt`·`app/package.json` version이 함께 갱신된다.
2. **그 Release PR을 사람이 머지하면** → git 태그 `vX.Y.Z` + GitHub Release(노트 게시)가 생성된다.

즉 릴리즈하려면: **Release PR을 확인하고 머지**하면 끝. 태그·노트는 자동.

## 버전 규칙 (Conventional Commits)

| 커밋 | 버전 |
|------|------|
| `feat:` | minor (0.1.0 → 0.2.0) |
| `fix:` | patch (0.1.0 → 0.1.1) |
| `feat!:` 또는 본문 `BREAKING CHANGE:` | major (0.1.0 → 1.0.0) |
| `chore:`·`docs:`·`refactor:`·`test:` | 버전 미변경 (기본 설정에서 CHANGELOG에 미표기) |

정확한 버전 계산은 release-please가 커밋 타입을 보고 한다 — 사람이 버전을 직접 정하지 않는다.

## 버전의 단일 소스

`.release-please-manifest.json`이 현재 버전의 진실 소스다. `version.txt`와 `app/package.json`의 version은 릴리즈 시 여기에 맞춰 갱신된다(수동 편집 금지 — Release PR이 관리).

## 배포와의 관계

릴리즈와 배포는 **독립**이다. 배포는 main push마다(`app/**` 변경 시) 즉시 일어나고(→ `deploying` 스킬), 릴리즈는 태그·노트만 관리한다. 태그가 배포를 트리거하지 않는다.

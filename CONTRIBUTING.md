# 기여 가이드 (Thumbs Up)

`thumbsup-studio/thumbsup` **모노레포**의 커밋 · 브랜치 · PR · 이슈 · 라벨 · 마일스톤 컨벤션.
바탕: [Conventional Commits](https://www.conventionalcommits.org) + 스프린트 추적 ID(F-xx · Q-xx) → GitHub Issue 흐름.

레포 구성(예정): `app/` (클라이언트) · `server/` (백엔드) · `shared/` (공용).

---

## 1. 커밋 컨벤션

타입은 영어, 요약은 한국어. 모노레포라 **스코프**로 어느 영역인지 표시(선택).

```
<type>(<scope>): <요약> (<추적ID 또는 #이슈>)

[본문 — 선택. 왜 이렇게 했는지]
```

- **type**: `feat` `fix` `docs` `refactor` `test` `chore`
- **scope**(선택): `app` · `server` · `shared`
- 요약은 50자 내외, 끝에 마침표 없이.
- 예: `feat(app): 좋아요 버튼 롱프레스 애니메이션 (F-05, #12)`

---

## 2. 브랜치 네이밍

```
<type>/<이슈번호>-<짧은-슬러그>
```

예: `feat/12-like-button` · `fix/23-login-crash`
`main` 직접 커밋 금지 — 모든 변경은 PR로만.

---

## 3. PR 컨벤션

- 제목은 커밋 컨벤션과 동일: `<type>(<scope>): <요약> (#이슈)`
- 본문은 PR 템플릿을 채운다.
- 관련 이슈를 `Closes #12`로 연결한다.
- **하나의 PR은 하나의 관심사만.** 리뷰 가능한 크기로.
- 병합은 **Squash merge** 권장.

---

## 4. 이슈 컨벤션

- 제목은 커밋 컨벤션과 동일: `<type>(<scope>): <요약> (Sx)`
- 본문은 이슈 템플릿(무엇을·왜 / 완료 기준 / 추적·의존 / 분류 근거)을 채운다.
- 모든 이슈에 **타입 1개 + 스코프 1개 + 영역(area) 1개 + 상태 1개 라벨 + 마일스톤 1개**를 붙인다.
- **서버 API 티켓의 area는 "받치는 화면"을 따른다** — 예: 문제 조회 API → `area: S3 퀴즈`. 화면과 무관한 작업은 `area: INFRA`(환경·배포·도구) 또는 `area: SYS 시스템`(파이프라인·푸시).
- 같은 화면이라도 **앱 작업과 서버 작업은 티켓을 분리**한다 (`scope:`로 구분) — 앱·서버 담당자가 병렬로 진행할 수 있게.

---

## 5. 라벨 컨벤션

| 그룹 | 라벨 |
|------|------|
| **타입** | `type: feat` `type: fix` `type: docs` `type: refactor` `type: chore` |
| **스코프** | `scope: app` (Next.js 앱) `scope: server` (Spring Boot 서버) |
| **영역** | `area: INFRA` `area: S0 로그인` ~ `area: S8 마이페이지` `area: SYS 시스템` |
| **상태** | `status: todo` `status: in-progress` `status: review` `status: blocked` |
| **기타** | `good first issue` `help wanted` `question` |

> 우선순위는 라벨이 아니라 **마일스톤**으로 표현한다(아래).

---

## 6. 마일스톤 (임팩트 × 난이도)

|              | 빨리 만들 수 있음 | 오래 걸림 |
|--------------|------------------|-----------|
| **임팩트 높음** | **M1** 핵심 | **M3** 큰 투자 |
| **임팩트 낮음** | **M2** 빠른 보완 | **M4** 나중 |

- **M1** — 지금 만드는 MVP 코어: 홈 · 퀴즈 · 해설 · 지식그래프 + 로그인.
- **M2** — 있으면 좋은 저비용 항목.
- **M3** — 중요하지만 시간이 드는 것.
- **M4** — 후순위.

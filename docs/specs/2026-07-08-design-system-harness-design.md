# 디자인 시스템 + 3단 하네스 설계 (이슈 #38)

- 날짜: 2026-07-08
- 관련 이슈: #38 (프론트엔드 디자인 설계 — 토큰·공통 컴포넌트)
- 상태: 설계 확정 — 구현 플랜은 `docs/plans/`에 별도 작성

## 1. 배경과 목표

**문제.** 팀원별 AI 세션이 각자 화면을 만들면 톤이 흩어진다. 첫 화면(홈, PR #85)은
`bg-[#f4f7fb]`·`rounded-[36px]` 같은 arbitrary value 하드코딩으로 구현되어 Vercel
preview에 배포됐고, 후속 화면이 이 디자인과 일관되게 만들어질 장치가 없다.
이슈 #38의 TC-38-22가 경고한 "토큰 확정 전 화면 착수 → 재작업" 리스크가 실현된 상태.

**목표.**

1. 기준 디자인을 레포 안에 문서·코드로 박제한다 (채팅·머릿속이 아니라).
2. 규칙을 어기면 자동으로 걸리는 하네스를 3단으로 구축한다.
3. 기존 홈 화면을 시스템 위로 재조립해 시스템 자체를 검증한다 (#38 완료 기준 4항).

## 2. 확정된 결정

| 결정 | 내용 |
|---|---|
| 기준 디자인 | **PR #85 preview 디자인을 공식 승격.** 사용자 제공 레퍼런스 시안 2장이 최상위 기준 |
| 브랜드 컬러 | 블루 프라이머리(#2f63ff 계열). 이슈 #38 본문의 "오렌지 포인트"는 폐기 — 오렌지는 스트릭·긴급 액센트로 역할 변경 |
| 강제 수준 | 3단 하네스: 스킬 지침(작업 전) + 정적 게이트(완료 전·CI) + 시각 게이트(UI 변경 PR 전) |
| 구현 방식 | 수제 미니멀: `@theme` 토큰 + `src/components/ui/` 직접 작성. shadcn 미도입, 신규 런타임 의존성 0 |
| 카탈로그·룰 관리 | **Storybook 채택** (devDependency) — 디자인 룰(MDX)과 컴포넌트 결과물(stories)을 한곳에서 관리. 별도 `/design` 라우트는 만들지 않음(카탈로그 이원화 방지) |

## 3. 기준 확정 (Source of Truth)

### 3.1 레퍼런스 이미지

`docs/design/references/`에 시안 6장을 커밋한다 (public 레포 노출은 승인됨 —
배포된 앱에서 보이는 디자인이므로 무해 판단).

| 파일 | 내용 |
|---|---|
| `home-today.png` | 홈/Today 단독 — 포인트·스트릭 카드, 오늘의 코스 블루 hero 카드, 이어보기 리스트, 4탭(Today·Course·Atlas·Basecamp) |
| `today-streak-recovery.png` | 투데이 변형 — 스트릭 복구 오렌지 배너, 진행바, 학습 잔디(그린 그리드), 티어 배지, 3탭 |
| `quiz-types-board.png` | 퀴즈 유형 4종 — 매칭형·OX(그린/레드 대형 버튼)·키워드 서술형·코드 문제(다크 코드 블록) |
| `quiz-flow-board.png` | 퀴즈 진행 6종 — OX·사지선다·빈칸·키워드 서술·코드 리딩·케이스 스터디, 상단 진행바 |
| `answer-insight.png` | 정답 해설/인사이트 — 정답 그린 배너, 핵심 정리 블루 카드, 이론·예시·실무 섹션, 파생 개념 칩, 다크 꼬리질문 카드 |
| `answer-feedback-popover.png` | 해설 상세 — 핵심 3줄 정리, 용어 팝오버(딤 오버레이), 꼬리 질문 CTA |

### 3.2 PRODUCT.md · DESIGN.md — impeccable init으로 작성

`/impeccable init`으로 `app/PRODUCT.md`·`app/DESIGN.md`를 생성한다.
단순 문서 생성이 아니라 하네스의 일부다: impeccable은 세션마다 `context.mjs`로
이 문서를 자동 로드하므로, 문서가 "사람이 읽는 규약"이 아니라 **"도구가 매 세션
주입하는 컨텍스트"**가 된다.

- ⚠️ impeccable의 자동 팔레트 시드(`palette.mjs`)는 **스킵** — 기존 브랜드 컬러(블루) 보존이 우선 (스킬 자체 규칙과 일치)
- DESIGN.md에 담을 것: 컬러 역할(블루=CTA·선택 상태, 오렌지=스트릭·긴급, 그린/레드=OX 정오답, slate 뉴트럴), radius 스케일, 그림자, 타이포 스케일, 스페이싱, 엄지 모티프 사용 규칙

### 3.3 `@theme` 토큰 (globals.css)

문서를 코드로 고정한다. 예시(값은 구현 시 레퍼런스에서 정밀 추출 — `impeccable extract` 활용):

```css
@theme {
  --color-primary: #2f63ff;   /* CTA·선택 상태 */
  --color-accent: #ff7a2f;    /* 스트릭 경고·긴급 */
  --color-ox-o: #22c55e;      /* OX 정답 그린 */
  --color-ox-x: #ef4444;      /* OX 오답 레드 */
  --radius-card: 2rem;        /* 외곽 카드 */
  --radius-control: 1rem;     /* 버튼·입력 */
  /* + surface·ink 뉴트럴, shadow, spacing, 타이포 스케일 */
}
```

- 컴포넌트는 `bg-primary`·`rounded-card`처럼 **토큰 이름으로만** 참조. `bg-[#2f63ff]` 금지
- 폰트: create-next-app 잔재(Arial) 제거 → Pretendard Variable(한국어 본문) + Geist Mono(코드 블록) 조합
- 기존 `prefers-color-scheme: dark` 분기 **제거** — 서비스는 라이트 고정. 다크는 그래프 화면(#10) 전용 토큰(`--color-graph-*`)으로 별도 네이밍해 일반 화면과 격리 (TC-38-13)

## 4. 공통 컴포넌트 + Storybook 카탈로그

### 4.1 첫 패스 컴포넌트 (YAGNI — 지금+다음 화면에 필요한 것만)

`src/components/ui/`:

| 컴포넌트 | 핵심 variant | 근거 |
|---|---|---|
| Button | primary CTA / secondary / ghost + loading·disabled 상태 | TC-38-06·09·10 (loading 중 연타 차단 포함) |
| Card | surface(흰 카드) / hero(블루 그라데이션) | 홈·퀴즈 공통 |
| Chip | 카테고리·상태 필 | 레퍼런스 전 화면에 등장 |
| BottomTabBar | 활성/비활성 탭 | 홈 기존 구현을 승격 |
| Feedback | info / "준비중" / error·재시도 / success | TC-38-17~19 (mock 화면 통일 안내) |
| Progress | 퀴즈 진행바 | 레퍼런스 퀴즈 화면 |
| Skeleton | 로딩 플레이스홀더 | TC-38-15 |
| EmptyState | 빈 데이터 안내 | TC-38-20 |

모달·토스트 등은 필요해지는 시점에 같은 규칙으로 추가한다.

### 4.2 품질 기준

- **impeccable craft 규칙 적용**: 본문 텍스트 대비 ≥4.5:1(WCAG AA), 터치 타깃 ≥44px(현행 `min-h-12`=48px 유지), 모션에 `prefers-reduced-motion` 대응, 시맨틱 z-index 스케일 — #38 접근성 TC(TC-38-24~29) 커버
- **시안에 없는 상태**(에러·빈·로딩·오프라인·준비중)는 감으로 짓지 않는다 — `lazyweb-quick-search`로 실서비스 학습 앱 레퍼런스를 확보한 뒤 디자인. (lazyweb MCP 미설치 환경에서는 생략 가능한 보조 단계)

### 4.3 Storybook 카탈로그 — 디자인 룰과 결과물의 단일 관리처

`@storybook/nextjs-vite` 프레임워크로 셋업(`npx storybook@latest init`),
`preview`에서 `globals.css`를 import해 앱과 동일한 토큰·폰트로 렌더링한다.
devDependency만 추가되므로 "신규 런타임 의존성 0" 결정과 충돌하지 않는다.

구성 (첫 패스는 이것만 — 애드온 최소화):

- **stories**: 컴포넌트 옆에 colocate (`button.stories.tsx`) — 전 variant·상태(loading·disabled·error 등)를 스토리로 열거. **`components/ui/`에 컴포넌트를 추가하면 스토리 작성이 필수** (§5 하네스로 강제)
- **MDX 문서 페이지**: 토큰 스와치(컬러 역할·radius·타이포·스페이싱) + 디자인 룰(DESIGN.md 요약, 엄지 모티프 사용법, OX 시맨틱 컬러 규칙) — 팀원이 코드를 읽지 않고 브라우징하는 진입점
- **실행**: `pnpm storybook` 로컬 전용. 호스팅·Chromatic(컴포넌트 단위 시각 회귀)은 필요가 증명되면 승격
- **visual-qa와의 역할 분담**: 시안 대조는 실제 앱 라우트(홈 등) 대상 유지. 토큰 변경 전파(TC-38-21)는 retrofit된 홈의 visual-qa + Storybook 육안 확인으로 검증

## 5. 3단 하네스

| 게이트 | 실행 시점 | 비용 |
|---|---|---|
| ① design-system 스킬 | UI 작업 시작 시 (에이전트 지침) | 0 |
| ② check-design 정적 검사 | verify-app 실행 시 + app 변경 PR의 CI | <1초 |
| ③ visual-qa 시안 대조 | **CI 자동 — app 변경 PR마다** (app-deploy.yml에 기 구현) + 로컬 선택 | 수 분 (엘리스 스프린트 리소스 종량제) |

### ① 작업 전 — design-system 프로젝트 스킬

`.claude/skills/design-system/SKILL.md` 신설. 내용: DESIGN.md 요약 + 토큰 목록 +
규칙(arbitrary value 금지 / 새 스타일이 필요하면 토큰을 먼저 추가 / 새 컴포넌트·variant는
스토리 필수 작성 / 시안에 없는 상태는 lazyweb 레퍼런스 확보). `app/CLAUDE.md`의 기존 "#38 전까지 `@theme`
토큰·공통 컴포넌트 금지" 조항을 **"UI 작업 시 design-system 스킬 필수 로드,
토큰·`components/ui`만 사용"**으로 교체한다. 팀원 세션도 레포를 열면 같은 규칙을 받는다.

### ② 정적 게이트 — check-design

`app/scripts/check-design.mjs`: 두 가지를 검사해 위반 목록과 함께 실패한다.

1. `src/**/*.tsx`에서 raw hex(`#2f63ff`)·arbitrary 클래스(`bg-[`, `rounded-[`, `shadow-[`, `text-[` 등) 검출
2. `components/ui/*.tsx`마다 대응하는 `*.stories.tsx` 존재 확인 (스토리 없는 컴포넌트 = 실패)

- 예외 탈출구는 `// design-ok` 주석 **한 가지**만
- `pnpm check:design`으로 등록. 실행 지점: **verify-app 4번 게이트** + **app-ci.yml 스텝**(기존 paths-filter 패턴으로 app 변경 시에만)
- pre-commit 훅이 아니다 — 커밋마다가 아니라 **작업 단위 + PR 단위**로만 돈다. grep 수준 스캔이라 기존 typecheck·build 대비 체감 증가 없음

### ③ 시각 게이트 — visual-qa 시안 대조 모드

**CI 파이프라인은 이미 존재한다** (`app-deploy.yml`의 `visual-qa` job, 2026-07-07 인프라
스펙에서 구현): app 변경 PR → Vercel preview 배포 → preview URL 대상 Playwright 스크린샷 →
엘리스 멀티모달 리뷰 → PR sticky 코멘트 + 스크린샷 아티팩트. soft gate(머지 차단 아님).
지금까지는 `ELICE_API_KEY` 미등록으로 리뷰가 스킵되고 있었다.

- **활성화**: `ELICE_API_KEY`·`ELICE_QA_BASE_URL`을 GitHub **Secret**으로 등록(레포가 public이라 워크플로우 로그 노출을 막기 위해 URL도 Secret — `app-deploy.yml`의 `vars.ELICE_BASE_URL` 참조를 `secrets.ELICE_QA_BASE_URL`로 변경), `ELICE_QA_MODEL`은 Variable. 엔드포인트 변수는 엘리스가 모델마다 다른 프록시 호스트(`mlapi.run/<모델별-ID>/v1`)를 발급하므로 공통 `ELICE_BASE_URL`이 아니라 역할 기반 `ELICE_QA_BASE_URL`로 명명(기존 `ELICE_QA_MODEL`과 짝). 시각 QA 모델은 팀 모델 운용 계획(§8) 기준 **Gemini 3.1 Pro**(`google/gemini-3.1-pro-preview`, 이미지 입력 담당) — 엔드포인트는 모델 라이브러리의 Gemini 페이지 값을 사용하고, 스크립트 기본값(gpt-5.2, 발급 모델에 없음)도 같은 ID로 갱신. 비용은 AI 스프린트 제공 리소스로 충당(serverless 종량제, 무제한 아님)
- **본 스펙에서 할 일**: `e2e/qa-routes.ts`의 `design` 필드에 레퍼런스 이미지를 연결해 휴리스틱 모드 → 시안 대조 모드(COMPARE_PROMPT)로 전환. CI·로컬 공통 적용
- **키 배포 문제 해소**: 팀원은 키가 필요 없다 — 리뷰는 CI가 수행하고, 로컬 실행은 키 없으면 스크린샷만 찍고 soft skip. 빠른 반복이 필요한 사람만 개인 `.env.local`에 키 보관(§8)
- **완료 규약**: PR의 visual-qa 코멘트에서 🔴은 해소 후 머지, 🟡은 판단 처리 (soft gate이므로 사람·에이전트가 지키는 규약)

### 보조 장치 (게이트 아님)

- `.coderabbit.yaml`의 `app/**` 지침에 토큰·공통 컴포넌트 사용 규칙 추가 → PR 리뷰에서 한 번 더
- `impeccable audit`은 **비차단** 품질 리뷰 도구로 수시 활용 (게이트로 넣지 않는 이유: 판단이 들어가는 도구라 pass/fail 자동화에 부적합, 게이트 증가는 마찰 증가)

## 6. 홈 화면 retrofit (시스템 검증 겸 부채 청산)

PR #85는 그대로 머지한다(로직·테스트 유효). 이후 본 브랜치에서 홈 컴포넌트를
토큰 + `components/ui`로 재조립한다.

- #38 완료 기준 4항 "대표 화면 1개 시안 검증"을 홈으로 충족
- 하드코딩 스타일 부채를 이 시점에 청산
- 기존 홈 테스트(vitest)가 깨지지 않아야 한다 — 시각만 바뀌고 동작·접근성 구조는 유지

## 7. 진행 순서 (팀원 교통정리)

1. **선행**: PR #85 머지
2. **본 브랜치**(`feat/38-design-system`): 기준 문서 → 토큰 → 컴포넌트+스토리 → Storybook·MDX → 하네스 3종 → 홈 retrofit → verify-app + visual-qa 통과 → PR (Storybook 셋업 포함 1일 예상)
3. **팀원**: #38 머지 전에는 스타일 무관 작업(로직·테스트·mock 데이터·라우팅 골격), 머지 후 rebase하고 토큰·컴포넌트로 UI 조립. 이후 모든 화면 이슈는 하네스 아래에서 진행

## 8. 엘리스 API 키 운영

### 모델 운용 계획 (2026-07-08 확정)

발급 키 1개가 3개 모델 공용. 엔드포인트는 모델별로 다름(`https://mlapi.run/<모델별-ID>/v1`).
등록은 **소비자가 생기는 시점**에 한다 — 미리 등록하면 파이프라인 설계에 따라 네이밍 재작업 리스크만 생김.

| 역할 | 모델 | 소비처 | 설정 보관처 |
|---|---|---|---|
| 시각 QA (이미지 입력) | **Gemini 3.1 Pro** | app CI `visual-qa` job · 로컬 | GitHub Secret/Variable + 개인 `.env.local` — **지금 세팅** |
| 문제·해설 생성 | GPT-5.4 | server(Spring) — 예정 | SSM `/thumbsup/prod/*` (server 설정 경로) — 파이프라인 설계 시 등록 |
| 대량 문제 생성 | GPT-5 mini | 배치/스크립트 — 예정 | 소비자 확정 시 결정 |

- **1차 보관처 — GitHub**: `ELICE_API_KEY`·`ELICE_QA_BASE_URL`(엔드포인트, `/v1`까지)은
  repo Secret, `ELICE_QA_MODEL`은 repo Variable. 이것으로 CI 시각 QA가
  활성화되며(§5-③), **팀원 개별 키 배포가 불필요**해진다. 주의: Secret은 등록 후 값 재조회
  불가(write-only)이므로 로컬 사용과는 별개
- **2차(선택) — 개인 `.env.local`**: 로컬에서 리뷰까지 돌리며 빠르게 반복하고 싶은 사람만.
  커밋된 `app/.env.example`을 복사해 채운다 (`cp .env.example .env.local`).
  `.env*`는 gitignored + gitleaks CI 이중 방어. `visual-qa.ts`에 `process.loadEnvFile()`
  (Node 22, try/catch) 자동 로드를 추가해 셸에 키 붙여넣는 방식 제거. 키 없이 로컬 실행하면
  스크린샷만 저장(soft skip)되므로 키 없어도 육안 QA는 가능
- **워크트리 주의**: `.env.local`은 gitignored라 워크트리에 따라오지 않는다 — 메인 레포에서 복사 필요

## 9. 이슈 #38 미해결 질문 해소

| 질문 | 결정 |
|---|---|
| 공통 컴포넌트 최종 목록 | §4.1의 8종 (탭바·스켈레톤·빈상태·"준비중" 포함). 모달·토스트는 필요 시 추가 |
| 대표 화면 검증 대상 | 홈 (retrofit 방식) |
| 다크 테마 범위 | 그래프 화면(#10) 한정. 시스템 `prefers-color-scheme` 다크모드는 미지원(라이트 고정) |
| 모션/애니메이션 토큰 | 첫 패스 제외. `prefers-reduced-motion` 대응만 컴포넌트 규칙으로 |
| 토큰 미준수 방지 방식 | 3단 하네스 (§5) — lint 규칙 대신 전용 check-design 스크립트 |
| 컴포넌트 카탈로그 도구 | Storybook (stories 필수 규칙 + MDX 디자인 룰 문서, §4.3) |
| 문서 승인·확정 오너 | PR 리뷰·머지로 갈음 (현행 브랜치 보호 정책과 일치) |
| 토큰 변경 전파 정책 | retrofit된 홈 visual-qa 재실행 + Storybook 육안 확인 (§4.3) |
| 터치 타깃·접근성 수치 | 터치 타깃 ≥44px, 텍스트 대비 WCAG AA(4.5:1) |

## 10. 완료 기준

- [ ] 이슈 #38 완료 기준 4항(PRODUCT/DESIGN 문서·토큰·공통 컴포넌트·대표 화면 검증) 전부 충족
- [ ] check-design이 로컬(verify-app)과 CI에서 위반을 실제로 검출하는 것 확인 (고의 위반 테스트)
- [ ] visual-qa 시안 대조 모드로 홈 리포트 생성 확인
- [ ] 홈이 토큰·공통 컴포넌트만으로 렌더링되고 기존 테스트 통과
- [ ] Storybook 기동(`pnpm storybook`) + 전 ui 컴포넌트 스토리·토큰 MDX 페이지 존재
- [ ] `app/CLAUDE.md`·verify-app·visual-qa 스킬 문서 갱신

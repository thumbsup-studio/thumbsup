# 퀴즈 게이미피케이션 설계 — #211 · #197

- **날짜**: 2026-08-02
- **상태**: 승인 (구현 대기)
- **관련 이슈**: [#211 문제 풀 때 게임적인 효과 — 정답 피드백·이펙트 (S3)](https://github.com/thumbsup-studio/thumbsup/issues/211) · [#197 정답 피드백 칭찬 강화 — 문구 다양화·맥락별 연출 (S4)](https://github.com/thumbsup-studio/thumbsup/issues/197)
- **브랜치**: `feat/211-quiz-gamification`
- **리뷰**: Codex(`gpt-5.6-luna`, effort=max) 읽기 전용 설계 리뷰 1회 — 지적 11건 반영, 3건 반박(§13)

---

## 1. 배경과 문제

2026-07-18 팀 회고에서 **게이미피케이션 부족**이 4명에게서 지적됐다(`R-08`). 핵심 가치가 "도파민·중독성"인데 장치가 얕다는 것.

**코드에서 확인한 실제 공백**: 기존 팡파레(`app/public/lottie/fanfare.lottie`, 116KB)는 **해설 화면(S4)** 에서 연속 3정답 이상일 때만 뜬다(`insight-page.tsx:53-67`). 반면 **퀴즈 화면(S3)은 이펙트가 0개**다 — `play-page.tsx:207`이 채점 결과를 받자마자 `/insight`로 라우팅해서 **"맞았다!" 하는 판정 순간 자체가 화면에 존재하지 않는다.**

## 2. 브랜드 톤 충돌 해소

`PRODUCT.md` Anti-references는 *"듀오링고 아류식 과다 장식 — 요란한 사운드/이펙트 UI. 성인 개발자 대상이므로 마스코트는 장식에 머물고 주인공이 되지 않는다"* 를 금지한다. 반면 #197은 *"정답 피드백을 의도적으로 과하게 만든다"* 를 요구한다.

**해소: 단계형 에스컬레이션.** 매번 과하게가 아니라 "가끔 크게". 도파민 설계의 핵심은 절대 강도가 아니라 변동 보상이며, 매 정답마다 컨페티가 터지면 며칠 안에 무감각해진다. PopCap의 celebration hierarchy(Peggle·Bejeweled)와 같은 패턴이고 `PRODUCT.md`를 위반하지 않는다.

**보강 근거** — [CHI 2024 "How does Juicy Game Feedback Motivate?"](https://dl.acm.org/doi/10.1145/3613904.3642656): juicy 피드백은 appeal·선호·즐거움을 올리지만 **mastery·몰입·객관적 수행에 대한 증거는 혼재**. 연출은 재접속을 위한 것이지 학습 효과를 위한 게 아니므로, **해설(진짜 콘텐츠)을 침범하면 순손실**이다. #211 완료 기준 3번("학습 흐름을 방해하지 않는 선")의 근거.

## 3. 연출 사다리

기존 S4 팡파레는 `insight-page.tsx:54`에서 **연속 3정답 이상**이면 뜬다(#171·#172 산출물). 여기에 S3 연출을 추가하면 3콤보에서 컨페티가 두 번(S3 → S4) 터진다.

**결정: 팡파레 발동 조건을 "연속 3정답"에서 "완주 + 퍼펙트"로 좁힌다.** 세션에서 최대 콤보는 곧 퍼펙트이므로 사다리 꼭대기와 완주 순간이 하나로 모이고, 사다리 전체가 화면을 넘나들며 한 번씩만 터진다.

| 콤보 | S3 (퀴즈 화면) | S4 (해설 화면) |
|---|---|---|
| 1 | 체크 팝 + 칭찬 1줄 (`subtle`) | — |
| 2 | + 콤보 칩 바운스 (`combo`) | — |
| 3+ | + 칩 주변 컨페티 (`confetti`) | — |
| 퍼펙트 | 컨페티 | **완주 카드 + 풀스크린 팡파레** |

- **퍼펙트 정의**: `correct >= totalCount`. **5를 하드코딩하지 않는다** — `QuizNextResponse.totalCount`는 옵셔널(`quiz.ts:22-24`)이고 없으면 `defaultStepTotal`(5)로 fallback하는 기존 규칙을 그대로 쓴다.
- **재도전(#63) 성공도 퍼펙트에 포함한다.** `play-page.tsx:184-186`의 기존 주석("재도전 성공이 연속을 잇도록")과 일관되게, 최종 정답이면 정답으로 센다.
**복습 플로우** — 같은 규칙을 적용한다. 구체적으로:
- S3 오버레이는 복습에서도 그대로 뜬다(복습은 `PlayPage`를 재사용하므로 `ReviewContext.streak`을 `combo`로 넘기면 끝)
- `insight-page.tsx`의 복습 팡파레(현행 `review.streak >= 3`)를 **제거**하고, `ReviewSummaryPage`에 **퍼펙트(`correct >= REVIEW_STEP_TOTAL`) 팡파레를 추가**한다. `ReviewSummaryPage:13`이 이미 `isPerfect`를 계산하고 있어 조건은 그대로 쓴다
- 복습에는 완주 요약 카드를 새로 만들지 않는다 — `ReviewSummaryPage`가 이미 그 역할이고, `bestCombo`는 복습 URL에 없으므로 표시하지 않는다
- **#172 동작 변경.**

## 3-1. 개정 (2026-08-03) — 연출 위치를 해설 화면으로 옮김

초안은 판정 순간을 **퀴즈 화면(S3)** 에 되찾는 설계였다. 로컬에서 실제로 만져 본 결과 두 가지가 뒤집혔다.

1. **아래에서 올라오는 바텀시트가 거슬린다.** 판정을 위해 흐름을 한 번 끊는 것 자체가 부담이었다.
2. **정작 밋밋한 건 판정이 아니라 풀이 과정 전체였다.** 콤보 연출 하나로는 "게임 같다"는 느낌이 안 난다.

**개정된 역할 분담:**

| 화면 | 역할 | 수단 |
|---|---|---|
| **S3 풀이** | 조작감 — 만지는 맛 | 선택지 스프링 반응·스태거 등장·카드 진입·버튼 press·진행바 (전부 CSS) |
| **S4 해설** | 보상 — 터지는 맛 | 정답 배너 팝·체크 그려지기·콤보 칩·컨페티·완주 카드·팡파레 |

이에 따라 **바텀시트 오버레이(`celebration-overlay.tsx`)와 `holdMs` 자동 이동·중복 라우팅 가드를 전부 제거**하고, 제출 → 즉시 라우팅이라는 기존 계약으로 되돌렸다. `celebration-logic`은 그대로 두되 소비처를 해설 화면(`verdict-banner.tsx`)으로 옮겼다.

**부수 변경:**
- 완주 카드의 "보리 밥을 줬어요" 줄 삭제 — 마스코트를 굳이 여기서 부를 이유가 없다는 판단.
- 재도전 성공 여부를 해설 화면이 알아야 하므로 URL에 `retry=1`을 추가. **맞힌 경우에만** 싣는다(틀린 재도전엔 특별 칭찬이 없으므로 파라미터 의미를 좁힌다).
- `Button`에 `active:scale-95`, `Progress`에 `duration-500 ease-out` — 공통 컴포넌트에 넣어 앱 전체가 같은 촉감을 공유하게 했다.

**포인트 연동은 범위 밖으로 뺐다.** 포인트를 어디에 쓰는지가 아직 정해지지 않아(#24, M4) 화면에 숫자만 늘리는 셈이 된다.

**Rive 재검토 결과: 여전히 미채택.** 이번 목표가 "UI 엘리먼트 모션"이라 CSS가 더 빠르고 토큰 체계 안에 있으며 `prefers-reduced-motion`도 공짜다. Rive의 강점(상태 기반 캐릭터)이 값을 하는 건 보리가 S3에 등장하는 #57(M4) 시점이다.

## 4. 판정 직후 흐름

```
[정답 확인] 탭
  → submitQuizAnswer()
  → (오답 + 중·상 난이도 + 재도전 미사용 → 기존 재도전 분기로. 연출 없음)
  → applyAnswer(session, isCorrect)             … session-progress
  → getCelebration({..., prefersReducedMotion}) … celebration-logic
  → CelebrationOverlay 렌더 + 선택지 채색
  → holdMs 경과 또는 사용자가 [계속] 탭 → router.push('/insight?...')
```

자동 이동의 유일한 위험(기다리기 싫은데 못 넘어감)은 **[계속] 버튼**으로 해소한다. `prefers-reduced-motion: reduce`면 `holdMs = 0`.

**중복 내비게이션 차단**: `navigateOnce` ref로 `router.push`를 1회로 묶고, 언마운트 시 `clearTimeout`한다. 타이머와 탭이 동시에 발화하거나 React StrictMode가 이펙트를 두 번 돌려도 이동은 한 번이다.

## 5. 아키텍처 — 3계층 분리

현재 `play-page.tsx`는 630줄이고 localStorage 키 규약·콤보 로직이 컴포넌트 안에 있다(`play-page.tsx:610-630`). 연출까지 얹으면 손대기 어려워지므로 셋으로 가른다.

### (a) `app/src/features/play/session-progress.ts` — 세션 상태 (신규)

```ts
type PlaySession = {
  answered: number;   // 채점한 문제 수
  correct: number;    // 맞힌 수
  combo: number;      // 현재 연속 정답
  bestCombo: number;  // 이번 스텝 최고 콤보
};

applyAnswer(session: PlaySession, correct: boolean): PlaySession  // 순수 함수
```

- `play-page.tsx:610-630`의 헬퍼 4개를 이 모듈로 이동·확장
- 저장 키: `thumbsup:play-session:{stepOrder}`
- **순수 함수와 얇은 read/write 래퍼를 분리** → localStorage 없이 단위 테스트 가능
- **복습 모드는 이 모듈을 쓰지 않는다.** 기존대로 URL(`rc`/`rs`)로 상태를 나른다. 복습을 `PlaySession`으로 어댑트하지 **않는다** — 복습 URL엔 `bestCombo`가 없어 성립하지 않고, 애초에 필요하지도 않다(§5(b) 참조).

**구키 마이그레이션** — 배포 시점에 세션 진행 중이던 사용자를 위해, 새 키가 없고 구키 `thumbsup:insight-correct-streak:api-quiz:{stepOrder}`가 있으면 1회 읽어 `{answered: 0, correct: 0, combo: <구값>, bestCombo: <구값>}`로 seed하고 구키를 지운다. `answered`·`correct`는 복원 불가이므로, **완주 카드는 `answered === totalCount`일 때만 "정답 n/N" 줄을 렌더**한다(마이그레이션된 세션은 최고 콤보만 표시). 사용자에게 틀린 숫자를 보여주지 않는다.

### (b) `app/src/features/play/celebration-logic.ts` — 연출 결정 (신규, 순수 함수)

```ts
type CelebrationTier = "none" | "subtle" | "combo" | "confetti";
type Celebration = {
  tier: CelebrationTier;
  praise: string;         // 칭찬 문구 (#197)
  comboCount: number;     // 칩 표시용 (2 미만이면 칩 없음)
  badge: string | null;   // 맥락 배지
  holdMs: number;         // 자동 이동 전 유지 시간
};

getCelebration(input: {
  correct: boolean;
  combo: number;
  difficulty: QuizDifficulty;
  wasRetry: boolean;
  quizId: number;
  prefersReducedMotion: boolean;
}): Celebration
```

- **입력이 narrow하다** — 일반 모드는 `PlaySession.combo`를, 복습 모드는 `ReviewContext.streak`을 넘긴다. 두 모드가 같은 타입을 공유할 필요가 없다.
- **tier는 콤보만으로** 결정 — 1:`subtle` / 2:`combo` / 3+:`confetti`
- **badge는 맥락으로** 결정 — `difficulty === "HARD"` 정답 → "난이도 상 정복", 재도전 성공(`hasUsedRetry && correct`) → "다시 잡았어요". 두 축을 섞지 않는다
- 예외 한 줄: badge가 있는데 tier가 `subtle`이면 `combo`로 승급
- **문구 다양화(#197)** — 풀에서 고르되 `quizId`를 시드로 한 **결정적 선택**. 리렌더에 문구가 안 바뀌고 테스트 가능
- **오답은 `tier: "none"` + 응원 문구.** 콤보가 깨진 것을 시각적으로 강조하지 않는다 — `PRODUCT.md` 브랜드 톤("훈계하거나 과장된 축하 문구를 쓰지 않는다")
- **`prefersReducedMotion`이 true면 `holdMs = 0`, `tier`는 최대 `subtle`.** 순수 함수가 결정하므로 테스트 가능하다.

`holdMs` 초안: `subtle` 500 / `combo` 700 / `confetti` 1000 / `none` 400 — Storybook에서 튜닝해 확정한다.

### (c) `app/src/features/play/components/celebration-overlay.tsx` — 표현 (신규 + stories)

`Celebration`을 받아 그리기만 한다. canvas-confetti·CSS 애니메이션이 전부 여기 갇힌다.

- `components/ui/`가 아니라 feature 하위 — 퀴즈 전용이라 디자인 시스템 프리미티브가 아니다. (`check:design`의 stories 강제는 `components/ui/`에만 적용되므로 이 스토리는 게이트 대상이 아니다. 그럼에도 **연출 강도 튜닝용**으로 동봉한다 — #211 완료 기준 3번을 여기서 반복 재생하며 맞춘다.)
- **[계속]은 `min-h-12` `<button>`** — `div onClick`이 아니다. 키보드·스크린리더로 접근 가능해야 하고 터치 타깃 48px를 지킨다.
- 기존 `Chip`(`components/ui/chip.tsx`)·`CheckIcon` 재사용
- **컨페티 색은 `getComputedStyle(document.documentElement)`로 CSS 변수에서 읽는다** — 소스에 raw hex를 넣지 않아 `check:design` 통과. **변수가 비어 있으면 컨페티를 생략한다**(하드코딩 fallback 금지)
- canvas-confetti 호출에 `disableForReducedMotion: true`
- canvas-confetti는 **사용자 이벤트 핸들러 안에서** `await import("canvas-confetti")` — 모듈 top-level이나 render 중에 호출하지 않는다. SSR `document` 접근을 피하고 초기 번들에서 빠진다.

## 6. 완주 요약 카드

마지막 문제의 해설 화면 하단에 렌더한다(새 라우트 없음).

```
[CircleCheckIcon] 오늘의 학습 완료
  정답        4 / 5        ← answered === totalCount 일 때만
  최고 콤보    3
  보리        밥을 줬어요
[      홈으로 가기      ]
```

- 퍼펙트면 기존 `fanfare.lottie` 풀스크린 재생
- **아이콘은 이모지가 아니라 기존 컴포넌트를 쓴다** — `CircleCheckIcon`·`DogIcon`(`components/icons.tsx`). `ReviewSummaryPage:20-22`가 이미 `CircleCheckIcon`으로 같은 성격의 완료 헤더를 그리고 있어 시각적으로 맞춘다.
- **보리 줄에 숫자를 쓰지 않는다.** `Mascot.MAX_FULLNESS = 100` 캡 때문에 포만감이 90이면 `FEED_AMOUNT = 20`을 줘도 +10만 오른다. "+20%"는 항상 참이 아니다.
- **`feedMascot()`은 현행 fire-and-forget 유지**(`play-page.tsx:205`). await하면 `client.ts:38`의 `REQUEST_TIMEOUT_MS = 15_000` 때문에 축하 연출이 최대 15초 막힌다. 카드가 포만감 수치를 안 쓰므로 응답이 필요 없다.

**URL 파라미터**: 마지막 문제에서 `/insight?...&done=1&c=4&bc=3`. localStorage로 넘기면 뒤로가기·bfcache에서 값이 흔들린다(PR #160에서 이미 겪은 문제). 복습 모드가 쓰는 URL 패턴과도 동일하다.

**신뢰 경계**: `c`·`bc`는 브라우저가 만든 값이므로 **`clamp(0, totalCount)`로 검증**하고, 완주 팡파레는 **one-shot**(같은 파라미터로 재진입하면 카드는 보이되 팡파레는 재생하지 않음 — 기존 `dismissedFanfareKey` 패턴 재사용)으로 처리한다. 서명·서버 토큰은 도입하지 않는다(§13 반박 1).

## 7. 기술 선택

| 후보 | 판정 |
|---|---|
| **CSS 토큰 + 기존 Lottie + canvas-confetti** | **채택.** 사다리 1~2단계는 `globals.css @theme` keyframes(디자인 게이트와 일치, `prefers-reduced-motion`을 CSS로 처리). **신규 애니메이션 런타임은 0개** — 추가 의존성은 `canvas-confetti`(6kB gz, **ISC**) 1개 + `@types/canvas-confetti`뿐 |
| Rive (`@rive-app/react-canvas`) | 미채택. WASM ~78KB CDN 요청 추가, 팀에 Rive 편집자 없음, Community 에셋 CC BY 출처 표기 의무. 제값을 하는 건 캐릭터 연출(#57)인데 그건 M4 |
| dotLottie state machine | 미채택. 설치된 `@lottiefiles/dotlottie-web@0.76.0`이 `stateMachineLoad` 등을 지원하지만(experimental 표기), 사다리 1~2단계는 UI 요소(칩·선택지) 애니메이션이라 Lottie 캔버스로 다룰 수 없다. 새 `.lottie` 에셋 제작 부담만 남는다 |

- **사운드 제외** — `PRODUCT.md` anti-reference가 "요란한 사운드/이펙트 UI"를 명시 금지하고, 사용 맥락(출퇴근길·공공장소)과 불일치.
- **햅틱은 Android만 progressive enhancement** — iOS Safari는 Vibration API 미지원. `<input switch>` 우회는 **iOS 26.5 이후 신뢰할 수 없다는 커뮤니티 보고가 있으나 Safari 26.5 공식 릴리스 노트에는 기재가 없다** — 실기기 확인 전까지 iOS는 없는 것으로 취급한다. `navigator.vibrate`가 있으면 쓰고 없으면 조용히 넘어간다.

## 8. 오픈소스 조사 결과

**코드 이식 대상 없음.** Claude 1차·2차 조사 + Codex 교차 검증 결과 일치.

| 대상 | 결론 |
|---|---|
| bluedone/react-quiz, VINAYAK9669/React-QuizApp, ebonow/react-quiz, Quizzy | 튜토리얼급. 콤보·스트릭 피드백 메커니즘 부재 |
| [Sup3r-Us3r/quiz](https://github.com/Sup3r-Us3r/quiz) (MIT) | 가장 관련 높음 — 오답 shake·Skia 체크마크 path 애니메이션·Expo Haptics. React Native라 이식 불가, 기법만 참고. **오답 shake는 브랜드 톤(응원하는)과 불일치해 미채택** |
| [neetos-llc/react-quiz-components](https://github.com/neetos-llc/react-quiz-components) (MIT) | Codex 발굴. instant feedback·continueTillCorrect 제공하나 2019년 v0.2.0의 JSON·로컬 단일 컴포넌트 — 서버 채점·#63 재도전·복습 URL 계약을 통째로 갈아야 해서 미채택 |
| learnhouse/learnhouse (1.7k★) | 게이미피케이션이 코스 단위지 문항 단위 피드백이 아님 |
| supabase-community/kahoot-alternative | 실시간 멀티플레이가 본질 — 1인 학습과 구조 상이 |
| [Trophy UI](https://github.com/trophyso/ui) (MIT) | streak/achievement/points/leaderboard 컴포넌트. per-answer juice가 아니고 #24(M4) 범위. shadcn 레지스트리라 자체 토큰 체계 리토큰화 비용이 붙는다 |

## 9. 에러 처리

- canvas-confetti dynamic import 실패 → 컨페티만 조용히 생략, 나머지 연출 유지
- CSS 변수 조회 실패(빈 문자열) → 컨페티 생략
- `feedMascot()` 실패 → 카드에 영향 없음(수치를 쓰지 않으므로)
- Lottie 로드 실패 → 기존 동작대로 미표시
- **연출 계층은 절대 throw하지 않는다** — 채점 결과 전달이 연출 때문에 막히면 안 됨

## 10. 접근성

- 색만으로 정오답 구분 금지 → 체크/엑스 아이콘 + 텍스트 병행 (`PRODUCT.md` Anti-references)
- 칭찬 문구는 `aria-live="polite"`
- `prefers-reduced-motion` → `matchMedia`로 감지해 `getCelebration`에 주입. 컨페티·팡파레·바운스 전부 끄고 `holdMs = 0`
- [계속]은 `<button>`, 터치 타깃 ≥48px

## 11. 테스트

| 파일 | 검증 |
|---|---|
| `session-progress.test.ts` (신규) | 콤보 증가·오답 리셋·bestCombo 유지·answered/correct 누적 · **구키 마이그레이션** · localStorage 사용 불가 환경 |
| `celebration-logic.test.ts` (신규) | 사다리 경계값(1/2/3), HARD·재도전 badge, subtle→combo 승급, 오답 none, 문구 결정성, **reduced-motion이면 holdMs=0·tier 상한** |
| `play-page.test.tsx` (확장) | 오버레이 노출 → holdMs 후 라우팅 / [계속] 탭 시 즉시 / **중복 push 차단(타이머+탭 동시, StrictMode 이중 마운트)** / 언마운트 후 타이머 미발화 / 재도전 분기엔 연출 없음 |
| `insight-page.test.tsx` (확장·수정) | 팡파레 조건 변경으로 **5묶음 재작성**(현행 220·244·260·294·319행) · done 파라미터 → 완주 카드 · **URL 조작 clamp** · **재진입 시 팡파레 미재생** · `answered !== totalCount`면 정답 줄 생략 · **totalCount 가변** |

## 12. 비범위

사운드 · 서버 세션 결과 API · 보리 캐릭터 반응(#57, M4) · 포인트 시스템(#24, M4) · 새 완주 전용 라우트 · 완주 결과의 서버 검증(§13)

## 13. Codex 리뷰 중 반박한 지적

1. **"완주 URL을 서버 확정 결과 또는 opaque token으로"** — 과한 대응. 금전적 보상이 없는 축하 연출이고, 기존 복습 플로우가 이미 `rc`/`rs`를 URL로 신뢰한다(`review-params.ts:37-69`). 여기만 서명하면 일관성이 깨지고 `scope: server`가 붙어 M2("빠른 보완") 성격을 벗어난다. URL 조작의 최대 이득은 자기 화면에 컨페티가 한 번 더 뜨는 것 → **clamp + one-shot**으로 충분.
2. **"포만감 `f`를 서버에서 재조회"** — 재조회 대신 **카드에서 수치를 없앴다**(§6). 요청이 하나도 안 늘고, 캡 때문에 어차피 부정확했을 숫자를 아예 안 쓴다.
3. **"Trophy UI가 토큰과 충돌한다고 단정할 수 없다"** — 타당한 지적이라 §8 표현을 "본질적 충돌"에서 "리토큰화 비용"으로 완화했다. 결론(미채택)은 유지 — per-answer juice가 아니라 #24(M4) 범위다.

## 14. 검증 게이트

`verify-app` 스킬 — `pnpm typecheck` → `pnpm lint` → `pnpm build` → `pnpm check:design` 전부 통과 후에만 완료 보고.

# 해설 꼬리 질문 풀기 + 히스토리 하단 탭바 복구

- 이슈: #122
- area: S4 해설 / scope: app
- 시안: Claude Design `꼬리문제풀기.dc.html` (project `b591fa62-…`)

## 배경 · 문제

두 가지를 한 이슈로 묶어 처리한다.

1. **꼬리 질문 부재 (신규 기능)** — 해설(Insight) 화면 하단엔 "다음 문제 풀기"만 있어 학습이 `문제 → 해설 → 문제`로만 순환한다. 방금 배운 개념을 한 걸음 더 파고드는 "꼬리 질문" 경험이 없다.
2. **히스토리 탭바 소실 (버그)** — 홈에서 히스토리 탭으로 진입하면 하단 홈 navbar가 사라진다. 홈(`HomePage`)만 탭바를 렌더하고 히스토리 화면(`AtlasPage`)엔 탭바가 없기 때문이다. 게다가 홈 탭바의 "홈" 버튼엔 `onClick`이 없어(홈에서만 쓰던 전제) 그대로 재사용하면 히스토리 → 홈 복귀가 불가능하다.

## 목표 · 비목표

**목표**
- 해설 → 꼬리질문 → 다음 문제로 이어지는 흐름을 만든다. 꼬리질문은 답을 먼저 가려 스스로 떠올리게 하는 2단계 화면.
- 홈·히스토리가 하단 탭바를 공유해, 어느 탭에서도 탭바가 보이고 탭 간 이동이 된다.

**비목표**
- 백엔드 API 연동 — 계약 미확정. **목업 데이터**로 구현하고 후속 이슈에서 교체한다.
- 프로필 탭 실제 화면 — 기존처럼 "준비 중" 토스트 유지.
- 미사용 제네릭 컴포넌트 `components/ui/bottom-tab-bar.tsx`(스토리북 데모 전용) 는 건드리지 않는다.

## 전체 흐름 (변경 후)

```
/play?question=N ──(정답 확인)──▶ /insight?question=N&correct=…&streak=…
                                        │  해설 화면 — 하단 CTA:
                                        │   ① 꼬리 질문 풀기 ──▶ /follow-up?question=N&correct=…&streak=…
                                        │   ② 다음 문제 풀기 ──▶ /play?question=N+1   (마지막이면 홈으로)
                                        ▼
                        /follow-up?question=N  (revealed: boolean 로컬 state)
                         ├ 상태A 답가림 : "답 확인하기"(→상태B) / "이 질문 건너뛰기"(→다음 본 문제)
                         └ 상태B 답확인 : "해설로 돌아가기"(◀ /insight 복귀) / "다음 문제로"(▶ 다음 본 문제)
```

결과적으로 `문제 → 해설 ⇄ 꼬리질문 → 다음 문제 → 해설 ⇄ 꼬리질문 …`. 꼬리질문을 **별도 라우트**(`/follow-up`)로 둬 "해설로 돌아가기"의 양방향(⇄) 이동이 브라우저 히스토리와 자연스럽게 맞물린다. 본 문제 1개당 꼬리질문 1개.

## 요구1 — 꼬리 질문 (features/play 내부)

꼬리질문은 본 문제(`PlayQuestion`)에서 파생되므로 `features/play` 안에 둔다.

### 데이터 모델 (`features/play/types.ts`)

```ts
export type FollowUpQuestion = {
  category: string;        // 헤더 카테고리 라벨 (예: "동시성")
  difficulty: Difficulty;  // 기존 타입 재사용
  question: string;        // 꼬리 질문
  oneLineAnswer: string;   // 한 줄 답
  explanation: string;     // 해설(상세 정리)
  usageExample: string;    // 실무 사용처
  keywords: { term: string; description: string }[]; // KeywordTooltipText 하이라이트+툴팁
};

// BaseQuestion 에 optional 필드 추가
//   followUp?: FollowUpQuestion;
```

- 목업(`mock-play-session.ts`): 기존 5개 본 문제(OS: 프로세스/스레드/동시성) 각각에 주제에 맞는 `followUp`을 채운다. 시안의 정렬/탐색/해시 예시는 형식 참고만.
- `keywords`는 기존 `insight.keywords`와 같은 형태 → `KeywordTooltipText`를 그대로 재사용해 `[[키워드]]` 하이라이트(사용자 결정: 툴팁 포함 통일).

### 라우팅

- `app/follow-up/page.tsx` (신규) — `/insight` 페이지와 동일 패턴: `searchParams` → `clampQuestionIndex` → `FollowUpPage` 렌더. `export const dynamic = "force-dynamic"`.
- 진입: 해설 하단 "꼬리 질문 풀기" → `/follow-up?question=N&correct=…&streak=…` (복귀용 파라미터 전달).
- "해설로 돌아가기" → `/insight?question=N&correct=…&streak=…` (원래 해설 상태 그대로 복원).
- "다음 문제로" / "이 질문 건너뛰기" → `isLast ? "/" : /play?question=N+1`.

### 컴포넌트 (`features/play/components/follow-up-page.tsx`, 신규)

```ts
type FollowUpPageProps = {
  session: PlaySession;
  questionIndex: number;
  correct: boolean;   // /insight 복귀 URL 재구성용
  correctStreak: number;
};
// 로컬 state: const [revealed, setRevealed] = useState(false);
```

- **헤더**: 뒤로 버튼 + `category` + "꼬리 질문" 타이틀 + 난이도 배지, 진행률(`{N}번 문제에서 이어짐` · `{N+1}/{total}` · Progress). 진행률은 기존 `getProgressPercent`·`getDifficultyLabel` 재사용.
- **본문**:
  - 꼬리 질문 카드 (물음표 아이콘 + `question`)
  - 한 줄 답 카드 — `revealed=false`면 스켈레톤 + eye-off 아이콘 + "먼저 스스로 답을 떠올려 보세요"; `true`면 `oneLineAnswer`(KeywordTooltipText).
  - 상세 정리(해설·실무 사용처) — `revealed=false`면 흐릿(opacity)/스켈레톤, `true`면 공개.
- **하단 CTA**: `revealed=false` → "답 확인하기"(→`setRevealed(true)`) / "이 질문 건너뛰기"(→다음 본 문제). `revealed=true` → "해설로 돌아가기" / "다음 문제로".

### 해설 화면 수정 (`features/play/components/insight-page.tsx`)

- 하단 CTA 영역에 "꼬리 질문 풀기" 버튼 추가 (`question.followUp`이 있을 때만 렌더). 링크: `/follow-up?question={questionIndex}&correct=…&streak=…`.
- 기존 "다음 문제 풀기/홈으로 돌아가기" 버튼은 유지.

## 요구2 — 히스토리 하단 탭바 복구 (탭바 공용화)

### 원인
`features/home/components/bottom-tab-bar.tsx`(앱 네비, 아이콘 3탭)는 `HomePage`와 그 테스트에서만 쓰이고, 히스토리(`AtlasPage`)엔 탭바가 없다.

### 설계
- `features/home/components/bottom-tab-bar.tsx` → **`components/ui/app-tab-bar.tsx`로 이동**하고 라우팅을 내부화한다.

```ts
// components/ui/app-tab-bar.tsx
export function AppTabBar({ activeTab }: { activeTab: "home" | "history" | "profile" }) {
  // 내부에서 useRouter + useAppToast
  //   home    → router.push("/")
  //   history → router.push("/history")
  //   profile → showToast({ message: "프로필은 준비 중입니다." })
}
```

- `HomePage`: `<AppTabBar activeTab="home" />` 로 교체(기존 `onHistoryClick`/`onProfileClick` prop 제거 — 라우팅이 컴포넌트 안으로 들어갔으므로).
- `AtlasPage`(히스토리): 최하단 `div`에 `mt-auto`로 `<AppTabBar activeTab="history" />` 추가 → 탭바 복구.
- 테스트 `src/test/bottom-tab-bar.test.tsx`: import 경로/props 변경 반영. `next/navigation`의 `useRouter` mock 필요.

> 참고: 아이콘 자산(`/icons/tabs/*.png`)·마크업은 그대로 옮겨온다. `useAppToast`는 `AppToastProvider` 하위에서만 동작하는데, 홈·히스토리 모두 앱 셸 안이라 문제없다.

## 파일 변경 요약

| 구분 | 경로 | 변경 |
| --- | --- | --- |
| 신규 | `app/follow-up/page.tsx` | 꼬리질문 라우트 |
| 신규 | `features/play/components/follow-up-page.tsx` | 꼬리질문 화면(2단계) |
| 신규 | `components/ui/app-tab-bar.tsx` | 공용 앱 탭바(라우팅 내부화) |
| 수정 | `features/play/types.ts` | `FollowUpQuestion` 타입 + `followUp?` 필드 |
| 수정 | `features/play/mock-play-session.ts` | 문제별 `followUp` 목업 |
| 수정 | `features/play/components/insight-page.tsx` | "꼬리 질문 풀기" CTA 추가 |
| 수정 | `features/home/components/home-page.tsx` | `AppTabBar`로 교체 |
| 수정 | `features/atlas/components/atlas-page.tsx` | 하단 `AppTabBar` 추가 |
| 삭제 | `features/home/components/bottom-tab-bar.tsx` | `components/ui`로 이동 |
| 수정 | `src/test/bottom-tab-bar.test.tsx` | 새 경로/props 반영 |

## 검증

- 신규 로직에 대한 단위 테스트 보강(꼬리질문 복귀 URL 계산, 탭바 라우팅 등) — 기존 테스트 패턴 준수.
- **Playwright로 로컬 육안 검증**: (1) 해설 → 꼬리 질문 풀기 → 답 가림 → 답 확인 → 해설로 돌아가기/다음 문제로, (2) 홈 → 히스토리 진입 시 탭바 유지 + 홈 복귀. 시안(`꼬리문제풀기.dc.html`)과 대조.
- `verify-app` 게이트(typecheck → lint → build → check:design) 전부 통과 후 PR.

## 후속

- 백엔드 꼬리질문 API 계약 확정 시 `mock-play-session.ts`의 `followUp` 목업을 실 API 응답으로 교체(`frontend-api` 규약).

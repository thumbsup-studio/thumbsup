# Design

Thumbs Up의 시각 언어를 기록한다. 근거는 `docs/design/references/`에 커밋된 시안 6장
(`home-today.png` · `today-streak-recovery.png` · `quiz-types-board.png` ·
`quiz-flow-board.png` · `answer-insight.png` · `answer-feedback-popover.png`)이며,
PR #85 preview 디자인이 공식 승격된 기준이다(`docs/superpowers/specs/2026-07-08-design-system-harness-design.md` §3).

**이 문서의 역할과 한계:** 아래 섹션의 항목명(`primary`, `card`, `hero` 등)은
Task 2가 `globals.css`의 `@theme`에 그대로 옮길 토큰 이름이다 — **이름은 이 문서가 확정**이지만,
**정밀한 hex·px 값은 Task 2가 시안에서 직접 추출해 확정**한다. 이 문서에 적은 값은
육안 관찰에 기반한 근사치이며 "약 ~대"로 표기한다.

## 컬러 역할

| 토큰명 | 역할 | 시안 근거 | 관찰 근사값 |
|---|---|---|---|
| `primary` | 블루. CTA 버튼, 선택된 상태, 진행바, 활성 탭 아이콘, 히어로 카드 그라데이션의 기본 톤 | `home-today.png` 오늘의 코스 히어로 카드·"오늘의 문제 시작" 버튼, `quiz-types-board.png`/`quiz-flow-board.png` 선택된 보기(파란 테두리+옅은 파란 배경), `today-streak-recovery.png` "다음 화 이어가기" 버튼 | 블루 계열, 약 `#2f63ff` (히어로 카드 그라데이션은 밝은 쪽 약 `#4d74f5` ~ 진한 쪽 약 `#3450d8`) |
| `primary-fg` | `primary` 배경 위에 얹는 전경(텍스트·아이콘) 색. 흰색 | `home-today.png` 히어로 카드 안 "TCP와 UDP의 차이" 제목·설명 텍스트, `today-streak-recovery.png` "다음 화 이어가기" 버튼 라벨 | 흰색, `#ffffff` 근접 |
| `accent` | 오렌지. 스트릭·긴급 전용 — 그 외 용도에는 쓰지 않는다 | `today-streak-recovery.png` "어제 학습을 놓쳤어요 · 지금 복구" 배너와 배너 안 흰 버튼 | 오렌지 계열, 약 `#f5923e` |
| `ox-o` | 그린. OX 문제의 "O"(맞다) 대형 버튼 전용 | `quiz-types-board.png` OX 화면의 초록 O 버튼, `quiz-flow-board.png` 1b OX 화면 | 그린 계열, 약 `#3fc27c` |
| `ox-x` | 레드. OX 문제의 "X"(아니다) 대형 버튼 전용 | `quiz-types-board.png` OX 화면의 붉은 X 버튼 | 코럴에 가까운 레드, 약 `#ee6868` |
| `success` | 정답 피드백 배너·아이콘의 그린. `ox-o`와 색상군은 같지만 역할은 분리(버튼 vs 피드백 배너) | `answer-insight.png`/`answer-feedback-popover.png` "정답이에요" 배너(옅은 초록 배경 + 진한 초록 텍스트/체크 아이콘) | 배경 약 `#e3f6e8`, 텍스트/아이콘 약 `#1f7a4d` |
| `danger` | 오답 피드백 배너·에러 상태 전용. 6장의 레퍼런스에는 오답 배너가 실제로 등장하지 않음 — `success` 배너와 대칭되는 역할로 **추론**했다(`ox-x`의 레드와는 별개 토큰이며, 톤은 유사할 수 있음) | (직접 관찰 안 됨 — `success` 배너의 구조를 레드로 반전한 대칭 역할로 정의) | `ox-x`와 유사한 레드 계열, 정밀 값은 Task 2에서 배너 대비 기준으로 재산정 |
| `warning` | 주의·경고 상태(폼 검증, 일반적 caution) 전용. `accent`(스트릭 전용 오렌지)와 혼동 금지 — 6장에는 별도 warning UI가 없어 시스템 완결성을 위해 **예약**해 둔 역할 | (직접 관찰 안 됨 — 시안에 없는 상태이므로 실제 화면이 필요해지면 `lazyweb-quick-search`로 실서비스 레퍼런스를 먼저 확보) | 앰버 계열로 예약, 정밀 값은 실사용 화면 등장 시 확정 |
| `info` | 중립적 안내 배너·라벨 전용. 6장에는 별도 info 배너가 없어 **예약**해 둔 역할 | (직접 관찰 안 됨) | `primary`보다 채도 낮은 라이트 블루로 예약 |
| `bg` | 앱 전체 배경. 아주 옅은 라벤더-블루 톤 | `home-today.png`·`today-streak-recovery.png` 전체 배경 | 약 `#eef2fb` |
| `surface` | 카드·리스트 아이템 등 콘텐츠가 얹히는 기본 서피스. 흰색 | `home-today.png` "이어보기" 리스트 카드, `answer-insight.png` "이론"/"코드 적용 예시" 카드 | `#ffffff` |
| `surface-muted` | 옅은 회색 서피스. 비활성 chip 배경, 진행바 트랙, 텍스트 입력창 배경 | `today-streak-recovery.png` 진행바 회색 트랙, `quiz-types-board.png` 서술형 입력창 배경 | 약 `#eef0f5` |
| `ink` | 본문·제목 텍스트의 기본 잉크 색. 진한 남색에 가까운 블랙 | 전 화면 헤딩·본문 텍스트 | 약 `#16182c` |
| `ink-muted` | 보조·캡션 텍스트 | `home-today.png` "3회 중 2차까지 완료 · 오늘 1문제 남음" 같은 캡션, `answer-feedback-popover.png` 라벨 텍스트 | 약 `#6b7280` |
| `border` | 카드·입력·선택되지 않은 보기의 얇은 테두리 | `quiz-types-board.png` 매칭형 미선택 보기 테두리, 서술형 입력창 테두리 | 약 `#dfe3ee` |

**정답/오답 대칭 원칙.** `success`·`danger`는 피드백 배너 전용, `ox-o`·`ox-x`는 OX 문제 버튼 전용으로
역할을 분리한다 — 같은 초록/빨강이라도 문제 버튼과 결과 배너는 다른 토큰이다. 재사용해도 되지만
컴포넌트가 "OX 버튼"인지 "피드백 배너"인지에 따라 토큰을 명시적으로 선택한다.

## radius 스케일

| 토큰명 | 역할 | 시안 근거 | 관찰 근사값 |
|---|---|---|---|
| `card` | 외곽 카드 코너. 히어로 카드, 이어보기 리스트 카드, 이론/코드/파생 개념 카드 | `home-today.png`가 가장 크게 둥근 라운드를 보여준다 | 약 `24px`~`32px` 대(레퍼런스 상 인상이 매우 둥글다) |
| `control` | 버튼·입력 공통 라운드 | CTA 버튼("정답 확인", "다음 화 이어가기")은 거의 완전한 캡슐형(pill)에 가깝고, 텍스트 입력(서술형·빈칸 채우기)은 그보다 작은 중간 라운드다 — **버튼과 입력의 실제 곡률에 눈에 띄는 차이가 있다** | 버튼은 `rounded-full`에 가깝고 입력창은 약 `12px`~`16px`. 단일 토큰으로 흡수하면 버튼 쪽이 손해 보므로, Task 2는 버튼에 `rounded-full`을 별도로 얹을지(`control` + 유틸리티 병용) 판단 필요 |
| `chip` | 필(pill) 태그. 카테고리 chip("매칭"·"OX"·"서술형" 등), 상태 배지("이어보기"·"복습"), 파생 개념 칩, 히어로 카드 상단 "오늘의 코스 · 네트워크" 태그 | 전 화면의 chip류가 공통적으로 완전한 캡슐형 | `rounded-full` |

## 그림자

| 토큰명 | 역할 | 시안 근거 | 관찰 인상 |
|---|---|---|---|
| `card` | 흰 서피스 카드(이어보기 리스트, 이론/코드/파생 개념 카드)에 적용되는 기본 그림자. `bg`와 `surface`의 밝기 대비가 커서 그림자 자체는 거의 느껴지지 않을 만큼 옅다 | `home-today.png` "이어보기" 리스트 카드 | 낮은 blur·낮은 opacity의 미묘한 elevation |
| `hero` | 오늘의 코스 블루 그라데이션 히어로 카드에 적용되는 강조 그림자. 카드가 배경 위로 살짝 떠 있는 듯한 블루 톤 글로우 | `home-today.png` 오늘의 코스 카드 | `card`보다 blur가 크고 블루 틴트가 도는 soft shadow |

## 타이포

- **본문:** Pretendard Variable (한국어 최적화 가변 폰트). 현재 `globals.css`에 남아 있는 create-next-app
  잔재(Arial/Helvetica)를 대체한다(Task 2).
- **코드:** Geist Mono. `quiz-types-board.png` 코드 문제 화면과 `quiz-flow-board.png` 코드 리딩 화면의
  다크 코드 블록에 쓰인다.
- **크기 스케일:** 커스텀 타이포 토큰을 만들지 않는다(YAGNI, TC-38-28의 rem 요구를 Tailwind 기본
  스케일로 그대로 충족). `text-2xl`/`text-xl`/`text-base`/`text-sm`/`text-xs` 같은 Tailwind 기본
  rem 단위 클래스를 그대로 쓴다.
- **관찰된 위계** (참고용 — 토큰화하지 않음):
  - 인사말/히어로 타이틀: 굵고 큼직함 (`home-today.png` "출근 전에 한 문제, 오늘도 이어가요", 히어로 카드
    "TCP와 UDP의 차이")
  - 카드 제목: semibold, 중간 크기 ("이어서 학습 · 자료구조 기초")
  - 본문: regular, 기본 크기 (해설 본문, 이론 설명)
  - 캡션/보조 텍스트: 작고 `ink-muted` 톤 ("오늘의 목표 10문제 중 4문제 완료")

## 스페이싱·터치 타깃

- Tailwind 기본 스페이싱(rem) 스케일을 그대로 쓴다. 커스텀 spacing 토큰 없음.
- 카드 내부 패딩은 넉넉한 편(대략 `p-4`~`p-6`급 인상), 리스트 아이템 사이 일정한 gap, 화면 좌우 마진 일관.
- **하단 CTA·탭 최소 높이는 `min-h-12`(48px).** `home-today.png`/`today-streak-recovery.png`의
  하단 탭바, "오늘의 문제 시작"/"다음 화 이어가기"/"정답 확인" 버튼 모두 엄지로 누르기 넉넉한 높이로
  보인다. WCAG 최소 터치 타깃(44px)보다 여유를 둔 값.

## 엄지 모티프 사용 규칙

- **용도:** 👍는 장식·응원용 그래픽이다 — 인사말 옆 큰 엄지(`home-today.png`), 스트릭 카드 안 작은 엄지
  아이콘, `answer-insight.png` "실무 사용처" 라벨 옆 장식 엄지처럼 브랜드 워터마크나 감정 표현으로 쓴다.
- **금지:** 색이나 엄지 아이콘만으로 상태(정답/오답, 성공/실패)를 전달하지 않는다(TC-38-29). 정보 전달은
  항상 텍스트·아이콘과 병행한다 — 실제 시안도 이 규칙을 지킨다: `answer-insight.png`의 정답 배너는
  초록색뿐 아니라 체크 아이콘 + "정답이에요. 잘 짚었어요." 텍스트를 함께 쓰고, OX 버튼도 색뿐 아니라
  "O"/"X" 문자를 명시한다.
- **레퍼런스 판독 주의:** `quiz-types-board.png`·`quiz-flow-board.png`는 여러 화면을 한 보드에 모아
  비교하는 합성 이미지라, 폰 프레임 **바깥** 여백에 떠 있는 빨간 하트·금색 별 아이콘이 보인다. 이건
  디자이너가 후보 화면을 표시해둔 리뷰용 주석(예: "마음에 드는 시안 표시")이며 **실제 앱 UI가 아니다**
  — 엄지 모티프나 토큰 추출 시 이 하트·별은 무시한다. 반면 폰 프레임 **안**의 초록 엄지 그래픽은 실제
  앱 UI다.

## 다크 격리

- 서비스는 **라이트 고정**이 원칙이다. 시스템 `prefers-color-scheme` 다크모드는 지원하지 않는다.
- 다크는 **그래프 화면(#10) 전용**으로 격리해 `--color-graph-*` 네이밍으로 분리한다(TC-38-13). 일반
  화면의 색 토큰(`bg`/`surface`/`ink` 등)과 이름 공간을 절대 공유하지 않는다.
- **혼동 주의:** `answer-insight.png`의 "대표 꼬리질문" 카드는 검은 배경에 흰 텍스트로 렌더링되지만,
  이건 앱 전역 다크모드가 아니라 라이트 UI 안에 놓인 **국소적으로 어두운 카드 한 장**(강조용 서피스)이다.
  그래프 화면의 다크 토큰과는 별개 개념이므로 이 카드를 다크모드 지원 근거로 삼지 않는다. 현재
  `app/src/app/globals.css`에 남아 있는 `@media (prefers-color-scheme: dark)` 분기는 이 정책에 따라
  Task 2에서 제거한다.

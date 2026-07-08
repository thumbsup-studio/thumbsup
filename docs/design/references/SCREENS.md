# 화면별 디자인 레퍼런스 레지스트리

떰즈업 각 화면의 **기준 시안(레퍼런스)** 과 **visual-qa 시안 대조** 연결을 화면 단위로 관리한다.
Claude 디자인 결과물이 오면 이 표의 슬롯에 채우고 아래 레시피로 연결한다.

## 레퍼런스 연결 레시피 (시안 확정 시 각 화면마다)

1. 시안 이미지를 `docs/design/references/<screen>.png` 로 커밋 (모바일 390px 기준 스크린샷 1장).
2. app 밖이라 e2e로 복사: `cp docs/design/references/<screen>.png app/e2e/designs/<screen>.png`
3. `app/e2e/qa-routes.ts` 에 라우트 추가: `{ path: "<route>", design: "e2e/designs/<screen>.png" }`
4. 해당 화면 페이지(`app/src/app/<route>/page.tsx`)가 구현돼 있어야 visual-qa가 스크린샷을 찍는다. (페이지 없으면 캡처 실패 → soft skip)

> ⚠️ 이미지·페이지가 없는 상태로 3번을 활성화하면 visual-qa가 깨진다. 세 조건(이미지·페이지·라우트)이 모두 준비된 화면만 qa-routes 에 넣는다.

## 화면 목록

**Claude 디자인으로 재설계 진행 중.** 확정 시안은 `docs/design/references/html/`의 **HTML 목업**(자립형 — 브라우저로 직접 열어 확인). 홈·퀴즈·해설은 아직 재디자인 대기.
(아래 `기존 레퍼런스`의 PNG 6장은 잠정/레거시 — 새 시안으로 교체.)

| 화면 | 라우트(잠정) | 레퍼런스 | 테마 | visual-qa | 상태 |
|---|---|---|---|---|---|
| 홈 / Today | `/` | *(비움 — 재디자인 대기)* | 라이트 | 잠정 `home.png` 연결 유지 | 🟡 재디자인 대기 |
| 퀴즈 | `/quiz` *(잠정)* | *(비움)* | 라이트 | 미연결 | 🟡 재디자인 대기 |
| 해설 | `/answer` *(잠정)* | *(비움)* | 라이트 | 미연결 | 🟡 재디자인 대기 |
| **로그인** | `/login` | `html/login.html` | 라이트 | 미연결 | 🟢 시안 확정(HTML) |
| **회원가입** | `/signup` | `html/signup.html` | 라이트 | 미연결 | 🟢 시안 확정(HTML) |
| **지식 그래프 (히스토리 탭)** | `/history` *(잠정)* | `html/knowledge-graph.html` | 라이트+다크 그래프카드 | 미연결 | 🟢 시안 확정(HTML) |

메모:
- **홈**: 현 구현은 #85 MVP + 토큰 retrofit. 라이브 visual-qa 연결(`/`→`home.png`)은 새 시안이 올 때까지 그대로 두고, 새 홈 시안 도착 시 교체.
- **퀴즈**: 유형 매칭·OX(ox-o/ox-x)·빈칸·키워드 서술·코드·케이스. 상단 Progress.
- **해설**: 정답 배너(success)·핵심 정리·이론/예시/실무·파생개념 chip·꼬리질문.
- **로그인 / 회원가입**: 백엔드는 **이메일/비밀번호**(소셜 아님) — 서버 PR #95(`/api/v1/auth`, Closes #44)가 소스. 엔드포인트: `/signup`(email+password 8~72자, 중복 시 409 `USER_EMAIL_DUPLICATED`) · `/login`(실패 401 `INVALID_CREDENTIALS`, 원인 미구분) · `/refresh`(회전) · `/logout`. 가입 성공 시 토큰 즉시 발급 = **자동 로그인** → 온보딩(#17 티어 배치 · #71 관심 코스). 두 화면 모두 프리-오스, 하단 탭바 없음. 화면은 로그인 폼 + 회원가입 폼(또는 한 화면 토글), 각각 로딩·에러(Feedback error) 상태 필요. 앱 이슈 #1(자동 로그인·신규/기존 분기)와 연결.
- **아틀라스**: 홈 `Atlas` 탭. 스펙 §다크격리의 #10 다크 화면 → 다크 팔레트를 `--color-graph-*` 토큰으로 편입 예정.

## HTML 레퍼런스 (`docs/design/references/html/`)

Claude 디자인 산출물 — **자립형 HTML 목업**(폰트 임베드, 브라우저로 직접 열어 확인). 화면 구현 시 이 파일이 **레이아웃·구성의 시각 기준**이다.
- `login.html`(로그인, 라이트) · `signup.html`(회원가입, 라이트) · `knowledge-graph.html`(지식 그래프/히스토리 탭, **다크**)
- HTML은 대부분 우리 토큰 값(`#2f63ff`·`#020617`·`#eef2f8`)을 이미 쓰지만, 구현 시엔 **raw hex 복붙 금지 — `globals.css` 토큰·`components/ui` 로 매핑**한다.
- **지식 그래프 테마**: 화면 자체는 라이트, **그래프 캔버스 카드만 다크**. 다크 팔레트(HTML 추출): 배경 `#3C4A6E` 계열, 마스터 노드 그린 `#34C88A`, 학습중 primary `#2F63FF`, 미학습 회색 dashed, 텍스트 흰색 → 확정 시 `globals.css` 에 `--color-graph-*` 로 편입. 숙련도는 색+아이콘(✓/반원/dashed) 병행.
- **visual-qa 시안(PNG) 준비 완료**: `login.png`·`signup.png`·`knowledge-graph.png`(단일 **기본 상태**, 390×844@2x) + `<screen>-board.png`(전체 상태 보드). Playwright(visual-qa와 같은 Chromium)로 HTML 렌더 추출 — 앱과 같은 엔진이라 대조 정확. **페이지 구현 시** `cp docs/design/references/<screen>.png app/e2e/designs/` + qa-routes 연결하면 시안 대조 활성화(지금은 페이지가 없어 미연결). (향후: CI에서 HTML 직접 렌더 + 픽셀 diff 1차 게이트 + Gemini 2차.)

### 화면당 상태 시안 (도착 시 보관, visual-qa 는 대표 1장만 연결)
- 로그인: `login-default.png` / `login-loading.png` / `login-error.png`
- 아틀라스: `atlas.png`(데이터 있음) / `atlas-empty.png`(빈 상태)

## 기존 레퍼런스 (잠정·레거시 — 새 시안으로 교체 예정)
#38에서 커밋된 6장. 새 Claude 디자인이 확정되기 전까지의 참고용이며 기준으로 고정하지 않는다.
`home-today.png` · `today-streak-recovery.png` · `quiz-types-board.png` · `quiz-flow-board.png` · `answer-insight.png` · `answer-feedback-popover.png`

## 다음 단계
- **Claude 디자인 결과물 도착 시**: 위 표의 파일명으로 커밋 → e2e/designs 복사 → 페이지 구현 후 qa-routes 연결.
- **아틀라스 다크 팔레트**가 시안으로 확정되면 `app/src/app/globals.css` 에 `--color-graph-*` 토큰으로 정의(현재는 이름만 예약).
- 디자인 생성 프롬프트: 로그인·지식그래프용 프롬프트는 별도 공유됨(디자인 시스템 토큰·컴포넌트·규칙 내장).

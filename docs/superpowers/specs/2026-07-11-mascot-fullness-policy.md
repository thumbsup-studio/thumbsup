# 홈 캐릭터 '보리' 포만감 정책 — #35

- **날짜**: 2026-07-11
- **상태**: 구현 완료 (빌드·테스트 그린)
- **관련 이슈**: [#35 feat: 홈 캐릭터 '보리' 포만감 API](https://github.com/thumbsup-studio/thumbsup/issues/35)
- **관련 커밋**: `41f9a75`/`770fb2f`(server), `ed075c9`/`0097173`/`f008dc1`(app), `eec2ec9`/`c79e063`(마이그레이션 타임스탬프 수정) — 이 문서가 다루는 초기값·표정 임계값 조정은 그 이후 후속 변경

## 배경과 목표

홈 화면(S2)에 상주하는 캐릭터 '보리'가 최근 학습 여부를 포만감(fullness, 0~100) 게이지와 표정으로 보여준다.
서버는 포만감 원본값만 관리하고, "몇 %면 어떤 표정인가"는 프론트(`app/src/features/home/home-logic.ts`)가 판단한다.

## 결정 기록

| 결정 | 선택 | 근거 |
|------|------|------|
| 포만감 저장 방식 | 배치·스케줄러 없이 조회 시점 계산 | `lastFedAt`·`fullnessAtLastFeed`만 저장하고, `getCurrentFullness(now)`가 경과일수 × `DECAY_PER_DAY`(10)를 빼서 즉시 계산(`Mascot.java`). 크론잡 인프라가 이 레포에 없어 가장 단순한 방식을 택함 |
| 감소·증가 폭 | 하루 10% 감소, 먹이 1회 20% 증가 | 표정 임계값을 10 단위로 정렬한 이유이기도 함 — 게이지가 어차피 10 단위로만 움직이므로 경계값도 10 단위로 맞춰야 "감소 한 번에 표정이 바뀌었다가 안 바뀌었다가" 하는 애매한 구간이 안 생김 |
| **신규 유저 초기값** | **50%(보통)** | 최초 구현 시엔 100%(만실)이었으나, "이유 없이 만실로 시작하는 게 어색하다"는 판단으로 50%로 조정(이 문서 작성 시점 변경). `Mascot.INITIAL_FULLNESS` 상수로 `Mascot.create()`와 `MascotService.getMascot()`의 "행 없는 신규 유저" 기본값 양쪽에 적용 |
| **표정 임계값** | **70%↑ 행복 · 30~69% 보통 · 29%↓ 배고픔** | 최초 구현 시엔 67/34였으나 10 단위 정렬을 위해 70/30으로 조정. `home-logic.ts`의 `getCharacterMood()` 하나에만 존재 — 서버 응답(`MascotResponse`)엔 표정 필드가 없고 fullness 숫자만 내려간다 |
| "화남" 표정 | 도입하지 않음 | 표정을 화남/보통/배고픔으로 나누자는 논의가 있었으나, 실제 의도는 기존 행복(happy) 표정의 임계값 조정이었음을 확인 — `CharacterMood` 타입은 `happy`/`neutral`/`hungry` 3종 그대로 유지 |
| 동시성 | 유저 단위 비관적 락 + 유니크 제약 위반 재조회 | `quiz.QuizService#lockOrCreateProgress`와 완전히 동일한 패턴을 재사용 — `MascotRepository#findByUserIdForUpdate` + `MascotService#lockOrCreateMascot`. 같은 유저가 `feed`를 동시에 두 번 호출해도(예: 네트워크 재시도) 행이 중복 생성되거나 갱신이 유실되지 않음 |
| `feed` 호출 시점 | 프론트가 세션(퀴즈 5문제 스텝) 완료 시 직접 호출 | 서버 쪽에서 `quiz.submitAnswer`와 자동 연동하지 않음 — cross-feature 의존을 피하기 위해 `POST /api/v1/mascot/feed`를 별도 엔드포인트로 두고 클라이언트가 오케스트레이션 |
| 캐릭터 이름 | `"보리"` 하드코딩 | 캐릭터 개인화(이름 변경 등)는 범위 밖(`MascotResponse` 주석) |

## 아키텍처

```text
studio.thumbsup.server.mascot/
├─ Mascot.java              (Entity — userId, fullnessAtLastFeed, lastFedAt.
│                             MAX_FULLNESS=100 · MIN_FULLNESS=0 · INITIAL_FULLNESS=50 ·
│                             DECAY_PER_DAY=10 · FEED_AMOUNT=20)
├─ MascotRepository.java    (findByUserId, findByUserIdForUpdate — PESSIMISTIC_WRITE)
├─ MascotController.java    (GET /api/v1/mascot, POST /api/v1/mascot/feed)
├─ MascotService.java       (@Transactional(readOnly=true) 기본, feed()만 쓰기로 오버라이드)
└─ dto/
   └─ MascotResponse.java   (name, fullness — 표정은 서버 응답에 없음)

app/src/features/home/
├─ home-logic.ts            (getCharacterMood: fullness → happy/neutral/hungry, formatFullness)
└─ components/
   ├─ character-block.tsx        (게이지 링 + DogIcon mood 렌더)
   └─ character-block.stories.tsx
```

### Flyway

- `V20260710222432__create_mascot.sql` — `mascot` 테이블(유저당 한 행, `uk_mascot_user` unique). 테이블명 `mascot`은 `character`가 MySQL 예약어라 회피한 것.

## 비범위

- 캐릭터 이름 개인화, 표정 종류 확장(화남 등 추가 감정).
- `quiz.submitAnswer`와의 서버 사이드 자동 연동(현재는 프론트가 `feed` 별도 호출).
- 포만감 변화 히스토리/통계.

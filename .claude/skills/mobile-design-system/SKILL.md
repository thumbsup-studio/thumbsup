---
name: mobile-design-system
description: apps/mobile UI(화면·스타일)를 만들거나 고칠 때 반드시 로드. NativeWind 토큰 사용 규칙, 모바일 전용 radius 토큰, 공용 컴포넌트가 없는 상황에서의 조립 방식, 접근성·터치 규칙을 다룬다. 웹용은 design-system 스킬이고 토큰 이름이 일부 다르다. 사용자가 "모바일 화면 만들어", "앱 스타일 바꿔", "RN 컴포넌트 추가"라고 할 때 트리거.
---

# mobile-design-system — 모바일 디자인 규약

`apps/mobile` UI 작업 전 이 규칙을 따른다. 웹·저작 앱은 `design-system` 스킬이 정본이고, **토큰 이름이 일부 다르므로 웹 규칙을 그대로 옮기지 않는다.**

토큰 정의의 정본은 `packages/tokens/src/index.ts`, 모바일 규약은 `apps/mobile/CLAUDE.md`다.

## 토큰이 전달되는 경로

```text
packages/tokens/src/index.ts        ← 정본. 여기만 고친다
  └ pnpm --filter @thumbsup/tokens generate
      └ generated/nativewind-v4.preset.cjs   ← 생성물. 직접 수정 금지
          └ apps/mobile/tailwind.config.js 의 presets
```

`apps/mobile/src/global.css`의 Tailwind 지시문 3줄이 시작점이고 `src/app/_layout.tsx`가 이를 import한다. NativeWind는 `metro.config.js`와 `babel.config.js`에서 연결된다. 이 배선은 건드릴 일이 거의 없다.

## radius 토큰이 웹과 다르다 — 제일 자주 틀리는 곳

색 토큰은 웹과 이름이 같지만 **radius는 모바일 전용 이름을 쓴다.**

| 용도 | 웹 | 모바일 |
| --- | --- | --- |
| 카드 | `rounded-card` | **`rounded-mobile-card`** |
| 버튼·입력 | `rounded-control` | **`rounded-mobile-control`** |
| 다이얼로그 | — | **`rounded-mobile-dialog`** |
| 칩 | `rounded-chip` | 없음 |

웹 화면을 참고해 옮길 때 `rounded-card`를 그대로 쓰면 클래스가 적용되지 않는다. NativeWind는 모르는 클래스를 조용히 무시하므로 **에러 없이 스타일만 빠진다.**

색은 공유된다. `bg-bg`·`bg-surface`·`bg-surface-muted`·`bg-primary`·`text-ink`·`text-ink-muted`·`text-primary`·`text-primary-fg`·`border-border`가 양쪽에서 같은 이름이다.

## 규칙

- **토큰만 쓴다.** 원시 hex(`#111111`)와 arbitrary value(`bg-[#fff]`·`rounded-[36px]`)를 쓰지 않는다.
- **새 색이 필요하면 `packages/tokens`에 먼저 추가**하고 생성 스크립트를 돌린 뒤 그 이름을 쓴다. 앱에서 값을 직접 박지 않는다.
- **className이 안 통하는 자리에서만 토큰을 JS로 읽는다.** expo-router의 `screenOptions`처럼 prop으로 색을 받는 API가 그렇다. `import { tokens } from "@thumbsup/tokens"` 후 `tokens.color.primary`를 쓴다. 기존 사용처는 `src/app/(tabs)/_layout.tsx`, `src/components/icons.tsx`다.
- 모바일 전용 타이포 값이 필요하면 `mobileTypography`를 쓴다.

## 공용 컴포넌트가 없다

웹의 `src/components/ui/` 같은 범용 부품이 **모바일에는 없다.** `packages/ui-web`은 DOM 기반이라 쓸 수 없다.

있는 것은 둘뿐이다.

- `src/components/screen-state.tsx` — 로딩·에러·빈 상태·오프라인
- `src/components/icons.tsx` — `react-native-svg` 아이콘

`src/components/auth/`는 로그인·회원가입 전용이라 다른 화면에서 재사용하지 않는다.

그래서 버튼·카드는 화면마다 `Pressable`·`View`에 토큰 클래스를 인라인으로 붙여 만든다. 기존 화면(`briefing`·`course`·`home`)에서 같은 조합을 복사해 쓰고, **같은 조합이 세 번째 반복되면 그때 `src/components/`로 올린다.** 올릴 때 웹처럼 스토리를 쓰지 않는다. 모바일에는 Storybook이 없다.

## React Native에서만 신경 쓸 것

- 문자열은 반드시 `<Text>` 안에 있어야 한다. 맨 문자열을 `<View>`에 두면 런타임 에러다.
- **CSS 상속이 없다.** 부모에 글자색을 줘도 자식 `Text`에 안 내려간다. `Text`마다 색 클래스를 붙인다.
- flex 기본 방향이 세로다. 가로 배치는 `flex-row`를 명시한다.
- 스크롤이 자동이 아니다. `ScrollView`로 감싸고 긴 목록은 `FlatList`를 쓴다. 패딩·간격은 `className`이 아니라 `contentContainerClassName`에 넣는다.
- `SafeAreaView`의 `edges`로 노치·홈 인디케이터를 피한다. 탭바가 가리는 화면은 `edges={["top"]}`처럼 아래를 뺀다.
- 키보드가 입력창을 가린다. `KeyboardAvoidingView`로 감싸고 iOS·Android 동작이 달라 분기한다.

## 접근성

- 터치 타깃 최소 44px. 기존 코드는 `min-h-12`로 맞춘다.
- 본문 대비 4.5:1 이상. 색만으로 상태를 구분하지 않는다.
- **`Pressable`에 `accessibilityRole`을 반드시 붙인다.** 스크린리더뿐 아니라 테스트가 이 prop으로 요소를 찾으므로 빼면 테스트가 깨진다.

## 완료 전

`verify-app`의 Mobile 게이트를 통과한다.

⚠️ **모바일에는 웹의 `check:design` 같은 자동 검사가 없다.** 토큰 위반을 잡아주는 게이트가 없으므로 원시 hex와 arbitrary value는 직접 확인한다.

```bash
grep -rnE "#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b" apps/mobile/src --include="*.tsx" --include="*.ts"
grep -rnE "\b[a-z][a-z-]*-\[[^]]+\]" apps/mobile/src --include="*.tsx"
```

둘 다 0건이어야 한다. 현재 main이 0건이므로 늘어났다면 이번 변경에서 생긴 것이다.

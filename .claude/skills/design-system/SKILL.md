---
name: design-system
description: apps/web·apps/authoring UI(화면·컴포넌트·스타일)를 만들거나 고칠 때 반드시 로드. 모바일은 radius 값과 컴포넌트 사정이 달라 mobile-design-system 스킬을 쓴다. 디자인 토큰·공통 컴포넌트 사용 규칙과 하네스를 강제한다. 사용자가 "화면 만들어", "컴포넌트 추가", "스타일 바꿔"라고 할 때도 트리거.
---

# design-system — 떰즈업 디자인 규약

`apps/web`과 `apps/authoring`의 UI 작업 전 이 규칙을 따른다. 상세는 `apps/web/DESIGN.md`, 토큰은 `apps/web/src/app/globals.css`, 카탈로그는 `pnpm storybook`.

> **모바일은 이 스킬을 쓰지 않는다.** radius 값이 다르고 범용 컴포넌트가 없다 — `mobile-design-system` 스킬을 읽는다.

## 화면 구현 시 레퍼런스 (먼저 확인)
화면(로그인·회원가입·지식그래프 등)을 만들 땐 **레퍼런스 HTML을 먼저 연다.**
- 화면↔파일 매핑: `docs/design/references/SCREENS.md`.
- 해당 시안 HTML: `docs/design/references/html/<screen>.html` (로그인=`login`·회원가입=`signup`·지식그래프=`knowledge-graph`). 브라우저로 열어 레이아웃·구성·상태를 **시각 기준**으로 재현한다.
- ⚠️ HTML의 raw hex를 그대로 옮기지 말 것 — 반드시 아래 토큰·`components/ui`로 매핑한다. 다크 화면(지식그래프)은 `--color-graph-*` 토큰을 정의해 쓴다(라이트 토큰 재사용 금지).

## 규칙
- **토큰만 사용.** `bg-primary`·`rounded-card`·`shadow-hero`·`text-ink` 등 이름 유틸리티로만. `bg-[#...]`·`rounded-[36px]`·raw hex 금지.
- **새 스타일이 필요하면 토큰을 먼저 추가.** 토큰의 정본은 `packages/tokens/src/index.ts`다. 여기에 추가하고 `pnpm --filter @thumbsup/tokens generate`로 생성물(`web.css`·nativewind preset)을 갱신한 뒤 그 이름을 쓴다. 웹·모바일이 같은 소스를 공유하므로 앱의 `globals.css`에 값을 직접 박지 않는다.
- **컴포넌트는 `@thumbsup/ui-web`에서.** 정본은 이 패키지이고 Button·Card·Chip·BottomTabBar·Feedback·Progress·Skeleton·EmptyState가 있다. `apps/web`은 `src/components/ui/`에 re-export shim을 두고 `@/components/ui`로 가져오며, `apps/authoring`은 shim 없이 서브패스로 직접 가져온다. 없는 것만 새로 만들되, **만들면 `<name>.stories.tsx`를 함께** 작성(게이트가 강제).
- **시안에 없는 상태**(에러·빈·로딩·오프라인·"준비중")는 감으로 짓지 말고 실서비스 레퍼런스(웹 리서치·유사 앱 스크린샷)를 확보 후 디자인.
- **접근성**: 터치 타깃 ≥44px, 본문 대비 ≥4.5:1, 색만으로 상태 구분 금지(아이콘·텍스트 병행), 모션은 `motion-safe:`/`prefers-reduced-motion` 대응.
- **불가피한 예외**: 그 한 줄에 `// design-ok` 주석.

## 완료 전
`verify-app` 게이트(typecheck·lint·build·check:design)를 통과. UI를 바꿨으면 `visual-qa`도.

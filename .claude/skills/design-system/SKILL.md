---
name: design-system
description: app UI(화면·컴포넌트·스타일)를 만들거나 고칠 때 반드시 로드. 디자인 토큰·공통 컴포넌트 사용 규칙과 하네스를 강제한다. 사용자가 "화면 만들어", "컴포넌트 추가", "스타일 바꿔"라고 할 때도 트리거.
---

# design-system — 떰즈업 디자인 규약

UI 작업 전 이 규칙을 따른다. 상세는 `app/DESIGN.md`, 토큰은 `app/src/app/globals.css`, 카탈로그는 `pnpm storybook`.

## 규칙
- **토큰만 사용.** `bg-primary`·`rounded-card`·`shadow-hero`·`text-ink` 등 이름 유틸리티로만. `bg-[#...]`·`rounded-[36px]`·raw hex 금지.
- **새 스타일이 필요하면 토큰을 먼저 추가.** globals.css `@theme`에 이름을 정의하고 그 이름을 쓴다.
- **컴포넌트는 components/ui에서.** 화면은 `src/components/ui/`의 Button·Card·Chip·BottomTabBar·Feedback·Progress·Skeleton·EmptyState를 조립. 없는 것만 새로 만들되, **만들면 `<name>.stories.tsx`를 함께** 작성(게이트가 강제).
- **시안에 없는 상태**(에러·빈·로딩·오프라인·"준비중")는 감으로 짓지 말고 `lazyweb-quick-search`로 실서비스 레퍼런스 확보 후 디자인.
- **접근성**: 터치 타깃 ≥44px, 본문 대비 ≥4.5:1, 색만으로 상태 구분 금지(아이콘·텍스트 병행), 모션은 `motion-safe:`/`prefers-reduced-motion` 대응.
- **불가피한 예외**: 그 한 줄에 `// design-ok` 주석.

## 완료 전
`verify-app` 게이트(typecheck·lint·build·check:design)를 통과. UI를 바꿨으면 `visual-qa`도.

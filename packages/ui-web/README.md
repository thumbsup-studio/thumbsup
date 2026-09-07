# @thumbsup/ui-web

web과 authoring 화면이 함께 쓰는 React UI 컴포넌트 11종을 제공한다. 컴포넌트는 `@thumbsup/tokens`가 만든 클래스 이름만 사용하며, Next.js 라우팅이나 앱 기능 코드에는 의존하지 않는다.

## 공개 경계

기본 진입점 `@thumbsup/ui-web`에서 모든 컴포넌트를 내보낸다. `@thumbsup/ui-web/button`처럼 컴포넌트별 `exports` 하위 경로도 지원한다. `src/`를 직접 가져오면 안 된다.

현재 `apps/web/src/components/ui/*`는 기존 `@/components/ui/*` import를 깨뜨리지 않도록 얇은 re-export 파일로 남겨 뒀다. 한 번에 수십 개 import를 바꾸는 대신 기존 기능 브랜치와의 충돌을 줄이고, 새 소비자는 패키지 공개 진입점을 바로 쓰도록 한 선택이다.

스토리는 `stories/`에 컴포넌트와 함께 관리하고 웹 Storybook이 이 경로를 읽는다. 별도 빌드 산출물은 만들지 않으며 Next.js가 TypeScript·TSX 소스를 변환한다.

## 의존성 정책

React는 소비 앱과 인스턴스를 공유하도록 `peerDependencies`에 둔다. 모노레포 내부 의존성을 추가할 때는 `workspace:*`를 사용하고, 앱 전용 alias나 기능 모듈은 가져오지 않는다.

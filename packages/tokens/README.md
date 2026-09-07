# @thumbsup/tokens

Thumbs Up 디자인 토큰의 단일 정본이다. 색상, radius, 그림자, 폰트, 애니메이션 값은 `src/index.ts`에서만 수정한다.

## 생성물과 공개 경계

`pnpm --filter @thumbsup/tokens generate`를 실행하면 두 파일이 갱신된다.

- `@thumbsup/tokens/web.css`: Tailwind CSS v4가 읽는 `@theme` 블록
- `@thumbsup/tokens/nativewind-v4`: #330에서 채택한 NativeWind 4.2.6·Tailwind CSS 3.4.17용 프리셋

TypeScript 소비자는 기본 진입점 `@thumbsup/tokens`에서 타입이 붙은 원시 토큰을 가져온다. 생성 파일은 직접 수정하지 않으며, 테스트가 생성 함수의 결과와 커밋된 파일이 같은지 확인하고 웹 CSS를 스냅샷으로 고정한다.

별도 빌드는 하지 않는다. TypeScript 정본과 CSS·CommonJS 생성물을 그대로 배포 경계로 사용한다.

## 의존성 정책

런타임 의존성은 없다. 모노레포 패키지를 참조하게 되면 `workspace:*`만 사용한다. 생성 도구에 필요한 패키지는 `devDependencies`에 둔다.

# @thumbsup/core

웹과 모바일에서 함께 쓰는 순수 TypeScript 로직을 모은 패키지다. React, DOM, Next.js에 의존하지 않으며 문제 풀이, 정답 연출 규칙, 완주·코스 URL 파라미터, 퀴즈 공통 타입을 제공한다.

## 공개 경계

기본 진입점 `@thumbsup/core`에서 모든 공개 API를 내보낸다. 번들 크기나 관심사 분리가 필요하면 `@thumbsup/core/play-logic`, `@thumbsup/core/types` 같은 `exports` 하위 경로도 사용할 수 있다. `src/` 경로를 직접 가져오면 안 된다.

이 패키지는 별도 빌드 산출물을 만들지 않는다. 워크스페이스 소비자가 TypeScript 소스를 직접 변환하며, `typecheck`와 Vitest 테스트로 배포 전 경계를 검증한다.

## 의존성 정책

런타임 의존성은 두지 않는다. 모노레포의 다른 패키지가 필요해지면 정확한 버전을 복제하지 않고 `workspace:*`로 선언한다. 외부 라이브러리를 추가할 때는 DOM이나 특정 렌더러 의존성이 생기지 않는지 먼저 확인한다.

# @thumbsup/api

Thumbs Up 앱이 함께 쓰는 API 클라이언트입니다. 환경변수와 토큰 저장소는 패키지 안에서 정하지 않습니다. 각 앱이 `createApiClient({ baseUrl, tokenStorage })`에 주입합니다. 클라이언트마다 refresh 단일-flight 상태를 따로 가지므로 웹·저작 도구·모바일 인스턴스가 서로 간섭하지 않습니다.

## 사용법

```ts
import { createApiClient, type TokenStorage } from "@thumbsup/api";

const tokenStorage: TokenStorage = /* 플랫폼 저장소 어댑터 */;
const api = createApiClient({
  baseUrl: "https://thumbsup-api.duckdns.org",
  tokenStorage,
});

const courses = await api.getCourses();
```

루트 export에는 `createApiClient`, `ApiClient`, `TokenStorage`, `Tokens`, 요청·응답 타입, endpoint 타입, `ApiError`, `NetworkError`, `ErrorCode`가 포함됩니다. `apiRequest`, 인증 함수, endpoint 함수는 전역으로 export하지 않으며 생성한 클라이언트 인스턴스에서 꺼내 씁니다.

## entrypoint와 빌드

`package.json`의 `exports["."]`는 `./src/index.ts`를 가리킵니다. #329 스파이크에서 pnpm isolated linker와 Next.js Turbopack이 workspace의 TS 소스를 그대로 소비하는 구성을 검증했습니다. 그래서 별도 빌드 산출물과 `transpilePackages`는 두지 않습니다. 패키지를 외부에 배포하거나 TS 소스 소비를 지원하지 않는 도구를 붙일 때 빌드 entrypoint 도입을 다시 검토합니다.

## 플랫폼 파일 정책

이 패키지에서는 `.native.ts` 확장자를 사용하지 않습니다. API 규격과 refresh 흐름은 플랫폼과 무관하게 유지하고, localStorage·SecureStore 같은 플랫폼별 구현은 각 앱에서 `TokenStorage` 어댑터로 작성해 주입합니다. 플랫폼별 코드가 꼭 필요해지면 resolver의 암묵적인 확장자 선택에 기대지 않고 명시적인 export subpath를 추가합니다.

<!-- HUMANIZE-SUMMARY
원본/윤문본: 1,226자/1,232자, 변경률 4.2%
탐지: A-2 0→0, A-10 0→0, C-2 0→0(기술 목록 예외), D-1 0→0, H-1 0→0, J-1 0→0
자체검증: 6/6 통과
등급: B — S1 잔존 0건, 기술 README의 코드·고유명사·수치를 보존해 변경률이 낮음
주요 변경: "공통으로 쓰는" → "함께 쓰는"; 긴 첫 문단을 세 문장으로 분리; "영향을 주지 않습니다" → "간섭하지 않습니다"; 긴 entrypoint 문장을 분리
-->

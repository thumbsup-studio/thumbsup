---
name: frontend-api
description: 웹·모바일·저작 앱에서 Thumbs Up 백엔드 API를 연동·소비하는 법. 세 앱이 packages/api 한 벌을 공유하므로 규칙도 하나다. 응답 envelope 언랩, Bearer 토큰·TOKEN_EXPIRED 재발급 흐름, 에러 코드 분기, 현재 사용 가능한 엔드포인트, 플랫폼별로 다른 네 가지(토큰 저장·환경변수·폴백·import 경로)를 정리한다. 계약 정본(docs/api-standard·error-spec)은 링크로 참조. 사용자가 "API 어떻게 붙여", "엔드포인트 뭐 있어", "토큰 처리 어떻게 해"라고 할 때 트리거.
---

# frontend-api — API 연동

웹·모바일·저작 앱이 서버 API를 소비하는 진입점. **계약의 정본은 아래 문서** — 이 스킬은 소비 관점만 모은다.

세 앱은 `packages/api` **한 벌을 공유**한다. envelope 언랩·Bearer 부착·`TOKEN_EXPIRED` 재발급·커서 페이지네이션이 `packages/api/src/client.ts` 한 곳에 구현돼 있으므로 **소비 규칙은 플랫폼과 무관하게 같다.** 플랫폼마다 다른 것은 아래 네 가지뿐이다.

## 정본 (계약은 여기서 확인)

- 공통 규격(envelope·인증 정책·CORS·페이지네이션): [`docs/api-standard.md`](../../../docs/api-standard.md)
- 에러 코드 카탈로그·FE 처리 흐름: [`docs/error-spec.md`](../../../docs/error-spec.md)
- 개별 엔드포인트 상세 스펙의 정본: Swagger UI `/swagger-ui.html` (Basic Auth 필요)

## 플랫폼별로 다른 것 (이것만 다르다)

| | `apps/web` · `apps/authoring` | `apps/mobile` |
| --- | --- | --- |
| 토큰 저장 | localStorage (동기) | `expo-secure-store` (**비동기**) |
| 베이스 URL 환경변수 | `NEXT_PUBLIC_API_URL` | `EXPO_PUBLIC_API_URL` |
| 미설정 시 | 운영 API로 폴백 | **시작 시점에 예외를 던진다** |
| 데이터 요청 | `src/lib/api`에서 import | `useApi()`로 받은 `client` |
| 로그인·회원가입·로그아웃 | 같은 클라이언트 메서드 | **`useApi()`의 래퍼**(`client`를 직접 부르지 않는다) |

`packages/api/src/token-storage.ts`가 `MaybePromise<T>` 타입으로 동기·비동기 저장소를 모두 받기 때문에 한 클라이언트가 양쪽을 지원한다.

⚠️ **모바일 인증은 `client`를 직접 부르면 안 된다.** `client.login()`은 토큰만 저장하는데, 모바일의 화면 전환은 `_layout.tsx`의 세션 상태 guard가 결정한다. `api-provider.tsx`의 `login`·`signup`·`logout` 래퍼가 토큰 저장에 더해 profile과 세션 상태까지 갱신하므로 **`useApi()`에서 꺼내 쓴다.** 401을 만난 화면이 `restoreSession()`으로 guard를 재평가시키는 것도 같은 이유다.

## 지금 상태 (작업 전 확인)

- 데이터 페칭 라이브러리 없음 → 순수 `fetch` 기반.
- **토큰 저장 = localStorage**(웹·저작 앱, #1에서 결정). httpOnly cookie는 전체 BFF 프록시가 필요해 범위 밖 — 하드닝 단계에서 재검토. 모바일은 SecureStore를 쓴다.
- 웹·저작 앱은 환경변수 미설정 시 prod 백엔드(`https://thumbsup-api.duckdns.org`)로 폴백한다. 로컬 서버를 직접 띄우는 경우에만 `.env.local`에 `http://localhost:8080`을 설정한다.

## 베이스 URL·접속

- prod API: `https://thumbsup-api.duckdns.org` + 공통 경로 prefix `/api/v1`
- local 서버: `http://localhost:8080` (포트 8080)
- **CORS 현실**: 로컬 FE(3000) → prod 서버 호출을 허용한다. 서버를 로컬에 띄우지 못하는 FE 개발자는 기본값 그대로 prod API를 쓰고, 서버를 직접 띄우는 개발자만 `.env.local`로 local 서버를 지정한다. Vercel preview(`*-thumbsup.vercel.app`)도 prod API를 바라봄.

## 현재 실제로 있는 엔드포인트

| 메서드·경로 | 인증 | body / 응답 data |
|---|---|---|
| POST `/api/v1/auth/signup` | 공개 | `{email,password}` → 201, `{accessToken,refreshToken}` |
| POST `/api/v1/auth/login` | 공개 | `{email,password}` → `{accessToken,refreshToken}` |
| POST `/api/v1/auth/refresh` | 공개 | `{refreshToken}` → `{accessToken,refreshToken}` |
| POST `/api/v1/auth/logout` | Bearer | 없음 → `null` |
| GET `/api/v1/notices` | Bearer | query `cursor?,size?(≤100)` → `{items:[...]}` + `meta` 커서 |
| GET `/api/v1/notices/{id}` | Bearer | → notice 상세 |

위 표는 #1 시점 기준이고 **이미 낡았다.** 그 뒤 quiz·course·history·feedback·`/auth/me`가 구현돼 `packages/api`의 `createApiClient()`가 제공한다. 소셜 로그인은 아직 없다.

**엔드포인트 존재 여부의 정본은 Swagger UI와 서버 컨트롤러 코드**이고, 소비 가능한 메서드의 정본은 `packages/api/src/index.ts`다. 이 표만 보고 "없다"고 단정하지 않는다.

## 소비 규칙 (핵심)

1. **Envelope 언랩**: 모든 응답은 `{code,message,data,meta}`. 성공 `code:"SUCCESS"`. 실제 payload는 `data`, 리스트는 항상 `data.items`, 커서는 `meta.nextCursor`/`meta.hasNext`(opaque — 해석 말고 그대로 전달).
2. **인증 부착**: login/signup/refresh로 받은 `accessToken`을 이후 요청에 `Authorization: Bearer {accessToken}`.
3. **재발급 (1회)**: `401 + code=="TOKEN_EXPIRED"` → `POST /api/v1/auth/refresh` (body `{refreshToken}`) → 새 토큰 저장(**회전식이라 refreshToken도 매번 갱신**) → 원 요청 1회 재시도. 그 외 401(재발급 실패 포함) → 로그인 화면.
4. **에러 분기**: HTTP status로 대분류, `code`로 세분류. `400 + INVALID_INPUT` → `data.fieldErrors[].{field,reason}` 폼 표시. `message`는 한국어 사용자 노출용 기본 문구.

소비 코드 예시(타입·언랩 헬퍼 시그니처 — 처방 아님, 방향 예시):

```ts
type CursorMeta = { hasNext: boolean; nextCursor: string | null };
type ApiResponse<T> = { code: string; message: string; data: T | null; meta: CursorMeta | null };
// unwrap(res): code !== "SUCCESS"면 code로 throw, 아니면 data 반환
```

## 아직 열린 항목

- Server Component vs Client Component fetch 경계 — 웹·저작 앱만 해당 (`next-best-practices` 참조).
- 페칭 라이브러리(TanStack Query 등) 도입 여부.

> 토큰 저장(localStorage)·fetch 래퍼·refresh 인터셉터는 #1에서 확정·구현됨(위 "지금 상태"). BFF+httpOnly cookie 이전은 하드닝 단계에서 별도 검토.

## 하지 말 것

- `userId`를 body/query로 전송 — 서버가 토큰에서 식별(IDOR 방지).
- 204/No-Content 기대 — 삭제도 200 + `data:null`.
- offset 페이지네이션 가정 — 커서 방식만.
- 로컬 서버가 필요하다고 가정하고 `localhost:8080`을 기본값으로 박아두기. local 서버 사용은 `.env.local` override로만 처리한다.
- 공용 클라이언트 계층을 우회한 임시 `fetch` 남발 — envelope 언랩·Bearer·refresh 재발급이 빠진다. 모바일도 같다(`useApi()`의 `client`만 쓴다).

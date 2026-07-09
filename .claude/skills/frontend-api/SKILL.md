---
name: frontend-api
description: 프론트엔드에서 Thumbs Up 백엔드 API를 연동·소비하는 법. 응답 envelope 언랩, Bearer 토큰·TOKEN_EXPIRED 재발급 흐름, 에러 코드 분기, 현재 사용 가능한 엔드포인트, base URL·CORS·env 계획을 정리한다. 계약 정본(docs/api-standard·error-spec)은 링크로 참조. 사용자가 "API 어떻게 붙여", "엔드포인트 뭐 있어", "토큰 처리 어떻게 해"라고 할 때 트리거.
---

# frontend-api — 프론트엔드 API 연동

FE가 서버 API를 소비하는 진입점. **계약의 정본은 아래 문서** — 이 스킬은 소비 관점만 모은다.

## 정본 (계약은 여기서 확인)

- 공통 규격(envelope·인증 정책·CORS·페이지네이션): [`docs/api-standard.md`](../../../docs/api-standard.md)
- 에러 코드 카탈로그·FE 처리 흐름: [`docs/error-spec.md`](../../../docs/error-spec.md)
- 개별 엔드포인트 상세 스펙의 정본: Swagger UI `/swagger-ui.html` (Basic Auth 필요)

## 지금 상태 (작업 전 확인)

- FE API 계층(fetch 래퍼·토큰 저장·refresh 인터셉터)은 **#1(로그인/회원가입)에서 `app/src/lib/api`에 구축**됨(`client.ts`·`auth.ts`·`token-store.ts`·`errors.ts`). 새 API 소비는 이 계층을 재사용한다.
- **토큰 저장 = localStorage** (#1에서 결정, 근거는 `token-store.ts` 주석). httpOnly cookie는 전체 BFF 프록시가 필요해 범위 밖 — 하드닝 단계에서 재검토.
- 데이터 페칭 라이브러리 없음 → 순수 `fetch` 기반.
- `NEXT_PUBLIC_API_URL` 미설정 시 클라이언트는 prod 백엔드(`https://thumbsup-api.duckdns.org`)로 폴백한다. 로컬 개발은 `.env.local`에 `http://localhost:8080` 설정.

## 베이스 URL·접속

- prod API: `https://thumbsup-api.duckdns.org` + 공통 경로 prefix `/api/v1`
- local 서버: `http://localhost:8080` (포트 8080)
- **CORS 현실**: 로컬 FE(3000) → prod 서버 호출은 의도적으로 차단. 로컬에서 API가 필요하면 서버를 로컬로 띄운다. Vercel preview(`*-thumbsup.vercel.app`)는 prod API를 바라봄.

## 현재 실제로 있는 엔드포인트

| 메서드·경로 | 인증 | body / 응답 data |
|---|---|---|
| POST `/api/v1/auth/signup` | 공개 | `{email,password}` → 201, `{accessToken,refreshToken}` |
| POST `/api/v1/auth/login` | 공개 | `{email,password}` → `{accessToken,refreshToken}` |
| POST `/api/v1/auth/refresh` | 공개 | `{refreshToken}` → `{accessToken,refreshToken}` |
| POST `/api/v1/auth/logout` | Bearer | 없음 → `null` |
| GET `/api/v1/notices` | Bearer | query `cursor?,size?(≤100)` → `{items:[...]}` + `meta` 커서 |
| GET `/api/v1/notices/{id}` | Bearer | → notice 상세 |

Quiz·User·소셜 로그인은 **미구현** — 새 엔드포인트는 Swagger로 존재부터 확인.

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

- Server Component vs Client Component fetch 경계 (`next-best-practices` 참조).
- 페칭 라이브러리(TanStack Query 등) 도입 여부.

> 토큰 저장(localStorage)·fetch 래퍼·refresh 인터셉터는 #1에서 확정·구현됨(위 "지금 상태"). BFF+httpOnly cookie 이전은 하드닝 단계에서 별도 검토.

## 하지 말 것

- `userId`를 body/query로 전송 — 서버가 토큰에서 식별(IDOR 방지).
- 204/No-Content 기대 — 삭제도 200 + `data:null`.
- offset 페이지네이션 가정 — 커서 방식만.
- 로컬 FE → prod 서버 직접 호출 (CORS 차단).
- 기존 `src/lib/api` 계층을 우회한 임시 `fetch` 남발 — envelope 언랩·Bearer·refresh 재발급이 빠진다.

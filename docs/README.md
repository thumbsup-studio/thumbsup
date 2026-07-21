# Thumbs Up 개발 문서 (계약)

이 폴더는 FE ↔ 서버가 공유하는 **계약(Contract) 문서 전용**이다.
API를 만들거나 호출하기 전에 먼저 확인한다 (Contract-first).

- [api-standard.md](api-standard.md) — 응답 envelope, HTTP status, 네이밍, 날짜, 페이지네이션, 인증, CORS
- [error-spec.md](error-spec.md) — 에러 응답 형식, ErrorType 코드 체계, 공통 에러 카탈로그, FE 처리 가이드

> **계약 변경은 FE·서버 모두에 파급된다** — 단독 PR로 올리고 양쪽 개발자의 확인을 받는다.

## 내부 문서는 각 모듈에 콜로케이션

역할별 내부 문서는 루트가 아니라 **자기 모듈 트리 안**에서 관리한다 —
코드와 규칙이 같은 PR로 묶이고, AI가 해당 모듈 작업 시 자동으로 발견한다.

| 위치 | 내용 | 진입점 |
|------|------|--------|
| [`server/docs/`](../server/docs/) | 서버 구현 규칙·운영 가이드 (DTO, 예외 구현, 환경변수, [CI 인수인계](../server/docs/ci-requirements.md)) | `server/CLAUDE.md` (AI 자동 로딩 인덱스) |
| `app/docs/` | FE 내부 문서 | `app/` 생성 시 FE 팀이 동일 규칙으로 |

> 예외: [`specs/`](specs/)(설계 사양)·[`plans/`](plans/)(구현 플랜)는 아카이브다(계약 문서 아님).

## 문서 역할 분담 (docs ↔ Swagger)

- **이 폴더(`docs/`)** = 계약·규격의 정본. "모든 API가 따라야 하는 규칙"을 정의한다.
- **Swagger UI (springdoc)** = 개별 API 엔드포인트의 레퍼런스. 서버 코드에서 자동 생성되므로 "지금 어떤 API가 있는지"는 Swagger가 정본이다.

> 개별 엔드포인트 명세를 이 폴더에 수기로 복사하지 않는다 — 코드와 문서가 어긋나는(drift) 원인이 된다.

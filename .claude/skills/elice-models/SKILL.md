---
name: elice-models
description: 엘리스 AX ML API(OpenAI 호환 프록시)로 Gemini 3.1 Pro·GPT-5.4·GPT-5 mini를 호출·설정할 때 사용. 엔드포인트·API 키·모델 ID 규칙, 용도별(시각 QA·문제 해설 생성·대량 생성) 모델 선택, Secret/SSM/.env.local 보관 정책을 알아야 할 때. 사용자가 "엘리스 모델 어떻게 불러", "API 키 어디에 둬", "엔드포인트 뭐야"라고 할 때도 트리거.
---

# elice-models — 엘리스 AX 모델 사용 규약

엘리스 AX가 발급한 ML API는 **OpenAI 호환 프록시**(MSP, `mlapi.run`). 기존 OpenAI SDK / `fetch`에서 **base URL만 바꾸면** 그대로 호출된다.

## 용도별 모델 (2026-07-08 스프린트 발급)

발급 **API 키 1개**가 3개 모델 공용. 엔드포인트는 **모델마다 다른** 프록시(`https://mlapi.run/<배포ID>/v1`).

| 용도 | 모델 ID | 소비처 | 설정 보관처 |
|---|---|---|---|
| 시각 QA (이미지 입력) | `google/gemini-3.1-pro-preview` | app CI `visual-qa` job · 로컬 | GitHub Secret + 개인 `.env.local` |
| 문제·해설 생성 | `openai/gpt-5.4` | server(Spring) — 예정 | SSM `/thumbsup/prod/*` |
| 대량 문제 생성 | `openai/gpt-5-mini`(실호출로 확인) | 배치/스크립트 — 예정 | 소비자 확정 시 결정 |

> **실제 배포 ID(UUID)와 API 키는 이 public 레포에 절대 커밋하지 않는다.** 값은 GitHub Secret / SSM / 개인 `.env.local` / 엘리스 모델 라이브러리의 각 모델 페이지에서 확인. (레포 공개라 노출 시 키 회수·오용 위험)

## 호출 방법 (OpenAI 호환)

- **base URL**: `https://mlapi.run/<배포ID>/v1` — 반드시 `/v1`까지.
- **엔드포인트**: `POST {base}/chat/completions` (Chat), `POST {base}/responses` (Responses), `GET {base}/health`.
- **헤더**: `Authorization: Bearer <API_KEY>`, `Content-Type: application/json`.
- body의 `model`은 위 표의 모델 ID를 **정확히**.

⚠️ 모델 라이브러리의 "빠른 복사(python/typescript/cURL)" 스니펫은 `https://mlapi.run/<ID>`(‥`/v1` 없이)로 raw POST하는 **범용 템플릿**(`{PAYLOAD}`·`{API_KEY}`가 자리표시자)이다. OpenAI 호환으로 쓰려면 **`/v1`을 붙이고 `/chat/completions`까지** 지정한다. (GPT-5.4 OpenAI-호환 문서가 `base_url=".../v1"`로 안내하는 것과 동일)

```ts
const res = await fetch(`${ELICE_QA_BASE_URL}/chat/completions`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${ELICE_API_KEY}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    model: "google/gemini-3.1-pro-preview",
    messages: [{ role: "user", content: "..." }],
  }),
});
```

## 환경변수 규칙

- **키는 공용**: `ELICE_API_KEY` (모든 모델 공유).
- **base URL·모델은 용도별**: `ELICE_QA_BASE_URL`·`ELICE_QA_MODEL`(시각 QA). 새 용도가 생기면 같은 패턴 `ELICE_<용도>_BASE_URL`. 엔드포인트가 모델마다 달라 공통 `ELICE_BASE_URL`은 쓰지 않는다.

## 보관 정책

- **public 레포라 키·엔드포인트 둘 다 노출 금지.** GitHub에는 Secret(`ELICE_API_KEY`·`ELICE_QA_BASE_URL`), Variable에는 비민감값(`ELICE_QA_MODEL`)만.
- **로컬**: `app/.env.local`(gitignored). `app/.env.example`를 복사해 채운다(`cp .env.example .env.local`).
- **server**: SSM Parameter Store `/thumbsup/prod/*`.
- gitleaks CI가 커밋 유출을 2차 방어.

## 인증 동작 (디버깅 팁)

게이트웨이는 **키를 먼저 검증**한다. 유효하지 않은 키면 경로가 진짜든 가짜든 전부 `401 {"error":{"code":"verification_failed_key"}}`. 따라서 **키 없이는 엔드포인트 진위를 판별할 수 없다** — 진짜 여부는 유효 키로 `200`(성공) vs `404`(경로 없음)로 확인한다.

## 비용

serverless **종량제**(무제한 아님, 스프린트 제공 리소스로 충당). 예: GPT-5.4 ₩3,937.5/1M input · ₩23,625/1M output.

## 스모크 테스트

```bash
cd app && set -a && . ./.env.local && set +a
curl -sS -X POST "$ELICE_QA_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $ELICE_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"'"$ELICE_QA_MODEL"'","messages":[{"role":"user","content":"ping"}]}'
```
정상: `choices[]` 포함 JSON. `401`=키 문제, `404`=엔드포인트/`v1` 경로 문제.

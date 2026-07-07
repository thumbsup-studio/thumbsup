# Swagger/OpenAPI 접근 정책

Swagger/OpenAPI는 FE 협업용 API 레퍼런스다. FE 개발자에게 로컬 Docker 서버를 띄워 Swagger를 보라고
요구하지 않는다. 대신 운영 서버의 Swagger를 제공하되 public 공개는 금지한다.

## 1. 접근 방식

| 대상 | URL |
|------|-----|
| 운영 API 문서 | `https://{prod-api-domain}/swagger-ui.html` |
| 운영 OpenAPI JSON | `https://{prod-api-domain}/v3/api-docs` |
| 서버 개발자 로컬 Swagger | `http://localhost:8080/swagger-ui.html` |

운영 API 도메인이 확정되면 `{prod-api-domain}`을 실제 도메인으로 교체해 팀 채널과 README에 공유한다.

## 2. 보안 정책

- `/swagger-ui/**`, `/swagger-ui.html`, `/v3/api-docs`, `/v3/api-docs/**`, `/v3/api-docs.yaml`은 Basic Auth로 보호한다.
- IP 제한과 VPN은 쓰지 않는다. FE 개발자의 접근 제약이 커지기 때문이다.
- Swagger Basic Auth 계정은 API 로그인 계정이 아니다. 문서 접근 전용 계정이다.
- Swagger 화면의 `Authorize` 버튼에 넣는 Bearer JWT는 API 테스트용이다. Basic Auth와 목적이 다르다.
- 운영 API 문서를 public으로 공개하지 않는다. 검색엔진, 외부 링크, 공개 위키에 Swagger URL과 계정을 올리지 않는다.

## 3. 계정 관리

| 환경 | SSM 키 |
|------|--------|
| local username | `/thumbsup/local/SWAGGER_USERNAME` |
| local password | `/thumbsup/local/SWAGGER_PASSWORD` |
| prod username | `/thumbsup/prod/SWAGGER_USERNAME` |
| prod password | `/thumbsup/prod/SWAGGER_PASSWORD` |

계정 값은 Parameter Store에서 관리한다. 비밀번호는 `SecureString`으로 저장한다.
운영 Swagger 계정 공유는 팀의 승인된 비밀 공유 채널을 사용하고, PR/이슈/문서에 평문을 남기지 않는다.

## 4. 변경 시 체크

Swagger 접근 정책을 바꾸는 PR은 다음을 같이 확인한다.

- `SecurityConfig`에서 Swagger 경로가 일반 `permitAll`에 포함되어 있지 않은가
- Swagger 전용 Basic Auth 프로퍼티가 local/prod 모두 fail-fast로 주입되는가
- `/swagger-ui.html`, `/swagger-ui/**`, `/v3/api-docs`, `/v3/api-docs/**`, `/v3/api-docs.yaml` 무인증 요청이 401과 `WWW-Authenticate: Basic`으로 응답하는가
- prod에서 `springdoc.api-docs.enabled`와 `springdoc.swagger-ui.enabled`가 켜져 있는가
- 계정/비밀번호가 코드, 테스트 로그, PR 본문에 노출되지 않았는가

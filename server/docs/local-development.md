# 로컬 개발 가이드

이 문서는 서버 개발자가 로컬에서 Thumbs Up 서버를 실행하는 절차다.
FE 개발자는 로컬 서버 실행과 AWS 설정 대상이 아니다. FE 개발자는 운영 Swagger URL을 통해 API 명세를 확인한다.

## 1. 준비물

- Java 21
- Docker Desktop
- AWS CLI
- AWS 권한이 연결된 named profile
- IntelliJ IDEA 또는 Java 21을 지원하는 IDE

## 2. AWS profile 준비

```bash
aws configure --profile thumbsup
export AWS_PROFILE=thumbsup
export AWS_REGION=ap-northeast-2

aws sts get-caller-identity
aws ssm get-parameters-by-path --path "/thumbsup/local/" --with-decryption
```

local profile은 `/thumbsup/local/*`만 읽는다. prod 값을 로컬 실행에 쓰지 않는다.

## 3. MySQL 실행

```bash
cd server
docker compose up -d mysql
docker compose ps
```

로컬 DB 접속정보는 SSM이 아니라 `docker-compose.yml`과 `application-local.yml`의 고정값을 사용한다.

## 4. 서버 실행

```bash
cd server
./gradlew bootRun
```

프로파일을 지정하지 않으면 `local`이 기본이다. local profile은 `/thumbsup/local/` SSM을 읽으므로
AWS profile이 없거나 SSM 권한이 없으면 부팅이 실패한다.

## 5. 확인 URL

| 용도 | URL |
|------|-----|
| 헬스체크 | `http://localhost:8080/actuator/health` |
| Swagger UI | `http://localhost:8080/swagger-ui.html` |
| OpenAPI JSON | `http://localhost:8080/v3/api-docs` |

Swagger는 local에서도 Basic Auth가 필요하다. 계정은 `/thumbsup/local/SWAGGER_USERNAME`,
`/thumbsup/local/SWAGGER_PASSWORD`에서 주입된다.

## 6. 앱 컨테이너 실행이 필요한 경우

일반 서버 개발은 `docker compose up -d mysql` + `./gradlew bootRun`을 우선한다.
앱까지 컨테이너로 띄우는 경로는 Docker 이미지 동작 확인용이다.

```bash
cd server
AWS_PROFILE=thumbsup AWS_REGION=ap-northeast-2 docker compose up --build
```

이 경로도 local SSM을 읽는다. 호스트의 AWS profile이 컨테이너에 읽히도록 `docker-compose.yml`에서
`~/.aws`를 읽기 전용으로 마운트한다.

## 7. 종료

```bash
cd server
docker compose down
```

DB 볼륨까지 지우려면 `docker compose down -v`를 사용한다.

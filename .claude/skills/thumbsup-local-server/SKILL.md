---
name: thumbsup-local-server
description: Thumbs Up Spring Boot 서버를 로컬에서 실행·검증할 때 사용. main 받기, 로컬 AWS 프로파일/Parameter Store 준비 상태 확인, Docker MySQL 기동, `server/`를 `./gradlew bootRun`으로 실행, health/Swagger 확인, 로컬 서버 기동 트러블슈팅이 필요할 때. 로컬 머신 전용이며 시크릿을 출력하거나 레포 파일을 스테이징하지 않는다.
---

# Thumbs Up 로컬 서버

Thumbs Up 모노레포에서 `server/`를 로컬로 실행할 때 이 스킬을 사용한다.

절대 규칙:
- AWS 액세스 키, 시크릿 키, SSM 파라미터 값, `~/.aws/credentials`를 출력하지 않는다.
- `git add`, `git commit`, `git push`를 실행하지 않는다.
- 파일이 예기치 않게 변경되면, 다른 작업을 하기 전에 멈추고 먼저 보고한다.
- 명령이 내부적으로 값을 필요로 하는 경우가 아니면, SSM 파라미터는 값이 아니라 이름만 조회한다.

## 준비 상태 확인

레포 루트에서:

```bash
git status --short --branch
git branch --show-current
```

워크트리가 깨끗하고 사용자가 최신 `main`을 원하면:

```bash
git checkout main
git pull --ff-only
```

로컬 도구 확인:

```bash
cd server
./gradlew -q javaToolchains
docker --version
docker compose version
docker info --format '{{.ServerVersion}}'
aws --version
aws configure list-profiles
```

기대 상태:
- Java 21이 설치돼 있거나 Gradle 툴체인으로 사용 가능하다.
- Docker 데몬이 실행 중이다. `docker info`가 실패하면 사용자에게 Docker Desktop을 켜달라고 요청한다.
- `aws configure list-profiles`에 `thumbsup`이 나타난다.

## AWS 프로파일 확인

크리덴셜 파일은 절대 표시하지 않는다. 신원과 파라미터 이름만 검증한다:

```bash
aws sts get-caller-identity --profile thumbsup --region ap-northeast-2

aws ssm get-parameters-by-path \
  --path "/thumbsup/local/" \
  --profile thumbsup \
  --with-decryption \
  --region ap-northeast-2 \
  --query "Parameters[].Name" \
  --output table
```

필수 로컬 SSM 키 (모두 필수 — `application-local.yml`이 `aws-parameterstore:/thumbsup/local/`를 non-optional로 import하므로 하나라도 없으면 기동 실패):

```text
/thumbsup/local/JWT_SECRET
/thumbsup/local/SWAGGER_USERNAME
/thumbsup/local/SWAGGER_PASSWORD
/thumbsup/local/ELICE_API_KEY
/thumbsup/local/ELICE_QUIZ_BASE_URL
/thumbsup/local/ELICE_QUIZ_MODEL
```

`/thumbsup/local/DB_PASSWORD`가 존재할 수 있으나, 로컬 DB 크리덴셜은 `server/docker-compose.yml`과 `application-local.yml`에 하드코딩돼 있다.

## 로컬 서버 기동

일반 개발에서는 호스트 JVM 경로를 사용한다:

```bash
cd server
export AWS_PROFILE=thumbsup
export AWS_REGION=ap-northeast-2
docker compose up -d mysql
docker compose ps
./gradlew bootRun
```

`bootRun`은 계속 실행 상태로 둔다. 다른 터미널이나 도구 호출에서 확인한다:

```bash
curl -fsS http://localhost:8080/actuator/health
```

기대 응답:

```json
{"status":"UP"}
```

Swagger URL:

```text
http://localhost:8080/swagger-ui.html
http://localhost:8080/v3/api-docs
```

Swagger는 Basic Auth가 필요하다. 로컬 사용자명/비밀번호는 승인된 시크릿 채널이나 SSM에서 가져오되, 채팅이나 로그에 출력하지 않는다.

## 트러블슈팅

- Docker 데몬 에러: Docker Desktop을 켠 뒤 `docker info`를 다시 실행한다.
- MySQL 포트 충돌: `lsof -nP -iTCP:3306 -sTCP:LISTEN`으로 확인한다.
- 서버 포트 충돌: `lsof -nP -iTCP:8080 -sTCP:LISTEN`으로 확인한다.
- SSM 임포트 실패: `AWS_PROFILE=thumbsup`, `AWS_REGION=ap-northeast-2`, `/thumbsup/local/*` 접근 권한을 확인한다. SecureString(`JWT_SECRET`·`SWAGGER_PASSWORD`·`ELICE_API_KEY`)은 `ssm:GetParametersByPath`에 더해 **`kms:Decrypt`** 권한이 있어야 `--with-decryption`으로 읽힌다 — 부팅 실패 시 1순위 확인.
- Flyway/JPA 스키마 에러: 사용자가 동의할 때만 로컬 DB를 재생성한다:
  ```bash
  docker compose down -v
  docker compose up -d mysql
  ```

## 마무리

작업이 끝나면:

```bash
cd server
docker compose down
```

완료 보고 전:

```bash
git status --short --branch
```

health URL 결과와 워크트리가 변경되지 않은 채로 유지됐는지를 보고한다.

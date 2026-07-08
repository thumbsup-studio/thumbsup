# 빌드 스테이지 — toolchain(21)과 일치하는 JDK로 wrapper 빌드
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle gradle
# 의존성 레이어 캐시 (소스 변경 시 재다운로드 방지)
RUN ./gradlew --no-daemon dependencies --quiet > /dev/null 2>&1 || true
COPY config config
COPY src src
RUN ./gradlew --no-daemon bootJar

# 실행 스테이지 — JRE만
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
# 루트가 아닌 최소 권한 유저로 실행 (컨테이너 탈출 시 피해 축소)
# local 컨테이너 스모크 실행 시 ~/.aws profile을 읽을 수 있도록 홈 디렉터리는 만든다.
RUN useradd --system --create-home --home-dir /home/appuser --shell /usr/sbin/nologin appuser
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

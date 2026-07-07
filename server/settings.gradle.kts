plugins {
    // JDK 21 미설치 머신에서도 toolchain이 자동 프로비저닝되도록
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "thumbsup-server"

const { withAppBuildGradle } = require("expo/config-plugins");

const releaseSigningConfig = `        ciRelease {
            if (project.hasProperty('THUMBSUP_UPLOAD_STORE_FILE')) {
                storeFile file(project.property('THUMBSUP_UPLOAD_STORE_FILE'))
                storePassword project.property('THUMBSUP_UPLOAD_STORE_PASSWORD')
                keyAlias project.property('THUMBSUP_UPLOAD_KEY_ALIAS')
                keyPassword project.property('THUMBSUP_UPLOAD_KEY_PASSWORD')
            }
        }`;

function withCiAndroidSigning(config) {
  return withAppBuildGradle(config, (gradleConfig) => {
    if (gradleConfig.modResults.language !== "groovy") {
      throw new Error("with-ci-android-signing은 Groovy build.gradle만 지원합니다.");
    }

    let source = gradleConfig.modResults.contents;
    const debugConfigEnd = `        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
    }`;

    if (!source.includes("ciRelease {")) {
      if (!source.includes(debugConfigEnd)) {
        throw new Error("Android signingConfigs 블록을 찾지 못했습니다.");
      }
      source = source.replace(
        debugConfigEnd,
        `${debugConfigEnd.slice(0, -6)}\n${releaseSigningConfig}\n    }`,
      );
    }

    const defaultReleaseSigning = `        release {
            // Caution! In production, you need to generate your own keystore file.
            // see https://reactnative.dev/docs/signed-apk-android.
            signingConfig signingConfigs.debug`;
    const ciReleaseSigning = `        release {
            signingConfig project.hasProperty('THUMBSUP_UPLOAD_STORE_FILE') ? signingConfigs.ciRelease : signingConfigs.debug`;

    if (source.includes(defaultReleaseSigning)) {
      source = source.replace(defaultReleaseSigning, ciReleaseSigning);
    } else if (!source.includes(ciReleaseSigning)) {
      throw new Error("Android release signingConfig 블록을 찾지 못했습니다.");
    }

    gradleConfig.modResults.contents = source;
    return gradleConfig;
  });
}

module.exports = withCiAndroidSigning;

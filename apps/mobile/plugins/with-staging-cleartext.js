const { withAndroidManifest } = require("expo/config-plugins");

module.exports = function withStagingCleartext(config) {
  if (config.extra?.appEnvironment !== "staging") {
    throw new Error("with-staging-cleartext must only be enabled for the staging profile");
  }
  return withAndroidManifest(config, (nextConfig) => {
    const application = nextConfig.modResults.manifest.application?.[0];
    if (!application) throw new Error("AndroidManifest application is missing");
    application.$ = application.$ ?? {};
    application.$["android:usesCleartextTraffic"] = "true";
    return nextConfig;
  });
};

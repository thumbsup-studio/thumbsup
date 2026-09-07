const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");
const path = require("node:path");

const config = getDefaultConfig(__dirname);

if (process.env.APP_ENV !== "staging") {
  const productionStub = path.resolve(__dirname, "src/features/dev-channels/production-stub.tsx");
  config.resolver.resolveRequest = (context, moduleName, platform) => {
    if (moduleName.includes("features/dev-channels/")) {
      return { filePath: productionStub, type: "sourceFile" };
    }
    return context.resolveRequest(context, moduleName, platform);
  };
}

module.exports = withNativeWind(config, { input: "./src/global.css" });

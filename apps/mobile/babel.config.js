function inlineAppEnvironment({ types }) {
  return {
    name: "inline-app-environment",
    visitor: {
      MemberExpression(path) {
        const node = path.node;
        if (
          !node.computed &&
          types.isIdentifier(node.property, { name: "APP_ENV" }) &&
          types.isMemberExpression(node.object) &&
          !node.object.computed &&
          types.isIdentifier(node.object.object, { name: "process" }) &&
          types.isIdentifier(node.object.property, { name: "env" })
        ) {
          path.replaceWith(types.stringLiteral(process.env.APP_ENV || "development"));
        }
      },
    },
  };
}

module.exports = function babelConfig(api) {
  api.cache(true);
  return {
    presets: [["babel-preset-expo", { jsxImportSource: "nativewind" }], "nativewind/babel"],
    plugins: [inlineAppEnvironment],
  };
};

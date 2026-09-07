import { keyframes, tokens } from "./index";

type CssDeclarations = Record<string, string>;

function renderDeclarations(declarations: CssDeclarations, indent: string): string {
  return Object.entries(declarations)
    .map(([property, value]) => `${indent}${property}: ${value};`)
    .join("\n");
}

export function renderWebTheme(): string {
  const variables = Object.entries(tokens).flatMap(([group, values]) =>
    Object.entries(values).map(([name, value]) => `  --${group}-${name}: ${value};`),
  );
  const frames = Object.entries(keyframes).map(([name, stops]) => {
    const renderedStops = Object.entries(stops)
      .map(
        ([stop, declarations]) =>
          `    ${stop} {\n${renderDeclarations(declarations as CssDeclarations, "      ")}\n    }`,
      )
      .join("\n");
    return `  @keyframes ${name} {\n${renderedStops}\n  }`;
  });

  return `/* 이 파일은 pnpm --filter @thumbsup/tokens generate로 생성합니다. 직접 수정하지 마세요. */\n@theme {\n${variables.join("\n")}\n${frames.join("\n")}\n}\n`;
}

export function renderNativeWindV4Preset(): string {
  const preset = {
    theme: {
      extend: {
        colors: tokens.color,
        borderRadius: tokens.radius,
        boxShadow: tokens.shadow,
        fontFamily: tokens.font,
        animation: tokens.animate,
        keyframes,
      },
    },
  };
  return `// 이 파일은 pnpm --filter @thumbsup/tokens generate로 생성합니다. 직접 수정하지 마세요.\nmodule.exports = ${JSON.stringify(preset, null, 2)};\n`;
}

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url)); // apps/authoring/
const SRC = join(ROOT, "src");
const UI_WEB = fileURLToPath(new URL("../../../packages/ui-web", import.meta.url));
const TOKENS = fileURLToPath(new URL("../../../packages/tokens", import.meta.url));

// 색상 길이(3/4/6/8)의 raw hex
const HEX = /#[0-9a-fA-F]{8}\b|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{4}\b|#[0-9a-fA-F]{3}\b/;
// Tailwind arbitrary value: `something-[...]`
const ARBITRARY = /\b[a-z][a-z-]*-\[[^\]]+\]/;

export function findStyleViolations(source, file) {
  const out = [];
  source.split("\n").forEach((line, i) => {
    if (line.includes("design-ok")) return;
    const hex = line.match(HEX);
    if (hex) out.push({ file, line: i + 1, kind: "raw-hex", text: hex[0] });
    const arb = line.match(ARBITRARY);
    if (arb) out.push({ file, line: i + 1, kind: "arbitrary-value", text: arb[0] });
  });
  return out;
}

export function findMissingStories(uiFileNames) {
  const isComponent = (f) => f.endsWith(".tsx") && !f.endsWith(".stories.tsx");
  const stories = new Set(uiFileNames.filter((f) => f.endsWith(".stories.tsx")));
  return uiFileNames
    .filter(isComponent)
    .filter((f) => !stories.has(f.replace(/\.tsx$/, ".stories.tsx")))
    .map((f) => ({ component: f, expected: f.replace(/\.tsx$/, ".stories.tsx") }));
}

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (/\.tsx?$/.test(name)) out.push(p);
  }
  return out;
}

function main() {
  const files = [...walk(SRC), ...walk(join(UI_WEB, "src"))];
  const style = files.flatMap((f) =>
    findStyleViolations(readFileSync(f, "utf8"), relative(ROOT, f)),
  );

  let missing = [];
  try {
    const components = readdirSync(join(UI_WEB, "src"));
    const stories = readdirSync(join(UI_WEB, "stories"));
    missing = findMissingStories([...components, ...stories]);
  } catch {
    /* packages/ui-web 아직 없음 */
  }

  const globals = readFileSync(join(SRC, "app", "globals.css"), "utf8");
  const generatedTheme = join(TOKENS, "generated", "web-theme.css");
  if (!globals.includes('@import "@thumbsup/tokens/web.css"')) {
    style.push({
      file: "src/app/globals.css",
      line: 1,
      kind: "token-source",
      text: "공용 토큰 import 누락",
    });
  }
  try {
    readFileSync(generatedTheme, "utf8");
  } catch {
    style.push({
      file: relative(ROOT, generatedTheme),
      line: 1,
      kind: "token-source",
      text: "웹 토큰 생성물 누락",
    });
  }

  if (style.length === 0 && missing.length === 0) {
    console.log("✅ check-design: 위반 없음");
    return;
  }
  for (const v of style) console.error(`🔴 ${v.file}:${v.line} ${v.kind} → ${v.text}`);
  for (const m of missing)
    console.error(`🔴 packages/ui-web/src/${m.component}: 스토리 누락 (${m.expected} 필요)`);
  console.error(
    `\n총 ${style.length + missing.length}건 — 토큰/컴포넌트 규칙 위반. // design-ok 로만 예외.`,
  );
  process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();

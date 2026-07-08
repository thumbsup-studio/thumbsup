import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url)); // app/
const SRC = join(ROOT, "src");

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
  const isComponent = (f) =>
    f.endsWith(".tsx") && !f.endsWith(".stories.tsx");
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
  const files = walk(SRC);
  const style = files.flatMap((f) => findStyleViolations(readFileSync(f, "utf8"), relative(ROOT, f)));

  let missing = [];
  try {
    missing = findMissingStories(readdirSync(join(SRC, "components", "ui")));
  } catch {
    /* components/ui 아직 없음 */
  }

  if (style.length === 0 && missing.length === 0) {
    console.log("✅ check-design: 위반 없음");
    return;
  }
  for (const v of style) console.error(`🔴 ${v.file}:${v.line} ${v.kind} → ${v.text}`);
  for (const m of missing) console.error(`🔴 components/ui/${m.component}: 스토리 누락 (${m.expected} 필요)`);
  console.error(`\n총 ${style.length + missing.length}건 — 토큰/컴포넌트 규칙 위반. // design-ok 로만 예외.`);
  process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();

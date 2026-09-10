import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const INTERACTIVE_ELEMENTS = new Set([
  "Pressable",
  "TouchableOpacity",
  "TouchableHighlight",
  "Button",
  "TextInput",
  "Switch",
]);

function findTagEnd(source, start) {
  let braceDepth = 0;
  let quote = null;
  for (let index = start; index < source.length; index += 1) {
    const character = source[index];
    const previous = source[index - 1];
    if (quote) {
      if (character === quote && previous !== "\\") quote = null;
      continue;
    }
    if (character === '"' || character === "'" || character === "`") {
      quote = character;
      continue;
    }
    if (character === "{") braceDepth += 1;
    if (character === "}") braceDepth = Math.max(0, braceDepth - 1);
    if (character === ">" && braceDepth === 0) return index;
  }
  return -1;
}

function findClosingTag(source, element, openingEnd) {
  const token = new RegExp(`<\\/?${element}\\b`, "g");
  token.lastIndex = openingEnd + 1;
  let depth = 1;
  for (let match = token.exec(source); match; match = token.exec(source)) {
    const closing = source[match.index + 1] === "/";
    if (closing) {
      depth -= 1;
      if (depth === 0) return match.index;
      continue;
    }
    const nestedEnd = findTagEnd(source, token.lastIndex);
    if (nestedEnd === -1) return -1;
    if (!/\/\s*>$/.test(source.slice(match.index, nestedEnd + 1))) depth += 1;
    token.lastIndex = nestedEnd + 1;
  }
  return -1;
}

function hasLiteralText(source) {
  const withoutComments = source.replace(/\{\/\*[\s\S]*?\*\/\}/g, "");
  const textNodes = withoutComments.matchAll(/>([^<]+)</g);
  for (const [, text] of textNodes) {
    const literal = text
      .replace(/\{[\s\S]*?\}/g, "")
      .replace(/&[a-z]+;/gi, "x")
      .trim();
    if (literal) return true;
  }
  return false;
}

function hasA11yException(lines, lineIndex) {
  const exception = /\/\/\s*a11y-ok:\s*\S/;
  return exception.test(lines[lineIndex] ?? "") || exception.test(lines[lineIndex - 1] ?? "");
}

export function scanSource(source, file = "source.tsx") {
  const violations = [];
  const lines = source.split("\n");
  const opening = /<([A-Za-z][\w.]*)\b/g;

  for (let match = opening.exec(source); match; match = opening.exec(source)) {
    const element = match[1];
    if (!INTERACTIVE_ELEMENTS.has(element)) continue;
    const previous = source[match.index - 1];
    if (previous && /[\w$]/.test(previous)) continue;

    const tagEnd = findTagEnd(source, opening.lastIndex);
    if (tagEnd === -1) continue;
    const tag = source.slice(match.index, tagEnd + 1);
    const line = source.slice(0, match.index).split("\n").length;
    const lineIndex = line - 1;
    opening.lastIndex = tagEnd + 1;
    if (hasA11yException(lines, lineIndex)) continue;

    const missing = [];
    if (!/\baccessibilityRole\s*=/.test(tag)) missing.push("accessibilityRole");
    const hasLabel = /\baccessibilityLabel\s*=/.test(tag);
    const selfClosing = /\/\s*>$/.test(tag);
    const closingTag = selfClosing ? -1 : findClosingTag(source, element, tagEnd);
    const body = closingTag === -1 ? "" : source.slice(tagEnd + 1, closingTag);
    if (!hasLabel && !hasLiteralText(`>${body}<`))
      missing.push("accessibilityLabel 또는 리터럴 텍스트");

    if (missing.length > 0) violations.push({ element, file, line, missing });
  }
  return violations;
}

async function collectTsxFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) return collectTsxFiles(target);
      return entry.isFile() && entry.name.endsWith(".tsx") ? [target] : [];
    }),
  );
  return nested.flat();
}

export async function checkDirectory(directory) {
  const files = await collectTsxFiles(directory);
  const violations = [];
  for (const file of files.sort()) {
    violations.push(...scanSource(await readFile(file, "utf8"), file));
  }
  return violations;
}

const isCli = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isCli) {
  const sourceDirectory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../src");
  const violations = await checkDirectory(sourceDirectory);
  for (const violation of violations) {
    const relative = path.relative(process.cwd(), violation.file);
    console.error(
      `${relative}:${violation.line} ${violation.element} ${violation.missing.join(", ")}`,
    );
  }
  if (violations.length > 0) {
    console.error(`접근성 위반 ${violations.length}건`);
    process.exitCode = 1;
  } else {
    console.log("접근성 위반 0건");
  }
}

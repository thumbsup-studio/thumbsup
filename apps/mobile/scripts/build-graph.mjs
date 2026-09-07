import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

const mobileRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const rendererRoot = resolve(mobileRoot, "graph-renderer");
const outputFile = resolve(mobileRoot, "assets/graph/index.html");

await build({
  root: rendererRoot,
  logLevel: "warn",
  plugins: [viteSingleFile()],
  build: {
    emptyOutDir: true,
    outDir: dirname(outputFile),
    target: "safari15",
  },
});

let html = await readFile(outputFile, "utf8");
const hash = (source) => `'sha256-${createHash("sha256").update(source).digest("base64")}'`;
const scriptHashes = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map((match) =>
  hash(match[1]),
);
const styleHashes = [...html.matchAll(/<style(?:\s[^>]*)?>([\s\S]*?)<\/style>/g)].map((match) =>
  hash(match[1]),
);

if (scriptHashes.length === 0 || html.includes('src="/')) {
  throw new Error("그래프 번들이 단일 HTML로 생성되지 않았습니다.");
}

const csp = [
  "default-src 'none'",
  `script-src ${scriptHashes.join(" ")}`,
  `style-src ${styleHashes.join(" ")}`,
  "img-src data:",
  "connect-src 'none'",
  "font-src 'none'",
  "media-src 'none'",
  "object-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join("; ");

html = html.replace("__GRAPH_CSP__", csp);
await writeFile(outputFile, html);
console.log(`그래프 번들 생성: ${outputFile} (${Buffer.byteLength(html)} bytes)`);

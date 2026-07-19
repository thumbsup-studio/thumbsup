import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

export type SpecSection = { file: string; heading: string; ids: string[]; body: string };

const ID_RE = /\b(?:[FPWHQ]|PG)-\d{2}\b|#\d{1,4}\b/g;

export function buildIndex(specDir: string): SpecSection[] {
  const sections: SpecSection[] = [];
  for (const name of readdirSync(specDir).filter((f) => f.endsWith(".md")).sort()) {
    const lines = readFileSync(join(specDir, name), "utf8").split("\n");
    let heading = name;
    let body: string[] = [];
    const flush = () => {
      const text = body.join("\n").trim();
      if (text) sections.push({ file: name, heading, ids: [...new Set(`${heading}\n${text}`.match(ID_RE) ?? [])], body: text });
    };
    for (const line of lines) {
      const h = line.match(/^#{2,3}\s+(.+)/);
      if (h) {
        flush();
        heading = h[1]!.trim();
        body = [];
      } else body.push(line);
    }
    flush();
  }
  return sections;
}

export function search(index: SpecSection[], query: string, limit = 5): SpecSection[] {
  const queryIds = new Set(query.match(ID_RE) ?? []);
  const tokens = query.split(/[\s?.,!·]+/).filter((t) => t.length >= 2);
  const scored = index.map((s) => {
    const idScore = [...queryIds].filter((id) => s.ids.includes(id)).length * 100;
    const tokenScore = tokens.filter((t) => s.body.includes(t) || s.heading.includes(t)).length;
    return { s, score: idScore + tokenScore };
  });
  return scored.filter((x) => x.score > 0).sort((a, b) => b.score - a.score).slice(0, limit).map((x) => x.s);
}

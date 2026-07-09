import type { ReactNode } from "react";

type CodeBlockProps = {
  code: string;
  languageLabel: string;
};

const keywordPattern = /\b(const|let|function|return|try|finally|lock|acquire|release)\b/g;

function highlightLine(line: string) {
  const nodes: ReactNode[] = [];
  let lastIndex = 0;

  for (const match of line.matchAll(keywordPattern)) {
    const word = match[0];
    const start = match.index;

    if (start > lastIndex) {
      nodes.push(line.slice(lastIndex, start));
    }

    nodes.push(
      <span className="text-blue-700" key={`${word}-${start}`}>
        {word}
      </span>,
    );
    lastIndex = start + word.length;
  }

  if (lastIndex < line.length) {
    nodes.push(line.slice(lastIndex));
  }

  return nodes.length > 0 ? nodes : line;
}

function getCodeLines(code: string) {
  const seenLines = new Map<string, number>();

  return code.split("\n").map((line) => {
    const seenCount = seenLines.get(line) ?? 0;
    seenLines.set(line, seenCount + 1);

    return {
      key: `${line}-${seenCount}`,
      line,
    };
  });
}

export function CodeBlock({ code, languageLabel }: CodeBlockProps) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-slate-950 text-slate-100 shadow-inner">
      <div className="flex items-center justify-between border-slate-800 border-b px-4 py-2 text-[0.68rem] font-semibold text-slate-400 uppercase">
        <span>{languageLabel}</span>
        <span>code</span>
      </div>
      <pre className="overflow-x-auto px-4 py-4 text-[0.82rem] leading-6 [tab-size:2]">
        <code>
          {getCodeLines(code).map(({ key, line }) => (
            <span className="block min-w-max" key={key}>
              {highlightLine(line)}
            </span>
          ))}
        </code>
      </pre>
    </div>
  );
}
